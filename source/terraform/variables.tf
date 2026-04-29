# Variables for NovaPay Microservices Migration

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (poc, dev, staging, prod)"
  type        = string
  default     = "poc"
}

variable "availability_zone" {
  description = "Single availability zone for cost optimization"
  type        = string
  default     = "us-east-1a"
}

variable "availability_zone_2" {
  description = "Second availability zone for RDS multi-AZ requirement"
  type        = string
  default     = "us-east-1b"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for second private subnet"
  type        = string
  default     = "10.0.3.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for second public subnet (for ALB multi-AZ requirement)"
  type        = string
  default     = "10.0.4.0/24"
}

# Database Configuration
variable "db_username" {
  description = "RDS PostgreSQL master username"
  type        = string
  default     = "novapay_admin"
  sensitive   = true
}

variable "db_password" {
  description = "RDS PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "RDS PostgreSQL database name"
  type        = string
  default     = "novapay"
}

# Container Images
variable "auth_service_image" {
  description = "Docker image for Authorization Service"
  type        = string
  default     = "novapay/auth-service:latest"
}

variable "charge_service_image" {
  description = "Docker image for Charge Service"
  type        = string
  default     = "novapay/charge-service:latest"
}

variable "webhook_service_image" {
  description = "Docker image for Webhook Service"
  type        = string
  default     = "novapay/webhook-service:latest"
}

variable "kyc_service_image" {
  description = "Docker image for KYC Service"
  type        = string
  default     = "novapay/kyc-service:latest"
}

# GitHub Configuration
variable "github_repo_url" {
  description = "GitHub repository URL (HTTPS format)"
  type        = string
  default     = "https://github.com/your-org/novapay.git"
}

variable "github_branch" {
  description = "GitHub branch to build from"
  type        = string
  default     = "main"
}
