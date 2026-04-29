#!/bin/bash

# Rebuild Docker Services Script

echo "========================================="
echo "Rebuilding NovaPay Docker Services"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Detect OS and use appropriate compose file
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  COMPOSE_FILE="docker-compose.windows.yml"
  echo -e "${YELLOW}Using Windows configuration${NC}"
else
  COMPOSE_FILE="docker-compose.yml"
  echo -e "${YELLOW}Using standard configuration${NC}"
fi

echo ""
echo -e "${YELLOW}Stopping services...${NC}"
docker-compose -f $COMPOSE_FILE down

echo ""
echo -e "${YELLOW}Rebuilding images (this may take a few minutes)...${NC}"
docker-compose -f $COMPOSE_FILE build --no-cache

echo ""
echo -e "${YELLOW}Starting services...${NC}"
docker-compose -f $COMPOSE_FILE up -d

echo ""
echo -e "${YELLOW}Waiting for services to be healthy...${NC}"
sleep 15

echo ""
echo "Service Status:"
docker-compose -f $COMPOSE_FILE ps

echo ""
echo -e "${GREEN}Done! Services have been rebuilt.${NC}"
echo ""
echo "Check logs with:"
echo "  docker-compose -f $COMPOSE_FILE logs -f"
echo ""
echo "Test services with:"
echo "  curl http://localhost:3001/health"
echo "  curl http://localhost:3002/health"
