# LocalStack Version Fix - Authentication Error Solution

## Problem

You're seeing this error:
```
LocalStack version: 2026.4.0.dev820
License activation failed! 🔑❌
Reason: No credentials were found in the environment
```

## Root Cause

Docker pulled a **development/nightly build** (`2026.4.0.dev`) instead of the stable Community Edition. Development builds require authentication even for free features.

## Solution

We've pinned the Docker image to **LocalStack 3.5.0**, a stable Community Edition release that doesn't require authentication.

### Quick Fix

**Windows:**
```bash
fix-localstack-version.bat
```

**Mac/Linux:**
```bash
chmod +x fix-localstack-version.sh
./fix-localstack-version.sh
```

### Manual Fix

If the scripts don't work:

**1. Stop and remove containers:**
```bash
# Windows
docker-compose -f docker-compose.windows.yml down

# Mac/Linux
docker-compose down
```

**2. Remove LocalStack images:**
```bash
# Remove all LocalStack images
docker rmi $(docker images localstack/localstack -q)

# Or manually
docker images | grep localstack
docker rmi <IMAGE_ID>
```

**3. Pull the stable version:**
```bash
docker pull localstack/localstack:3.5.0
```

**4. Verify the image:**
```bash
docker images | grep localstack
# Should show: localstack/localstack   3.5.0
```

**5. Restart services:**
```bash
# Windows
docker-compose -f docker-compose.windows.yml up -d

# Mac/Linux
docker-compose up -d
```

**6. Verify the version:**
```bash
docker logs novapay-localstack | grep "LocalStack version"
# Should show: LocalStack version: 3.5.0
```

## What Changed

### Before (Broken)
```yaml
image: localstack/localstack:latest    # Could pull dev builds
```

### After (Fixed)
```yaml
image: localstack/localstack:3.5.0     # Pinned stable version
```

## Why This Happened

- `latest` tag can point to development/nightly builds
- Development builds (e.g., `2026.4.0.dev`) require `LOCALSTACK_AUTH_TOKEN`
- Stable releases (e.g., `3.5.0`) are free and don't require authentication

## Verification

After fixing, you should see:

```bash
$ docker logs novapay-localstack | grep "LocalStack version"
LocalStack version: 3.5.0

$ docker logs novapay-localstack | grep -i "license\|auth"
# (No output = good!)

$ curl http://localhost:4566/_localstack/health
{"sqs": "available", ...}
```

## Alternative Stable Versions

If 3.5.0 doesn't work, try these stable Community Edition versions:

- `3.4.0` - Previous stable
- `3.3.0` - Older stable
- `3.2.0` - Even older stable

**Update docker-compose.yml:**
```yaml
image: localstack/localstack:3.4.0
```

## Why Not Use `latest`?

| Tag | Pros | Cons |
|-----|------|------|
| `latest` | Always newest | May pull dev builds requiring auth |
| `3.5.0` | Stable, no auth | Slightly older features |
| `3.x` | Latest 3.x stable | Still may pull dev builds |

**Recommendation:** Always pin to a specific stable version (e.g., `3.5.0`)

## Troubleshooting

### Still seeing auth errors after fix?

**Check the actual image version:**
```bash
docker inspect novapay-localstack | grep "Image"
```

**Force recreate with new image:**
```bash
docker-compose up -d --force-recreate localstack
```

### Can't pull 3.5.0?

**Try a different stable version:**
```bash
docker pull localstack/localstack:3.4.0
```

Then update docker-compose.yml to use `3.4.0`.

### Image keeps reverting to dev version?

**Check for cached images:**
```bash
docker images -a | grep localstack
```

**Remove all LocalStack images:**
```bash
docker rmi -f $(docker images localstack/localstack -q)
```

**Clear Docker cache:**
```bash
docker system prune -a
```

## Prevention

To prevent this in the future:

1. ✅ Always pin to specific stable versions
2. ✅ Don't use `latest` tag for LocalStack
3. ✅ Check version after pulling: `docker images | grep localstack`
4. ✅ Verify version in logs: `docker logs novapay-localstack | grep version`

## Resources

- [LocalStack Releases](https://github.com/localstack/localstack/releases)
- [LocalStack Docker Hub](https://hub.docker.com/r/localstack/localstack)
- [LocalStack Community Edition](https://docs.localstack.cloud/getting-started/)

## Summary

✅ **Fixed:** Pinned to LocalStack 3.5.0 (stable Community Edition)
✅ **No authentication required**
✅ **No license needed**
✅ **100% free**

Run the fix script and you should be good to go!
