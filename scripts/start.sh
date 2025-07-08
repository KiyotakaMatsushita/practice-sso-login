#!/bin/bash

# 色付き出力の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Starting Keycloak SSO Environment ===${NC}"

# Docker Composeの起動
echo -e "${YELLOW}Starting Docker containers...${NC}"
docker-compose up -d

# 起動の待機
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 10

# Keycloakのセットアップ
echo -e "${YELLOW}Running Keycloak setup...${NC}"
./scripts/setup-keycloak.sh

echo -e "\n${GREEN}=== Environment is ready! ===${NC}"
echo -e "${YELLOW}Services:${NC}"
echo "- Keycloak1 (IdP): http://localhost:8080"
echo "- Keycloak2 (SP): http://localhost:8180"
echo "- Mailhog: http://localhost:8025"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Start App1: cd app1 && npm start"
echo "2. Start App2: cd app2 && npm start"