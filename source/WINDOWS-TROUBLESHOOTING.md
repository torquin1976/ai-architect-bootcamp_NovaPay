# Windows Docker Troubleshooting Guide

## LocalStack "Device or resource busy" Error

If you see this error:
```
ERROR: 'rm -rf "/tmp/localstack"': exit code 1
ERROR: the LocalStack runtime exited unexpectedly: [Errno 16] Device or resource busy
```

### Solution 1: Use Windows-Optimized Configuration (Recommended)

We've created a Windows-specific Docker Compose file that avoids this issue:

```bash
# Use the Windows-optimized configuration
docker-compose -f docker-compose.windows.yml up --build -d
```

Or use the batch file:
```bash
start-local.bat
```

### Solution 2: Clean Docker Environment

```bash
# Stop all containers
docker-compose down

# Remove all volumes
docker-compose down -v

# Prune Docker system
docker system prune -a --volumes

# Restart Docker Desktop
# (Right-click Docker Desktop icon → Quit Docker Desktop → Start Docker Desktop)

# Try again
docker-compose up --build -d
```

### Solution 3: Use Alternative LocalStack Configuration

If the issue persists, you can run without LocalStack and use a mock SQS:

1. Comment out the `localstack` service in `docker-compose.yml`
2. Update services to not depend on LocalStack
3. The webhook service will fail gracefully without SQS

## Other Common Windows Issues

### Port Already in Use

**Error:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:3001: bind: Only one usage of each socket address
```

**Solution:**
```bash
# Find what's using the port
netstat -ano | findstr :3001

# Kill the process (replace PID with actual process ID)
taskkill /PID <PID> /F

# Or change the port in docker-compose.yml
ports:
  - "3011:3000"  # Changed from 3001 to 3011
```

### Line Ending Issues (CRLF vs LF)

**Error:**
```
/bin/sh: bad interpreter: No such file or directory
```

**Solution:**
```bash
# Convert line endings for shell scripts
dos2unix localstack-init.sh
dos2unix start-local.sh

# Or in Git Bash
sed -i 's/\r$//' localstack-init.sh
sed -i 's/\r$//' start-local.sh
```

### Docker Desktop Not Starting

**Solution:**
1. Open Task Manager (Ctrl+Shift+Esc)
2. End all Docker-related processes
3. Restart Docker Desktop as Administrator
4. Wait for "Docker Desktop is running" message

### WSL 2 Backend Issues

**Error:**
```
Docker Desktop requires a newer WSL kernel version
```

**Solution:**
```bash
# Update WSL
wsl --update

# Set WSL 2 as default
wsl --set-default-version 2

# Restart Docker Desktop
```

### Volume Mount Issues

**Error:**
```
Error response from daemon: invalid mount config
```

**Solution:**

In Docker Desktop settings:
1. Go to Settings → Resources → File Sharing
2. Add your project directory
3. Click "Apply & Restart"

### Build Context Issues

**Error:**
```
failed to solve with frontend dockerfile.v0: failed to read dockerfile
```

**Solution:**
```bash
# Ensure you're in the project root directory
cd C:\Users\peero\OneDrive\Documents\Study\AI Bootcamp\NovaPay\source

# Check dockerfile exists
dir DockerFiles\Payment\dockerfile

# Build with explicit context
docker-compose -f docker-compose.windows.yml build --no-cache
```

## Quick Fixes Checklist

- [ ] Docker Desktop is running
- [ ] WSL 2 is updated (if using WSL backend)
- [ ] Project directory is shared in Docker Desktop settings
- [ ] No port conflicts (3001, 3002, 5432, 6379, 4566)
- [ ] Using `docker-compose.windows.yml` on Windows
- [ ] Line endings are LF (not CRLF) for shell scripts
- [ ] Docker has enough resources (4GB RAM minimum)

## Testing Without LocalStack

If LocalStack continues to cause issues, you can test without it:

### Option 1: Mock SQS in Code

Update `DockerFiles/Payment/server.js`:

```javascript
// Mock SQS for local testing
if (!SQS_QUEUE_URL || process.env.MOCK_SQS === 'true') {
  console.log('Using mock SQS (no actual queue)');
  // Skip SQS send
} else {
  await sqs.send(new SendMessageCommand({
    QueueUrl: SQS_QUEUE_URL,
    MessageBody: JSON.stringify({ token, event: 'captured' })
  }));
}
```

### Option 2: Use AWS SQS Directly

If you have AWS credentials:

```yaml
# In docker-compose.yml, remove AWS_ENDPOINT_URL
environment:
  SQS_QUEUE_URL: https://sqs.us-east-1.amazonaws.com/637423409019/novapay-webhook-queue
  AWS_ACCESS_KEY_ID: your-access-key
  AWS_SECRET_ACCESS_KEY: your-secret-key
  # Remove: AWS_ENDPOINT_URL: http://localstack:4566
```

## Recommended Windows Setup

For the best experience on Windows:

1. **Use WSL 2 Backend** (Docker Desktop Settings → General → Use WSL 2)
2. **Allocate Resources** (Settings → Resources):
   - CPUs: 4
   - Memory: 4 GB
   - Swap: 1 GB
3. **Use Windows-Optimized Compose File**:
   ```bash
   docker-compose -f docker-compose.windows.yml up -d
   ```
4. **Run from Git Bash or PowerShell** (not CMD)

## Getting Help

If issues persist:

1. **Check Docker logs:**
   ```bash
   docker-compose -f docker-compose.windows.yml logs localstack
   ```

2. **Check Docker Desktop logs:**
   - Docker Desktop → Troubleshoot → View logs

3. **Verify Docker version:**
   ```bash
   docker --version
   docker-compose --version
   ```

4. **Test basic Docker functionality:**
   ```bash
   docker run hello-world
   ```

## Alternative: Use Git Bash

Git Bash provides a better Unix-like environment on Windows:

```bash
# Install Git for Windows (includes Git Bash)
# Download from: https://git-scm.com/download/win

# Run commands in Git Bash
bash start-local.sh
bash test-services.sh
```

## Contact

For persistent issues, check:
- [Docker Desktop for Windows Documentation](https://docs.docker.com/desktop/windows/)
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [WSL 2 Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
