# LocalStack Community Edition (Free Tier)

## Overview

This project uses **LocalStack Community Edition 3.5.0**, which is completely free and open-source. No license key or authentication is required.

## ⚠️ Important: Version Pinning

We use a **specific stable version** (`3.5.0`) instead of `latest` because:

- ✅ `3.5.0` is a stable Community Edition release (free)
- ❌ `latest` may pull development/nightly builds that require authentication
- ❌ Development builds (e.g., `2026.4.0.dev`) require `LOCALSTACK_AUTH_TOKEN`

## Configuration

Both `docker-compose.yml` and `docker-compose.windows.yml` use:

```yaml
image: localstack/localstack:3.5.0    # Pinned stable version
environment:
  SERVICES: sqs                        # Only using SQS (free service)
  AWS_DEFAULT_REGION: us-east-1
```

**No authentication variables needed!**

## Free vs Pro Features

### ✅ Free (Community Edition)
- **SQS** - Simple Queue Service ✓ (what we use)
- **S3** - Object storage
- **DynamoDB** - NoSQL database
- **Lambda** - Serverless functions
- **API Gateway** - REST APIs
- **CloudWatch** - Logs and metrics
- **SNS** - Notifications
- **IAM** - Identity management
- And many more...

### 🔒 Pro (Requires License)
- Advanced IAM features
- RDS (Relational databases)
- ECS/EKS (Container orchestration)
- CloudFormation (full support)
- Persistence across restarts
- Cloud Pods
- Advanced debugging

## What We Use

For NovaPay local testing, we only use:
- **SQS** - For webhook queue (100% free)

All other infrastructure (PostgreSQL, Redis) runs in separate containers, not through LocalStack.

## Verifying Free Tier

When LocalStack starts, you should see:
```
LocalStack version: X.X.X
LocalStack Community Edition
```

If you see "Pro" or license warnings, check:

1. **No API key set:**
   ```bash
   docker exec novapay-localstack env | grep LOCALSTACK_API_KEY
   # Should show: LOCALSTACK_API_KEY=
   ```

2. **Using Community image:**
   ```bash
   docker inspect novapay-localstack | grep Image
   # Should show: localstack/localstack:latest
   ```

3. **No Pro features enabled:**
   ```bash
   docker logs novapay-localstack | grep -i "pro\|license"
   # Should not show Pro activation messages
   ```

## Troubleshooting Pro Image Warnings

### Error: "License activation failed" or "No credentials were found"

This means Docker pulled a development/nightly build instead of the stable Community Edition.

**Solution:**

1. **Remove the current image:**
   ```bash
   docker-compose down
   docker rmi localstack/localstack:latest
   ```

2. **Pull the specific stable version:**
   ```bash
   docker pull localstack/localstack:3.5.0
   ```

3. **Verify the version:**
   ```bash
   docker images | grep localstack
   # Should show: localstack/localstack   3.5.0
   ```

4. **Restart with the pinned version:**
   ```bash
   # Windows
   docker-compose -f docker-compose.windows.yml up -d
   
   # Mac/Linux
   docker-compose up -d
   ```

### If you see "2026.4.0.dev" or similar development versions:

### If you see "2026.4.0.dev" or similar development versions:

**This is a development/nightly build that requires authentication.**

**Fix:**
```bash
# Remove all LocalStack images
docker rmi $(docker images localstack/localstack -q)

# Pull the stable Community Edition
docker pull localstack/localstack:3.5.0

# Verify
docker images | grep localstack

# Restart
docker-compose up -d
```

**1. Pull the latest Community image:**
```bash
docker pull localstack/localstack:latest
```

**2. Remove old containers:**
```bash
docker-compose down
docker rm -f novapay-localstack
```

**3. Clear Docker cache:**
```bash
docker system prune -a
```

**4. Restart with fresh image:**
```bash
# Windows
docker-compose -f docker-compose.windows.yml up --build -d

# Mac/Linux
docker-compose up --build -d
```

### If warnings persist:

**Check for environment variables:**
```bash
# Ensure no LOCALSTACK_API_KEY in your environment
echo $LOCALSTACK_API_KEY
# Should be empty

# Windows
echo %LOCALSTACK_API_KEY%
# Should be empty
```

**Verify docker-compose configuration:**
```bash
# Check the environment section
docker-compose config | grep -A 10 localstack
```

## Cost

LocalStack Community Edition is:
- ✅ **100% Free**
- ✅ **Open Source** (Apache 2.0 License)
- ✅ **No Credit Card Required**
- ✅ **No Time Limits**
- ✅ **No Usage Limits** for Community features

## Alternative: Real AWS SQS

If you prefer to use real AWS SQS instead of LocalStack:

**1. Create SQS queue in AWS:**
```bash
aws sqs create-queue --queue-name novapay-webhook-queue
```

**2. Update docker-compose.yml:**
```yaml
payment-service:
  environment:
    SQS_QUEUE_URL: https://sqs.us-east-1.amazonaws.com/637423409019/novapay-webhook-queue
    AWS_ACCESS_KEY_ID: your-access-key
    AWS_SECRET_ACCESS_KEY: your-secret-key
    # Remove: AWS_ENDPOINT_URL: http://localstack:4566
```

**3. Remove LocalStack service:**
```yaml
# Comment out or remove the localstack service
```

**Cost:** AWS SQS Free Tier includes 1 million requests/month.

## Resources

- [LocalStack Community Edition](https://github.com/localstack/localstack)
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [LocalStack Free vs Pro](https://localstack.cloud/pricing/)
- [AWS SQS Pricing](https://aws.amazon.com/sqs/pricing/)

## Summary

✅ **You are using the free Community Edition**
✅ **No license or payment required**
✅ **SQS is fully supported in the free tier**
✅ **Perfect for local development and testing**

If you see any Pro-related messages, they're just informational - you can safely ignore them as long as the SQS service works correctly.
