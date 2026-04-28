output "webhook_queue_url" {
  description = "Webhook queue URL"
  value       = aws_sqs_queue.webhook.url
}

output "webhook_queue_arn" {
  description = "Webhook queue ARN"
  value       = aws_sqs_queue.webhook.arn
}

output "webhook_dlq_url" {
  description = "Webhook DLQ URL"
  value       = aws_sqs_queue.webhook_dlq.url
}

output "webhook_dlq_arn" {
  description = "Webhook DLQ ARN"
  value       = aws_sqs_queue.webhook_dlq.arn
}
