# NovaPay Microservices Infrastructure

This Terraform configuration deploys a cost-optimized microservices architecture on AWS for PoC and learning purposes.

## Architecture Overview

- **Single-AZ deployment** for cost optimization
- **4 microservices**: Authorization, Charge, Webhook, KYC
- **ECS Fargate** with 1 task per service (0.25 vCPU, 0.5 GB RAM)
- **RDS PostgreSQL** db.t3.micro (Single-AZ)
- **ElastiCache Redis** cache.t3.micro (Single-node)
- **Application Load Balancer** with path-based routing
- **SQS Standard Queue** for webhook events
- **AWS Systems Manager Parameter Store** for credentials (free tier)
- **CloudWatch Logs** for observability

## Cost Estimate

- **Hourly**: ~$0.12/hour
- **Daily**: ~$2.88/day
- **Monthly**: ~$87.60/month
- **With AWS Free Tier**: ~$0.05/hour (first 12 months)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** >= 1.0 installed
4. **S3 Bucket** for Terraform state (create manually first)
5. **DynamoDB Table** for state locking (create manually first)

## Setup Instructions

### 1. Create S3 Backend Resources

```bash
# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket novapay-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket novapay-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name novapay-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### 2. Configure Variables

```bash
# Copy example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values
# IMPORTANT: Change the db_password!
nano terraform.tfvars
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Plan Deployment

```bash
terraform plan
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

### 6. Get Outputs

```bash
# Get ALB URL
terraform output alb_url

# Get all outputs
terraform output
```

## Accessing Services

After deployment, services are available at:

```
http://<ALB_DNS_NAME>/auth    - Authorization Service
http://<ALB_DNS_NAME>/charge  - Charge Service
http://<ALB_DNS_NAME>/refund  - Refund endpoint (Charge Service)
http://<ALB_DNS_NAME>/kyc     - KYC Service
```

## Testing the Deployment

```bash
# Get ALB DNS name
ALB_URL=$(terraform output -raw alb_url)

# Test Authorization Service
curl -X POST $ALB_URL/auth \
  -H 'Content-Type: application/json' \
  -d '{
    "card": "4111111111111111",
    "amount": 4999,
    "merchantId": "m_42",
    "idempotencyKey": "test-key-1"
  }'

# Test Health Endpoints
curl $ALB_URL/auth/health
curl $ALB_URL/charge/health
curl $ALB_URL/kyc/health
```

## Destroying Infrastructure

**IMPORTANT**: This will delete all resources. Make sure you have backups if needed.

```bash
terraform destroy
```

## Module Structure

```
terraform/
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example variables
└── modules/
    ├── vpc/                   # VPC and networking
    ├── parameter-store/       # AWS Systems Manager Parameter Store
    ├── rds/                   # PostgreSQL database
    ├── redis/                 # ElastiCache Redis
    ├── sqs/                   # SQS queues
    ├── alb/                   # Application Load Balancer
    ├── ecs/                   # ECS Fargate cluster and services
    └── cloudwatch/            # CloudWatch log groups
```

## Security Considerations

### For PoC/Learning (Current Configuration)
- ✅ Encryption at rest (RDS, Redis)
- ✅ Encryption in transit (Redis TLS)
- ✅ Parameter Store for credentials
- ✅ Security groups with least privilege
- ⚠️ HTTP only (no HTTPS/SSL certificate)
- ⚠️ Public subnets for ECS (no NAT Gateway)
- ⚠️ Single-AZ (no redundancy)

### For Production (Recommended Changes)
- Add HTTPS with ACM certificate
- Use private subnets with NAT Gateway
- Enable Multi-AZ for RDS and Redis
- Add WAF for ALB
- Enable VPC Flow Logs
- Add AWS Config rules
- Implement secrets rotation
- Add backup automation

## Monitoring

### CloudWatch Logs
```bash
# View logs for a service
aws logs tail /ecs/novapay-poc/auth-service --follow
```

### CloudWatch Metrics
- ECS Container Insights enabled
- RDS Enhanced Monitoring enabled
- Redis slow log enabled

## Troubleshooting

### ECS Tasks Not Starting
```bash
# Check ECS service events
aws ecs describe-services \
  --cluster novapay-poc-cluster \
  --services novapay-poc-auth-service

# Check task logs
aws logs tail /ecs/novapay-poc/auth-service --since 1h
```

### Database Connection Issues
```bash
# Verify Parameter Store values
aws ssm get-parameter --name /novapay/poc/rds/host
aws ssm get-parameter --name /novapay/poc/rds/database

# Check security group rules
aws ec2 describe-security-groups --group-ids <RDS_SG_ID>
```

### ALB Health Check Failures
```bash
# Check target health
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>
```

## Cost Optimization Tips

1. **Stop when not in use**: Destroy infrastructure when not actively testing
2. **Use AWS Free Tier**: First 12 months get significant discounts
3. **Monitor costs**: Set up AWS Budgets and Cost Alerts
4. **Right-size resources**: Adjust instance types based on actual usage

## Next Steps

1. Build and push Docker images to ECR
2. Update `terraform.tfvars` with ECR image URIs
3. Run `terraform apply` to deploy services
4. Implement database migrations
5. Set up CI/CD pipeline with GitHub Actions
6. Add monitoring and alerting

## Support

For issues or questions:
- Check Terraform logs: `terraform apply -debug`
- Review AWS CloudWatch Logs
- Verify security group rules
- Check IAM permissions

## License

This is a PoC/learning project. Use at your own risk.
