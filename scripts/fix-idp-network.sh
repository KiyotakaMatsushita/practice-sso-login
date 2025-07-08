#!/bin/bash

# 色付き出力の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Fixing Identity Provider Network Configuration ===${NC}"

# 環境変数の読み込み
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

KEYCLOAK2_URL=${KEYCLOAK2_URL:-"http://localhost:8180"}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}

# アクセストークンの取得
echo "Getting admin token..."
TOKEN=$(curl -s -X POST "$KEYCLOAK2_URL/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KEYCLOAK_ADMIN" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

# Identity Providerの更新（コンテナ間通信用に修正）
echo "Updating Identity Provider with container networking..."
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

echo -e "\n${GREEN}Identity Provider configuration updated with container networking!${NC}"
echo -e "${YELLOW}Note: authorizationUrl and logoutUrl use localhost (for browser access)${NC}"
echo -e "${YELLOW}      tokenUrl, userInfoUrl, and jwksUrl use keycloak1-idp (for container-to-container)${NC}"