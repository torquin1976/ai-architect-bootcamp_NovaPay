variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for subnets"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
}

variable "availability_zone_2" {
  description = "Second availability zone for RDS multi-AZ requirement"
  type        = string
}

variable "private_subnet_2_cidr" {
  description = "CIDR block for second private subnet"
  type        = string
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for second public subnet (for ALB multi-AZ requirement)"
  type        = string
}
