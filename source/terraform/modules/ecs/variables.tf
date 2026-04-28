variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet ID for ECS tasks"
  type        = string
}

variable "alb_security_group_id" {
  description = "ALB security group ID"
  type        = string
}

variable "alb_target_group_auth" {
  description = "ALB target group ARN for auth service"
  type        = string
}

variable "alb_target_group_charge" {
  description = "ALB target group ARN for charge service"
  type        = string
}

variable "alb_target_group_kyc" {
  description = "ALB target group ARN for KYC service"
  type        = string
}

variable "auth_image" {
  description = "Docker image for Authorization Service"
  type        = string
}

variable "charge_image" {
  description = "Docker image for Charge Service"
  type        = string
}

variable "webhook_image" {
  description = "Docker image for Webhook Service"
  type        = string
}

variable "kyc_image" {
  description = "Docker image for KYC Service"
  type        = string
}

variable "parameter_store_arns" {
  description = "List of Parameter Store ARNs for IAM policy"
  type        = list(string)
}

variable "webhook_queue_url" {
  description = "SQS webhook queue URL"
  type        = string
}
