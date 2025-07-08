#!/bin/bash

# 色付き出力の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Updating Identity Provider Configuration ===${NC}"

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

# Identity Providerの更新
echo "Updating Identity Provider configuration..."
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
            \"tokenUrl\": \"http://localhost:8080/realms/idp-realm/protocol/openid-connect/token\",
            \"userInfoUrl\": \"http://localhost:8080/realms/idp-realm/protocol/openid-connect/userinfo\",
            \"logoutUrl\": \"http://localhost:8080/realms/idp-realm/protocol/openid-connect/logout\",
            \"clientId\": \"keycloak2-broker\",
            \"clientSecret\": \"$KEYCLOAK2_BROKER_SECRET\",
            \"defaultScope\": \"openid profile email\",
            \"syncMode\": \"IMPORT\",
            \"useJwksUrl\": \"true\",
            \"validateSignature\": \"true\",
            \"jwksUrl\": \"http://localhost:8080/realms/idp-realm/protocol/openid-connect/certs\",
            \"issuer\": \"http://localhost:8080/realms/idp-realm\"
        }
    }"

echo -e "\n${GREEN}Identity Provider configuration updated!${NC}"

# Keycloak1のブローカークライアントも更新
echo "Getting Keycloak1 admin token..."
TOKEN1=$(curl -s -X POST "http://localhost:8080/realms/master/protocol/openid-connect/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "username=$KEYCLOAK_ADMIN" \
    -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
    -d "grant_type=password" \
    -d "client_id=admin-cli" | jq -r '.access_token')

# ブローカークライアントのIDを取得
echo "Getting broker client ID..."
BROKER_CLIENT_ID=$(curl -s "http://localhost:8080/admin/realms/idp-realm/clients?clientId=keycloak2-broker" \
    -H "Authorization: Bearer $TOKEN1" | jq -r '.[0].id')

# ブローカークライアントの更新
echo "Updating broker client..."
curl -s -X PUT "http://localhost:8080/admin/realms/idp-realm/clients/$BROKER_CLIENT_ID" \
    -H "Authorization: Bearer $TOKEN1" \
    -H "Content-Type: application/json" \
    -d '{
        "clientId": "keycloak2-broker",
        "name": "Keycloak2 Broker",
        "protocol": "openid-connect",
        "publicClient": false,
        "standardFlowEnabled": true,
        "directAccessGrantsEnabled": false,
        "serviceAccountsEnabled": false,
        "authorizationServicesEnabled": false,
        "redirectUris": [
            "http://localhost:8180/realms/sp-realm/broker/keycloak1-oidc/endpoint",
            "http://localhost:8180/auth/realms/sp-realm/broker/keycloak1-oidc/endpoint",
            "http://localhost:8180/*"
        ],
        "webOrigins": ["http://localhost:8180", "+"]
    }'

echo -e "\n${GREEN}All configurations updated successfully!${NC}"