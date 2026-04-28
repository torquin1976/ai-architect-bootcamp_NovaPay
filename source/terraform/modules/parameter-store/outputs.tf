output "parameter_arns" {
  description = "ARNs of all parameters for IAM policy"
  value = [
    aws_ssm_parameter.db_username.arn,
    aws_ssm_parameter.db_password.arn,
    aws_ssm_parameter.db_host.arn,
    aws_ssm_parameter.db_name.arn,
    aws_ssm_parameter.redis_host.arn,
    aws_ssm_parameter.redis_port.arn,
  ]
}

output "parameter_paths" {
  description = "Paths of all parameters"
  value = {
    db_username = aws_ssm_parameter.db_username.name
    db_password = aws_ssm_parameter.db_password.name
    db_host     = aws_ssm_parameter.db_host.name
    db_name     = aws_ssm_parameter.db_name.name
    redis_host  = aws_ssm_parameter.redis_host.name
    redis_port  = aws_ssm_parameter.redis_port.name
  }
}
