# ECR and CodeBuild Setup

This document describes the ECR (Elastic Container Registry) and CodeBuild infrastructure for the NovaPay microservices migration.

## Overview

The infrastructure includes:
- **3 ECR repositories** for storing Docker images (payment, kyc, webhook)
- **3 CodeBuild projects** for building and pushing Docker images to ECR
- **IAM roles and policies** for CodeBuild to access ECR and CloudWatch Logs

## ECR Repositories

### Created Repositories

1. **novapay-payment** - Used by Auth and Charge ECS services
2. **novapay-kyc** - Used by KYC ECS service
3. **novapay-webhook** - Used by WebHook ECS service

### Repository Configuration

- **Image Scanning**: Enabled on push for security vulnerability detection
- **Lifecycle Policy**: Retains last 10 images, automatically expires older images
- **Encryption**: AES256 encryption at rest
- **Tag Mutability**: MUTABLE (allows overwriting tags like `latest`)

### Repository URLs

After deployment, ECR repository URLs will be available in Terraform outputs:

```bash
terraform output ecr_repository_urls
```

Example output:
```
{
  "kyc" = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-kyc"
  "payment" = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment"
  "webhook" = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-webhook"
}
```

## CodeBuild Projects

### Created Projects

1. **novapay-payment-build** - Builds Payment service Docker image
2. **novapay-kyc-build** - Builds KYC service Docker image
3. **novapay-webhook-build** - Builds WebHook service Docker image

### Build Configuration

- **Compute Type**: BUILD_GENERAL1_SMALL (3 GB memory, 2 vCPUs)
- **Build Image**: aws/codebuild/standard:7.0 (Ubuntu with Docker support)
- **Privileged Mode**: Enabled (required for Docker builds)
- **Build Timeout**: 20 minutes
- **Source**: GitHub repository with buildspec.yml in each service directory

### Environment Variables

Each CodeBuild project has the following environment variables:

- `AWS_DEFAULT_REGION` - AWS region (us-east-1)
- `AWS_ACCOUNT_ID` - AWS account ID (auto-populated)
- `IMAGE_REPO_NAME` - ECR repository name (e.g., novapay-payment)
- `IMAGE_TAG` - Docker image tag (default: latest)
- `ECR_REPOSITORY_URL` - Full ECR repository URL

### Buildspec Files

Each service has a `buildspec.yml` file in its DockerFiles directory:

- `DockerFiles/Payment/buildspec.yml`
- `DockerFiles/KYC/buildspec.yml`
- `DockerFiles/WebHook/buildspec.yml`

The buildspec defines three phases:

1. **pre_build**: Log in to ECR
2. **build**: Build Docker image with commit hash and latest tags
3. **post_build**: Push images to ECR and create imagedefinitions.json

## IAM Permissions

### CodeBuild IAM Role

The CodeBuild IAM role (`novapay-codebuild-role`) has the following permissions:

**ECR Permissions**:
- `ecr:GetAuthorizationToken` - Get ECR login token
- `ecr:BatchCheckLayerAvailability` - Check if image layers exist
- `ecr:PutImage` - Push Docker images
- `ecr:InitiateLayerUpload` - Start layer upload
- `ecr:UploadLayerPart` - Upload layer parts
- `ecr:CompleteLayerUpload` - Complete layer upload

**CloudWatch Logs Permissions**:
- `logs:CreateLogGroup` - Create log groups
- `logs:CreateLogStream` - Create log streams
- `logs:PutLogEvents` - Write log events

**S3 Permissions** (for build artifacts):
- `s3:GetObject` - Read build artifacts
- `s3:PutObject` - Write build artifacts

### Terraform User Permissions

The `novapay-terraform-deploy` user needs additional permissions for ECR and CodeBuild:

**ECR Management**:
- `ecr:CreateRepository`
- `ecr:DeleteRepository`
- `ecr:DescribeRepositories`
- `ecr:PutLifecyclePolicy`
- `ecr:PutImageScanningConfiguration`

**CodeBuild Management**:
- `codebuild:CreateProject`
- `codebuild:DeleteProject`
- `codebuild:UpdateProject`
- `codebuild:BatchGetProjects`

**IAM Role Management** (for CodeBuild role):
- `iam:CreateRole`
- `iam:DeleteRole`
- `iam:GetRole`
- `iam:PutRolePolicy`
- `iam:PassRole`

These permissions are included in `terraform/iam-policy-supplement.json`.

## Manual Build Trigger

To manually trigger a CodeBuild project:

```bash
# Start a build for Payment service
aws codebuild start-build --project-name novapay-payment-build

# Start a build for KYC service
aws codebuild start-build --project-name novapay-kyc-build

# Start a build for WebHook service
aws codebuild start-build --project-name novapay-webhook-build
```

## Viewing Build Logs

Build logs are sent to CloudWatch Logs:

- Log Group: `/aws/codebuild/novapay-{service}`
- Log Stream: `build-log`

View logs in AWS Console or using AWS CLI:

```bash
aws logs tail /aws/codebuild/novapay-payment --follow
```

## GitHub Integration

### Repository Configuration

Update the `github_repo_url` variable in `terraform.tfvars`:

```hcl
github_repo_url = "https://github.com/your-org/novapay.git"
github_branch   = "main"
```

### Buildspec Location

CodeBuild expects buildspec files at:

- `DockerFiles/Payment/buildspec.yml`
- `DockerFiles/KYC/buildspec.yml`
- `DockerFiles/WebHook/buildspec.yml`

### GitHub Authentication

For private repositories, you'll need to configure GitHub authentication:

1. Create a GitHub personal access token with `repo` scope
2. Store it in AWS Secrets Manager or SSM Parameter Store
3. Update CodeBuild project source configuration to use the token

For public repositories, no authentication is needed.

## Updating ECS Task Definitions

After building and pushing images to ECR, update the ECS task definitions to use the ECR image URLs:

```hcl
# In terraform.tfvars
auth_service_image    = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment:latest"
charge_service_image  = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment:latest"
webhook_service_image = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-webhook:latest"
kyc_service_image     = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-kyc:latest"
```

Then apply Terraform:

```bash
terraform apply
```

## Cost Optimization

### ECR Costs

- **Storage**: $0.10 per GB-month
- **Data Transfer**: Free within same region
- **Lifecycle Policy**: Automatically deletes old images to minimize storage costs

With 10 images per repository and ~100 MB per image:
- 3 repositories × 10 images × 0.1 GB = 3 GB
- Monthly cost: 3 GB × $0.10 = **$0.30/month**

### CodeBuild Costs

- **BUILD_GENERAL1_SMALL**: $0.005 per build minute
- **Free Tier**: 100 build minutes/month

Typical build time: 3-5 minutes per service
- 3 services × 5 minutes = 15 minutes per deployment
- Monthly cost (assuming 10 deployments): 150 minutes × $0.005 = **$0.75/month**
- With free tier: (150 - 100) × $0.005 = **$0.25/month**

**Total ECR + CodeBuild Cost**: ~$0.55/month

## Troubleshooting

### Build Fails with "Cannot connect to Docker daemon"

**Cause**: Privileged mode not enabled

**Solution**: Ensure `privileged_mode = true` in CodeBuild project configuration

### Build Fails with "denied: User is not authorized to perform: ecr:PutImage"

**Cause**: CodeBuild IAM role lacks ECR permissions

**Solution**: Verify IAM role has `ecr:PutImage` permission for the target repository

### Build Fails with "repository does not exist"

**Cause**: ECR repository not created or wrong repository name

**Solution**: 
1. Verify ECR repositories exist: `aws ecr describe-repositories`
2. Check `IMAGE_REPO_NAME` environment variable matches repository name

### GitHub Source Not Found

**Cause**: Invalid GitHub URL or branch name

**Solution**: 
1. Verify `github_repo_url` is correct HTTPS URL
2. Verify `github_branch` exists in repository
3. For private repos, configure GitHub authentication

## Next Steps

1. **Deploy Infrastructure**: Run `terraform apply` to create ECR and CodeBuild resources
2. **Configure GitHub URL**: Update `terraform.tfvars` with your GitHub repository URL
3. **Trigger Builds**: Manually trigger CodeBuild projects to build and push images
4. **Update ECS**: Update ECS task definitions to use ECR image URLs
5. **Automate**: Set up GitHub webhooks or EventBridge rules to trigger builds on code push

## References

- [AWS ECR Documentation](https://docs.aws.amazon.com/ecr/)
- [AWS CodeBuild Documentation](https://docs.aws.amazon.com/codebuild/)
- [Buildspec Reference](https://docs.aws.amazon.com/codebuild/latest/userguide/build-spec-ref.html)
