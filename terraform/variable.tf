variable "vpc-name" {
  description = "The name of the VPC"
  type        = string
}

variable "cidr-block-range" {
  description = "The CIDR block range for the VPC"
  type        = string
}

variable "igw-name" {
  description = "The name of the Internet Gateway"
  type        = string
}

variable "rt-name" {
  description = "The name of the Route Table"
  type        = string
}

variable "subnet-name" {
  description = "The name of the Subnet"
  type        = string
}

variable "sg-name" {
  description = "The name of the Security Group"
  type        = string
}

variable "instance-name" {
  description = "The name of the EC2 instance"
  type        = string
}

variable "ami" {
  description = "The Amazon Machine Image (AMI) ID"
  type        = string
}

variable "key-name" {
  description = "The name of the SSH key pair"
  type        = string
}

variable "iam-role" {
  description = "The IAM role to attach to the EC2 instance"
  type        = string
}