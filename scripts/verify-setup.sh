#!/bin/bash

# 色付き出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SSO Setup Verification ===${NC}"

# ディレクトリをスクリプトの親ディレクトリに移動
cd "$(dirname "$0")/.."

# 1. 環境変数ファイルの確認
echo -e "\n${YELLOW}1. Checking .env file...${NC}"
if [ -f .env ]; then
    echo -e "${GREEN}✓ .env file exists${NC}"
    
    # 必要な環境変数の確認
    required_vars=("APP1_CLIENT_SECRET" "APP2_CLIENT_SECRET" "KEYCLOAK2_BROKER_SECRET" "KEYCLOAK1_URL" "KEYCLOAK2_URL")
    missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if grep -q "^${var}=.\\+" .env; then
            echo -e "${GREEN}✓ $var is set${NC}"
        else
            echo -e "${RED}✗ $var is missing or empty${NC}"
            missing_vars+=($var)
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}Missing environment variables: ${missing_vars[*]}${NC}"
        echo -e "${YELLOW}Run ./scripts/setup-keycloak.sh to generate missing secrets${NC}"
    fi
else
    echo -e "${RED}✗ .env file not found${NC}"
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"
    cp .env.example .env
fi

# 2. Dockerコンテナの確認
echo -e "\n${YELLOW}2. Checking Docker containers...${NC}"
containers=("keycloak1-idp" "keycloak2-sp" "keycloak-postgres1" "keycloak-postgres2" "keycloak-mailhog")
all_running=true

for container in "${containers[@]}"; do
    if docker ps | grep -q "$container"; then
        echo -e "${GREEN}✓ $container is running${NC}"
    else
        echo -e "${RED}✗ $container is not running${NC}"
        all_running=false
    fi
done

if [ "$all_running" = false ]; then
    echo -e "${YELLOW}Some containers are not running. Run ./scripts/start.sh to start all services${NC}"
fi

# 3. Keycloakの接続確認
echo -e "\n${YELLOW}3. Checking Keycloak connectivity...${NC}"

check_keycloak() {
    local url=$1
    local name=$2
    
    if curl -s -f -o /dev/null "$url/health/ready"; then
        echo -e "${GREEN}✓ $name is accessible at $url${NC}"
        return 0
    else
        echo -e "${RED}✗ $name is not accessible at $url${NC}"
        return 1
    fi
}

check_keycloak "http://localhost:8080" "Keycloak1 (IdP)"
keycloak1_status=$?

check_keycloak "http://localhost:8180" "Keycloak2 (SP)"
keycloak2_status=$?

if [ $keycloak1_status -ne 0 ] || [ $keycloak2_status -ne 0 ]; then
    echo -e "${YELLOW}Keycloak services are not ready. They may still be starting up.${NC}"
    echo -e "${YELLOW}Wait a few seconds and try again, or check logs with:${NC}"
    echo "  docker logs keycloak1-idp"
    echo "  docker logs keycloak2-sp"
fi

# 4. アプリケーションのNode.js依存関係確認
echo -e "\n${YELLOW}4. Checking application dependencies...${NC}"

check_app_deps() {
    local app_dir=$1
    local app_name=$2
    
    if [ -d "$app_dir/node_modules" ]; then
        echo -e "${GREEN}✓ $app_name dependencies are installed${NC}"
    else
        echo -e "${YELLOW}! $app_name dependencies not installed${NC}"
        echo -e "  Run: cd $app_dir && npm install"
    fi
}

check_app_deps "app1" "App1"
check_app_deps "app2" "App2"

# 5. ポートの確認
echo -e "\n${YELLOW}5. Checking required ports...${NC}"
ports=("8080:Keycloak1" "8180:Keycloak2" "3000:App1" "3001:App2" "8025:Mailhog")

for port_info in "${ports[@]}"; do
    port="${port_info%:*}"
    service="${port_info#*:}"
    
    if lsof -i :$port > /dev/null 2>&1; then
        # ポートが使用中
        if docker ps | grep -q "${service,,}"; then
            echo -e "${GREEN}✓ Port $port is used by $service (expected)${NC}"
        else
            echo -e "${YELLOW}! Port $port is in use (might conflict with $service)${NC}"
        fi
    else
        # ポートが空いている
        if [[ "$service" == "App1" ]] || [[ "$service" == "App2" ]]; then
            echo -e "${GREEN}✓ Port $port is available for $service${NC}"
        else
            echo -e "${YELLOW}! Port $port is not in use ($service might not be running)${NC}"
        fi
    fi
done

# 6. 総合判定
echo -e "\n${GREEN}=== Setup Verification Complete ===${NC}"
echo -e "${YELLOW}Summary:${NC}"

if [ "$all_running" = true ] && [ $keycloak1_status -eq 0 ] && [ $keycloak2_status -eq 0 ] && [ ${#missing_vars[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All services are properly configured and running!${NC}"
    echo -e "\n${YELLOW}You can now start the applications:${NC}"
    echo "  Terminal 1: cd app1 && npm start"
    echo "  Terminal 2: cd app2 && npm start"
    echo -e "\n${YELLOW}Then test SSO with:${NC}"
    echo "  ./scripts/test-sso.sh"
else
    echo -e "${YELLOW}⚠ Some issues were found. Please address them before proceeding.${NC}"
    echo -e "\n${YELLOW}Quick fix:${NC}"
    echo "  ./scripts/stop.sh"
    echo "  ./scripts/start.sh"
fi