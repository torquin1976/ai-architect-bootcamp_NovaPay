variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for RDS (deprecated, use private_subnet_ids)"
  type        = string
  default     = ""
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS (requires at least 2 AZs)"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "ECS security group ID for ingress rules"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for RDS instance"
  type        = string
  default     = "us-east-1a"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
}
