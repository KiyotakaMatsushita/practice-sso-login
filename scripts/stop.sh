#!/bin/bash

# 色付き出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Stopping Keycloak SSO Environment ===${NC}"

# Docker Composeの停止
docker-compose down

echo -e "${GREEN}All services stopped.${NC}"

# データを削除するかの確認
read -p "Do you want to remove all data (volumes)? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker-compose down -v
    echo -e "${RED}All data has been removed.${NC}"
fi