#!/bin/bash

# 色付き出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SSO Login Flow Test Script ===${NC}"

# テストユーザー情報
TEST_USER="testuser"
TEST_PASSWORD="password123"

# URLs
KEYCLOAK1_URL="http://localhost:8080"
KEYCLOAK2_URL="http://localhost:8180"
APP1_URL="http://localhost:3000"
APP2_URL="http://localhost:3001"

# サービスの確認
check_service() {
    local url=$1
    local name=$2
    
    if curl -s -f -o /dev/null "$url"; then
        echo -e "${GREEN}✓${NC} $name is running at $url"
    else
        echo -e "${RED}✗${NC} $name is not accessible at $url"
        return 1
    fi
}

# 全サービスの状態確認
echo -e "\n${BLUE}Checking services...${NC}"
check_service "$KEYCLOAK1_URL/health/ready" "Keycloak1 (IdP)"
check_service "$KEYCLOAK2_URL/health/ready" "Keycloak2 (SP)"
check_service "$APP1_URL" "Application 1"
check_service "$APP2_URL" "Application 2"

# Keycloak管理コンソールの情報
echo -e "\n${BLUE}Keycloak Admin Consoles:${NC}"
echo -e "Keycloak1: ${YELLOW}$KEYCLOAK1_URL/admin${NC}"
echo -e "Keycloak2: ${YELLOW}$KEYCLOAK2_URL/admin${NC}"
echo -e "Username: ${YELLOW}admin${NC}"
echo -e "Password: ${YELLOW}admin${NC}"

# アプリケーションURLの表示
echo -e "\n${BLUE}Application URLs:${NC}"
echo -e "App1 (Direct Auth): ${YELLOW}$APP1_URL${NC}"
echo -e "App2 (SSO Auth): ${YELLOW}$APP2_URL${NC}"

# テストユーザー情報
echo -e "\n${BLUE}Test User Credentials:${NC}"
echo -e "Username: ${YELLOW}$TEST_USER${NC}"
echo -e "Password: ${YELLOW}$TEST_PASSWORD${NC}"

# SSO テストシナリオ
echo -e "\n${BLUE}SSO Test Scenarios:${NC}"
echo -e "\n${YELLOW}Scenario 1: Direct Authentication${NC}"
echo "1. Open App1 at $APP1_URL"
echo "2. Click 'Login with Keycloak'"
echo "3. Login with testuser/password123"
echo "4. You should see the user profile"

echo -e "\n${YELLOW}Scenario 2: SSO Authentication Flow${NC}"
echo "1. Open App2 at $APP2_URL"
echo "2. Click 'Login with SSO'"
echo "3. You will be redirected to Keycloak2"
echo "4. Keycloak2 will redirect you to Keycloak1"
echo "5. Login with testuser/password123"
echo "6. You will be redirected back to App2"

echo -e "\n${YELLOW}Scenario 3: SSO Between Applications${NC}"
echo "1. Login to App1 first"
echo "2. Open App2 in the same browser"
echo "3. Click 'Login with SSO'"
echo "4. You should be automatically logged in without entering credentials"

echo -e "\n${YELLOW}Scenario 4: Logout Test${NC}"
echo "1. While logged in to both apps"
echo "2. Logout from App1"
echo "3. Try to access App2"
echo "4. You should need to login again"

# 自動テスト（基本的な接続確認）
echo -e "\n${BLUE}Running automated connectivity tests...${NC}"

# Keycloak1のトークンエンドポイント確認
echo -n "Testing Keycloak1 token endpoint... "
TOKEN_RESPONSE=$(curl -s -X POST "$KEYCLOAK1_URL/realms/idp-realm/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=password" \
    -d "client_id=app1-client" \
    -d "client_secret=$APP1_CLIENT_SECRET" \
    -d "username=$TEST_USER" \
    -d "password=$TEST_PASSWORD" 2>/dev/null)

if [[ $TOKEN_RESPONSE == *"access_token"* ]]; then
    echo -e "${GREEN}✓ Success${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# Keycloak2のディスカバリーエンドポイント確認
echo -n "Testing Keycloak2 discovery endpoint... "
DISCOVERY_RESPONSE=$(curl -s "$KEYCLOAK2_URL/realms/sp-realm/.well-known/openid-configuration")

if [[ $DISCOVERY_RESPONSE == *"authorization_endpoint"* ]]; then
    echo -e "${GREEN}✓ Success${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# 詳細ログの確認方法
echo -e "\n${BLUE}Debugging Tips:${NC}"
echo "1. Check Docker logs:"
echo "   docker logs keycloak1-idp"
echo "   docker logs keycloak2-sp"
echo "2. Check application logs:"
echo "   In app1/ directory: npm start"
echo "   In app2/ directory: npm start"
echo "3. Monitor network traffic:"
echo "   Use browser Developer Tools (F12) → Network tab"

echo -e "\n${GREEN}Test setup complete! Open your browser and start testing.${NC}"