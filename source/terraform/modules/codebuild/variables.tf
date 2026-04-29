# CodeBuild Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., poc, dev, prod)"
  type        = string
}

variable "github_repo_url" {
  description = "GitHub repository URL (HTTPS)"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to build from"
  type        = string
  default     = "main"
}

variable "ecr_repository_urls" {
  description = "Map of service names to ECR repository URLs"
  type        = map(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "build_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "build_image" {
  description = "CodeBuild Docker image"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "services" {
  description = "List of services to create CodeBuild projects for"
  type        = list(string)
  default     = ["payment", "kyc", "webhook"]
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
