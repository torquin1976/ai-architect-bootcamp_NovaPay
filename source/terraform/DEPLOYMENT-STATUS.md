# NovaPay Terraform Deployment Status

## Current Status: Ready for Deployment

### Changes Completed (This Session)

#### 1. VPC Module Updates
- ✅ Added second public subnet (10.0.4.0/24) in us-east-1b for ALB multi-AZ requirement
- ✅ Added route table association for second public subnet
- ✅ Updated outputs to expose `public_subnet_ids` list
- ✅ Updated variables to include `public_subnet_2_cidr`

#### 2. ALB Module Updates
- ✅ Changed from single `public_subnet_id` to `public_subnet_ids` list
- ✅ ALB now deploys across both public subnets (us-east-1a and us-east-1b)

#### 3. IAM Policy Updates
- ✅ Added `iam:ListInstanceProfilesForRole` permission for cleanup operations
- ✅ File: `terraform/iam-policy-supplement.json`

#### 4. Main Configuration Updates
- ✅ Updated VPC module call to pass `public_subnet_2_cidr`
- ✅ Updated ALB module call to use `public_subnet_ids` instead of `public_subnet_id`

### Architecture Summary

**Network Layout:**
- VPC: 10.0.0.0/16
- Public Subnet 1: 10.0.1.0/24 (us-east-1a) - ALB, ECS tasks
- Public Subnet 2: 10.0.4.0/24 (us-east-1b) - ALB
- Private Subnet 1: 10.0.2.0/24 (us-east-1a) - RDS, Redis
- Private Subnet 2: 10.0.3.0/24 (us-east-1b) - RDS subnet group requirement

**Key Design Decisions:**
- ALB spans 2 AZs (AWS requirement)
- RDS uses 2 subnets but deploys to single AZ (cost optimization)
- ECS tasks run in single public subnet (cost optimization)
- Redis single-node in single AZ (cost optimization)

### Next Steps (When AWS Access Restored)

#### 1. Apply Updated IAM Policy
```bash
# The user needs to manually apply the updated iam-policy-supplement.json
# to the novapay-terraform-deploy IAM user
```

#### 2. Clean Up Remaining Resources from Previous Attempt
```bash
cd terraform

# Check for any remaining resources
terraform state list

# If state shows resources, destroy them
terraform destroy

# Manually delete these IAM roles if they still exist:
# - novapay-poc-rds-monitoring
# - novapay-poc-ecs-task
# - novapay-poc-ecs-task-execution
```

#### 3. Create Service-Linked Roles (Optional - Terraform will create if needed)
```bash
# ECS Service-Linked Role
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com

# ELB Service-Linked Role
aws iam create-service-linked-role --aws-service-name elasticloadbalancing.amazonaws.com

# RDS Service-Linked Role
aws iam create-service-linked-role --aws-service-name rds.amazonaws.com
```

#### 4. Deploy Infrastructure
```bash
cd terraform

# Initialize (if needed)
terraform init

# Review the plan
terraform plan -out=tfplan

# Apply the configuration
terraform apply tfplan
```

### Expected Resources to be Created

- **VPC & Networking:** VPC, 2 public subnets, 2 private subnets, IGW, route tables
- **ALB:** Application Load Balancer with 3 target groups (auth, charge, kyc)
- **ECS:** Cluster with 4 services (auth, charge, webhook, kyc)
- **RDS:** PostgreSQL instance (single-AZ, db.t3.micro)
- **Redis:** ElastiCache single-node cluster (cache.t3.micro)
- **SQS:** 2 queues (webhook, webhook-dlq)
- **Parameter Store:** Database and Redis connection parameters
- **CloudWatch:** Log groups for each service
- **IAM:** Task execution roles and task roles

### Known Issues Resolved

1. ✅ ALB multi-AZ requirement - now uses 2 public subnets
2. ✅ RDS subnet group requirement - uses 2 private subnets
3. ✅ Redis transit encryption - disabled for single-node
4. ✅ IAM cleanup permission - added ListInstanceProfilesForRole

### Files Modified

- `terraform/main.tf`
- `terraform/variables.tf`
- `terraform/modules/vpc/main.tf`
- `terraform/modules/vpc/variables.tf`
- `terraform/modules/vpc/outputs.tf`
- `terraform/modules/alb/main.tf`
- `terraform/modules/alb/variables.tf`
- `terraform/iam-policy-supplement.json`

### Estimated Costs (Monthly)

- RDS db.t3.micro: ~$15
- ElastiCache cache.t3.micro: ~$12
- ALB: ~$16
- ECS Fargate (4 services, 0.25 vCPU, 0.5 GB each): ~$15
- Data transfer, CloudWatch, etc.: ~$5
- **Total: ~$63/month**

### Contact Points

- AWS Account: 637423409019
- Region: us-east-1
- IAM User: novapay-terraform-deploy
- S3 State Bucket: novapay-terraform-state
- DynamoDB Lock Table: novapay-terraform-locks
