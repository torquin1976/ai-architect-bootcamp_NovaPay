# NovaPay Microservices Migration - Project Inputs

## Document Purpose
This document captures the original problem statement, requirements, and key decisions made during the NovaPay microservices migration project. It can be shared with team members, stakeholders, or used as reference documentation.

---

## Original Problem Statement

**Company**: NovaPay  
**Business**: Payment API powering checkout for 420 Shopify and WooCommerce merchants across the US  
**Scale**: ~$22M GMV/month, peak at ~210 TPS

### Current Architecture (As-Is)

**Infrastructure**:
- Single Node.js monolith on one m5.2xlarge EC2 instance
- Single availability zone (us-east-1a only)
- Fronted by a single Elastic IP
- Route53 → Elastic IP → EC2 instance

**Application**:
- Node.js monolith (pm2, 1 process)
- nginx :80 → app :3000
- Endpoints: /auth, /charge, /refund, /webhook, /kyc, /settle, /admin, /reports

**Data Layer**:
- PostgreSQL RDS (db.t3.medium, single-AZ, no replica)
- Redis (same EC2 box, redis-server 6.2, no AOF)
- S3 (receipts, us-east-1)
- Backup: daily snapshot

**Operational Characteristics**:
- RTO: "few hours"
- RPO: up to 24h
- AZ redundancy: NONE
- Deploys: SSH + git pull + pm2 restart
- CI/CD: none
- Observability: pm2 logs, 1 CloudWatch alarm (CPU > 90%)

---

## Project Requirements

### 1. Service Decomposition
- 3 independent services with isolated failure domains
- Externalize idempotency via ElastiCache
- Durable webhook queue - replace in-memory array with SQS

### 2. Infrastructure Requirements (Original)
- Multi-AZ AWS Fargate tasks across 2 AZs with autoscaling
- ALB path-based routing with automatic deregistration
- RDS Multi-AZ & RDS Proxy with transparent connection pooling and failover
- ElastiCache Redis 7 with multi-AZ and automatic failover

### 3. CI/CD Pipeline
- GitHub Actions
- CodeDeploy with rollback (blue/green deployment)

### 4. Migration Strategy
- Strangler Fig migration with incremental cutover

### 5. Observability
- Structured logs
- CloudWatch dashboard with alarms (P99 in particular)

### 6. Infrastructure as Code
- Terraform
- No secrets in source

---

## Key Project Decisions & Changes

### Decision 1: Cost Optimization for PoC/Learning
**Context**: Initial design was production-grade with Multi-AZ, RDS Proxy, NAT Gateway, etc.

**User Request**: "Please alter this to be fully cost optimized, very light weight, and use bare minimum AWS resources - for PoC and internal learning at this stage."

**Changes Made**:
- **RDS**: Changed from Multi-AZ to Single-AZ (db.t3.micro)
- **RDS Proxy**: Removed (direct connections instead)
- **ElastiCache**: Changed to single-node Redis (cache.t3.micro)
- **NAT Gateway**: Removed (ECS tasks in public subnet)
- **SQS**: Standard queue instead of FIFO
- **Secrets Manager**: Replaced with AWS Systems Manager Parameter Store (free tier)
- **Deployment**: Single-AZ deployment in us-east-1a

**Cost Impact**: ~$0.12/hour (~$0.05/hour with free tier) vs. original production-grade estimate

### Decision 2: Credentials Management
**User Request**: "What is the hourly cost to run this setup? Please include shift from Secrets Manager to AWS Systems Manager Parameter Store"

**Implementation**:
- Use AWS Systems Manager Parameter Store instead of environment variables
- Store database credentials as SecureString parameters
- Free tier eligible
- Path prefix: `/novapay/*`

### Decision 3: IAM Security
**User Request**: "Create least privileged IAM policy"

**Implementation**:
- Created comprehensive IAM policy with 15 permission statements
- Scoped permissions where possible:
  - IAM roles limited to `novapay-*` prefix
  - Parameter Store limited to `/novapay/*` paths
  - S3 limited to specific state bucket
- Created automated setup script (`setup-iam.sh`)
- Created automated cleanup script (`cleanup-iam.sh`)
- Documented in `IAM-POLICY-README.md`

---

## Target Architecture

### Microservices (4 Services)
1. **Authorization Service** - POST /auth, GET /health
2. **Charge Service** - POST /charge, POST /refund, GET /health
3. **Webhook Service** - Background worker processing SQS queue
4. **KYC Service** - POST /kyc, GET /health

### AWS Infrastructure
- **Compute**: ECS Fargate (0.5 vCPU, 1 GB memory per service)
- **Database**: RDS PostgreSQL db.t3.micro (Single-AZ)
- **Cache**: ElastiCache Redis cache.t3.micro (Single-node)
- **Queue**: SQS Standard queue + DLQ
- **Load Balancer**: Application Load Balancer with path-based routing
- **Networking**: VPC with public subnet (Single-AZ, no NAT Gateway)
- **Secrets**: AWS Systems Manager Parameter Store
- **Logging**: CloudWatch Logs (30-day retention)
- **Monitoring**: CloudWatch Dashboard + Alarms

### Service Configuration
- **Min tasks**: 3 per service
- **Max tasks**: 10 per service
- **Autoscaling**: Target 70% CPU utilization
- **Health checks**: 30s interval, 5s timeout
- **Connection draining**: 60 seconds

---

## Terraform Structure

### Root Files
- `main.tf` - Main infrastructure orchestration
- `variables.tf` - Input variables
- `outputs.tf` - Output values
- `terraform.tfvars.example` - Example configuration
- `README.md` - Setup and deployment instructions
- `.gitignore` - Exclude sensitive files
- `deploy.sh` - Deployment automation script

### Modules (8 Total)
1. **vpc** - VPC, subnets, route tables, security groups
2. **parameter-store** - SSM parameters for credentials
3. **rds** - PostgreSQL database
4. **redis** - ElastiCache Redis cluster
5. **sqs** - SQS queues (main + DLQ)
6. **alb** - Application Load Balancer, target groups, listeners
7. **ecs** - ECS cluster, task definitions, services
8. **cloudwatch** - Log groups, dashboard, alarms

### IAM Files
- `iam-policy-terraform-deploy.json` - Least-privilege IAM policy
- `setup-iam.sh` - Automated IAM user creation
- `cleanup-iam.sh` - Automated IAM resource cleanup
- `IAM-POLICY-README.md` - Comprehensive IAM documentation

---

## Implementation Plan

### Total Tasks: 26
- **Infrastructure setup**: Tasks 1-6
- **Service implementation**: Tasks 7-10
- **Containerization**: Task 13
- **ECS deployment**: Tasks 14-17
- **CI/CD pipeline**: Task 18
- **Migration phases**: Tasks 19-24
- **Backup strategy**: Task 25
- **Final validation**: Task 26

### Optional Tasks (marked with *)
- Unit tests for each service (Tasks 7.5, 8.5, 9.4, 10.4)
- Can be skipped for faster MVP delivery

---

## Migration Strategy (Strangler Fig Pattern)

### Phase 1: Parallel Run
- Deploy all microservices with 0% traffic
- Validate functional equivalence
- Monitor for 24 hours

### Phase 2: Authorization Service Cutover
- 10% traffic → monitor 24h
- 50% traffic → monitor 48h
- 100% traffic → monitor 1 week
- Automatic rollback if error rate > 1%

### Phase 3: Charge Service Cutover
- Same gradual rollout as Phase 2
- Monitor webhook delivery success rates

### Phase 4: KYC Service Cutover
- Same gradual rollout as Phase 2
- Monitor CPU utilization and latency improvements

### Phase 5: Monolith Decommission
- Verify 100% traffic on microservices for 1 week
- Create AMI snapshot
- Remove from ALB
- Terminate EC2 instance

---

## Reference Files

### Original Context Files
- `DockerFile.txt` - Current monolith Dockerfile
- `server.js` - Current monolith application code
- `NovaPay As-is.png` - Current architecture diagram
- `Target Architecture PartA.png` - Target architecture (Part A)
- `Target Architecture PartB.png` - Target architecture (Part B)
- `Additional Rqmts.txt` - Additional requirements

### Generated Specification Files
- `.kiro/specs/novapay-microservices-migration/requirements.md` - 17 requirements
- `.kiro/specs/novapay-microservices-migration/design.md` - Complete architecture design
- `.kiro/specs/novapay-microservices-migration/tasks.md` - 26 implementation tasks

---

## AWS Account Information

**Account ID**: 637423409019  
**Region**: us-east-1  
**IAM User**: novapay-terraform-deploy  
**User ARN**: arn:aws:iam::637423409019:user/novapay-terraform-deploy

---

## Next Steps

### Prerequisites
1. ✅ AWS CLI configured
2. ✅ IAM user created with proper permissions
3. ⏳ Create S3 bucket for Terraform state
4. ⏳ Create DynamoDB table for state locking

### Deployment Steps
1. Initialize Terraform backend (S3 + DynamoDB)
2. Configure `terraform.tfvars` with environment-specific values
3. Run `terraform init`
4. Run `terraform plan` to review changes
5. Run `terraform apply` to deploy infrastructure
6. Implement microservices (Tasks 7-10)
7. Build and push Docker images
8. Deploy services to ECS
9. Execute migration phases

---

## Cost Estimates

### Hourly Cost: ~$0.12/hour
- RDS db.t3.micro (Single-AZ): ~$0.017/hour
- ElastiCache cache.t3.micro (Single-node): ~$0.017/hour
- ECS Fargate (4 services × 3 tasks × 0.5 vCPU, 1 GB): ~$0.073/hour
- ALB: ~$0.025/hour
- SQS, CloudWatch, Parameter Store: Minimal/free tier

### With Free Tier: ~$0.05/hour
- First 750 hours of db.t3.micro free
- First 750 hours of cache.t3.micro free
- Reduced ECS Fargate costs

### Monthly Cost (24/7 operation)
- Without free tier: ~$86/month
- With free tier: ~$36/month

---

## Document History

**Created**: 2026-04-25  
**Purpose**: Capture project inputs for team sharing  
**Audience**: Team members, stakeholders, future maintainers  
**Status**: Complete - Ready for implementation

---

## Contact & Support

For questions about this project:
- Review the specification files in `.kiro/specs/novapay-microservices-migration/`
- Check the Terraform README at `terraform/README.md`
- Review IAM setup at `terraform/IAM-POLICY-README.md`
