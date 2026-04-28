#!/bin/bash
# Script to create IAM user/role for Terraform deployment

set -e

echo "========================================="
echo "NovaPay Terraform IAM Setup"
echo "========================================="
echo ""

# Check prerequisites
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI is not installed"; exit 1; }

# Check AWS credentials (must have admin access to create IAM resources)
aws sts get-caller-identity >/dev/null 2>&1 || { echo "Error: AWS credentials not configured"; exit 1; }

echo "This script will create:"
echo "1. IAM policy for Terraform deployment"
echo "2. IAM user 'novapay-terraform-deploy'"
echo "3. Access keys for the user"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Setup cancelled"
    exit 0
fi

echo ""
echo "Creating IAM policy..."

# Create IAM policy
POLICY_ARN=$(aws iam create-policy \
    --policy-name NovaPay-Terraform-Deploy \
    --policy-document file://iam-policy-terraform-deploy.json \
    --description "Least-privilege policy for NovaPay Terraform deployment" \
    --query 'Policy.Arn' \
    --output text 2>/dev/null || \
    aws iam list-policies --query "Policies[?PolicyName=='NovaPay-Terraform-Deploy'].Arn" --output text)

echo "✓ Policy created/found: $POLICY_ARN"

echo ""
echo "Creating IAM user..."

# Create IAM user
aws iam create-user \
    --user-name novapay-terraform-deploy \
    --tags Key=Project,Value=NovaPay Key=Purpose,Value=Terraform 2>/dev/null || \
    echo "✓ User already exists"

echo "✓ User created/found: novapay-terraform-deploy"

echo ""
echo "Attaching policy to user..."

# Attach policy to user
aws iam attach-user-policy \
    --user-name novapay-terraform-deploy \
    --policy-arn "$POLICY_ARN"

echo "✓ Policy attached"

echo ""
echo "Creating access keys..."

# Create access keys
ACCESS_KEY_OUTPUT=$(aws iam create-access-key \
    --user-name novapay-terraform-deploy \
    --output json 2>/dev/null || echo '{"AccessKey":{"AccessKeyId":"EXISTS","SecretAccessKey":"EXISTS"}}')

ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | grep -o '"AccessKeyId": "[^"]*' | cut -d'"' -f4)
SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | grep -o '"SecretAccessKey": "[^"]*' | cut -d'"' -f4)

if [ "$ACCESS_KEY_ID" = "EXISTS" ]; then
    echo "⚠ Access keys already exist for this user"
    echo "  To create new keys, delete existing ones first:"
    echo "  aws iam list-access-keys --user-name novapay-terraform-deploy"
    echo "  aws iam delete-access-key --user-name novapay-terraform-deploy --access-key-id <KEY_ID>"
else
    echo "✓ Access keys created"
    echo ""
    echo "========================================="
    echo "IMPORTANT: Save these credentials!"
    echo "========================================="
    echo ""
    echo "AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID"
    echo "AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY"
    echo ""
    echo "These credentials will NOT be shown again!"
    echo ""
    echo "To configure AWS CLI:"
    echo "  aws configure --profile novapay-terraform"
    echo ""
    echo "Or export as environment variables:"
    echo "  export AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID"
    echo "  export AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY"
    echo "  export AWS_DEFAULT_REGION=us-east-1"
    echo ""
fi

echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "IAM User: novapay-terraform-deploy"
echo "Policy: NovaPay-Terraform-Deploy"
echo ""
echo "Next steps:"
echo "1. Configure AWS CLI with the credentials above"
echo "2. Run ./deploy.sh to deploy infrastructure"
echo ""
