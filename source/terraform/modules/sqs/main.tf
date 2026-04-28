# SQS Module - Standard queue for webhook events

# Dead Letter Queue
resource "aws_sqs_queue" "webhook_dlq" {
  name                      = "novapay-${var.environment}-webhook-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name = "novapay-${var.environment}-webhook-dlq"
  }
}

# Main Webhook Queue
resource "aws_sqs_queue" "webhook" {
  name                       = "novapay-${var.environment}-webhook-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 20      # Long polling

  # Dead letter queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.webhook_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "novapay-${var.environment}-webhook-queue"
  }
}

# SQS Queue Policy (allow services to send/receive messages)
resource "aws_sqs_queue_policy" "webhook" {
  queue_url = aws_sqs_queue.webhook.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSServices"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.webhook.arn
      }
    ]
  })
}
