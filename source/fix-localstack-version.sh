#!/bin/bash

# Fix LocalStack Version - Remove development builds and use stable Community Edition

echo "========================================="
echo "LocalStack Version Fix"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "This script will:"
echo "1. Stop LocalStack container"
echo "2. Remove development/nightly images"
echo "3. Pull stable Community Edition (3.5.0)"
echo "4. Restart with correct version"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Stop containers
echo ""
echo -e "${YELLOW}Stopping containers...${NC}"
docker-compose down 2>/dev/null || docker-compose -f docker-compose.windows.yml down 2>/dev/null

# Remove LocalStack images
echo ""
echo -e "${YELLOW}Removing LocalStack images...${NC}"
IMAGES=$(docker images localstack/localstack -q)
if [ -n "$IMAGES" ]; then
    docker rmi -f $IMAGES
    echo -e "${GREEN}✓ Removed old LocalStack images${NC}"
else
    echo -e "${YELLOW}No LocalStack images found${NC}"
fi

# Pull stable version
echo ""
echo -e "${YELLOW}Pulling LocalStack Community Edition 3.5.0...${NC}"
docker pull localstack/localstack:3.5.0

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Successfully pulled LocalStack 3.5.0${NC}"
else
    echo -e "${RED}✗ Failed to pull LocalStack 3.5.0${NC}"
    exit 1
fi

# Verify version
echo ""
echo -e "${YELLOW}Verifying image...${NC}"
docker images | grep localstack

# Detect OS and restart
echo ""
echo -e "${YELLOW}Restarting services...${NC}"

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    docker-compose -f docker-compose.windows.yml up -d
else
    docker-compose up -d
fi

# Wait for LocalStack to start
echo ""
echo -e "${YELLOW}Waiting for LocalStack to start...${NC}"
sleep 10

# Check version
echo ""
echo -e "${YELLOW}Checking LocalStack version...${NC}"
VERSION=$(docker logs novapay-localstack 2>&1 | grep "LocalStack version" | head -1)

if echo "$VERSION" | grep -q "3.5.0"; then
    echo -e "${GREEN}✓ $VERSION${NC}"
    echo -e "${GREEN}✓ Using stable Community Edition${NC}"
elif echo "$VERSION" | grep -q "dev"; then
    echo -e "${RED}✗ Still using development version${NC}"
    echo "$VERSION"
    echo ""
    echo "Try manually:"
    echo "  docker pull localstack/localstack:3.5.0"
    echo "  docker-compose up -d --force-recreate"
else
    echo -e "${YELLOW}⚠ Could not determine version${NC}"
    echo "$VERSION"
fi

# Check for auth errors
echo ""
echo -e "${YELLOW}Checking for authentication errors...${NC}"
AUTH_ERROR=$(docker logs novapay-localstack 2>&1 | grep -i "license\|auth\|credential" | head -3)

if [ -z "$AUTH_ERROR" ]; then
    echo -e "${GREEN}✓ No authentication errors${NC}"
else
    echo -e "${RED}✗ Found authentication errors:${NC}"
    echo "$AUTH_ERROR"
fi

# Check SQS
echo ""
echo -e "${YELLOW}Checking SQS availability...${NC}"
sleep 5
HEALTH=$(curl -s http://localhost:4566/_localstack/health 2>/dev/null)

if echo "$HEALTH" | grep -q '"sqs"'; then
    echo -e "${GREEN}✓ SQS is available${NC}"
else
    echo -e "${RED}✗ SQS not available yet (may need more time)${NC}"
fi

echo ""
echo "========================================="
echo "Done!"
echo "========================================="
echo ""
echo "Check logs with:"
echo "  docker logs novapay-localstack"
echo ""
echo "Verify version with:"
echo "  docker logs novapay-localstack | grep 'LocalStack version'"
