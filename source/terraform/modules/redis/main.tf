# Redis Module - Single-node cache.t3.micro for cost optimization

# Security Group for Redis
resource "aws_security_group" "redis" {
  name        = "novapay-${var.environment}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.ecs_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "novapay-${var.environment}-redis-sg"
  }
}

# ElastiCache Subnet Group (single subnet for single-AZ)
resource "aws_elasticache_subnet_group" "main" {
  name       = "novapay-${var.environment}-redis-subnet-group"
  subnet_ids = [var.private_subnet_id]

  tags = {
    Name = "novapay-${var.environment}-redis-subnet-group"
  }
}

# ElastiCache Redis Cluster (single-node)
resource "aws_elasticache_cluster" "main" {
  cluster_id           = "novapay-${var.environment}-redis"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.main.name
  port                 = 6379

  # Network configuration
  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  # Encryption (transit encryption not supported for single-node clusters)
  # at-rest encryption also not supported for single-node clusters

  # Backup configuration
  snapshot_retention_limit = 7
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "mon:05:00-mon:07:00"

  tags = {
    Name = "novapay-${var.environment}-redis"
  }
}

# Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  name   = "novapay-${var.environment}-redis7"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = {
    Name = "novapay-${var.environment}-redis7"
  }
}
