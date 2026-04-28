# CloudWatch Module - Log groups for ECS services

resource "aws_cloudwatch_log_group" "auth_service" {
  name              = "/ecs/novapay-${var.environment}/auth-service"
  retention_in_days = 7

  tags = {
    Name    = "novapay-${var.environment}-auth-service-logs"
    Service = "authorization"
  }
}

resource "aws_cloudwatch_log_group" "charge_service" {
  name              = "/ecs/novapay-${var.environment}/charge-service"
  retention_in_days = 7

  tags = {
    Name    = "novapay-${var.environment}-charge-service-logs"
    Service = "charge"
  }
}

resource "aws_cloudwatch_log_group" "webhook_service" {
  name              = "/ecs/novapay-${var.environment}/webhook-service"
  retention_in_days = 7

  tags = {
    Name    = "novapay-${var.environment}-webhook-service-logs"
    Service = "webhook"
  }
}

resource "aws_cloudwatch_log_group" "kyc_service" {
  name              = "/ecs/novapay-${var.environment}/kyc-service"
  retention_in_days = 7

  tags = {
    Name    = "novapay-${var.environment}-kyc-service-logs"
    Service = "kyc"
  }
}
