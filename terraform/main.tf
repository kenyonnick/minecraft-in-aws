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

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name  = "minecraft-vpc",
    Stack = var.stack
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "minecraft-subnet",
    Stack = var.stack
  }
}

resource "aws_security_group" "minecraft_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

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

  tags = {
    Name  = "Minecraft Security Group",
    Stack = var.stack
  }
}

resource "aws_instance" "minecraft-server" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t3.medium"
  key_name             = "minecraft-admin"
  iam_instance_profile = "minecraft-vanilla-ec2-to-s3"
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.minecraft_sg.id]

  subnet_id = aws_subnet.main.id

  root_block_device {
    volume_size = "8"
  }

  tags = {
    Name  = "Minecraft Server",
    Stack = var.stack
  }
}