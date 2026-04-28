output "log_group_names" {
  description = "CloudWatch log group names"
  value = {
    auth_service    = aws_cloudwatch_log_group.auth_service.name
    charge_service  = aws_cloudwatch_log_group.charge_service.name
    webhook_service = aws_cloudwatch_log_group.webhook_service.name
    kyc_service     = aws_cloudwatch_log_group.kyc_service.name
  }
}

output "log_group_arns" {
  description = "CloudWatch log group ARNs"
  value = {
    auth_service    = aws_cloudwatch_log_group.auth_service.arn
    charge_service  = aws_cloudwatch_log_group.charge_service.arn
    webhook_service = aws_cloudwatch_log_group.webhook_service.arn
    kyc_service     = aws_cloudwatch_log_group.kyc_service.arn
  }
}
