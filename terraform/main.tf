# terraform/main.tf
####################################
# Provider
####################################
provider "aws" {
  region = var.aws_region
}

####################################
# Network
####################################
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "stashcloud-vpc" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "stashcloud-igw" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "stashcloud-public-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "stashcloud-public-rt" }
}

resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_main_route_table_association" "assoc" {
  vpc_id         = aws_vpc.main_vpc.id
  route_table_id = aws_route_table.public_rt.id
}

####################################
# Security Group
####################################
resource "aws_security_group" "web_sg" {
  name   = "stashcloud-sg"
  vpc_id = aws_vpc.main_vpc.id
  tags   = { Name = "stashcloud-web-sg" }

  ingress {
    description = "SSH from admin IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  ingress {
    description = "HTTP public"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS public"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

####################################
# SSH access 
####################################
resource "aws_key_pair" "admin_key" {
  key_name   = "stashcloud-admin-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}


####################################
# EC2 Instance
####################################

data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_instance" "stashcloud_ec2" {
  ami                    = data.aws_ssm_parameter.ubuntu_2404_ami.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.admin_key.key_name

  # IMDSv2 securisation
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tags = {
    Name    = "stashcloud_ec2"
    Stack   = "frontend"
    Project = "stashcloud"
  }

}


####################################
# Elastic IP
####################################

resource "aws_eip" "stashcloud_eip" {
  tags = {
    Name = "stashcloud_eip"
  }
}

####################################
# EIP and Instance association
####################################

resource "aws_eip_association" "stashcloud_eip_association" {
  allocation_id = aws_eip.stashcloud_eip.id
  instance_id   = aws_instance.stashcloud_ec2.id
}

####################################
# Outputs
####################################

output "ec2_public_ip" {
  description = "EC2 public IP adress"
  value       = aws_eip.stashcloud_eip.public_ip
}
