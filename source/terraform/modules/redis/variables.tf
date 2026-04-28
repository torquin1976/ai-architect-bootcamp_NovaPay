variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID for Redis"
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS security group ID for ingress rules"
  type        = string
}
