# NovaPay Local Testing Guide

This guide explains how to test the NovaPay microservices locally using Docker Desktop before deploying to AWS.

## Prerequisites

1. **Docker Desktop** installed and running
2. **Docker Compose** (included with Docker Desktop)
3. **curl** or **Postman** for API testing

## Architecture Overview

The local environment includes:

- **PostgreSQL** (port 5432) - Transaction database
- **Redis** (port 6379) - Idempotency cache
- **LocalStack** (port 4566) - AWS services emulation (SQS)
- **Payment Service** (port 3001) - Handles /auth, /charge, /refund
- **KYC Service** (port 3002) - Handles /kyc
- **Webhook Service** (background) - Processes webhook queue

## Quick Start

### 1. Start All Services

```bash
# From the project root directory
docker-compose up --build
```

This will:
- Build Docker images for all services
- Start PostgreSQL with sample data
- Start Redis cache
- Start LocalStack with SQS queue
- Start all microservices

### 2. Verify Services Are Running

```bash
# Check all containers are healthy
docker-compose ps

# Expected output:
# NAME                  STATUS
# novapay-postgres      Up (healthy)
# novapay-redis         Up (healthy)
# novapay-localstack    Up (healthy)
# novapay-payment       Up (healthy)
# novapay-kyc           Up (healthy)
# novapay-webhook       Up
```

### 3. Check Health Endpoints

```bash
# Payment service health
curl http://localhost:3001/health

# KYC service health
curl http://localhost:3002/health
```

Expected response:
```json
{
  "status": "ok",
  "pid": 1,
  "uptime": 12.345
}
```

## Testing Each Service

### Payment Service - Authorization Endpoint

**Test card authorization with idempotency:**

```bash
curl -X POST http://localhost:3001/auth \
  -H "Content-Type: application/json" \
  -d '{
    "card": "4111111111111111",
    "amount": 4999,
    "merchantId": "m_42",
    "idempotencyKey": "test-key-001"
  }'
```

Expected response:
```json
{
  "token": "abc123def456",
  "status": "AUTHORIZED",
  "amount": 4999
}
```

**Test idempotency (same request again):**

```bash
# Same request should return cached response
curl -X POST http://localhost:3001/auth \
  -H "Content-Type: application/json" \
  -d '{
    "card": "4111111111111111",
    "amount": 4999,
    "merchantId": "m_42",
    "idempotencyKey": "test-key-001"
  }'
```

Should return the same token.

### Payment Service - Charge Endpoint

**Test payment capture:**

```bash
curl -X POST http://localhost:3001/charge \
  -H "Content-Type: application/json" \
  -d '{
    "token": "abc123def456"
  }'
```

Expected response:
```json
{
  "ok": true
}
```

This will:
1. Update transaction status to CAPTURED in PostgreSQL
2. Send webhook event to SQS queue
3. Webhook service will process the event

### Payment Service - Refund Endpoint

**Test refund:**

```bash
curl -X POST http://localhost:3001/refund \
  -H "Content-Type: application/json" \
  -d '{
    "token": "abc123def456",
    "amount": 4999
  }'
```

Expected response:
```json
{
  "ok": true,
  "refunded": 4999
}
```

### KYC Service - Validation Endpoint

**Test SSN validation:**

```bash
# Valid SSN format
curl -X POST http://localhost:3002/kyc \
  -H "Content-Type: application/json" \
  -d '{
    "ssn": "123-45-6789"
  }'
```

Expected response:
```json
{
  "valid": true
}
```

**Test invalid SSN:**

```bash
curl -X POST http://localhost:3002/kyc \
  -H "Content-Type: application/json" \
  -d '{
    "ssn": "invalid"
  }'
```

Expected response:
```json
{
  "valid": false
}
```

## Verifying Data Persistence

### Check PostgreSQL Database

```bash
# Connect to PostgreSQL
docker exec -it novapay-postgres psql -U np -d novapay

# Query transactions
SELECT * FROM txns;

# Exit
\q
```

### Check Redis Cache

```bash
# Connect to Redis
docker exec -it novapay-redis redis-cli

# Check idempotency keys
KEYS idempotency:*

# Get a specific key
GET idempotency:test-key-001

# Exit
exit
```

### Check SQS Queue (LocalStack)

```bash
# List queues
docker exec -it novapay-localstack awslocal sqs list-queues

# Get queue attributes
docker exec -it novapay-localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/novapay-webhook-queue \
  --attribute-names All

# Receive messages (check what webhook service is processing)
docker exec -it novapay-localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/novapay-webhook-queue
```

## Viewing Logs

### View All Logs

```bash
docker-compose logs -f
```

### View Specific Service Logs

```bash
# Payment service
docker-compose logs -f payment-service

# KYC service
docker-compose logs -f kyc-service

# Webhook service
docker-compose logs -f webhook-service

# PostgreSQL
docker-compose logs -f postgres

# Redis
docker-compose logs -f redis

# LocalStack
docker-compose logs -f localstack
```

## End-to-End Test Flow

Test the complete payment flow:

```bash
# 1. Authorize payment
TOKEN=$(curl -s -X POST http://localhost:3001/auth \
  -H "Content-Type: application/json" \
  -d '{
    "card": "4111111111111111",
    "amount": 9999,
    "merchantId": "m_test",
    "idempotencyKey": "e2e-test-001"
  }' | jq -r '.token')

echo "Token: $TOKEN"

# 2. Capture payment (sends webhook to SQS)
curl -X POST http://localhost:3001/charge \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}"

# 3. Check webhook service logs
docker-compose logs webhook-service

# 4. Verify transaction status in database
docker exec -it novapay-postgres psql -U np -d novapay -c "SELECT * FROM txns WHERE id='$TOKEN';"

# 5. Refund payment
curl -X POST http://localhost:3001/refund \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\", \"amount\": 9999}"
```

## Performance Testing

### Test Idempotency Performance

```bash
# Send 100 requests with same idempotency key
for i in {1..100}; do
  curl -s -X POST http://localhost:3001/auth \
    -H "Content-Type: application/json" \
    -d '{
      "card": "4111111111111111",
      "amount": 4999,
      "merchantId": "m_perf",
      "idempotencyKey": "perf-test-001"
    }' > /dev/null
  echo "Request $i completed"
done
```

All requests should return the same token (cached response).

### Test KYC CPU Load

```bash
# Send multiple KYC requests
for i in {1..50}; do
  curl -s -X POST http://localhost:3002/kyc \
    -H "Content-Type: application/json" \
    -d '{"ssn": "123-45-6789"}' > /dev/null &
done
wait
echo "All KYC requests completed"
```

## Troubleshooting

### Services Won't Start

**Check Docker Desktop is running:**
```bash
docker info
```

**Check for port conflicts:**
```bash
# Check if ports are already in use
netstat -an | grep -E "3001|3002|5432|6379|4566"
```

**Rebuild images:**
```bash
docker-compose down
docker-compose build --no-cache
docker-compose up
```

### Database Connection Errors

**Check PostgreSQL is healthy:**
```bash
docker-compose ps postgres
```

**Manually test connection:**
```bash
docker exec -it novapay-postgres psql -U np -d novapay -c "SELECT 1;"
```

### Redis Connection Errors

**Check Redis is healthy:**
```bash
docker-compose ps redis
```

**Test Redis connection:**
```bash
docker exec -it novapay-redis redis-cli ping
```

### SQS/LocalStack Errors

**Check LocalStack is healthy:**
```bash
curl http://localhost:4566/_localstack/health
```

**Verify queue exists:**
```bash
docker exec -it novapay-localstack awslocal sqs list-queues
```

**Recreate queue:**
```bash
docker-compose restart localstack
```

### Webhook Service Not Processing Messages

**Check webhook service logs:**
```bash
docker-compose logs webhook-service
```

**Verify messages in queue:**
```bash
docker exec -it novapay-localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/novapay-webhook-queue \
  --attribute-names ApproximateNumberOfMessages
```

**Restart webhook service:**
```bash
docker-compose restart webhook-service
```

## Stopping Services

### Stop All Services

```bash
docker-compose down
```

### Stop and Remove Volumes (Clean Slate)

```bash
docker-compose down -v
```

This will delete all data (PostgreSQL, Redis, LocalStack).

### Stop Specific Service

```bash
docker-compose stop payment-service
docker-compose start payment-service
```

## Testing with Postman

Import this collection to test all endpoints:

**Collection JSON:**
```json
{
  "info": {
    "name": "NovaPay Local Testing",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Authorization",
      "request": {
        "method": "POST",
        "header": [{"key": "Content-Type", "value": "application/json"}],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"card\": \"4111111111111111\",\n  \"amount\": 4999,\n  \"merchantId\": \"m_42\",\n  \"idempotencyKey\": \"postman-test-001\"\n}"
        },
        "url": "http://localhost:3001/auth"
      }
    },
    {
      "name": "Charge",
      "request": {
        "method": "POST",
        "header": [{"key": "Content-Type", "value": "application/json"}],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"token\": \"{{token}}\"\n}"
        },
        "url": "http://localhost:3001/charge"
      }
    },
    {
      "name": "Refund",
      "request": {
        "method": "POST",
        "header": [{"key": "Content-Type", "value": "application/json"}],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"token\": \"{{token}}\",\n  \"amount\": 4999\n}"
        },
        "url": "http://localhost:3001/refund"
      }
    },
    {
      "name": "KYC Validation",
      "request": {
        "method": "POST",
        "header": [{"key": "Content-Type", "value": "application/json"}],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"ssn\": \"123-45-6789\"\n}"
        },
        "url": "http://localhost:3002/kyc"
      }
    },
    {
      "name": "Payment Health",
      "request": {
        "method": "GET",
        "url": "http://localhost:3001/health"
      }
    },
    {
      "name": "KYC Health",
      "request": {
        "method": "GET",
        "url": "http://localhost:3002/health"
      }
    }
  ]
}
```

## Next Steps

After successful local testing:

1. **Push images to ECR:**
   ```bash
   # Tag and push to ECR
   docker tag novapay-payment:latest 637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment:latest
   docker push 637423409019.dkr.ecr.us-east-1.amazonaws.com/novapay-payment:latest
   ```

2. **Update terraform.tfvars** with ECR image URLs

3. **Deploy to AWS:**
   ```bash
   cd terraform
   terraform apply
   ```

4. **Test on AWS** using ALB DNS name

## Differences Between Local and AWS

| Component | Local | AWS |
|-----------|-------|-----|
| Database | PostgreSQL container | RDS PostgreSQL (db.t3.micro) |
| Cache | Redis container | ElastiCache Redis (cache.t3.micro) |
| Queue | LocalStack SQS | AWS SQS Standard |
| Networking | Docker network | VPC with public/private subnets |
| Load Balancer | Direct port access | Application Load Balancer |
| Secrets | Environment variables | Parameter Store SecureString |
| Logging | Docker logs | CloudWatch Logs |

## Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
- [Redis Docker Image](https://hub.docker.com/_/redis)
