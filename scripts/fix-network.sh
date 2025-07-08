#!/bin/bash

# 色付き出力の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Fixing Docker Network Configuration for SSO ===${NC}"

# ディレクトリをスクリプトの親ディレクトリに移動
cd "$(dirname "$0")/.."

# 環境変数の読み込み
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${RED}Error: .env file not found${NC}"
    exit 1
fi

KEYCLOAK2_URL=${KEYCLOAK2_URL:-"http://localhost:8180"}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}

# Keycloak2が起動しているか確認
echo -e "${YELLOW}Checking Keycloak2 availability...${NC}"
if ! curl -s -f -o /dev/null "$KEYCLOAK2_URL/health/ready"; then
    echo -e "${RED}Error: Keycloak2 is not ready at $KEYCLOAK2_URL${NC}"
    echo "Please ensure Keycloak2 is running: docker ps | grep keycloak2-sp"
    exit 1
fi

# アクセストークンの取得
echo "Getting admin token..."
TOKEN=$(curl -s -X POST "$KEYCLOAK2_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KEYCLOAK_ADMIN" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo -e "${RED}Error: Failed to get admin token${NC}"
    exit 1
fi

# Identity Providerの設定を修正
echo -e "${YELLOW}Updating Identity Provider configuration...${NC}"
echo "Setting up network URLs:"
echo "  - Browser URLs: Using localhost (for user browser access)"
echo "  - Container URLs: Using keycloak1-idp (for container-to-container communication)"

curl -s -X PUT "$KEYCLOAK2_URL/admin/realms/sp-realm/identity-provider/instances/keycloak1-oidc" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"alias\": \"keycloak1-oidc\",
        \"displayName\": \"Keycloak1 IdP\",
        \"providerId\": \"oidc\",
        \"enabled\": true,
        \"trustEmail\": true,
        \"storeToken\": true,
        \"addReadTokenRoleOnCreate\": true,
        \"authenticateByDefault\": false,
        \"linkOnly\": false,
        \"firstBrokerLoginFlowAlias\": \"first broker login\",
        \"config\": {
            \"authorizationUrl\": \"http://localhost:8080/realms/idp-realm/protocol/openid-connect/auth\",
            \"tokenUrl\": \"http://keycloak1-idp:8080/realms/idp-realm/protocol/openid-connect/token\",
            \"userInfoUrl\": \"http://keycloak1-idp:8080/realms/idp-realm/protocol/openid-connect/userinfo\",
            \"logoutUrl\": \"http://localhost:8080/realms/idp-realm/protocol/openid-connect/logout\",
            \"clientId\": \"keycloak2-broker\",
            \"clientSecret\": \"$KEYCLOAK2_BROKER_SECRET\",
            \"defaultScope\": \"openid profile email\",
            \"syncMode\": \"IMPORT\",
            \"useJwksUrl\": \"true\",
            \"validateSignature\": \"true\",
            \"jwksUrl\": \"http://keycloak1-idp:8080/realms/idp-realm/protocol/openid-connect/certs\",
            \"issuer\": \"http://localhost:8080/realms/idp-realm\",
            \"clientAuthMethod\": \"client_secret_post\"
        }
    }"

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓ Identity Provider configuration updated successfully!${NC}"
    echo -e "${YELLOW}URL Configuration:${NC}"
    echo "  - authorizationUrl: localhost (browser redirect)"
    echo "  - tokenUrl: keycloak1-idp (container API call)"
    echo "  - userInfoUrl: keycloak1-idp (container API call)"
    echo "  - jwksUrl: keycloak1-idp (container API call)"
    echo "  - logoutUrl: localhost (browser redirect)"
    echo ""
    echo -e "${GREEN}You should now be able to use SSO without 502 errors!${NC}"
else
    echo -e "\n${RED}✗ Failed to update Identity Provider configuration${NC}"
    echo "Please check the logs: docker logs keycloak2-sp"
fi