# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "newsapiVpc"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "newsapi-igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  count = length(var.public_subnets_cidr)
  cidr_block = element(var.public_subnets_cidr,count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${element(data.aws_availability_zones.available.names, count.index)}-public-subnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.main.id
  count = length(var.private_subnets_cidr)
  cidr_block = element(var.private_subnets_cidr,count.index)
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = false

  tags = {
    Name = "${data.aws_availability_zones.available.names[count.index]}-private-subnet"
  }
}

#### Routing ####

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "private-route-table"
    }
}

##attach igw to public route
resource "aws_route" "public_internet_gateway" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.ig.id
}

## connect private route table to natgw
resource "aws_route" "natgw-route" {
  route_table_id = aws_route_table.private.id
  nat_gateway_id = aws_nat_gateway.natgw.id
  destination_cidr_block = "0.0.0.0/0"
}

### route association ###
resource "aws_route_table_association" "public" {
    count = length(var.public_subnets_cidr)
    subnet_id = element(aws_subnet.public_subnet.*.id,count.index)
    route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
    count = length(var.private_subnets_cidr)
    subnet_id = element(aws_subnet.private_subnet.*.id,count.index)
    route_table_id = aws_route_table.private.id
}

#### Security Group for the vpc
resource "aws_security_group" "newsapi_sg" {
  name = "newsapi-sg"
  description = "news api security group"
  vpc_id = aws_vpc.main.id
  depends_on = [ aws_vpc.main ]

  #allow just ssh from internet
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    self = true
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

#####ALB####
resource "aws_lb" "airflow_alb" {
  name               = "airflow-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [for subnet in aws_subnet.public_subnet: subnet.id]
}

# ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP access to ALB"
  vpc_id      = aws_vpc.main.id
  depends_on = [ aws_vpc.main ]

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ALB Listener
resource "aws_lb_listener" "airflow_listener" {
  load_balancer_arn = aws_lb.airflow_alb.arn
  port = "80"
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.airflow_tg.arn
  }
}

# Target Group for Airflow
resource "aws_lb_target_group" "airflow_tg" {
  name = "airflow-tg"
  port = 8080
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
  #target_type = "instance"
  
}

# attach target_group to the airflow instance
resource "aws_lb_target_group_attachment" "airflow_attach_tg" {
  target_group_arn = aws_lb_target_group.airflow_tg.arn
  target_id = aws_instance.launch_ec2.id
  port = 8080
}


resource "aws_security_group" "private_launch" {
  name = "launch-sg"
  description = "launch security group"
  vpc_id = aws_vpc.main.id
  depends_on = [ aws_vpc.main ]

  #allow just ssh from internet
  ingress {
    from_port = "8080"
    to_port = "8080"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #allow just ssh from internet
  ingress {
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    self = true
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [
      "${aws_security_group.newsapi_sg.id}",
    ]
  }

  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}



###NATgw in a public subnet###
# elastic ip association
resource "aws_eip" "eipnat" {
  #associate_with_private_ip = "10.0.0.11"
  #depends_on = [ aws_internet_gateway.ig ]
  domain = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.eipnat.id
  subnet_id = aws_subnet.public_subnet[0].id
  tags = {Name="newsapi-natgw"}
  depends_on = [ aws_internet_gateway.ig ]
}


resource "aws_route" "publish_route" {
  route_table_id = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.ig.id
}

resource "aws_instance" "newsapi_bastion" {
  ami = "ami-052387465d846f3fc"
  instance_type = var.master_instance_type
  subnet_id = aws_subnet.public_subnet[0].id
  key_name = "eunorth1"
  vpc_security_group_ids = [aws_security_group.newsapi_sg.id]
  tags = {
    Name = "newsapibastion" 
    }  
}

resource "aws_instance" "launch_ec2"{
  ami = "ami-052387465d846f3fc"
  instance_type = var.launch_instance_type
  subnet_id = aws_subnet.private_subnet[0].id # Target Group for Airflowt[0].id
  key_name = "eunorth1"
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.private_launch.id]
  tags = {
    Name = "launch-airflow" 
    }
  
  user_data = <<-EOL
  #!/bin/bash
  sudo yum update -y
  sudo yum -y install docker
  sudo service docker start
  sudo usermod -a -G docker ec2-user
  sudo chmod 666 /var/run/docker.sock
  EOL
}