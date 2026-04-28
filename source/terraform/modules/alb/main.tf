# ALB Module - Application Load Balancer for path-based routing

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "novapay-${var.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "novapay-${var.environment}-alb-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "novapay-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  enable_http2               = true

  tags = {
    Name = "novapay-${var.environment}-alb"
  }
}

# Target Group for Authorization Service
resource "aws_lb_target_group" "auth" {
  name        = "novapay-${var.environment}-auth-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 60

  tags = {
    Name = "novapay-${var.environment}-auth-tg"
  }
}

# Target Group for Charge Service
resource "aws_lb_target_group" "charge" {
  name        = "novapay-${var.environment}-charge-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 60

  tags = {
    Name = "novapay-${var.environment}-charge-tg"
  }
}

# Target Group for KYC Service
resource "aws_lb_target_group" "kyc" {
  name        = "novapay-${var.environment}-kyc-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  deregistration_delay = 60

  tags = {
    Name = "novapay-${var.environment}-kyc-tg"
  }
}

# HTTP Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "NovaPay API - Use specific endpoints: /auth, /charge, /refund, /kyc"
      status_code  = "200"
    }
  }
}

# Listener Rule for /auth
resource "aws_lb_listener_rule" "auth" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth.arn
  }

  condition {
    path_pattern {
      values = ["/auth"]
    }
  }
}

# Listener Rule for /charge
resource "aws_lb_listener_rule" "charge" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.charge.arn
  }

  condition {
    path_pattern {
      values = ["/charge"]
    }
  }
}

# Listener Rule for /refund
resource "aws_lb_listener_rule" "refund" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 3

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.charge.arn
  }

  condition {
    path_pattern {
      values = ["/refund"]
    }
  }
}

# Listener Rule for /kyc
resource "aws_lb_listener_rule" "kyc" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 4

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kyc.arn
  }

  condition {
    path_pattern {
      values = ["/kyc"]
    }
  }
}
