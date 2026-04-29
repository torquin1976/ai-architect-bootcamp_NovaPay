# NovaPay Docker Local Testing - Quick Start

## ⚠️ Important: LocalStack Version

We use **LocalStack 3.5.0** (stable Community Edition). If you see authentication errors, run:

**Windows:**
```bash
fix-localstack-version.bat
```

**Mac/Linux:**
```bash
chmod +x fix-localstack-version.sh
./fix-localstack-version.sh
```

## 🚀 For Windows Users

### Quick Start
```bash
start-local.bat
```

### If You Get LocalStack Errors
The error `Device or resource busy` is common on Windows. We've created a Windows-optimized configuration:

```bash
docker-compose -f docker-compose.windows.yml up --build -d
```

See [WINDOWS-TROUBLESHOOTING.md](WINDOWS-TROUBLESHOOTING.md) for detailed solutions.

## 🚀 For Mac/Linux Users

### Quick Start
```bash
chmod +x start-local.sh
./start-local.sh
```

Or manually:
```bash
docker-compose up --build -d
```

## 📋 What Gets Started

- **PostgreSQL** (port 5432) - Database with sample data
- **Redis** (port 6379) - Cache for idempotency
- **LocalStack** (port 4566) - SQS queue emulation
- **Payment Service** (port 3001) - `/auth`, `/charge`, `/refund`
- **KYC Service** (port 3002) - `/kyc`
- **Webhook Service** (background) - Processes webhooks

## 🧪 Test the Services

```bash
# Test authorization
curl -X POST http://localhost:3001/auth \
  -H "Content-Type: application/json" \
  -d '{"card":"4111111111111111","amount":4999,"merchantId":"m_42","idempotencyKey":"test-001"}'

# Test KYC
curl -X POST http://localhost:3002/kyc \
  -H "Content-Type: application/json" \
  -d '{"ssn":"123-45-6789"}'

# Check health
curl http://localhost:3001/health
curl http://localhost:3002/health
```

Or run the automated test suite:
```bash
chmod +x test-services.sh
./test-services.sh
```

## 📚 Documentation

- **[DOCKER-SETUP-README.md](DOCKER-SETUP-README.md)** - Complete Docker setup guide
- **[LOCAL-TESTING-GUIDE.md](LOCAL-TESTING-GUIDE.md)** - Detailed testing guide with examples
- **[WINDOWS-TROUBLESHOOTING.md](WINDOWS-TROUBLESHOOTING.md)** - Windows-specific issues and solutions

## 🛑 Stop Services

**Windows:**
```bash
docker-compose -f docker-compose.windows.yml down
```

**Mac/Linux:**
```bash
docker-compose down
```

## 🔧 Common Issues

### "Cannot find module" errors in services
→ **Rebuild services:** `rebuild-services.bat` (Windows) or `./rebuild-services.sh` (Mac/Linux)
→ See [DOCKER-REBUILD-GUIDE.md](DOCKER-REBUILD-GUIDE.md) for details

### LocalStack authentication error ("License activation failed")
→ **Run the fix script:** `fix-localstack-version.bat` (Windows) or `./fix-localstack-version.sh` (Mac/Linux)
→ See [LOCALSTACK-VERSION-FIX.md](LOCALSTACK-VERSION-FIX.md) for details

### LocalStack "Pro image" warning
→ See [LOCALSTACK-FREE-TIER.md](LOCALSTACK-FREE-TIER.md) - We use the free Community Edition (no license needed)

### LocalStack keeps restarting (Windows)
→ Use `docker-compose.windows.yml` instead of `docker-compose.yml`

### Port already in use
→ Check what's using the port: `netstat -ano | findstr :3001`

### Services won't start
→ Ensure Docker Desktop is running: `docker info`

### Need to reset everything
```bash
docker-compose down -v
docker system prune -a
```

## 📁 Files Overview

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Main Docker Compose (Mac/Linux) |
| `docker-compose.windows.yml` | Windows-optimized configuration |
| `start-local.sh` | Automated startup (Mac/Linux) |
| `start-local.bat` | Automated startup (Windows) |
| `test-services.sh` | Automated test suite |
| `init-db.sql` | Database initialization |
| `localstack-init.sh` | SQS queue setup |

## ✅ Next Steps

After successful local testing:

1. Push images to ECR
2. Update `terraform.tfvars` with ECR URLs
3. Deploy to AWS: `terraform apply`

See [terraform/ECR-CODEBUILD-README.md](terraform/ECR-CODEBUILD-README.md) for deployment instructions.
