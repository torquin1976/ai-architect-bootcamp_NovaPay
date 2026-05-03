# ECS Connectivity Issue - CloudWatch Logs

**Date**: May 3, 2026  
**Status**: All ECS tasks failing to start

## Problem

ECS tasks in private subnets cannot reach CloudWatch Logs to send logs. Error message:
```
ResourceInitializationError: failed to validate logger args: 
The task cannot find the Amazon CloudWatch log group defined in the task definition. 
There is a connection issue between the task and Amazon CloudWatch. 
Check your network configuration.
```

## Root Cause

ECS tasks are deployed in **private subnets** without **public IPs** (as per requirements). To reach AWS services like CloudWatch Logs, they need one of:

1. **VPC Endpoints** for AWS services (recommended for production)
2. **NAT Gateway/Instance** with proper routing (we have this, but it's not sufficient alone)
3. **VPC Endpoints** are specifically needed for:
   - CloudWatch Logs (`com.amazonaws.us-east-1.logs`)
   - ECR API (`com.amazonaws.us-east-1.ecr.api`)
   - ECR Docker (`com.amazonaws.us-east-1.ecr.dkr`)
   - S3 Gateway Endpoint (for ECR image layers)

## Current Infrastructure

✅ **NAT Instance**: Running (i-00cb3460ece99ff99)  
✅ **Private Route Table**: Configured (0.0.0.0/0 → NAT instance)  
✅ **Security Groups**: Configured  
❌ **VPC Endpoints**: Not configured

## Solutions

### Option 1: Add VPC Endpoints (Recommended for Production)

**Pros:**
- Secure, private connectivity to AWS services
- Better performance (no internet gateway hop)
- Follows AWS best practices
- Required for production workloads

**Cons:**
- Additional cost: ~$7/month per endpoint × 3 endpoints = ~$21/month
- Requires Terraform changes

**Implementation:**
1. Add VPC endpoints to Terraform:
   - `com.amazonaws.us-east-1.logs` (CloudWatch Logs)
   - `com.amazonaws.us-east-1.ecr.api` (ECR API)
   - `com.amazonaws.us-east-1.ecr.dkr` (ECR Docker)
   - `com.amazonaws.us-east-1.s3` (S3 Gateway - free)

2. Update Terraform and apply:
   ```bash
   terraform apply
   ```

### Option 2: Temporarily Use Public Subnets (Quick PoC Fix)

**Pros:**
- Immediate fix
- No additional cost
- Good for testing/PoC

**Cons:**
- Tasks get public IPs (not ideal for production)
- Deviates from original requirements
- Less secure

**Implementation:**
1. Update Terraform to use public subnets temporarily
2. Set `assign_public_ip = true` in network configuration
3. Apply changes

### Option 3: Disable CloudWatch Logging Temporarily

**Pros:**
- Quick workaround
- No infrastructure changes

**Cons:**
- No logs (makes debugging impossible)
- Not recommended even for PoC

## Recommendation

For this PoC, I recommend **Option 1 (VPC Endpoints)** because:
1. It's the correct production-ready solution
2. Cost is minimal for a PoC (~$21/month)
3. We can test the actual production architecture
4. Logs are essential for debugging

Alternative: If cost is a concern for the PoC, use **Option 2** temporarily to test functionality, then switch to Option 1 before production.

## Implementation Steps for Option 1

### 1. Create VPC Endpoints Module

Create `terraform/modules/vpc_endpoints/main.tf`:

```hcl
# CloudWatch Logs VPC Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.environment}-logs-endpoint"
  }
}

# ECR API VPC Endpoint
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.environment}-ecr-api-endpoint"
  }
}

# ECR Docker VPC Endpoint
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project}-${var.environment}-ecr-dkr-endpoint"
  }
}

# S3 Gateway Endpoint (Free)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  tags = {
    Name = "${var.project}-${var.environment}-s3-endpoint"
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project}-${var.environment}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project}-${var.environment}-vpc-endpoints-sg"
  }
}
```

### 2. Add Module to Main Terraform

In `terraform/main.tf`, add:

```hcl
module "vpc_endpoints" {
  source = "./modules/vpc_endpoints"

  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = "10.0.0.0/16"
  private_subnet_ids  = [module.vpc.private_subnet_id, module.vpc.private_subnet_2_id]
  route_table_ids     = [module.vpc.private_route_table_id]
  region              = var.aws_region
  project             = var.project_name
  environment         = var.environment
}
```

### 3. Apply Changes

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Restart ECS Services

```bash
aws ecs update-service --cluster novapay-poc-cluster --service novapay-poc-kyc-service --force-new-deployment
aws ecs update-service --cluster novapay-poc-cluster --service novapay-poc-charge-service --force-new-deployment
aws ecs update-service --cluster novapay-poc-cluster --service novapay-poc-webhook-service --force-new-deployment
aws ecs update-service --cluster novapay-poc-cluster --service novapay-poc-auth-service --force-new-deployment
```

## Cost Breakdown

### VPC Endpoints (Option 1)
- Interface Endpoints: $0.01/hour × 3 endpoints = $0.03/hour
- Data Processing: $0.01/GB (minimal for logs)
- **Monthly Cost**: ~$21.60 + data transfer

### Current Infrastructure
- NAT Instance (t3.nano): $3.74/month
- **Total with VPC Endpoints**: ~$25/month

### Alternative (NAT Gateway)
- NAT Gateway: $32/month + data transfer
- **More expensive than NAT Instance + VPC Endpoints**

## Next Steps

1. **Decide on approach** (Option 1 or Option 2)
2. **Implement chosen solution**
3. **Test ECS services**
4. **Verify logs in CloudWatch**
5. **Test ALB endpoints**

## Current Build Status

✅ **All Docker images built successfully:**
- KYC: `637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-kyc:latest`
- Payment: `637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment:latest`
- Webhook: `637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-webhook:latest`

⚠️ **ECS services waiting for connectivity fix to start**
