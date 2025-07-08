#!/bin/bash

# 色付き出力の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Starting Keycloak SSO Environment ===${NC}"

# ディレクトリをスクリプトの親ディレクトリに移動
cd "$(dirname "$0")/.."

# Docker Composeの起動
echo -e "${YELLOW}Starting Docker containers...${NC}"
docker-compose up -d

# 起動の待機
echo -e "${YELLOW}Waiting for services to be ready...${NC}"
sleep 10

# Keycloakのセットアップ
echo -e "${YELLOW}Running Keycloak setup...${NC}"
bash ./scripts/setup-keycloak.sh

echo -e "\n${GREEN}=== Environment is ready! ===${NC}"
echo -e "${YELLOW}Services:${NC}"
echo "- Keycloak1 (IdP): http://localhost:8080/admin"
echo "- Keycloak2 (SP): http://localhost:8180/admin"
echo "- Mailhog: http://localhost:8025"
echo ""
echo -e "${YELLOW}Admin credentials:${NC}"
echo "- Username: admin"
echo "- Password: admin"
echo ""
echo -e "${YELLOW}Test user:${NC}"
echo "- Username: testuser"
echo "- Password: password123"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Start App1: cd app1 && npm install && npm start"
echo "2. Start App2: cd app2 && npm install && npm start"
echo ""
echo -e "${GREEN}Quick test command:${NC}"
echo "./scripts/test-sso.sh"