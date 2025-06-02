# Provider AWS
provider "aws" {
  region = "eu-west-3"
}

# VPC, Internet Gateway and network
resource "aws_vpc" "k3s_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "k3s-vpc"
  }
}

resource "aws_internet_gateway" "k3s_igw" {
  vpc_id = aws_vpc.k3s_vpc.id
  
  tags = {
    Name = "k3s-igw"
  }
}

resource "aws_subnet" "k3s_public" {
  vpc_id                  = aws_vpc.k3s_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-west-3a"
  
  tags = {
    Name = "k3s-public-subnet"
  }
}

resource "aws_route_table" "k3s_public" {
  vpc_id = aws_vpc.k3s_vpc.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k3s_igw.id
  }
  
  tags = {
    Name = "k3s-public-rt"
  }
}

resource "aws_route_table_association" "k3s_public" {
  subnet_id      = aws_subnet.k3s_public.id
  route_table_id = aws_route_table.k3s_public.id
}

# Generate SSH key
resource "tls_private_key" "k3s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair
resource "aws_key_pair" "k3s_keypair" {
  key_name   = "k3s-key"
  public_key = tls_private_key.k3s_key.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content  = tls_private_key.k3s_key.private_key_pem
  filename = "${path.module}/k3s-key.pem"
  file_permission = "0600"
}

# Get Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Minimal security group for SSH and k3s
resource "aws_security_group" "k3s_minimal" {
  name   = "k3s-minimal"
  vpc_id = aws_vpc.k3s_vpc.id
  
   # HTTP services (for ingress/load balancer)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # HTTPS services (for ingress/load balancer)
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 6443
    to_port     = 6443
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

# Simple EC2 instance with k3s
resource "aws_instance" "k3s_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = aws_key_pair.k3s_keypair.key_name
  vpc_security_group_ids = [aws_security_group.k3s_minimal.id]
  subnet_id              = aws_subnet.k3s_public.id
  
  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    curl -sfL https://get.k3s.io | sh -
    sleep 30
    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/kubeconfig
    chown ubuntu:ubuntu /home/ubuntu/kubeconfig
    chmod 644 /home/ubuntu/kubeconfig
  EOF

  tags = {
    Name = "k3s-simple"
  }
}

# Outputs
output "instance_ip" {
  value = aws_eip.k3s_ip.public_ip
}

output "ssh_command" {
  value = "ssh -i k3s-key.pem ubuntu@${aws_eip.k3s_ip.public_ip}"
}

# Required providers
terraform {
  required_providers {
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "aws_eip" "k3s_ip" {
  instance = aws_instance.k3s_server.id
  domain   = "vpc"
  
  tags = {
    Name = "k3s-elastic-ip"
  }
} 