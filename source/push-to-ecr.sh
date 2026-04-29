#!/bin/bash

# Script to build and push Docker images to ECR
# This script builds the local Docker images and pushes them to AWS ECR

set -e

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="637423409019"
ECR_PAYMENT="637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment"
ECR_KYC="637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-kyc"
ECR_WEBHOOK="637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-webhook"

echo "=========================================="
echo "NovaPay - Push Docker Images to ECR"
echo "=========================================="
echo ""

# Step 1: Login to ECR
echo "Step 1: Logging in to Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to login to ECR. Please check your AWS credentials."
    exit 1
fi

echo "✓ Successfully logged in to ECR"
echo ""

# Step 2: Build and push Payment service
echo "Step 2: Building Payment service..."
cd DockerFiles/Payment
docker build -t $ECR_PAYMENT:latest -f dockerfile .

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build Payment service"
    exit 1
fi

echo "✓ Payment service built successfully"
echo "Pushing Payment service to ECR..."
docker push $ECR_PAYMENT:latest

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to push Payment service to ECR"
    exit 1
fi

echo "✓ Payment service pushed to ECR"
cd ../..
echo ""

# Step 3: Build and push KYC service
echo "Step 3: Building KYC service..."
cd DockerFiles/KYC
docker build -t $ECR_KYC:latest -f dockerfile .

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build KYC service"
    exit 1
fi

echo "✓ KYC service built successfully"
echo "Pushing KYC service to ECR..."
docker push $ECR_KYC:latest

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to push KYC service to ECR"
    exit 1
fi

echo "✓ KYC service pushed to ECR"
cd ../..
echo ""

# Step 4: Build and push WebHook service
echo "Step 4: Building WebHook service..."
cd DockerFiles/WebHook
docker build -t $ECR_WEBHOOK:latest -f dockerfile .

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build WebHook service"
    exit 1
fi

echo "✓ WebHook service built successfully"
echo "Pushing WebHook service to ECR..."
docker push $ECR_WEBHOOK:latest

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to push WebHook service to ECR"
    exit 1
fi

echo "✓ WebHook service pushed to ECR"
cd ../..
echo ""

# Summary
echo "=========================================="
echo "✓ All images successfully pushed to ECR!"
echo "=========================================="
echo ""
echo "ECR Image URLs:"
echo "  Payment: $ECR_PAYMENT:latest"
echo "  KYC:     $ECR_KYC:latest"
echo "  WebHook: $ECR_WEBHOOK:latest"
echo ""
echo "Next steps:"
echo "1. Update terraform/terraform.tfvars with these ECR URLs"
echo "2. Run 'terraform apply' to update ECS services"
echo ""
