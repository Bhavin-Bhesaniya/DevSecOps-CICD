resource "aws_vpc" "devsecops-jenkins-vpc" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = var.vpc-name
  }
}

resource "aws_subnet" "subnets" {
  count                   = length(var.subnet_cidrs)
  vpc_id                  = aws_vpc.devsecops-jenkins-vpc.id
  cidr_block              = var.subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index % length(var.azs)]
  map_public_ip_on_launch = count.index < 2 ? true : false
  tags = {
    Name = "Subnet -${count.index}"
  }
}

# Assign IGW for VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devsecops-jenkins-vpc.id

  tags = {
    Name = var.igw-name
  }
}

# Route table 
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.devsecops-jenkins-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "Public-Route-Table-Association" {
  count          = 2
  subnet_id      = aws_subnet.subnets[count.index].id
  route_table_id = aws_route_table.public-rt.id
}


# resource "aws_route_table_association" "public-rt-association-1" {
#   subnet_id      = aws_subnet.public-subnet-1.id
#   route_table_id = aws_route_table.public-rt.id
# }

# resource "aws_route_table_association" "public-rt-association-2" {
#   subnet_id      = aws_subnet.public-subnet-2.id
#   route_table_id = aws_route_table.public-rt.id
# }

# Public Subnet
# resource "aws_subnet" "public-subnet-1" {
#   vpc_id                  = aws_vpc.devsecops-jenkins-vpc.id
#   cidr_block              = "10.0.1.0/24"
#   availability_zone       = "ap-south-1a"
#   map_public_ip_on_launch = "true"

#   tags = {
#     Name = var.subnet-name
#   }
# }

# resource "aws_subnet" "public-subnet-2" {
#   vpc_id                  = aws_vpc.devsecops-jenkins-vpc.id
#   cidr_block              = "10.0.2.0/24"
#   availability_zone       = "ap-south-1b"
#   map_public_ip_on_launch = "true"

#   tags = {
#     Name = var.subnet-name
#   }
# }



resource "aws_security_group" "security-group" {
  name        = "Security Group"
  vpc_id      = aws_vpc.devsecops-jenkins-vpc.id
  description = "Allowing Jenkins, Sonarqube, SSH Access"

  ingress = [
    for port in [22, 80, 443, 8080, 9000, 9090] : {
      description      = "TLS from VPC"
      from_port        = port
      to_port          = port
      protocol         = "tcp"
      ipv6_cidr_blocks = ["::/0"]
      self             = false
      prefix_list_ids  = []
      security_groups  = []
      cidr_blocks      = ["0.0.0.0/0"]
    }
  ]

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.sg-name
  }
}