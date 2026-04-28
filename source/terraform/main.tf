# NovaPay Microservices Migration - Main Terraform Configuration
# Cost-optimized PoC architecture with single-AZ deployment

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "novapay-terraform-state"
    key            = "microservices/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "novapay-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "NovaPay"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "PoC-Learning"
    }
  }
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  environment           = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zone     = var.availability_zone
  availability_zone_2   = var.availability_zone_2
  public_subnet_cidr    = var.public_subnet_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  private_subnet_cidr   = var.private_subnet_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
}

# Parameter Store Module
module "parameter_store" {
  source = "./modules/parameter-store"

  environment = var.environment
  db_username = var.db_username
  db_password = var.db_password
  db_host     = module.rds.db_endpoint
  db_name     = var.db_name
  redis_host  = module.redis.redis_endpoint
  redis_port  = 6379
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  ecs_security_group_id = module.ecs.ecs_security_group_id
  availability_zone     = var.availability_zone
  db_username           = var.db_username
  db_password           = var.db_password
  db_name               = var.db_name
}

# Redis Module
module "redis" {
  source = "./modules/redis"

  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  private_subnet_id     = module.vpc.private_subnet_id
  ecs_security_group_id = module.ecs.ecs_security_group_id
}

# SQS Module
module "sqs" {
  source = "./modules/sqs"

  environment = var.environment
}

# ALB Module
module "alb" {
  source = "./modules/alb"

  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"

  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  public_subnet_id        = module.vpc.public_subnet_id
  alb_security_group_id   = module.alb.alb_security_group_id
  alb_target_group_auth   = module.alb.target_group_auth_arn
  alb_target_group_charge = module.alb.target_group_charge_arn
  alb_target_group_kyc    = module.alb.target_group_kyc_arn

  # Service configuration
  auth_image    = var.auth_service_image
  charge_image  = var.charge_service_image
  webhook_image = var.webhook_service_image
  kyc_image     = var.kyc_service_image

  # Parameter Store ARNs
  parameter_store_arns = module.parameter_store.parameter_arns

  # SQS Queue URL
  webhook_queue_url = module.sqs.webhook_queue_url
}

# CloudWatch Logs Module
module "cloudwatch" {
  source = "./modules/cloudwatch"

  environment = var.environment
}
