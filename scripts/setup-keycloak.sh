#!/bin/bash

# 色付き出力の定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Keycloak SSO Setup Script ===${NC}"

# 環境変数の読み込み
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo -e "${YELLOW}Warning: .env file not found. Using default values.${NC}"
fi

# デフォルト値の設定
KEYCLOAK1_URL=${KEYCLOAK1_URL:-"http://localhost:8080"}
KEYCLOAK2_URL=${KEYCLOAK2_URL:-"http://localhost:8180"}
KEYCLOAK_ADMIN=${KEYCLOAK_ADMIN:-"admin"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-"admin"}

# Keycloakが起動するまで待機
wait_for_keycloak() {
    local url=$1
    local name=$2
    echo -e "${YELLOW}Waiting for $name to be ready...${NC}"
    
    while ! curl -s -f -o /dev/null "$url/health/ready"; do
        echo -n "."
        sleep 2
    done
    
    echo -e "\n${GREEN}$name is ready!${NC}"
}

# アクセストークンの取得
get_admin_token() {
    local base_url=$1
    local token=$(curl -s -X POST "$base_url/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=$KEYCLOAK_ADMIN" \
        -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r '.access_token')
    
    echo $token
}

# Keycloak1 (IdP) の設定
setup_keycloak1() {
    echo -e "\n${GREEN}=== Setting up Keycloak1 (IdP) ===${NC}"
    
    local token=$(get_admin_token $KEYCLOAK1_URL)
    
    # 1. レルムの作成
    echo "Creating idp-realm..."
    curl -s -X POST "$KEYCLOAK1_URL/admin/realms" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "realm": "idp-realm",
            "enabled": true,
            "displayName": "Identity Provider Realm",
            "loginTheme": "keycloak",
            "sslRequired": "none",
            "registrationAllowed": true,
            "resetPasswordAllowed": true,
            "rememberMe": true,
            "verifyEmail": false,
            "smtpServer": {
                "host": "mailhog",
                "port": "1025",
                "from": "noreply@keycloak.local"
            }
        }'
    
    # 2. テストユーザーの作成
    echo "Creating test users..."
    curl -s -X POST "$KEYCLOAK1_URL/admin/realms/idp-realm/users" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "username": "testuser",
            "email": "testuser@example.com",
            "firstName": "Test",
            "lastName": "User",
            "enabled": true,
            "emailVerified": true,
            "credentials": [{
                "type": "password",
                "value": "password123",
                "temporary": false
            }]
        }'
    
    # 3. App1用クライアントの作成
    echo "Creating app1-client..."
    curl -s -X POST "$KEYCLOAK1_URL/admin/realms/idp-realm/clients" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "clientId": "app1-client",
            "name": "Application 1",
            "protocol": "openid-connect",
            "publicClient": false,
            "standardFlowEnabled": true,
            "directAccessGrantsEnabled": true,
            "serviceAccountsEnabled": false,
            "authorizationServicesEnabled": false,
            "redirectUris": ["http://localhost:3000/*"],
            "webOrigins": ["http://localhost:3000"],
            "attributes": {
                "access.token.lifespan": "300"
            }
        }'
    
    # クライアントIDの取得
    APP1_CLIENT_RESPONSE=$(curl -s "$KEYCLOAK1_URL/admin/realms/idp-realm/clients?clientId=app1-client" \
        -H "Authorization: Bearer $token")
    APP1_CLIENT_ID=$(echo $APP1_CLIENT_RESPONSE | jq -r '.[0].id')
    
    # クライアントシークレットの生成
    curl -s -X POST "$KEYCLOAK1_URL/admin/realms/idp-realm/clients/$APP1_CLIENT_ID/client-secret" \
        -H "Authorization: Bearer $token"
    
    # クライアントシークレットの取得
    APP1_SECRET=$(curl -s "$KEYCLOAK1_URL/admin/realms/idp-realm/clients/$APP1_CLIENT_ID/client-secret" \
        -H "Authorization: Bearer $token" | jq -r '.value')
    
    echo -e "${GREEN}App1 Client Secret: $APP1_SECRET${NC}"
    
    # 4. Keycloak2用ブローカークライアントの作成
    echo "Creating keycloak2-broker client..."
    curl -s -X POST "$KEYCLOAK1_URL/admin/realms/idp-realm/clients" \
        -H "Authorization: Bearer $token" \
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
            "redirectUris": ["http://localhost:8180/realms/sp-realm/broker/keycloak1-oidc/endpoint"],
            "webOrigins": ["http://localhost:8180"]
        }'
    
    # ブローカークライアントIDの取得
    BROKER_CLIENT_RESPONSE=$(curl -s "$KEYCLOAK1_URL/admin/realms/idp-realm/clients?clientId=keycloak2-broker" \
        -H "Authorization: Bearer $token")
    BROKER_CLIENT_ID=$(echo $BROKER_CLIENT_RESPONSE | jq -r '.[0].id')
    
    # ブローカーシークレットの生成
    curl -s -X POST "$KEYCLOAK1_URL/admin/realms/idp-realm/clients/$BROKER_CLIENT_ID/client-secret" \
        -H "Authorization: Bearer $token"
    
    BROKER_SECRET=$(curl -s "$KEYCLOAK1_URL/admin/realms/idp-realm/clients/$BROKER_CLIENT_ID/client-secret" \
        -H "Authorization: Bearer $token" | jq -r '.value')
    
    echo -e "${GREEN}Broker Client Secret: $BROKER_SECRET${NC}"
    
    # シークレットを.envファイルに保存（既存の値を更新）
    update_env_variable "APP1_CLIENT_SECRET" "$APP1_SECRET"
    update_env_variable "KEYCLOAK2_BROKER_SECRET" "$BROKER_SECRET"
}

# Keycloak2 (SP) の設定
setup_keycloak2() {
    echo -e "\n${GREEN}=== Setting up Keycloak2 (SP) ===${NC}"
    
    local token=$(get_admin_token $KEYCLOAK2_URL)
    
    # 1. レルムの作成
    echo "Creating sp-realm..."
    curl -s -X POST "$KEYCLOAK2_URL/admin/realms" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "realm": "sp-realm",
            "enabled": true,
            "displayName": "Service Provider Realm",
            "loginTheme": "keycloak",
            "sslRequired": "none",
            "registrationAllowed": false,
            "resetPasswordAllowed": true,
            "rememberMe": true,
            "verifyEmail": false
        }'
    
    # 2. Identity Providerの設定
    echo "Setting up OIDC Identity Provider..."
    curl -s -X POST "$KEYCLOAK2_URL/admin/realms/sp-realm/identity-provider/instances" \
        -H "Authorization: Bearer $token" \
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
                \"authorizationUrl\": \"$KEYCLOAK1_URL/realms/idp-realm/protocol/openid-connect/auth\",
                \"tokenUrl\": \"$KEYCLOAK1_URL/realms/idp-realm/protocol/openid-connect/token\",
                \"userInfoUrl\": \"$KEYCLOAK1_URL/realms/idp-realm/protocol/openid-connect/userinfo\",
                \"logoutUrl\": \"$KEYCLOAK1_URL/realms/idp-realm/protocol/openid-connect/logout\",
                \"clientId\": \"keycloak2-broker\",
                \"clientSecret\": \"$BROKER_SECRET\",
                \"defaultScope\": \"openid profile email\",
                \"syncMode\": \"IMPORT\",
                \"useJwksUrl\": \"true\",
                \"validateSignature\": \"true\",
                \"jwksUrl\": \"$KEYCLOAK1_URL/realms/idp-realm/protocol/openid-connect/certs\",
                \"issuer\": \"$KEYCLOAK1_URL/realms/idp-realm\"
            }
        }"
    
    # 3. App2用クライアントの作成
    echo "Creating app2-client..."
    curl -s -X POST "$KEYCLOAK2_URL/admin/realms/sp-realm/clients" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -d '{
            "clientId": "app2-client",
            "name": "Application 2",
            "protocol": "openid-connect",
            "publicClient": false,
            "standardFlowEnabled": true,
            "directAccessGrantsEnabled": true,
            "serviceAccountsEnabled": false,
            "authorizationServicesEnabled": false,
            "redirectUris": ["http://localhost:3001/*"],
            "webOrigins": ["http://localhost:3001"]
        }'
    
    # App2クライアントIDの取得
    APP2_CLIENT_RESPONSE=$(curl -s "$KEYCLOAK2_URL/admin/realms/sp-realm/clients?clientId=app2-client" \
        -H "Authorization: Bearer $token")
    APP2_CLIENT_ID=$(echo $APP2_CLIENT_RESPONSE | jq -r '.[0].id')
    
    # App2シークレットの生成
    curl -s -X POST "$KEYCLOAK2_URL/admin/realms/sp-realm/clients/$APP2_CLIENT_ID/client-secret" \
        -H "Authorization: Bearer $token"
    
    APP2_SECRET=$(curl -s "$KEYCLOAK2_URL/admin/realms/sp-realm/clients/$APP2_CLIENT_ID/client-secret" \
        -H "Authorization: Bearer $token" | jq -r '.value')
    
    echo -e "${GREEN}App2 Client Secret: $APP2_SECRET${NC}"
    
    # シークレットを.envファイルに保存（既存の値を更新）
    update_env_variable "APP2_CLIENT_SECRET" "$APP2_SECRET"
}

# 環境変数を更新する関数
update_env_variable() {
    local key=$1
    local value=$2
    
    if grep -q "^$key=" .env 2>/dev/null; then
        # 既存の値を更新（macOSとLinuxの両方で動作）
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^$key=.*|$key=$value|" .env
        else
            sed -i "s|^$key=.*|$key=$value|" .env
        fi
    else
        # 新規追加
        echo "$key=$value" >> .env
    fi
}

# メイン処理
main() {
    # 依存関係のチェック
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq is not installed. Please install jq first.${NC}"
        exit 1
    fi
    
    # .envファイルの初期化
    if [ ! -f .env ]; then
        cp .env.example .env
    else
        # 既存の.envファイルがある場合、必要な変数が存在するか確認
        echo -e "${YELLOW}既存の.envファイルを使用します${NC}"
    fi
    
    # Keycloakの起動を待つ
    wait_for_keycloak $KEYCLOAK1_URL "Keycloak1 (IdP)"
    wait_for_keycloak $KEYCLOAK2_URL "Keycloak2 (SP)"
    
    # セットアップ実行
    setup_keycloak1
    setup_keycloak2
    
    echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
    echo -e "${YELLOW}Keycloak1 Admin Console:${NC} $KEYCLOAK1_URL/admin"
    echo -e "${YELLOW}Keycloak2 Admin Console:${NC} $KEYCLOAK2_URL/admin"
    echo -e "${YELLOW}Username:${NC} admin"
    echo -e "${YELLOW}Password:${NC} admin"
    echo -e "\n${GREEN}Client secrets have been saved to .env file${NC}"
}

# スクリプトの実行
main