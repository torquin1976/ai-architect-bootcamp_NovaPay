#!/bin/bash
# NovaPay Microservices Deployment Script

set -e

echo "========================================="
echo "NovaPay Microservices Deployment"
echo "========================================="
echo ""

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform is not installed"; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI is not installed"; exit 1; }

# Check AWS credentials
aws sts get-caller-identity >/dev/null 2>&1 || { echo "Error: AWS credentials not configured"; exit 1; }

echo "✓ Prerequisites check passed"
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and configure it"
    exit 1
fi

echo "✓ terraform.tfvars found"
echo ""

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

echo ""
echo "========================================="
echo "Terraform Plan"
echo "========================================="
echo ""

# Run terraform plan
terraform plan -out=tfplan

echo ""
echo "========================================="
echo "Review the plan above"
echo "========================================="
echo ""
read -p "Do you want to apply this plan? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

echo ""
echo "========================================="
echo "Applying Terraform Configuration"
echo "========================================="
echo ""

# Apply terraform
terraform apply tfplan

# Clean up plan file
rm -f tfplan

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""

# Show outputs
echo "Infrastructure Outputs:"
echo ""
terraform output

echo ""
echo "========================================="
echo "Next Steps:"
echo "========================================="
echo "1. Build and push Docker images to ECR"
echo "2. Update terraform.tfvars with ECR image URIs"
echo "3. Run 'terraform apply' again to deploy services"
echo "4. Test endpoints using the ALB URL above"
echo ""
echo "To destroy infrastructure: terraform destroy"
echo ""
