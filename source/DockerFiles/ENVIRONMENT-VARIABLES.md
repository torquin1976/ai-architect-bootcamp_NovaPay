# NovaPay Microservices - Environment Variables Configuration

## Overview
This document describes the environment variables required by each microservice and how they're injected via ECS Task Definitions.

## Environment Variable Strategy

### Sensitive Data (via Parameter Store - `secrets`)
- Database credentials (username, password)
- Database host
- Redis host

### Non-Sensitive Data (via `environment`)
- Port numbers
- AWS region
- SQS queue URLs
- Service names

## Service-Specific Environment Variables

### 1. Authorization Service (Auth)
**Location:** `DockerFiles/Payment/server.js` (will need separate auth service)

**Environment Variables:**
- `NODE_ENV` - Environment name (poc, dev, prod)
- `SERVICE_NAME` - "authorization-service"
- `AWS_REGION` - "us-east-1"
- `DB_PORT` - "5432"
- `REDIS_PORT` - "6379"

**Secrets (from Parameter Store):**
- `DB_HOST` - RDS endpoint
- `DB_NAME` - Database name
- `DB_USERNAME` - Database username
- `DB_PASSWORD` - Database password
- `REDIS_HOST` - Redis endpoint

### 2. Charge Service (Payment)
**Location:** `DockerFiles/Payment/server.js`

**Environment Variables:**
- `NODE_ENV` - Environment name
- `SERVICE_NAME` - "charge-service"
- `AWS_REGION` - "us-east-1"
- `SQS_QUEUE_URL` - Webhook queue URL
- `DB_PORT` - "5432"
- `REDIS_PORT` - "6379"

**Secrets (from Parameter Store):**
- `DB_HOST` - RDS endpoint
- `DB_NAME` - Database name
- `DB_USERNAME` - Database username
- `DB_PASSWORD` - Database password
- `REDIS_HOST` - Redis endpoint

**Dependencies:**
- Requires `@aws-sdk/client-sqs` package for SQS integration

### 3. Webhook Service
**Location:** `DockerFiles/WebHook/server.js`

**Environment Variables:**
- `NODE_ENV` - Environment name
- `SERVICE_NAME` - "webhook-service"
- `AWS_REGION` - "us-east-1"
- `SQS_QUEUE_URL` - Webhook queue URL

**No Secrets Required** - This service only reads from SQS

**Dependencies:**
- Requires `@aws-sdk/client-sqs` package

### 4. KYC Service
**Location:** `DockerFiles/KYC/server.js`

**Environment Variables:**
- `NODE_ENV` - Environment name
- `SERVICE_NAME` - "kyc-service"
- `AWS_REGION` - "us-east-1"
- `DB_PORT` - "5432"

**Secrets (from Parameter Store):**
- `DB_HOST` - RDS endpoint
- `DB_NAME` - Database name
- `DB_USERNAME` - Database username
- `DB_PASSWORD` - Database password

**Note:** KYC service doesn't use Redis but the connection is initialized for consistency

## Parameter Store Paths

All parameters are stored under `/novapay/poc/` prefix:

- `/novapay/poc/rds/host` - RDS endpoint (String)
- `/novapay/poc/rds/database` - Database name (String)
- `/novapay/poc/rds/username` - Database username (SecureString)
- `/novapay/poc/rds/password` - Database password (SecureString)
- `/novapay/poc/redis/host` - Redis endpoint (String)
- `/novapay/poc/redis/port` - Redis port (String)

## Required NPM Packages

### Payment Service (Charge)
```json
{
  "dependencies": {
    "express": "^4.18.0",
    "body-parser": "^1.20.0",
    "pg": "^8.11.0",
    "ioredis": "^5.3.0",
    "@aws-sdk/client-sqs": "^3.0.0"
  }
}
```

### KYC Service
```json
{
  "dependencies": {
    "express": "^4.18.0",
    "body-parser": "^1.20.0",
    "pg": "^8.11.0",
    "ioredis": "^5.3.0"
  }
}
```

### Webhook Service
```json
{
  "type": "module",
  "dependencies": {
    "@aws-sdk/client-sqs": "^3.0.0"
  }
}
```

## Terraform Configuration

The ECS task definitions in `terraform/modules/ecs/main.tf` have been updated to:

1. **Inject environment variables** using the `environment` block
2. **Inject secrets** from Parameter Store using the `secrets` block
3. **Grant IAM permissions** for:
   - Reading from Parameter Store
   - Decrypting SecureString parameters
   - Sending/receiving SQS messages

## Testing Locally

To test services locally, create a `.env` file:

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=novapay
DB_USERNAME=np
DB_PASSWORD=np

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# AWS
AWS_REGION=us-east-1
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/YOUR_ACCOUNT/novapay-poc-webhook-queue

# Service
NODE_ENV=development
SERVICE_NAME=charge-service
```

## Next Steps

1. **Create Authorization Service** - Currently missing, needs to be created based on Payment service
2. **Update package.json** files in each service directory with required dependencies
3. **Build Docker images** for each service
4. **Push images** to ECR or Docker Hub
5. **Update terraform.tfvars** with image URIs
6. **Deploy** using `terraform apply`
