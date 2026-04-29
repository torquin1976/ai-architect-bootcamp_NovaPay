# Docker Services Rebuild Guide

## When to Rebuild

Rebuild Docker images when you see errors like:
- `Cannot find module '@aws-sdk/client-sqs'`
- `Cannot find module 'express'`
- `MODULE_NOT_FOUND`
- After updating `package.json` files
- After updating `Dockerfile` files
- After updating `server.js` files

## Quick Rebuild

### Windows
```bash
rebuild-services.bat
```

### Mac/Linux
```bash
chmod +x rebuild-services.sh
./rebuild-services.sh
```

## Manual Rebuild

### Full Rebuild (Recommended)

**Windows:**
```bash
# Stop services
docker-compose -f docker-compose.windows.yml down

# Rebuild without cache
docker-compose -f docker-compose.windows.yml build --no-cache

# Start services
docker-compose -f docker-compose.windows.yml up -d
```

**Mac/Linux:**
```bash
# Stop services
docker-compose down

# Rebuild without cache
docker-compose build --no-cache

# Start services
docker-compose up -d
```

### Rebuild Specific Service

If only one service needs rebuilding:

```bash
# Windows
docker-compose -f docker-compose.windows.yml build --no-cache payment-service
docker-compose -f docker-compose.windows.yml up -d payment-service

# Mac/Linux
docker-compose build --no-cache payment-service
docker-compose up -d payment-service
```

## What Gets Rebuilt

The rebuild process:
1. ✅ Stops all running containers
2. ✅ Rebuilds Docker images from scratch (no cache)
3. ✅ Installs all dependencies from `package.json`
4. ✅ Copies updated code
5. ✅ Starts services with new images

## Dockerfile Changes

### Before (Broken)
```dockerfile
# Manually installing packages - missing @aws-sdk/client-sqs
RUN npm install express body-parser pg ioredis
```

### After (Fixed)
```dockerfile
# Copy package.json and install all dependencies
COPY package*.json ./
RUN npm install --production
```

## Verifying the Rebuild

After rebuilding, verify services are working:

```bash
# Check service status
docker-compose ps

# Check Payment service logs
docker logs novapay-payment

# Test Payment service
curl http://localhost:3001/health

# Test KYC service
curl http://localhost:3002/health
```

## Common Issues

### Build fails with "COPY failed"

**Error:**
```
COPY failed: file not found in build context
```

**Solution:**
Ensure you're running docker-compose from the project root directory where `docker-compose.yml` is located.

### Services still show old errors after rebuild

**Solution:**
```bash
# Remove old containers and volumes
docker-compose down -v

# Remove old images
docker rmi novapay-payment novapay-kyc novapay-webhook

# Rebuild
docker-compose build --no-cache
docker-compose up -d
```

### "Cannot find module" persists

**Check package.json exists:**
```bash
ls DockerFiles/Payment/package.json
ls DockerFiles/KYC/package.json
ls DockerFiles/WebHook/package.json
```

**Check Dockerfile copies package.json:**
```bash
grep "COPY package" DockerFiles/Payment/dockerfile
# Should show: COPY package*.json ./
```

### Build is very slow

**This is normal for `--no-cache` builds.**

To speed up subsequent builds, omit `--no-cache`:
```bash
docker-compose build
```

But use `--no-cache` when:
- Dependencies changed
- Dockerfile changed
- Troubleshooting build issues

## Partial Rebuild (Faster)

If you only changed code (not dependencies):

```bash
# Rebuild without --no-cache (uses cache for dependencies)
docker-compose build

# Restart services
docker-compose up -d
```

## Clean Slate Rebuild

For a completely fresh start:

```bash
# Stop everything
docker-compose down -v

# Remove all images
docker rmi $(docker images -q novapay-*)

# Remove build cache
docker builder prune -a

# Rebuild from scratch
docker-compose build --no-cache
docker-compose up -d
```

## Troubleshooting Build Errors

### Check Docker is running
```bash
docker info
```

### Check disk space
```bash
docker system df
```

### Clean up Docker
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes
docker volume prune

# Remove everything unused
docker system prune -a --volumes
```

## Build Time Estimates

| Build Type | Time | When to Use |
|------------|------|-------------|
| Full rebuild (`--no-cache`) | 3-5 min | After dependency changes |
| Cached rebuild | 30-60 sec | After code changes only |
| Single service rebuild | 1-2 min | When only one service changed |

## Best Practices

1. ✅ Always rebuild after updating `package.json`
2. ✅ Use `--no-cache` when troubleshooting
3. ✅ Test services after rebuild
4. ✅ Check logs if services fail to start
5. ✅ Keep Docker Desktop updated

## Quick Commands Reference

```bash
# Full rebuild (Windows)
rebuild-services.bat

# Full rebuild (Mac/Linux)
./rebuild-services.sh

# Manual rebuild
docker-compose build --no-cache && docker-compose up -d

# Rebuild one service
docker-compose build --no-cache payment-service

# Check logs
docker-compose logs -f payment-service

# Restart service
docker-compose restart payment-service
```

## Resources

- [Docker Compose Build Documentation](https://docs.docker.com/compose/reference/build/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker Build Cache](https://docs.docker.com/build/cache/)
