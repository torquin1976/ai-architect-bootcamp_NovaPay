output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_security_group_id" {
  description = "ALB security group ID"
  value       = aws_security_group.alb.id
}

output "target_group_auth_arn" {
  description = "Authorization service target group ARN"
  value       = aws_lb_target_group.auth.arn
}

output "target_group_charge_arn" {
  description = "Charge service target group ARN"
  value       = aws_lb_target_group.charge.arn
}

output "target_group_kyc_arn" {
  description = "KYC service target group ARN"
  value       = aws_lb_target_group.kyc.arn
}
