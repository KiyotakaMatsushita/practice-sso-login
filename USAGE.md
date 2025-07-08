# SSO実装の使い方ガイド

## 手順

### 1. アプリケーションの準備

**App1の依存関係インストール（ターミナル1）:**
```bash
cd app1
rm -rf node_modules package-lock.json
npm install
```

**App2の依存関係インストール（ターミナル2）:**
```bash
cd app2
rm -rf node_modules package-lock.json
npm install
```

### 2. アプリケーションの起動

**App1の起動（ターミナル1）:**
```bash
npm start
```

**App2の起動（ターミナル2）:**
```bash
npm start
```

### 3. SSO動作確認

#### シナリオ1: App1で直接ログイン
1. ブラウザで http://localhost:3000 を開く
2. "Login with Keycloak"をクリック
3. Keycloak1のログイン画面が表示される
4. ユーザー名: `testuser`、パスワード: `password123` でログイン
5. App1のプロファイルページにリダイレクトされる

#### シナリオ2: App2でSSOログイン
1. 新しいブラウザタブで http://localhost:3001 を開く
2. "Login with SSO"をクリック
3. Keycloak2にリダイレクトされる
4. Keycloak2がKeycloak1にリダイレクト
5. ユーザー名: `testuser`、パスワード: `password123` でログイン
6. App2のプロファイルページにリダイレクトされる

#### シナリオ3: SSO動作確認
1. App1でログイン済みの状態で
2. 同じブラウザで http://localhost:3001 を開く
3. "Login with SSO"をクリック
4. **パスワード入力なしで自動的にログインされる**（これがSSO！）

### 4. ログアウト確認
1. App1またはApp2でログアウト
2. Keycloakのログアウトページにリダイレクトされる
3. 他のアプリにアクセスすると再度ログインが必要

## トラブルシューティング

### エラー: Invalid client or Invalid client credentials
**原因**: クライアントシークレットが正しく設定されていない

**解決方法**:
```bash
# .envファイルを確認
cat .env | grep CLIENT_SECRET

# 値が設定されていない場合は、セットアップを再実行
./scripts/setup-keycloak.sh
```

### エラー: Failed to setup OIDC client
**原因**: Keycloakが起動していない

**解決方法**:
```bash
# Keycloakの状態確認
docker ps

# 起動していない場合
docker-compose up -d
```

### ログインループが発生する
**原因**: リダイレクトURIの設定ミス

**解決方法**:
1. Keycloak管理コンソールにログイン（http://localhost:8080/admin）
2. Clients → app1-client → Valid Redirect URIs
3. `http://localhost:3000/*` が設定されていることを確認

## 管理コンソールでの確認

### Keycloak1 (IdP) - http://localhost:8080/admin
- ユーザー名: admin
- パスワード: admin
- 確認項目:
  - Realm: idp-realm
  - Users: testuser
  - Clients: app1-client, keycloak2-broker

### Keycloak2 (SP) - http://localhost:8180/admin
- ユーザー名: admin
- パスワード: admin
- 確認項目:
  - Realm: sp-realm
  - Identity Providers: keycloak1-oidc
  - Clients: app2-client

## SSO認証フローの詳細

```
1. User → App2: アクセス
2. App2 → Keycloak2: 認証要求
3. Keycloak2 → Keycloak1: IdPへリダイレクト
4. Keycloak1 → User: ログイン画面表示
5. User → Keycloak1: 認証情報送信
6. Keycloak1 → Keycloak2: 認証成功通知
7. Keycloak2 → App2: トークン発行
8. App2 → User: サービス提供
```

## ポイント
- App1は**Keycloak1と直接**認証
- App2は**Keycloak2経由でKeycloak1**と認証（SSO）
- 一度ログインすれば、両方のアプリにアクセス可能
- Keycloak2が認証の仲介役（ブローカー）として機能