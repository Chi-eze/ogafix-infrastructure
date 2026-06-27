terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "OgaFix"
      ManagedBy   = "Terraform"
    }
  }
}

# VPC and Networking
resource "aws_vpc" "ogafix" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "ogafix-vpc"
  }
}

resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.ogafix.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "ogafix-public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.ogafix.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "ogafix-public-subnet-2"
  }
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.ogafix.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "ogafix-private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.ogafix.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]

  tags = {
    Name = "ogafix-private-subnet-2"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Internet Gateway
resource "aws_internet_gateway" "ogafix" {
  vpc_id = aws_vpc.ogafix.id

  tags = {
    Name = "ogafix-igw"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.ogafix.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.ogafix.id
  }

  tags = {
    Name = "ogafix-public-rt"
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for Lightsail Instance
resource "aws_security_group" "lightsail" {
  name        = "ogafix-lightsail-sg"
  description = "Security group for OgaFix Lightsail instance"
  vpc_id      = aws_vpc.ogafix.id

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

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
    Name = "ogafix-lightsail-sg"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "ogafix-rds-sg"
  description = "Security group for OgaFix RDS database"
  vpc_id      = aws_vpc.ogafix.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lightsail.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ogafix-rds-sg"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "ogafix" {
  name       = "ogafix-db-subnet-group"
  subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]

  tags = {
    Name = "ogafix-db-subnet-group"
  }
}

# RDS PostgreSQL Database
resource "aws_db_instance" "ogafix" {
  identifier              = "ogafix-db"
  engine                  = "postgres"
  engine_version          = "14"
  instance_class          = var.db_instance_class
  allocated_storage       = 20
  storage_type            = "gp2"
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.ogafix.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  multi_az                = false
  publicly_accessible     = false
  backup_retention_period = 0

  tags = {
    Name = "ogafix-db"
  }
}

# S3 Bucket for Images
resource "aws_s3_bucket" "ogafix_images" {
  bucket = var.s3_bucket_name

  tags = {
    Name = "ogafix-images"
  }
}

resource "aws_s3_bucket_versioning" "ogafix_images" {
  bucket = aws_s3_bucket.ogafix_images.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "ogafix_images" {
  bucket = aws_s3_bucket.ogafix_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket.ogafix_images]
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "ogafix" {
  origin {
    domain_name = aws_s3_bucket.ogafix_images.bucket_regional_domain_name
    origin_id   = "S3Origin"
  }

  enabled = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3Origin"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "ogafix-cdn"
  }
}

# AWS Systems Manager Parameter Store for Secrets
resource "aws_ssm_parameter" "db_password" {
  name  = "/ogafix/db/password"
  type  = "SecureString"
  value = var.db_password

  tags = {
    Name = "ogafix-db-password"
  }
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/ogafix/db/username"
  type  = "String"
  value = var.db_username

  tags = {
    Name = "ogafix-db-username"
  }
}

resource "aws_ssm_parameter" "db_host" {
  name  = "/ogafix/db/host"
  type  = "String"
  value = aws_db_instance.ogafix.address

  tags = {
    Name = "ogafix-db-host"
  }
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/ogafix/db/port"
  type  = "String"
  value = tostring(aws_db_instance.ogafix.port)

  tags = {
    Name = "ogafix-db-port"
  }
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/ogafix/db/name"
  type  = "String"
  value = var.db_name

  tags = {
    Name = "ogafix-db-name"
  }
}

# Outputs
output "rds_endpoint" {
  value       = aws_db_instance.ogafix.endpoint
  description = "RDS database endpoint"
}

output "rds_address" {
  value       = aws_db_instance.ogafix.address
  description = "RDS database address"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.ogafix_images.id
  description = "S3 bucket name for images"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.ogafix.domain_name
  description = "CloudFront distribution domain name"
}

output "vpc_id" {
  value       = aws_vpc.ogafix.id
  description = "VPC ID"
}

output "security_group_lightsail_id" {
  value       = aws_security_group.lightsail.id
  description = "Security group ID for Lightsail"
}

output "ssm_parameter_db_password" {
  value       = aws_ssm_parameter.db_password.name
  description = "Parameter Store path for database password"
}

output "ssm_parameter_db_username" {
  value       = aws_ssm_parameter.db_username.name
  description = "Parameter Store path for database username"
}

output "ssm_parameter_db_host" {
  value       = aws_ssm_parameter.db_host.name
  description = "Parameter Store path for database host"
}

output "ssm_parameter_db_port" {
  value       = aws_ssm_parameter.db_port.name
  description = "Parameter Store path for database port"
}

output "ssm_parameter_db_name" {
  value       = aws_ssm_parameter.db_name.name
  description = "Parameter Store path for database name"
}
