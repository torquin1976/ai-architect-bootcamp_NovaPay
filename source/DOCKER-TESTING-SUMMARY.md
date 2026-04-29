# Docker Local Testing Setup - Summary

## Problem Solved

You encountered a LocalStack error on Windows:
```
ERROR: 'rm -rf "/tmp/localstack"': exit code 1
ERROR: the LocalStack runtime exited unexpectedly: [Errno 16] Device or resource busy
```

This is a common issue with LocalStack on Windows Docker Desktop due to volume mount conflicts.

## Solutions Implemented

### 1. Fixed Main docker-compose.yml
- Removed problematic volume mount for LocalStack
- Simplified LocalStack configuration
- Works better on Windows now

### 2. Created Windows-Optimized Configuration
**File:** `docker-compose.windows.yml`
- Uses LocalStack 3.0 (more stable on Windows)
- Separate init container for SQS queue creation
- No persistent volumes for LocalStack
- Optimized health checks

### 3. Updated Startup Scripts
- **`start-local.sh`** - Auto-detects OS and uses appropriate config
- **`start-local.bat`** - Uses Windows-optimized config by default

### 4. Created Comprehensive Documentation
- **`WINDOWS-TROUBLESHOOTING.md`** - Windows-specific issues and solutions
- **`README-DOCKER-TESTING.md`** - Quick start guide
- **`DOCKER-SETUP-README.md`** - Updated with Windows instructions
- **`LOCAL-TESTING-GUIDE.md`** - Detailed testing guide

## How to Use

### Windows Users (Recommended)

**Option 1: Use the batch file**
```bash
start-local.bat
```

**Option 2: Use Windows-optimized compose file**
```bash
docker-compose -f docker-compose.windows.yml up --build -d
```

### Mac/Linux Users

**Option 1: Use the shell script**
```bash
chmod +x start-local.sh
./start-local.sh
```

**Option 2: Use standard compose file**
```bash
docker-compose up --build -d
```

## What's Different in Windows Configuration

| Feature | Standard | Windows-Optimized |
|---------|----------|-------------------|
| LocalStack Version | latest | 3.0 (stable) |
| Volume Mounts | Yes | No (ephemeral) |
| Init Method | Shell script mount | Separate init container |
| Persistence | Enabled | Disabled |
| Health Check | Standard | Extended timeouts |

## Testing Your Setup

### 1. Start Services
```bash
# Windows
start-local.bat

# Mac/Linux
./start-local.sh
```

### 2. Verify All Services Are Running
```bash
# Windows
docker-compose -f docker-compose.windows.yml ps

# Mac/Linux
docker-compose ps
```

Expected output:
```
NAME                  STATUS
novapay-postgres      Up (healthy)
novapay-redis         Up (healthy)
novapay-localstack    Up (healthy)
novapay-payment       Up (healthy)
novapay-kyc           Up (healthy)
novapay-webhook       Up
```

### 3. Test Endpoints
```bash
# Health checks
curl http://localhost:3001/health
curl http://localhost:3002/health

# Authorization
curl -X POST http://localhost:3001/auth \
  -H "Content-Type: application/json" \
  -d '{"card":"4111111111111111","amount":4999,"merchantId":"m_42","idempotencyKey":"test-001"}'

# KYC
curl -X POST http://localhost:3002/kyc \
  -H "Content-Type: application/json" \
  -d '{"ssn":"123-45-6789"}'
```

### 4. Run Automated Tests
```bash
chmod +x test-services.sh
./test-services.sh
```

## Troubleshooting

### LocalStack "Pro Image" Warning

If you see messages about LocalStack Pro, don't worry - we're using the **free Community Edition**. The configuration explicitly sets:

```yaml
LOCALSTACK_API_KEY: ""           # Empty = Community Edition
DISABLE_EVENTS: 1                # Disable Pro features
```

See [LOCALSTACK-FREE-TIER.md](LOCALSTACK-FREE-TIER.md) for details.

**Key points:**
- ✅ LocalStack Community Edition is 100% free
- ✅ SQS is fully supported in the free tier
- ✅ No license or credit card required
- ✅ No usage limits for Community features

### LocalStack Still Failing?

**Try these steps:**

1. **Clean Docker environment:**
   ```bash
   docker-compose -f docker-compose.windows.yml down -v
   docker system prune -a
   ```

2. **Restart Docker Desktop:**
   - Right-click Docker Desktop icon
   - Quit Docker Desktop
   - Start Docker Desktop
   - Wait for "Docker Desktop is running"

3. **Check Docker resources:**
   - Docker Desktop → Settings → Resources
   - Ensure at least 4GB RAM allocated

4. **Use alternative approach:**
   See "Testing Without LocalStack" in WINDOWS-TROUBLESHOOTING.md

### Other Issues?

See [WINDOWS-TROUBLESHOOTING.md](WINDOWS-TROUBLESHOOTING.md) for:
- Port conflicts
- Line ending issues
- WSL 2 problems
- Volume mount issues
- Build context errors

## Files Created/Modified

### New Files
- ✅ `docker-compose.windows.yml` - Windows-optimized configuration
- ✅ `WINDOWS-TROUBLESHOOTING.md` - Windows troubleshooting guide
- ✅ `README-DOCKER-TESTING.md` - Quick start guide
- ✅ `DOCKER-TESTING-SUMMARY.md` - This file

### Modified Files
- ✅ `docker-compose.yml` - Fixed LocalStack volume issue
- ✅ `start-local.sh` - Auto-detects OS
- ✅ `start-local.bat` - Uses Windows config
- ✅ `DOCKER-SETUP-README.md` - Added Windows instructions

### Existing Files (Unchanged)
- `init-db.sql` - Database initialization
- `localstack-init.sh` - SQS setup (not used in Windows config)
- `test-services.sh` - Test suite
- `.env.example` - Environment variables reference
- `LOCAL-TESTING-GUIDE.md` - Testing guide

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Network                        │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐         │
│  │PostgreSQL│  │  Redis   │  │  LocalStack  │         │
│  │  :5432   │  │  :6379   │  │    :4566     │         │
│  └────┬─────┘  └────┬─────┘  └──────┬───────┘         │
│       │             │                │                  │
│  ┌────┴─────────────┴────────────────┴───────┐         │
│  │                                            │         │
│  │  ┌──────────┐  ┌──────────┐  ┌─────────┐ │         │
│  │  │ Payment  │  │   KYC    │  │ Webhook │ │         │
│  │  │  :3001   │  │  :3002   │  │(worker) │ │         │
│  │  └──────────┘  └──────────┘  └─────────┘ │         │
│  │                                            │         │
│  └────────────────────────────────────────────┘         │
│                                                          │
└─────────────────────────────────────────────────────────┘
         │                    │                    │
    localhost:3001      localhost:3002      localhost:5432
```

## Next Steps

1. ✅ **Test locally** - Verify all services work
2. ✅ **Run test suite** - Ensure endpoints respond correctly
3. 📦 **Build for AWS** - Push images to ECR
4. 🚀 **Deploy** - Use Terraform to deploy to AWS

## Support

If you continue to have issues:

1. Check [WINDOWS-TROUBLESHOOTING.md](WINDOWS-TROUBLESHOOTING.md)
2. Review Docker Desktop logs (Troubleshoot → View logs)
3. Verify Docker version: `docker --version`
4. Test basic Docker: `docker run hello-world`

## Success Criteria

You'll know everything is working when:

- ✅ All containers show "Up (healthy)" status
- ✅ Health endpoints return 200 OK
- ✅ Authorization creates transactions in PostgreSQL
- ✅ Idempotency works (same key returns same token)
- ✅ Charge sends messages to SQS
- ✅ Webhook service processes messages
- ✅ KYC validates SSN format

Run `./test-services.sh` to verify all of the above automatically!
