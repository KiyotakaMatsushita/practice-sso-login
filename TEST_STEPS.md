# SSO動作テスト手順

## 前提条件
- Docker環境が起動している
- App1とApp2が起動している

## テスト手順

### 1. ブラウザのキャッシュをクリア
- ブラウザのプライベート/シークレットモードを使用するか
- ブラウザのキャッシュとCookieをクリア

### 2. App1での直接ログイン
1. http://localhost:3000 にアクセス
2. "Login with Keycloak"をクリック
3. Keycloak1のログイン画面が表示される
4. ユーザー名: `testuser`
5. パスワード: `password123`
6. ログインをクリック
7. App1のプロファイルページが表示される

### 3. App2でのSSOログイン
1. **新しいタブ**で http://localhost:3001 を開く
2. "Login with SSO"をクリック
3. 以下のフローが自動的に実行される：
   - Keycloak2のログイン画面にリダイレクト
   - "Login with keycloak1-oidc"ボタンが表示される場合はクリック
   - Keycloak1にリダイレクトされる
   - 既にログイン済みの場合は自動的にApp2にリダイレクト
   - 初回の場合はログイン画面が表示される

### 4. トラブルシューティング

#### 502 Bad Gatewayエラーが出る場合
1. Identity Provider設定を再更新：
   ```bash
   ./scripts/update-idp.sh
   ```

2. Keycloak2を再起動：
   ```bash
   docker restart keycloak2-sp
   ```

#### ログインループが発生する場合
1. ブラウザのCookieをクリア
2. http://localhost:8080/realms/idp-realm/account でログアウト
3. http://localhost:8180/realms/sp-realm/account でログアウト
4. 再度テスト

### 5. 管理コンソールで確認

#### Keycloak1管理コンソール
- URL: http://localhost:8080/admin
- ユーザー名: admin
- パスワード: admin
- 確認項目:
  - Realm Settings → idp-realm
  - Clients → keycloak2-broker → Settings
  - Valid Redirect URIsに以下が含まれていること:
    - http://localhost:8180/realms/sp-realm/broker/keycloak1-oidc/endpoint
    - http://localhost:8180/*

#### Keycloak2管理コンソール
- URL: http://localhost:8180/admin
- ユーザー名: admin
- パスワード: admin
- 確認項目:
  - Realm Settings → sp-realm
  - Identity Providers → keycloak1-oidc
  - 設定が正しいことを確認

### 6. 成功時の動作
1. App1でログイン後、App2にアクセスすると自動的にログインされる
2. App2のプロファイルページに以下が表示される：
   - ユーザー名: testuser
   - メール: testuser@example.com
   - Auth Flow: SSO via Keycloak2 → Keycloak1

### 7. ログアウトのテスト
1. App1またはApp2でログアウト
2. 両方のアプリケーションからログアウトされることを確認