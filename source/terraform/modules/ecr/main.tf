# ECR Repositories for NovaPay Microservices

resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = "${var.project_name}-${each.value}"
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${each.value}"
      Environment = var.environment
      Service     = each.value
    }
  )
}

# Lifecycle policy to retain only the last N images
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.lifecycle_policy_count} images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = var.lifecycle_policy_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
