provider "aws" {
  region = var.aws_region
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.s3_bucket_name
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
# S3 versioning
resource "aws_s3_bucket_versioning" "state_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }
  hash_key = "LockID"
  tags = {
    Name = "terraform-locks-table"
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "main-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main-igw"
  }
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "main-route-table"
  }
}

# Subnet
resource "aws_subnet" "main-a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_a
  availability_zone = var.availability_zone_a
  tags = {
    Name = "main-subnet"
  }
}

resource "aws_subnet" "main-b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.subnet_cidr_b
  availability_zone = var.availability_zone_b
  tags = {
    Name = "main-subnet"
  }
}

# Security Group
resource "aws_security_group" "https" {
  vpc_id = aws_vpc.main.id
  name   = "Allow Glogal HTTP"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    Name = "main-security-group"
    Source = "Global"
  }
}

resource "aws_security_group" "ssh" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ssh-security-group"
    Source = "Global"
  }
}

# ALB
resource "aws_lb" "main" {
  name               = "main-alb"
  internal           = false
  security_groups    = [aws_security_group.https.id, aws_security_group.ssh.id]
  subnets            = [aws_subnet.main-a.id,aws_subnet.main-b.id]
  load_balancer_type = "application"

  enable_deletion_protection = false
  tags = {
    Name = "main-alb"
  }
}
