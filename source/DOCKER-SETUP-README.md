# NovaPay Docker Local Testing Setup

Complete Docker-based local testing environment for NovaPay microservices.

## What's Included

This setup provides a complete local environment that mirrors the AWS architecture:

### Infrastructure Services
- **PostgreSQL 15** - Transaction database with sample data
- **Redis 7** - Idempotency cache
- **LocalStack** - AWS services emulation (SQS queues)

### Application Services
- **Payment Service** (port 3001) - Handles authorization, charge, and refund
- **KYC Service** (port 3002) - Handles SSN validation
- **Webhook Service** (background) - Processes webhook events from SQS

## Quick Start

### Option 1: Automated Setup (Recommended)

**For Windows:**
```bash
# Double-click or run in Command Prompt:
start-local.bat

# Or in Git Bash/PowerShell:
docker-compose -f docker-compose.windows.yml up --build -d
```

**For Mac/Linux:**
```bash
# Make script executable
chmod +x start-local.sh

# Start everything
./start-local.sh
```

**Windows Users:** If you encounter LocalStack errors, see [WINDOWS-TROUBLESHOOTING.md](WINDOWS-TROUBLESHOOTING.md)

This will:
1. Check Docker is running
2. Stop any existing containers
3. Build all Docker images
4. Start all services
5. Wait for health checks
6. Display service URLs

### Option 2: Manual Setup

**For Windows:**
```bash
# Build and start all services
docker-compose -f docker-compose.windows.yml up --build -d

# Check status
docker-compose -f docker-compose.windows.yml ps
```

**For Mac/Linux:**
```bash
# Build and start all services
docker-compose up --build -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

## Running Tests

### Automated Test Suite

```bash
# Make script executable
chmod +x test-services.sh

# Run all tests
./test-services.sh
```

This tests:
- Health endpoints
- Authorization with idempotency
- Charge transactions
- Refund transactions
- KYC validation
- Database persistence
- Redis cache
- SQS queue

### Manual Testing

See [LOCAL-TESTING-GUIDE.md](LOCAL-TESTING-GUIDE.md) for detailed curl commands and testing scenarios.

## Project Structure

```
.
├── docker-compose.yml           # Docker Compose configuration
├── init-db.sql                  # PostgreSQL initialization script
├── localstack-init.sh           # LocalStack SQS setup script
├── start-local.sh               # Automated startup script
├── test-services.sh             # Automated test script
├── .env.example                 # Environment variables reference
├── DockerFiles/
│   ├── Payment/
│   │   ├── dockerfile           # Payment service Dockerfile
│   │   ├── server.js            # Payment service code
│   │   ├── package.json         # Dependencies
│   │   └── buildspec.yml        # CodeBuild spec (for AWS)
│   ├── KYC/
│   │   ├── dockerfile           # KYC service Dockerfile
│   │   ├── server.js            # KYC service code
│   │   ├── package.json         # Dependencies
│   │   └── buildspec.yml        # CodeBuild spec (for AWS)
│   └── WebHook/
│       ├── dockerfile           # Webhook service Dockerfile
│       ├── server.js            # Webhook service code
│       ├── package.json         # Dependencies
│       └── buildspec.yml        # CodeBuild spec (for AWS)
└── LOCAL-TESTING-GUIDE.md       # Detailed testing guide
```

## Service Ports

| Service | Port | Endpoints |
|---------|------|-----------|
| Payment | 3001 | /auth, /charge, /refund, /health |
| KYC | 3002 | /kyc, /health |
| PostgreSQL | 5432 | Database connection |
| Redis | 6379 | Cache connection |
| LocalStack | 4566 | SQS API |

## Environment Variables

All services are pre-configured with environment variables in `docker-compose.yml`:

- **Database**: `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`
- **Redis**: `REDIS_HOST`, `REDIS_PORT`
- **AWS**: `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`
- **SQS**: `SQS_QUEUE_URL`, `AWS_ENDPOINT_URL` (for LocalStack)

See `.env.example` for reference.

## Common Commands

### Start Services
```bash
docker-compose up -d
```

### Stop Services
```bash
docker-compose down
```

### Rebuild Services
```bash
docker-compose up --build -d
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f payment-service
```

### Restart Service
```bash
docker-compose restart payment-service
```

### Check Service Status
```bash
docker-compose ps
```

### Clean Everything (including data)
```bash
docker-compose down -v
```

## Accessing Services

### PostgreSQL Database
```bash
# Connect to database
docker exec -it novapay-postgres psql -U np -d novapay

# Run query
docker exec -it novapay-postgres psql -U np -d novapay -c "SELECT * FROM txns;"
```

### Redis Cache
```bash
# Connect to Redis
docker exec -it novapay-redis redis-cli

# Check keys
docker exec -it novapay-redis redis-cli KEYS '*'
```

### LocalStack SQS
```bash
# List queues
docker exec -it novapay-localstack awslocal sqs list-queues

# Get queue attributes
docker exec -it novapay-localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/novapay-webhook-queue \
  --attribute-names All
```

## Troubleshooting

### Services Won't Start

**Check Docker Desktop is running:**
```bash
docker info
```

**Check for port conflicts:**
```bash
# Windows
netstat -an | findstr "3001 3002 5432 6379 4566"

# Mac/Linux
lsof -i :3001 -i :3002 -i :5432 -i :6379 -i :4566
```

**Clean and rebuild:**
```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Service Health Check Failing

**Check logs:**
```bash
docker-compose logs payment-service
```

**Check dependencies:**
```bash
# Ensure PostgreSQL is healthy
docker-compose ps postgres

# Ensure Redis is healthy
docker-compose ps redis
```

**Restart service:**
```bash
docker-compose restart payment-service
```

### Database Connection Errors

**Verify PostgreSQL is running:**
```bash
docker exec -it novapay-postgres psql -U np -d novapay -c "SELECT 1;"
```

**Check database logs:**
```bash
docker-compose logs postgres
```

### Redis Connection Errors

**Test Redis:**
```bash
docker exec -it novapay-redis redis-cli ping
```

**Check Redis logs:**
```bash
docker-compose logs redis
```

### LocalStack/SQS Issues

**Check LocalStack health:**
```bash
curl http://localhost:4566/_localstack/health
```

**Verify queue exists:**
```bash
docker exec -it novapay-localstack awslocal sqs list-queues
```

**Restart LocalStack:**
```bash
docker-compose restart localstack
```

### Webhook Service Not Processing

**Check webhook logs:**
```bash
docker-compose logs webhook-service
```

**Verify messages in queue:**
```bash
docker exec -it novapay-localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/novapay-webhook-queue \
  --attribute-names ApproximateNumberOfMessages
```

## Performance Considerations

### Resource Usage

Typical resource usage:
- **CPU**: ~10-15% (idle), ~30-40% (under load)
- **Memory**: ~2-3 GB total
- **Disk**: ~1-2 GB (images + volumes)

### Scaling for Load Testing

To test with higher load, increase service replicas:

```yaml
# In docker-compose.yml
payment-service:
  deploy:
    replicas: 3
```

Or run multiple instances manually:
```bash
docker-compose up --scale payment-service=3
```

## Differences from AWS Deployment

| Component | Local | AWS |
|-----------|-------|-----|
| Database | PostgreSQL container | RDS PostgreSQL (db.t3.micro) |
| Cache | Redis container | ElastiCache Redis (cache.t3.micro) |
| Queue | LocalStack SQS | AWS SQS Standard |
| Networking | Docker network | VPC with subnets |
| Load Balancer | Direct port access | Application Load Balancer |
| Secrets | Environment variables | Parameter Store |
| Logging | Docker logs | CloudWatch Logs |
| Scaling | Manual | ECS auto-scaling |

## Next Steps

After successful local testing:

1. **Push images to ECR:**
   ```bash
   # Login to ECR
   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 637423409019.dkr.ecr.us-east-1.amazonaws.com
   
   # Tag images
   docker tag novapay-payment:latest 637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment:latest
   docker tag novapay-kyc:latest 637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-kyc:latest
   docker tag novapay-webhook:latest 637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-webhook:latest
   
   # Push images
   docker push 637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment:latest
   docker push 637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-kyc:latest
   docker push 637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-webhook:latest
   ```

2. **Update Terraform variables:**
   ```hcl
   # In terraform.tfvars
   auth_service_image    = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment:latest"
   charge_service_image  = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment:latest"
   webhook_service_image = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-webhook:latest"
   kyc_service_image     = "637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-kyc:latest"
   ```

3. **Deploy to AWS:**
   ```bash
   cd terraform
   terraform apply
   ```

## Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres)
- [Redis Docker Hub](https://hub.docker.com/_/redis)
- [AWS SDK for JavaScript](https://docs.aws.amazon.com/sdk-for-javascript/)

## Support

For issues or questions:
1. Check the [LOCAL-TESTING-GUIDE.md](LOCAL-TESTING-GUIDE.md)
2. Review Docker logs: `docker-compose logs -f`
3. Check service health: `docker-compose ps`
4. Verify environment variables in `docker-compose.yml`
