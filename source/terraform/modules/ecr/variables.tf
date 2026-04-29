# ECR Module Variables

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., poc, dev, prod)"
  type        = string
}

variable "repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = ["payment", "kyc", "webhook"]
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting (MUTABLE or IMMUTABLE)"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push"
  type        = bool
  default     = true
}

variable "lifecycle_policy_count" {
  description = "Number of images to retain in lifecycle policy"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
