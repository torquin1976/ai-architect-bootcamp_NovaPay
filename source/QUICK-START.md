# NovaPay Docker Testing - Quick Reference

## 🚀 Start Services

### Windows
```bash
start-local.bat
```

### Mac/Linux
```bash
chmod +x start-local.sh && ./start-local.sh
```

## 🧪 Test Services

```bash
# Quick health check
curl http://localhost:3001/health
curl http://localhost:3002/health

# Test authorization
curl -X POST http://localhost:3001/auth \
  -H "Content-Type: application/json" \
  -d '{"card":"4111111111111111","amount":4999,"merchantId":"m_42","idempotencyKey":"test-001"}'

# Run full test suite
chmod +x test-services.sh && ./test-services.sh
```

## 🛑 Stop Services

### Windows
```bash
docker-compose -f docker-compose.windows.yml down
```

### Mac/Linux
```bash
docker-compose down
```

## 📊 View Logs

### Windows
```bash
docker-compose -f docker-compose.windows.yml logs -f
```

### Mac/Linux
```bash
docker-compose logs -f
```

## 🔧 Troubleshooting

### LocalStack authentication error?
→ Run fix: `fix-localstack-version.bat` or `./fix-localstack-version.sh`
→ See [LOCALSTACK-VERSION-FIX.md](LOCALSTACK-VERSION-FIX.md)

### LocalStack "Pro image" warning?
→ Run verification: `bash verify-localstack-free.sh`
→ See [LOCALSTACK-FREE-TIER.md](LOCALSTACK-FREE-TIER.md)

### LocalStack Error on Windows?
→ See [WINDOWS-TROUBLESHOOTING.md](WINDOWS-TROUBLESHOOTING.md)

### Port Conflict?
```bash
# Windows
netstat -ano | findstr :3001

# Mac/Linux
lsof -i :3001
```

### Reset Everything
```bash
# Windows
docker-compose -f docker-compose.windows.yml down -v
docker system prune -a

# Mac/Linux
docker-compose down -v
docker system prune -a
```

## 📚 Full Documentation

- [README-DOCKER-TESTING.md](README-DOCKER-TESTING.md) - Quick start
- [DOCKER-SETUP-README.md](DOCKER-SETUP-README.md) - Complete setup guide
- [LOCAL-TESTING-GUIDE.md](LOCAL-TESTING-GUIDE.md) - Detailed testing
- [WINDOWS-TROUBLESHOOTING.md](WINDOWS-TROUBLESHOOTING.md) - Windows issues

## 🎯 Service Ports

| Service | Port | Endpoints |
|---------|------|-----------|
| Payment | 3001 | /auth, /charge, /refund, /health |
| KYC | 3002 | /kyc, /health |
| PostgreSQL | 5432 | Database |
| Redis | 6379 | Cache |
| LocalStack | 4566 | SQS |
