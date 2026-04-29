#!/bin/bash

# NovaPay Local Testing Script
# Tests all microservices endpoints

set -e

echo "========================================="
echo "NovaPay Microservices Local Testing"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base URLs
PAYMENT_URL="http://localhost:3001"
KYC_URL="http://localhost:3002"

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to print test result
print_result() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✓ PASSED${NC}: $2"
    ((TESTS_PASSED++))
  else
    echo -e "${RED}✗ FAILED${NC}: $2"
    ((TESTS_FAILED++))
  fi
}

# Function to test endpoint
test_endpoint() {
  local method=$1
  local url=$2
  local data=$3
  local expected_status=$4
  local test_name=$5
  
  echo -e "\n${YELLOW}Testing:${NC} $test_name"
  
  if [ -z "$data" ]; then
    response=$(curl -s -w "\n%{http_code}" -X $method "$url")
  else
    response=$(curl -s -w "\n%{http_code}" -X $method "$url" \
      -H "Content-Type: application/json" \
      -d "$data")
  fi
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  echo "Response: $body"
  echo "HTTP Status: $http_code"
  
  if [ "$http_code" -eq "$expected_status" ]; then
    print_result 0 "$test_name"
    echo "$body"
  else
    print_result 1 "$test_name (Expected $expected_status, got $http_code)"
  fi
}

echo "1. Testing Health Endpoints"
echo "----------------------------"

test_endpoint "GET" "$PAYMENT_URL/health" "" 200 "Payment Service Health Check"
test_endpoint "GET" "$KYC_URL/health" "" 200 "KYC Service Health Check"

echo ""
echo "2. Testing Payment Service - Authorization"
echo "------------------------------------------"

# Test authorization with new idempotency key
AUTH_RESPONSE=$(curl -s -X POST "$PAYMENT_URL/auth" \
  -H "Content-Type: application/json" \
  -d '{
    "card": "4111111111111111",
    "amount": 4999,
    "merchantId": "m_test",
    "idempotencyKey": "test-'$(date +%s)'"
  }')

TOKEN=$(echo $AUTH_RESPONSE | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -n "$TOKEN" ]; then
  print_result 0 "Authorization - New Transaction"
  echo "Token: $TOKEN"
else
  print_result 1 "Authorization - New Transaction (No token received)"
fi

# Test idempotency (same key should return cached response)
IDEMPOTENCY_KEY="idempotency-test-$(date +%s)"

AUTH1=$(curl -s -X POST "$PAYMENT_URL/auth" \
  -H "Content-Type: application/json" \
  -d "{
    \"card\": \"4111111111111111\",
    \"amount\": 9999,
    \"merchantId\": \"m_test\",
    \"idempotencyKey\": \"$IDEMPOTENCY_KEY\"
  }")

TOKEN1=$(echo $AUTH1 | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

AUTH2=$(curl -s -X POST "$PAYMENT_URL/auth" \
  -H "Content-Type: application/json" \
  -d "{
    \"card\": \"4111111111111111\",
    \"amount\": 9999,
    \"merchantId\": \"m_test\",
    \"idempotencyKey\": \"$IDEMPOTENCY_KEY\"
  }")

TOKEN2=$(echo $AUTH2 | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ "$TOKEN1" == "$TOKEN2" ]; then
  print_result 0 "Idempotency Check (Same token returned)"
  echo "Token: $TOKEN1"
else
  print_result 1 "Idempotency Check (Different tokens: $TOKEN1 vs $TOKEN2)"
fi

echo ""
echo "3. Testing Payment Service - Charge"
echo "------------------------------------"

if [ -n "$TOKEN" ]; then
  test_endpoint "POST" "$PAYMENT_URL/charge" "{\"token\": \"$TOKEN\"}" 200 "Charge Transaction"
else
  echo -e "${RED}Skipping charge test - no token available${NC}"
fi

echo ""
echo "4. Testing Payment Service - Refund"
echo "------------------------------------"

if [ -n "$TOKEN" ]; then
  test_endpoint "POST" "$PAYMENT_URL/refund" "{\"token\": \"$TOKEN\", \"amount\": 4999}" 200 "Refund Transaction"
else
  echo -e "${RED}Skipping refund test - no token available${NC}"
fi

echo ""
echo "5. Testing KYC Service - Validation"
echo "------------------------------------"

test_endpoint "POST" "$KYC_URL/kyc" '{"ssn": "123-45-6789"}' 200 "Valid SSN Format"
test_endpoint "POST" "$KYC_URL/kyc" '{"ssn": "invalid"}' 200 "Invalid SSN Format"

echo ""
echo "6. Testing Database Persistence"
echo "--------------------------------"

echo -e "\n${YELLOW}Checking PostgreSQL:${NC}"
DB_CHECK=$(docker exec novapay-postgres psql -U np -d novapay -t -c "SELECT COUNT(*) FROM txns;" 2>/dev/null || echo "0")
DB_COUNT=$(echo $DB_CHECK | tr -d ' ')

if [ "$DB_COUNT" -gt 0 ]; then
  print_result 0 "Database has $DB_COUNT transactions"
else
  print_result 1 "Database check failed or empty"
fi

echo ""
echo "7. Testing Redis Cache"
echo "----------------------"

echo -e "\n${YELLOW}Checking Redis:${NC}"
REDIS_CHECK=$(docker exec novapay-redis redis-cli DBSIZE 2>/dev/null || echo "ERR")

if [[ "$REDIS_CHECK" != "ERR" ]]; then
  print_result 0 "Redis is accessible (keys: $REDIS_CHECK)"
else
  print_result 1 "Redis check failed"
fi

echo ""
echo "8. Testing SQS Queue (LocalStack)"
echo "----------------------------------"

echo -e "\n${YELLOW}Checking SQS Queue:${NC}"
QUEUE_CHECK=$(docker exec novapay-localstack awslocal sqs list-queues 2>/dev/null || echo "ERR")

if [[ "$QUEUE_CHECK" != "ERR" ]]; then
  print_result 0 "SQS queue is accessible"
  echo "$QUEUE_CHECK"
else
  print_result 1 "SQS queue check failed"
fi

echo ""
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed! ✓${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed. Check the output above.${NC}"
  exit 1
fi
