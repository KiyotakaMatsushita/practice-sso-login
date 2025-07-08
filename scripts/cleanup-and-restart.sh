#!/bin/bash

# 色付き出力の定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== SSO環境のクリーンアップと再起動 ===${NC}"

# ディレクトリをスクリプトの親ディレクトリに移動
cd "$(dirname "$0")/.."

# 1. アプリケーションの停止
echo -e "${YELLOW}Stopping applications...${NC}"
pkill -f "node.*app1" 2>/dev/null || true
pkill -f "node.*app2" 2>/dev/null || true

# 2. Dockerコンテナの停止と削除
echo -e "${YELLOW}Stopping and removing Docker containers...${NC}"
docker-compose down -v

# 3. 古い.envファイルのバックアップと削除
echo -e "${YELLOW}Backing up and removing old .env file...${NC}"
if [ -f .env ]; then
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    rm .env
fi

# 4. 環境の再起動
echo -e "${YELLOW}Starting fresh environment...${NC}"
./scripts/start.sh

# 5. ネットワーク修正の適用
echo -e "${YELLOW}Applying network fixes...${NC}"
sleep 30  # Keycloakの起動を待つ
./scripts/fix-network.sh

# 6. 設定の検証
echo -e "${YELLOW}Verifying setup...${NC}"
./scripts/verify-setup.sh

echo -e "\n${GREEN}=== 環境のクリーンアップと再起動が完了しました ===${NC}"
echo -e "${YELLOW}次のステップ:${NC}"
echo "1. Terminal 1: cd app1 && npm start"
echo "2. Terminal 2: cd app2 && npm start"
echo ""
echo -e "${GREEN}その後、ブラウザのキャッシュをクリアしてからテストしてください。${NC}"