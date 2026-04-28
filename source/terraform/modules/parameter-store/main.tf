# Parameter Store Module - Free tier for credentials management

# Database credentials
resource "aws_ssm_parameter" "db_username" {
  name        = "/novapay/${var.environment}/rds/username"
  description = "RDS PostgreSQL username"
  type        = "SecureString"
  value       = var.db_username

  tags = {
    Name = "novapay-${var.environment}-db-username"
  }
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/novapay/${var.environment}/rds/password"
  description = "RDS PostgreSQL password"
  type        = "SecureString"
  value       = var.db_password

  tags = {
    Name = "novapay-${var.environment}-db-password"
  }
}

resource "aws_ssm_parameter" "db_host" {
  name        = "/novapay/${var.environment}/rds/host"
  description = "RDS PostgreSQL host"
  type        = "String"
  value       = var.db_host

  tags = {
    Name = "novapay-${var.environment}-db-host"
  }
}

resource "aws_ssm_parameter" "db_name" {
  name        = "/novapay/${var.environment}/rds/database"
  description = "RDS PostgreSQL database name"
  type        = "String"
  value       = var.db_name

  tags = {
    Name = "novapay-${var.environment}-db-name"
  }
}

# Redis credentials
resource "aws_ssm_parameter" "redis_host" {
  name        = "/novapay/${var.environment}/redis/host"
  description = "ElastiCache Redis host"
  type        = "String"
  value       = var.redis_host

  tags = {
    Name = "novapay-${var.environment}-redis-host"
  }
}

resource "aws_ssm_parameter" "redis_port" {
  name        = "/novapay/${var.environment}/redis/port"
  description = "ElastiCache Redis port"
  type        = "String"
  value       = tostring(var.redis_port)

  tags = {
    Name = "novapay-${var.environment}-redis-port"
  }
}
