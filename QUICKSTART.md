# Keycloak SSO クイックスタートガイド

## 必要な環境
- Docker & Docker Compose
- Node.js (v14以上)
- jq コマンド（セットアップスクリプト用）
  - macOS: `brew install jq`
  - Ubuntu/Debian: `sudo apt-get install jq`
  - CentOS/RHEL: `sudo yum install jq`

## クイックスタート

### 1. 環境の起動
```bash
# プロジェクトルートで実行
cd practice-sso-login

# Dockerコンテナの起動とKeycloakの設定
./scripts/start.sh
```

このスクリプトは以下を実行します：
- PostgreSQLデータベース x2
- Keycloak1 (IdP) on port 8080
- Keycloak2 (SP) on port 8180
- Mailhog (メールテスト用) on port 8025
- レルム、ユーザー、クライアントの自動設定

### 2. アプリケーションの起動

**ターミナル1:**
```bash
cd app1
npm install
npm start
```

**ターミナル2:**
```bash
cd app2
npm install
npm start
```

### 3. 動作確認

#### セットアップの検証
```bash
# セットアップが正しく完了しているか確認
./scripts/verify-setup.sh
```

#### SSOテスト
```bash
# SSOの動作テスト
./scripts/test-sso.sh
```

## アクセスURL

### Keycloak管理コンソール
- **Keycloak1 (IdP)**: http://localhost:8080/admin
- **Keycloak2 (SP)**: http://localhost:8180/admin
- **ユーザー名**: admin
- **パスワード**: admin

### アプリケーション
- **App1**: http://localhost:3000 (直接認証)
- **App2**: http://localhost:3001 (SSO認証)

### その他
- **Mailhog**: http://localhost:8025

## テストユーザー
- **ユーザー名**: testuser
- **パスワード**: password123

## SSOテストシナリオ

### シナリオ1: 基本的なログイン
1. App1 (http://localhost:3000) にアクセス
2. "Login with Keycloak"をクリック
3. testuser/password123 でログイン
4. プロファイルページが表示される

### シナリオ2: SSO動作確認
1. App1にログイン済みの状態で
2. 同じブラウザでApp2 (http://localhost:3001) を開く
3. "Login with SSO"をクリック
4. 自動的にログインされる（パスワード入力不要）

### シナリオ3: 認証フローの確認
1. ブラウザの開発者ツール（F12）でNetworkタブを開く
2. App2でログインプロセスを実行
3. 以下のリダイレクトフローを確認：
   - App2 → Keycloak2
   - Keycloak2 → Keycloak1
   - Keycloak1 → Keycloak2
   - Keycloak2 → App2

## 初回起動時の注意点

- Keycloakの起動には数分かかる場合があります
- `setup-keycloak.sh`が失敗する場合は、Keycloakが完全に起動するまで待ってから再実行してください
- 環境変数は`.env`ファイルに自動保存されます

## トラブルシューティング

### ポートが使用中の場合
```bash
# 使用中のポートを確認
lsof -i :8080
lsof -i :8180
lsof -i :3000
lsof -i :3001

# 全サービスを停止
./scripts/stop.sh
```

### セットアップが失敗する場合
```bash
# セットアップの状態を確認
./scripts/verify-setup.sh

# 問題がある場合は、全データを削除してやり直す
docker-compose down -v
./scripts/start.sh
```

### .envファイルの問題
```bash
# .envファイルをリセット
cp .env.example .env
./scripts/setup-keycloak.sh
```

### ログの確認
```bash
# Keycloakのログ
docker logs keycloak1-idp
docker logs keycloak2-sp

# アプリケーションのログはターミナルに表示される
```

## 環境の停止
```bash
./scripts/stop.sh
```

データも削除する場合は、プロンプトで `y` を入力してください。

## 次回以降の起動

一度セットアップが完了していれば、次回以降は以下のコマンドで起動できます：

```bash
# Dockerコンテナのみ起動
docker-compose up -d

# アプリケーションの起動
cd app1 && npm start
cd app2 && npm start
```