# CodeBuild Module Outputs

output "codebuild_project_names" {
  description = "Map of service names to CodeBuild project names"
  value = {
    for k, v in aws_codebuild_project.service : k => v.name
  }
}

output "codebuild_project_arns" {
  description = "Map of service names to CodeBuild project ARNs"
  value = {
    for k, v in aws_codebuild_project.service : k => v.arn
  }
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild IAM role"
  value       = aws_iam_role.codebuild.arn
}

output "codebuild_role_name" {
  description = "Name of the CodeBuild IAM role"
  value       = aws_iam_role.codebuild.name
}
