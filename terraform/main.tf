terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region  = "us-east-2"
}

data "aws_ami" "amazon_linux_2" {
 most_recent = true


 filter {
   name   = "owner-alias"
   values = ["amazon"]
 }


 filter {
   name   = "name"
   values = ["amzn2-ami-hvm*"]
 }

 owners = ["amazon"]
}

resource "aws_vpc" "minecraft_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name  = "minecraft_vpc",
    Stack = var.stack
  }
}

resource "aws_subnet" "minecraft_subnet" {
  vpc_id     = aws_vpc.minecraft_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name  = "minecraft_subnet",
    Stack = var.stack
  }
}

resource "aws_security_group" "minecraft_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.minecraft_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 22065
    to_port     = 22065
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22065
    to_port     = 22065
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "minecraft_sg",
    Stack = var.stack
  }
}

resource "aws_eip" "minecraft_elastic_ip" {
  instance = aws_instance.minecraft_server.id
  vpc      = true

  tags = {
    Name  = "minecraft_elastic_ip",
    Stack = var.stack
  }
}

resource "aws_internet_gateway" "minecraft_gateway" {
  vpc_id = aws_vpc.minecraft_vpc.id

  tags = {
    Name  = "minecraft_gateway",
    Stack = var.stack
  }
}

resource "aws_route_table" "minecraft_route_table" {
  vpc_id = aws_vpc.minecraft_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.minecraft_gateway.id
  }

  tags = {
    Name  = "minecraft_route_table",
    Stack = var.stack
  }
}

resource "aws_route_table_association" "subnet_association" {
  subnet_id      = aws_subnet.minecraft_subnet.id
  route_table_id = aws_route_table.minecraft_route_table.id
}

resource "aws_instance" "minecraft_server" {
  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = "t3.medium"
  key_name                    = "minecraft-admin"
  iam_instance_profile        = "minecraft-vanilla-ec2-to-s3"
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.minecraft_sg.id]

  subnet_id = aws_subnet.minecraft_subnet.id

  root_block_device {
    volume_size = "8"
  }

  tags = {
    Name  = "minecraft_server",
    Stack = var.stack
  }
}