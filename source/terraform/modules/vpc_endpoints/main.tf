# VPC Endpoints for AWS Services
# Required for ECS tasks in private subnets to access AWS services

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project}-${var.environment}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.project}-${var.environment}-vpc-endpoints-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project
    Purpose     = "PoC-Learning"
  }
}

# CloudWatch Logs VPC Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.environment}-logs-endpoint"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project
    Purpose     = "PoC-Learning"
  }
}

# ECR API VPC Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.environment}-ecr-api-endpoint"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project
    Purpose     = "PoC-Learning"
  }
}

# ECR Docker VPC Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.environment}-ecr-dkr-endpoint"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project
    Purpose     = "PoC-Learning"
  }
}

# S3 Gateway Endpoint (Free - no hourly charge)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = {
    Name        = "${var.project}-${var.environment}-s3-endpoint"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project
    Purpose     = "PoC-Learning"
  }
}
