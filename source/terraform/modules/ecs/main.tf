# ECS Module - Fargate cluster with 4 microservices

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "novapay-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "novapay-${var.environment}-cluster"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "novapay-${var.environment}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "novapay-${var.environment}-ecs-tasks-sg"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution" {
  name = "novapay-${var.environment}-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "novapay-${var.environment}-ecs-task-execution"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Policy for Parameter Store access (for task execution role)
resource "aws_iam_role_policy" "parameter_store_execution_access" {
  name = "parameter-store-execution-access"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = var.parameter_store_arns
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for ECS Tasks (application permissions)
resource "aws_iam_role" "ecs_task" {
  name = "novapay-${var.environment}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "novapay-${var.environment}-ecs-task"
  }
}

# IAM Policy for Parameter Store access
resource "aws_iam_role_policy" "parameter_store_access" {
  name = "parameter-store-access"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = var.parameter_store_arns
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Policy for SQS access
resource "aws_iam_role_policy" "sqs_access" {
  name = "sqs-access"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = "*"
      }
    ]
  })
}


# ===== Authorization Service =====

resource "aws_ecs_task_definition" "auth" {
  family                   = "novapay-${var.environment}-auth-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 0.5 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "auth-service"
      image     = "public.ecr.aws/docker/library/nginx:alpine"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/novapay-${var.environment}/auth-service"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name    = "novapay-${var.environment}-auth-service"
    Service = "authorization"
  }
}

resource "aws_ecs_service" "auth" {
  name            = "novapay-${var.environment}-auth-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.auth.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_auth
    container_name   = "auth-service"
    container_port   = 3000
  }

  health_check_grace_period_seconds = 60

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200

  tags = {
    Name    = "novapay-${var.environment}-auth-service"
    Service = "authorization"
  }
}

# ===== Charge Service =====

resource "aws_ecs_task_definition" "charge" {
  family                   = "novapay-${var.environment}-charge-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "charge-service"
      image     = "public.ecr.aws/docker/library/nginx:alpine"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/novapay-${var.environment}/charge-service"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name    = "novapay-${var.environment}-charge-service"
    Service = "charge"
  }
}

resource "aws_ecs_service" "charge" {
  name            = "novapay-${var.environment}-charge-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.charge.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_charge
    container_name   = "charge-service"
    container_port   = 3000
  }

  health_check_grace_period_seconds = 60

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200

  tags = {
    Name    = "novapay-${var.environment}-charge-service"
    Service = "charge"
  }
}

# ===== Webhook Service =====

resource "aws_ecs_task_definition" "webhook" {
  family                   = "novapay-${var.environment}-webhook-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "webhook-service"
      image     = "public.ecr.aws/docker/library/nginx:alpine"
      essential = true

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/novapay-${var.environment}/webhook-service"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name    = "novapay-${var.environment}-webhook-service"
    Service = "webhook"
  }
}

resource "aws_ecs_service" "webhook" {
  name            = "novapay-${var.environment}-webhook-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.webhook.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200

  tags = {
    Name    = "novapay-${var.environment}-webhook-service"
    Service = "webhook"
  }
}

# ===== KYC Service =====

resource "aws_ecs_task_definition" "kyc" {
  family                   = "novapay-${var.environment}-kyc-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "kyc-service"
      image     = "public.ecr.aws/docker/library/nginx:alpine"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/novapay-${var.environment}/kyc-service"
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name    = "novapay-${var.environment}-kyc-service"
    Service = "kyc"
  }
}

resource "aws_ecs_service" "kyc" {
  name            = "novapay-${var.environment}-kyc-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.kyc.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.private_subnet_id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.alb_target_group_kyc
    container_name   = "kyc-service"
    container_port   = 3000
  }

  health_check_grace_period_seconds = 60

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200

  tags = {
    Name    = "novapay-${var.environment}-kyc-service"
    Service = "kyc"
  }
}
