# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "testVpc"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "test-igw"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main.id
  count = length(var.public_subnets_cidr)
  cidr_block = element(var.public_subnets_cidr,count.index)
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = "${data.aws_availability_zones.available.names[count.index]}-public-subnet"
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

resource "aws_route" "public_internet_gateway" {
  route_table_id = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.ig.id
}

### route association ###

resource "aws_route_table_association" "public" {
    count = length(var.public_subnets_cidr)
    subnet_id = element(aws_subnet.public_subnet.*.id,count.index)
    route_table_id = aws_route_table.public.id
}

#### Security Group for the vpc
resource "aws_security_group" "default" {
  name = "default-sg"
  description = "default security group"
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

  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}