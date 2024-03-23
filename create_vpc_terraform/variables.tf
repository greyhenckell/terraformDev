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
