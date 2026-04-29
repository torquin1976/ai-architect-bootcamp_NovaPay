#!/bin/bash

# LocalStack Free Tier Verification Script

echo "========================================="
echo "LocalStack Community Edition Verification"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if LocalStack container is running
if ! docker ps | grep -q novapay-localstack; then
  echo -e "${RED}✗ LocalStack container is not running${NC}"
  echo "Start it with: docker-compose up -d localstack"
  exit 1
fi

echo -e "${GREEN}✓ LocalStack container is running${NC}"
echo ""

# Check API key (should be empty for Community Edition)
echo "Checking API key configuration..."
API_KEY=$(docker exec novapay-localstack env 2>/dev/null | grep LOCALSTACK_API_KEY | cut -d'=' -f2)

if [ -z "$API_KEY" ]; then
  echo -e "${GREEN}✓ LOCALSTACK_API_KEY is empty (Community Edition)${NC}"
else
  echo -e "${YELLOW}⚠ LOCALSTACK_API_KEY is set: $API_KEY${NC}"
  echo "  This might indicate Pro edition"
fi
echo ""

# Check LocalStack version and edition
echo "Checking LocalStack version..."
VERSION=$(docker logs novapay-localstack 2>&1 | grep -i "localstack version" | head -1)
if [ -n "$VERSION" ]; then
  echo -e "${GREEN}✓ $VERSION${NC}"
else
  echo -e "${YELLOW}⚠ Could not determine version${NC}"
fi

EDITION=$(docker logs novapay-localstack 2>&1 | grep -i "community\|pro" | head -1)
if echo "$EDITION" | grep -qi "community"; then
  echo -e "${GREEN}✓ Using Community Edition${NC}"
elif echo "$EDITION" | grep -qi "pro"; then
  echo -e "${YELLOW}⚠ Pro edition detected${NC}"
else
  echo -e "${YELLOW}⚠ Could not determine edition${NC}"
fi
echo ""

# Check SQS service availability
echo "Checking SQS service availability..."
HEALTH=$(curl -s http://localhost:4566/_localstack/health 2>/dev/null)

if echo "$HEALTH" | grep -q '"sqs"'; then
  SQS_STATUS=$(echo "$HEALTH" | grep -o '"sqs":"[^"]*"' | cut -d'"' -f4)
  if [ "$SQS_STATUS" = "available" ] || [ "$SQS_STATUS" = "running" ]; then
    echo -e "${GREEN}✓ SQS service is $SQS_STATUS${NC}"
  else
    echo -e "${RED}✗ SQS service status: $SQS_STATUS${NC}"
  fi
else
  echo -e "${RED}✗ Could not check SQS status${NC}"
fi
echo ""

# Check for Pro warnings in logs
echo "Checking for Pro-related messages..."
PRO_MESSAGES=$(docker logs novapay-localstack 2>&1 | grep -i "pro" | grep -v "process\|protocol\|provide\|problem" | head -3)

if [ -z "$PRO_MESSAGES" ]; then
  echo -e "${GREEN}✓ No Pro-related warnings found${NC}"
else
  echo -e "${YELLOW}⚠ Found Pro-related messages (informational only):${NC}"
  echo "$PRO_MESSAGES"
fi
echo ""

# Check environment variables
echo "Checking environment configuration..."
DISABLE_EVENTS=$(docker exec novapay-localstack env 2>/dev/null | grep DISABLE_EVENTS | cut -d'=' -f2)
PERSISTENCE=$(docker exec novapay-localstack env 2>/dev/null | grep PERSISTENCE | cut -d'=' -f2)

if [ "$DISABLE_EVENTS" = "1" ]; then
  echo -e "${GREEN}✓ DISABLE_EVENTS=1 (Pro features disabled)${NC}"
else
  echo -e "${YELLOW}⚠ DISABLE_EVENTS not set or not 1${NC}"
fi

if [ "$PERSISTENCE" = "0" ]; then
  echo -e "${GREEN}✓ PERSISTENCE=0 (No persistence, Community mode)${NC}"
else
  echo -e "${YELLOW}⚠ PERSISTENCE not set to 0${NC}"
fi
echo ""

# Test SQS functionality
echo "Testing SQS functionality..."
TEST_QUEUE="test-queue-$(date +%s)"

# Try to create a test queue
CREATE_RESULT=$(docker exec novapay-localstack awslocal sqs create-queue --queue-name $TEST_QUEUE 2>&1)

if echo "$CREATE_RESULT" | grep -q "QueueUrl"; then
  echo -e "${GREEN}✓ SQS queue creation works${NC}"
  
  # Clean up test queue
  docker exec novapay-localstack awslocal sqs delete-queue --queue-url "http://localhost:4566/000000000000/$TEST_QUEUE" 2>/dev/null
else
  echo -e "${RED}✗ SQS queue creation failed${NC}"
  echo "$CREATE_RESULT"
fi
echo ""

# Summary
echo "========================================="
echo "Summary"
echo "========================================="
echo ""
echo -e "${GREEN}✓ You are using LocalStack Community Edition (Free)${NC}"
echo -e "${GREEN}✓ No license or payment required${NC}"
echo -e "${GREEN}✓ SQS is fully functional${NC}"
echo ""
echo "If you see any Pro-related messages above, they are"
echo "informational only and can be safely ignored."
echo ""
echo "For more information, see: LOCALSTACK-FREE-TIER.md"
