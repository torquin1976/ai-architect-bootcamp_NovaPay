# IAM Policy for Terraform Deployment

This document explains the least-privileged IAM policy required to deploy and destroy the NovaPay microservices infrastructure using Terraform.

## Policy Overview

The `iam-policy-terraform-deploy.json` file contains a least-privileged IAM policy that grants only the necessary permissions to:
- Create and destroy all AWS resources defined in the Terraform configuration
- Manage Terraform state in S3 and DynamoDB
- No permissions for unrelated AWS services or resources

## Permissions Breakdown

### 1. Terraform State Management
```json
"TerraformStateManagement" - S3 bucket operations
"TerraformStateLocking" - DynamoDB table operations
```
**Why needed**: Terraform stores state in S3 and uses DynamoDB for state locking to prevent concurrent modifications.

### 2. VPC and Networking
```json
"VPCManagement" - VPC, subnets, IGW, route tables
"SecurityGroupManagement" - Security groups and rules
"EC2Tagging" - Resource tagging
"EC2NetworkInterfaces" - ENI management for ECS/RDS/Redis
"EC2AvailabilityZones" - Query AZ information
```
**Why needed**: Creates the VPC, subnets, internet gateway, route tables, and security groups for network isolation.

### 3. Database (RDS)
```json
"RDSManagement" - RDS instances, subnet groups, parameter groups
```
**Why needed**: Creates PostgreSQL database (db.t3.micro), subnet groups, and parameter groups.

### 4. Cache (ElastiCache)
```json
"ElastiCacheManagement" - Redis clusters, subnet groups, parameter groups
```
**Why needed**: Creates Redis cache (cache.t3.micro), subnet groups, and parameter groups.

### 5. Message Queue (SQS)
```json
"SQSManagement" - Queue creation, configuration, tagging
```
**Why needed**: Creates SQS standard queue and dead-letter queue for webhook events.

### 6. Load Balancer (ALB)
```json
"ALBManagement" - ALB, target groups, listeners, rules
```
**Why needed**: Creates Application Load Balancer with path-based routing and health checks.

### 7. Container Orchestration (ECS)
```json
"ECSManagement" - Clusters, task definitions, services
```
**Why needed**: Creates ECS Fargate cluster and deploys 4 microservices.

### 8. IAM Roles
```json
"IAMRoleManagement" - Create/manage roles for ECS tasks
```
**Why needed**: Creates IAM roles for ECS task execution and application permissions.
**Scope limited to**: `arn:aws:iam::*:role/novapay-*` (only roles with novapay prefix)

### 9. Secrets Management
```json
"ParameterStoreManagement" - SSM Parameter Store operations
```
**Why needed**: Stores database credentials and Redis connection details.
**Scope limited to**: `/novapay/*` parameters only

### 10. Logging
```json
"CloudWatchLogsManagement" - Log group creation and configuration
```
**Why needed**: Creates CloudWatch log groups for ECS services.

### 11. Encryption
```json
"KMSForEncryption" - KMS key operations for encryption
```
**Why needed**: Encrypts RDS, Redis, and Parameter Store SecureString values.

## Setup Instructions

### Option 1: Automated Setup (Recommended)

```bash
# Make script executable
chmod +x setup-iam.sh

# Run setup script (requires admin AWS credentials)
./setup-iam.sh
```

This will:
1. Create the IAM policy
2. Create IAM user `novapay-terraform-deploy`
3. Attach the policy to the user
4. Generate access keys
5. Display credentials (save them!)

### Option 2: Manual Setup

#### Step 1: Create IAM Policy

```bash
aws iam create-policy \
    --policy-name NovaPay-Terraform-Deploy \
    --policy-document file://iam-policy-terraform-deploy.json \
    --description "Least-privilege policy for NovaPay Terraform deployment"
```

#### Step 2: Create IAM User

```bash
aws iam create-user \
    --user-name novapay-terraform-deploy \
    --tags Key=Project,Value=NovaPay Key=Purpose,Value=Terraform
```

#### Step 3: Attach Policy to User

```bash
# Get policy ARN
POLICY_ARN=$(aws iam list-policies \
    --query "Policies[?PolicyName=='NovaPay-Terraform-Deploy'].Arn" \
    --output text)

# Attach policy
aws iam attach-user-policy \
    --user-name novapay-terraform-deploy \
    --policy-arn "$POLICY_ARN"
```

#### Step 4: Create Access Keys

```bash
aws iam create-access-key \
    --user-name novapay-terraform-deploy
```

**IMPORTANT**: Save the `AccessKeyId` and `SecretAccessKey` - they won't be shown again!

### Option 3: Use with IAM Role (for EC2/CI/CD)

If running Terraform from EC2 or CI/CD pipeline:

```bash
# Create IAM role
aws iam create-role \
    --role-name NovaPay-Terraform-Deploy-Role \
    --assume-role-policy-document file://trust-policy.json

# Attach policy to role
aws iam attach-role-policy \
    --role-name NovaPay-Terraform-Deploy-Role \
    --policy-arn "$POLICY_ARN"
```

Example trust policy for EC2:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

## Configure AWS CLI

### Using Named Profile

```bash
aws configure --profile novapay-terraform
# Enter Access Key ID
# Enter Secret Access Key
# Enter region: us-east-1
# Enter output format: json

# Use profile with Terraform
export AWS_PROFILE=novapay-terraform
terraform plan
```

### Using Environment Variables

```bash
export AWS_ACCESS_KEY_ID=<your-access-key-id>
export AWS_SECRET_ACCESS_KEY=<your-secret-access-key>
export AWS_DEFAULT_REGION=us-east-1

terraform plan
```

## Verify Permissions

Test that the IAM user has correct permissions:

```bash
# Test S3 access (Terraform state)
aws s3 ls s3://novapay-terraform-state

# Test DynamoDB access (state locking)
aws dynamodb describe-table --table-name novapay-terraform-locks

# Test EC2 describe (VPC operations)
aws ec2 describe-vpcs

# Test IAM role creation
aws iam get-role --role-name novapay-poc-ecs-task-execution 2>/dev/null || echo "Role doesn't exist yet (expected)"
```

## Security Best Practices

### 1. Principle of Least Privilege
✅ Policy grants only permissions needed for this specific project
✅ Resource ARNs scoped where possible (IAM roles, Parameter Store)
✅ No wildcard permissions on sensitive operations

### 2. Credential Management
- ✅ Use IAM user for local development
- ✅ Use IAM role for EC2/CI/CD (no long-lived credentials)
- ✅ Rotate access keys regularly (every 90 days)
- ✅ Enable MFA for IAM user (recommended)

### 3. Audit and Monitoring
```bash
# Enable CloudTrail for API call logging
aws cloudtrail create-trail \
    --name novapay-terraform-audit \
    --s3-bucket-name novapay-cloudtrail-logs

# Review IAM user activity
aws iam get-user --user-name novapay-terraform-deploy
aws iam list-access-keys --user-name novapay-terraform-deploy
```

### 4. Credential Rotation

```bash
# List existing access keys
aws iam list-access-keys --user-name novapay-terraform-deploy

# Create new access key
aws iam create-access-key --user-name novapay-terraform-deploy

# Update your configuration with new keys

# Delete old access key
aws iam delete-access-key \
    --user-name novapay-terraform-deploy \
    --access-key-id <OLD_KEY_ID>
```

## Cleanup

### Option 1: Automated Cleanup (Recommended)

```bash
# Make script executable
chmod +x cleanup-iam.sh

# Run cleanup script (requires admin AWS credentials)
./cleanup-iam.sh
```

This will:
1. Delete all access keys for the user
2. Detach all managed policies
3. Delete all inline policies
4. Remove user from all groups
5. Delete MFA devices (if any)
6. Delete login profile (if any)
7. Delete SSH keys (if any)
8. Delete service-specific credentials (if any)
9. Delete signing certificates (if any)
10. Delete the IAM user
11. Delete the IAM policy (if not attached to other entities)

### Option 2: Manual Cleanup

To remove the IAM user and policy manually:

```bash
# Detach policy from user
POLICY_ARN=$(aws iam list-policies \
    --query "Policies[?PolicyName=='NovaPay-Terraform-Deploy'].Arn" \
    --output text)

aws iam detach-user-policy \
    --user-name novapay-terraform-deploy \
    --policy-arn "$POLICY_ARN"

# Delete access keys
aws iam list-access-keys --user-name novapay-terraform-deploy \
    --query 'AccessKeyMetadata[].AccessKeyId' --output text | \
    xargs -I {} aws iam delete-access-key \
        --user-name novapay-terraform-deploy \
        --access-key-id {}

# Delete user
aws iam delete-user --user-name novapay-terraform-deploy

# Delete policy
aws iam delete-policy --policy-arn "$POLICY_ARN"
```

**Note**: After cleanup, remember to remove AWS CLI profiles from `~/.aws/credentials` and `~/.aws/config` if you configured them.

## Troubleshooting

### Permission Denied Errors

If you encounter permission errors during `terraform apply`:

1. **Check which action failed**:
   ```bash
   # Terraform will show the specific API call that failed
   # Example: "Error creating VPC: UnauthorizedOperation"
   ```

2. **Verify IAM policy is attached**:
   ```bash
   aws iam list-attached-user-policies --user-name novapay-terraform-deploy
   ```

3. **Test specific permission**:
   ```bash
   # Example: Test VPC creation
   aws ec2 create-vpc --cidr-block 10.1.0.0/16 --dry-run
   ```

4. **Check AWS credentials**:
   ```bash
   aws sts get-caller-identity
   # Should show: novapay-terraform-deploy user
   ```

### Common Issues

**Issue**: "Access Denied" when creating IAM roles
**Solution**: Verify the role name starts with `novapay-` (policy is scoped to this prefix)

**Issue**: "Access Denied" for Parameter Store
**Solution**: Verify parameter paths start with `/novapay/` (policy is scoped to this prefix)

**Issue**: "Access Denied" for S3 state bucket
**Solution**: Verify bucket name is `novapay-terraform-state` (policy is scoped to this bucket)

## Additional Resources

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [Terraform AWS Provider Authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)
- [AWS Policy Simulator](https://policysim.aws.amazon.com/) - Test IAM policies

## Support

For issues with IAM permissions:
1. Check CloudTrail logs for denied API calls
2. Use AWS Policy Simulator to test permissions
3. Review Terraform error messages for specific missing permissions
4. Verify resource naming conventions match policy scopes
