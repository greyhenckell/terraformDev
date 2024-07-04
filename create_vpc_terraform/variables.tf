variable "region" {
    description = "region for aws resources"
    type = string
    default = "eu-north-1"
}

variable "profile" {
  description = "aws profile"
  type = string
}

variable "vpc_cidr" {
    description = "vpc cidr block "
}

variable "public_subnets_cidr" {
    type = list(any)
    description = "list of public subnet ips"
}

variable "private_subnets_cidr" {
    type = list(any)
    description = "list of private subnet ips"
}

variable "master_instance_type" {
  type        = string
  description = "EC2 instance type for the worker nodes."
  default     = "t3.micro" #t3.medium
}