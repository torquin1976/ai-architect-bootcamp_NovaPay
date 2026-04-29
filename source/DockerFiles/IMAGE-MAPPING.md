# NovaPay Docker Image to ECS Service Mapping

## Overview
For the PoC, we're using 3 Docker images to power 4 ECS services. The Payment image is reused for both Auth and Charge services, with the ALB routing determining which endpoints each service handles.

## Image to Service Mapping

### 1. Payment Image → Auth Service + Charge Service
**Docker Image:** `DockerFiles/Payment/`
**Contains Endpoints:** `/auth`, `/charge`, `/refund`, `/health`

**Used By:**
- **Auth Service** (ECS) - ALB routes `/auth` traffic here
- **Charge Service** (ECS) - ALB routes `/charge` and `/refund` traffic here

**Why:** Both services run the same container image. The ALB path-based routing determines which endpoint gets called. This is a PoC simplification - in production, you'd split these into separate services.

### 2. KYC Image → KYC Service
**Docker Image:** `DockerFiles/KYC/`
**Contains Endpoints:** `/kyc`, `/health`

**Used By:**
- **KYC Service** (ECS) - ALB routes `/kyc` traffic here

### 3. WebHook Image → WebHook Service
**Docker Image:** `DockerFiles/WebHook/`
**Contains:** Background SQS worker (no HTTP endpoints)

**Used By:**
- **WebHook Service** (ECS) - Polls SQS queue and sends webhooks

## Terraform Configuration

In your `terraform.tfvars`, you'll set:

```hcl
# Same image for both auth and charge services
auth_service_image    = "your-registry/novapay-payment:latest"
charge_service_image  = "your-registry/novapay-payment:latest"

# Separate images for KYC and webhook
kyc_service_image     = "your-registry/novapay-kyc:latest"
webhook_service_image = "your-registry/novapay-webhook:latest"
```

## Docker Build Commands

```bash
# Build Payment image (used for both Auth and Charge services)
cd DockerFiles/Payment
docker build -t novapay-payment:latest .

# Build KYC image
cd ../KYC
docker build -t novapay-kyc:latest .

# Build WebHook image
cd ../WebHook
docker build -t novapay-webhook:latest .
```

## ALB Routing Configuration

The Application Load Balancer routes traffic as follows:

| Path       | Target Service | Container Image | Container Endpoint |
|------------|----------------|-----------------|-------------------|
| `/auth`    | Auth Service   | Payment         | `/auth`           |
| `/charge`  | Charge Service | Payment         | `/charge`         |
| `/refund`  | Charge Service | Payment         | `/refund`         |
| `/kyc`     | KYC Service    | KYC             | `/kyc`            |
| (none)     | WebHook Service| WebHook         | (SQS worker)      |

## Environment Variables

### Auth Service (using Payment image)
- All DB and Redis credentials
- No SQS_QUEUE_URL needed (doesn't send webhooks)

### Charge Service (using Payment image)
- All DB and Redis credentials
- **SQS_QUEUE_URL** - Needed to send webhook events after charge/refund

### KYC Service
- DB credentials only
- No Redis or SQS needed

### WebHook Service
- **SQS_QUEUE_URL** - Needed to poll for webhook events
- No DB or Redis needed

## Future Production Considerations

For production, consider:
1. **Split Payment image** into separate Auth and Charge services
2. **Add authentication/authorization** middleware
3. **Implement circuit breakers** between services
4. **Add distributed tracing** (X-Ray, OpenTelemetry)
5. **Implement proper error handling** and retry logic
6. **Add rate limiting** per service
7. **Use separate databases** per service (if following strict microservices pattern)
