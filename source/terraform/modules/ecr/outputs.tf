# ECR Module Outputs

output "repository_urls" {
  description = "Map of repository names to their URLs"
  value = {
    for k, v in aws_ecr_repository.this : k => v.repository_url
  }
}

output "repository_arns" {
  description = "Map of repository names to their ARNs"
  value = {
    for k, v in aws_ecr_repository.this : k => v.arn
  }
}

output "repository_names" {
  description = "Map of repository names"
  value = {
    for k, v in aws_ecr_repository.this : k => v.name
  }
}

output "registry_id" {
  description = "Registry ID where repositories are created"
  value       = values(aws_ecr_repository.this)[0].registry_id
}
