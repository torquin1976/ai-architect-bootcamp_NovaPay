# CodeBuild Projects for NovaPay Microservices

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-codebuild-role"
      Environment = var.environment
    }
  )
}

# IAM Policy for CodeBuild - ECR Permissions
resource "aws_iam_role_policy" "codebuild_ecr" {
  name = "${var.project_name}-codebuild-ecr-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          for url in values(var.ecr_repository_urls) :
          "arn:aws:ecr:${var.aws_region}:*:repository/${split("/", url)[0]}"
        ]
      }
    ]
  })
}

# IAM Policy for CodeBuild - CloudWatch Logs
resource "aws_iam_role_policy" "codebuild_logs" {
  name = "${var.project_name}-codebuild-logs-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/codebuild/${var.project_name}-*"
      }
    ]
  })
}

# IAM Policy for CodeBuild - S3 (for build artifacts if needed)
resource "aws_iam_role_policy" "codebuild_s3" {
  name = "${var.project_name}-codebuild-s3-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-*/*"
      }
    ]
  })
}

# CodeBuild Projects for each service
resource "aws_codebuild_project" "service" {
  for_each = toset(var.services)

  name          = "${var.project_name}-${each.value}-build"
  description   = "Build Docker image for ${each.value} service"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 20

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = var.build_compute_type
    image                       = var.build_image
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = "${var.project_name}-${each.value}"
    }

    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }

    environment_variable {
      name  = "ECR_REPOSITORY_URL"
      value = var.ecr_repository_urls[each.value]
    }
  }

  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = "DockerFiles/${title(each.value)}/buildspec.yml"

    git_submodules_config {
      fetch_submodules = false
    }
  }

  source_version = var.github_branch

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-${each.value}"
      stream_name = "build-log"
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${each.value}-build"
      Environment = var.environment
      Service     = each.value
    }
  )
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}
