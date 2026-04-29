#!/bin/bash

# NovaPay Local Environment Startup Script

set -e

echo "========================================="
echo "NovaPay Local Environment Setup"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running. Please start Docker Desktop."
  exit 1
fi

echo -e "${GREEN}✓${NC} Docker is running"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
  echo "Error: docker-compose is not installed."
  exit 1
fi

echo -e "${GREEN}✓${NC} docker-compose is available"

# Detect OS and use appropriate compose file
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  COMPOSE_FILE="docker-compose.windows.yml"
  echo -e "${YELLOW}Detected Windows - using Windows-optimized configuration${NC}"
else
  COMPOSE_FILE="docker-compose.yml"
fi

# Stop any existing containers
echo ""
echo -e "${YELLOW}Stopping existing containers...${NC}"
docker-compose -f $COMPOSE_FILE down 2>/dev/null || true

# Build and start services
echo ""
echo -e "${YELLOW}Building and starting services...${NC}"
docker-compose -f $COMPOSE_FILE up --build -d

# Wait for services to be healthy
echo ""
echo -e "${YELLOW}Waiting for services to be healthy...${NC}"

MAX_WAIT=60
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
  HEALTHY=$(docker-compose ps | grep -c "(healthy)" || true)
  
  if [ $HEALTHY -ge 4 ]; then
    echo -e "${GREEN}✓${NC} All services are healthy!"
    break
  fi
  
  echo "Waiting... ($ELAPSED/$MAX_WAIT seconds) - $HEALTHY/4 services healthy"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
  echo "Warning: Some services may not be healthy yet. Check with: docker-compose ps"
fi

# Show service status
echo ""
echo "Service Status:"
echo "---------------"
docker-compose -f $COMPOSE_FILE ps

# Show service URLs
echo ""
echo "Service URLs:"
echo "-------------"
echo "Payment Service: http://localhost:3001"
echo "  - POST /auth    - Card authorization"
echo "  - POST /charge  - Payment capture"
echo "  - POST /refund  - Payment refund"
echo "  - GET  /health  - Health check"
echo ""
echo "KYC Service: http://localhost:3002"
echo "  - POST /kyc     - SSN validation"
echo "  - GET  /health  - Health check"
echo ""
echo "PostgreSQL: localhost:5432"
echo "  - Database: novapay"
echo "  - User: np"
echo "  - Password: np"
echo ""
echo "Redis: localhost:6379"
echo ""
echo "LocalStack (SQS): http://localhost:4566"
echo ""

# Show logs command
echo "View logs with:"
echo "  docker-compose -f $COMPOSE_FILE logs -f"
echo ""
echo "Run tests with:"
echo "  bash test-services.sh"
echo ""
echo "Stop services with:"
echo "  docker-compose -f $COMPOSE_FILE down"
echo ""

echo -e "${GREEN}Local environment is ready!${NC}"
