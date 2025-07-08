# Keycloak SSO実装練習プロジェクト

## 概要
2つのKeycloakインスタンスを使用して、SSO（シングルサインオン）の仕組みを理解・実装するプロジェクトです。

## 基本概念の解説

### SP（Service Provider）とIdP（Identity Provider）の詳細解説

#### 1. SP（Service Provider）とは？

**Service Provider（サービス提供者）**は、**実際にサービスを提供するアプリケーション**のことです。

**具体例で理解する**：
- **Google Workspace** = SP（メール、ドキュメント編集などのサービスを提供）
- **Salesforce** = SP（顧客管理サービスを提供）
- **Slack** = SP（チャットサービスを提供）
- **このプロジェクトでは** = App2がSP

#### 2. IdP（Identity Provider）とは？

**Identity Provider（認証基盤提供者）**は、**ユーザーの認証情報を管理し、認証サービスを提供**する専門システムです。

**具体例で理解する**：
- **Microsoft Active Directory** = IdP（社内の全ユーザーを管理）
- **Google Identity Platform** = IdP（Googleアカウントで認証）
- **Okta** = IdP（エンタープライズ向け認証サービス）
- **このプロジェクトでは** = Keycloak1がIdP

#### 3. 実世界での例え

**図書館システムで例えると**：
```
┌─────────────────┐     ┌─────────────────┐
│   図書館        │     │   市役所        │
│   (SP)          │     │   (IdP)         │
│                 │     │                 │
│ ・本の貸出     │     │ ・住民登録     │
│ ・読書スペース │     │ ・身分証明書発行│
│ ・資料検索     │  ◄──┤ ・住民情報管理 │
│                 │     │                 │
│ ※身分確認は    │     │ ※住民の身分を  │
│   市役所に依頼  │     │   一元管理      │
└─────────────────┘     └─────────────────┘
```

1. **利用者**が図書館で本を借りようとする
2. **図書館（SP）**「身分証明書を見せてください」
3. **利用者**が市役所発行の身分証明書を提示
4. **図書館（SP）**が市役所（IdP）に身分を確認
5. **市役所（IdP）**「この人は確かに住民です」と回答
6. **図書館（SP）**がサービス（本の貸出）を提供

#### 4. SPとIdPの責任分担

**SP（Service Provider）の責任**：
- アプリケーションの機能提供
- 認証後のユーザー管理
- リソースへのアクセス制御
- ビジネスロジックの実装

**IdP（Identity Provider）の責任**：
- ユーザー認証（パスワード確認など）
- 認証情報の管理
- セキュリティポリシーの実装
- 認証証明書の発行

#### 5. このプロジェクトでの構成

```
┌─────────────────┐     ┌─────────────────┐
│   App1          │     │   Keycloak1     │
│   (SP)          │────▶│   (IdP)         │
│                 │     │                 │
│ ・直接認証      │     │ ・ユーザー管理  │
│ ・ユーザー情報  │     │ ・認証処理      │
│   表示          │     │ ・トークン発行  │
└─────────────────┘     └─────────────────┘
                                 ▲
                                 │
┌─────────────────┐     ┌─────────────────┐
│   App2          │     │   Keycloak2     │
│   (SP)          │────▶│   (SP)          │
│                 │     │                 │
│ ・SSO経由認証   │     │ ・認証の仲介    │
│ ・ユーザー情報  │     │ ・IdPへの       │
│   表示          │     │   リダイレクト  │
└─────────────────┘     └─────────────────┘
```

**注意**: Keycloak2は、App2に対してはIdPとして動作しますが、Keycloak1に対してはSPとして動作します。

#### 6. 認証フローでの役割

**Step 1: ユーザーがApp2にアクセス**
```
User → App2 (SP): 「サービスを使いたい」
App2 (SP) → User: 「まず認証が必要です」
```

**Step 2: App2がKeycloak2に認証を委託**
```
App2 (SP) → Keycloak2 (IdP): 「この人を認証してください」
Keycloak2 (IdP) → User: 「認証画面にリダイレクトします」
```

**Step 3: Keycloak2がKeycloak1に認証を委託**
```
Keycloak2 (SP) → Keycloak1 (IdP): 「この人を認証してください」
Keycloak1 (IdP) → User: 「ログイン画面を表示します」
```

**Step 4: 認証完了後の応答**
```
User → Keycloak1 (IdP): 「ログイン情報を送信」
Keycloak1 (IdP) → Keycloak2 (SP): 「認証成功、ユーザー情報を送信」
Keycloak2 (IdP) → App2 (SP): 「認証成功、トークンを発行」
App2 (SP) → User: 「サービスを提供」
```

#### 7. プロトコルの選択

**OIDC（OpenID Connect）の場合**：
- モダンなWeb/モバイルアプリケーション
- JSON形式でのデータ交換
- RESTful API
- JWT（JSON Web Token）の使用

**SAML2.0の場合**：
- エンタープライズ環境
- XML形式でのデータ交換
- 豊富な属性情報の交換
- 高度なセキュリティ機能

#### 8. 設定のポイント

**SP側の設定**：
```javascript
// App2（SP）の設定例
{
  // 認証をどのIdPに委託するか
  issuer: 'http://localhost:8180/auth/realms/sp-realm',
  
  // このアプリケーションの識別子
  clientId: 'app2-client',
  
  // 認証後のリダイレクト先
  redirectUri: 'http://localhost:3001/callback',
  
  // 必要な権限の範囲
  scope: 'openid profile email'
}
```

**IdP側の設定**：
```javascript
// Keycloak1（IdP）の設定例
{
  // どのSPからの認証要求を受け付けるか
  clientId: 'keycloak2-broker',
  
  // 認証後のリダイレクト先
  redirectUris: [
    'http://localhost:8180/auth/realms/sp-realm/broker/keycloak1-oidc/endpoint'
  ],
  
  // 提供する属性情報
  attributeMapping: {
    email: 'email',
    name: 'name',
    groups: 'groups'
  }
}
```

#### 9. メリット・デメリット

**SPのメリット**：
- 認証ロジックをIdPに委託できる
- 複数のIdPと連携可能
- パスワード管理が不要

**SPのデメリット**：
- IdPとの連携設定が必要
- IdPが停止するとログインできない
- 複雑な設定が必要

**IdPのメリット**：
- 複数のSPに対して一元的に認証を提供
- セキュリティポリシーを集中管理
- SSO（シングルサインオン）を実現

**IdPのデメリット**：
- 単一障害点になる可能性
- 高可用性が必要
- 管理が複雑

### SPとIdPが一緒のケース（統合型システム）

#### 1. 統合型システムとは？

**一つのシステムが両方の役割を果たす**ケースが実際に多く存在します。これは現実世界でよく見られるパターンです。

#### 2. 身近な例

**Google**：
```
┌─────────────────┐
│     Google      │
├─────────────────┤
│ 【SP機能】      │
│ ・Gmail         │
│ ・Drive         │
│ ・YouTube       │
│ ・Maps          │
├─────────────────┤
│ 【IdP機能】     │
│ ・Google Account│
│ ・Google Login  │
│ ・OAuth2.0      │
│ ・OpenID Connect│
└─────────────────┘
```

**Microsoft**：
```
┌─────────────────┐
│   Microsoft     │
├─────────────────┤
│ 【SP機能】      │
│ ・Office365     │
│ ・Teams         │
│ ・OneDrive      │
│ ・Azure Portal  │
├─────────────────┤
│ 【IdP機能】     │
│ ・Azure AD      │
│ ・Microsoft ID  │
│ ・SAML2.0       │
│ ・OpenID Connect│
└─────────────────┘
```

#### 3. このプロジェクトでの例

**Keycloak2の二重の役割**：
```
┌─────────────────┐
│   Keycloak2     │
├─────────────────┤
│ 【IdP機能】     │
│ App2に対して    │
│ ・認証サービス  │
│ ・トークン発行  │
│ ・ユーザー管理  │
├─────────────────┤
│ 【SP機能】      │
│ Keycloak1に対して│
│ ・認証委託      │
│ ・認証要求      │
│ ・トークン受信  │
└─────────────────┘
```

#### 4. 実装パターン

**パターン1: 自社サービス + 外部IdP対応**
```javascript
// 自社サービス（SP）+ 自社認証（IdP）
const authConfig = {
  // 自社認証（IdP機能）
  localAuth: {
    enabled: true,
    userDatabase: 'internal',
    passwordPolicy: 'strong'
  },
  
  // 外部IdP連携（SP機能）
  externalIdP: {
    google: {
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET
    },
    microsoft: {
      clientId: process.env.MICROSOFT_CLIENT_ID,
      clientSecret: process.env.MICROSOFT_CLIENT_SECRET
    }
  }
};
```

**パターン2: 企業内統合システム**
```javascript
// 企業ポータル（SP + IdP）
const enterprisePortal = {
  // サービス提供（SP機能）
  services: [
    'employee-portal',
    'time-tracking',
    'expense-management',
    'document-management'
  ],
  
  // 認証サービス（IdP機能）
  authenticationService: {
    userDirectory: 'LDAP',
    ssoSupport: true,
    externalApps: [
      'salesforce',
      'slack',
      'github'
    ]
  }
};
```

#### 5. 設定の考慮点

**同一システム内での設定**：
```javascript
// Keycloak2の設定例
{
  // IdP設定（App2向け）
  idpConfig: {
    realm: 'sp-realm',
    clients: ['app2-client'],
    users: 'federated', // 外部IdPから取得
    roles: ['user', 'admin']
  },
  
  // SP設定（Keycloak1向け）
  spConfig: {
    identityProvider: {
      alias: 'keycloak1-oidc',
      providerId: 'oidc',
      config: {
        authorizationUrl: 'http://localhost:8080/auth/realms/idp-realm/protocol/openid-connect/auth',
        tokenUrl: 'http://localhost:8080/auth/realms/idp-realm/protocol/openid-connect/token',
        clientId: 'keycloak2-broker',
        clientSecret: '${CLIENT_SECRET}'
      }
    }
  }
}
```

#### 6. 認証フロー

**統合システムでの認証フロー**：
```
┌─────────────────┐
│   外部ユーザー   │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 統合システム     │
│ (SP + IdP)      │
├─────────────────┤
│ 1. 認証要求受信  │
│ 2. 認証方法選択  │
│    a) 内部認証   │
│    b) 外部IdP    │
│ 3. 認証実行      │
│ 4. トークン発行  │
│ 5. サービス提供  │
└─────────────────┘
```

#### 7. メリット・デメリット

**メリット**：
- **統合管理**: 一つのシステムで完結
- **コスト削減**: 複数システムの運用コストを削減
- **ユーザー体験**: シームレスな認証体験
- **データ一貫性**: ユーザー情報の一元管理

**デメリット**：
- **複雑性**: 設定や管理が複雑
- **単一障害点**: システム停止時の影響が大きい
- **スケーラビリティ**: 負荷が集中しやすい
- **セキュリティリスク**: 攻撃対象が集中

#### 8. 実装時の注意点

**1. 役割の明確化**
```javascript
// 役割を明確に分離
const systemRoles = {
  asIdP: {
    responsibilities: ['user-authentication', 'token-issuance', 'session-management'],
    interfaces: ['oidc-endpoint', 'saml-endpoint', 'user-info-endpoint']
  },
  asSP: {
    responsibilities: ['service-provision', 'resource-access', 'business-logic'],
    interfaces: ['web-ui', 'api-gateway', 'service-endpoints']
  }
};
```

**2. セキュリティ境界**
```javascript
// セキュリティ境界の設定
const securityBoundaries = {
  authentication: {
    internalUsers: 'local-database',
    externalUsers: 'federated-idp',
    adminUsers: 'separate-realm'
  },
  authorization: {
    serviceAccess: 'role-based',
    apiAccess: 'token-based',
    adminAccess: 'mfa-required'
  }
};
```

### Keycloakでの統合的なIdP・SP提供について

#### 1. Keycloakの統合機能

**Keycloakは統合的にIdPとSPを提供することが設計思想**です。これは単なる可能性ではなく、**推奨される標準的な使用方法**です。

#### 2. Identity Brokeringとは？

**Identity Brokering**は、Keycloakの核心機能の一つで、**複数のIdPを統合して単一の認証エントリーポイントを提供**する機能です。

```
┌─────────────────┐
│   Keycloak      │
│ (Identity Broker)│
├─────────────────┤
│ 【統合IdP機能】  │
│ ・Google        │
│ ・Microsoft     │
│ ・GitHub        │
│ ・Facebook      │
│ ・LDAP          │
│ ・SAML IdP      │
│ ・内部ユーザー   │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│ 統一認証エンドポイント│
│ すべてのアプリが    │
│ ここにアクセス      │
└─────────────────┘
```

#### 3. 実際のエンタープライズ使用例

**例1: 大企業の統合認証システム**
```javascript
// 企業のKeycloakレルム設定
{
  realmName: "company-realm",
  
  // IdP機能: 複数の認証ソース統合
  identityProviders: [
    {
      alias: "internal-ldap",
      providerId: "ldap",
      config: {
        connectionUrl: "ldap://company-ldap.internal:389",
        usersDn: "ou=Users,dc=company,dc=com"
      }
    },
    {
      alias: "google-sso",
      providerId: "google",
      config: {
        clientId: "${GOOGLE_CLIENT_ID}",
        clientSecret: "${GOOGLE_CLIENT_SECRET}"
      }
    },
    {
      alias: "microsoft-ad",
      providerId: "microsoft",
      config: {
        clientId: "${MICROSOFT_CLIENT_ID}",
        clientSecret: "${MICROSOFT_CLIENT_SECRET}"
      }
    }
  ],
  
  // SP機能: 企業アプリケーションへの認証提供
  clients: [
    {
      clientId: "employee-portal",
      protocol: "openid-connect",
      redirectUris: ["https://portal.company.com/*"]
    },
    {
      clientId: "crm-system",
      protocol: "openid-connect",
      redirectUris: ["https://crm.company.com/*"]
    },
    {
      clientId: "hr-system",
      protocol: "saml",
      redirectUris: ["https://hr.company.com/saml/callback"]
    }
  ]
}
```

**例2: SaaS企業のマルチテナント認証**
```javascript
// SaaS企業のKeycloak設定
{
  // テナントA用レルム
  realmName: "tenant-a-realm",
  
  // IdP機能: 顧客企業の認証システム統合
  identityProviders: [
    {
      alias: "tenant-a-adfs",
      providerId: "saml",
      config: {
        singleSignOnServiceUrl: "https://tenant-a.com/adfs/ls",
        entityId: "https://tenant-a.com/adfs/services/trust"
      }
    },
    {
      alias: "tenant-a-okta",
      providerId: "oidc",
      config: {
        authorizationUrl: "https://tenant-a.okta.com/oauth2/v1/authorize",
        tokenUrl: "https://tenant-a.okta.com/oauth2/v1/token"
      }
    }
  ],
  
  // SP機能: 自社SaaSアプリへの認証提供
  clients: [
    {
      clientId: "saas-app-frontend",
      protocol: "openid-connect",
      publicClient: true,
      redirectUris: ["https://app.saas-company.com/*"]
    },
    {
      clientId: "saas-app-api",
      protocol: "openid-connect",
      bearerOnly: true
    }
  ]
}
```

#### 4. Keycloakの設定実例

**Admin Console での設定手順**:

1. **Identity Providers追加**
```
Realm Settings → Identity Providers → Add provider
├── Google
├── Microsoft 
├── GitHub
├── SAML v2.0
├── OpenID Connect v1.0
└── LDAP
```

2. **Client設定**
```
Clients → Create
├── Client ID: myapp-client
├── Client Protocol: openid-connect
├── Access Type: confidential
└── Valid Redirect URIs: https://myapp.com/*
```

3. **User Federation設定**
```
User Federation → Add provider
├── LDAP
├── Kerberos
└── Custom providers
```

#### 5. 認証フロー例

**統合認証フロー**:
```
1. User → MyApp: 「ログインしたい」
2. MyApp → Keycloak: 「認証してください」
3. Keycloak → User: 「認証方法を選択」
   ┌─────────────────┐
   │ 認証方法選択     │
   ├─────────────────┤
   │ □ 社内アカウント │
   │ □ Google       │
   │ □ Microsoft    │
   │ □ GitHub       │
   └─────────────────┘
4. User選択 → 対応するIdPで認証
5. IdP → Keycloak: 「認証成功」
6. Keycloak → User: 「統一トークン発行」
7. User → MyApp: 「トークンでアクセス」
```

#### 6. メリット

**1. 統一認証エクスペリエンス**
- ユーザーは常に同じ認証画面
- 認証方法を自由に選択可能
- 企業ポリシーに従った認証フロー

**2. 運用効率**
- 単一のKeycloakインスタンスで管理
- 統一されたユーザー管理
- 一元的なセキュリティポリシー

**3. 柔軟性**
- 新しいIdPの追加が簡単
- 既存システムとの統合が容易
- 段階的な移行が可能

**4. セキュリティ**
- 統一されたセキュリティポリシー
- 中央集権的な監査ログ
- 一元的なアクセス制御

#### 7. 実装時の注意点

**1. パフォーマンス考慮**
```javascript
// 接続プール設定
const keycloakConfig = {
  connectionPoolSize: 20,
  connectionTimeout: 5000,
  readTimeout: 10000,
  
  // キャッシュ設定
  cacheConfig: {
    enabled: true,
    maxEntries: 10000,
    timeToLiveSeconds: 3600
  }
};
```

**2. 高可用性設定**
```javascript
// クラスター設定
const clusterConfig = {
  clustering: {
    enabled: true,
    clusterName: "keycloak-cluster",
    nodes: [
      "keycloak-node1.company.com",
      "keycloak-node2.company.com",
      "keycloak-node3.company.com"
    ]
  },
  
  // データベース設定
  database: {
    vendor: "postgresql",
    host: "keycloak-db-cluster.company.com",
    port: 5432,
    database: "keycloak",
    connectionPool: {
      min: 5,
      max: 50
    }
  }
};
```

**3. 監視設定**
```javascript
// メトリクス設定
const monitoringConfig = {
  metrics: {
    enabled: true,
    path: "/metrics",
    format: "prometheus"
  },
  
  // ヘルスチェック
  health: {
    enabled: true,
    path: "/health",
    checks: [
      "database",
      "ldap-connection",
      "cache-status"
    ]
  }
};
```

#### 8. 実際の導入事例

**Netflix**: Keycloakを使用してマイクロサービス間の認証を統合  
**Red Hat**: 自社製品の認証基盤としてKeycloakを使用  
**BMW**: 車両管理システムの認証統合  
**Lufthansa**: 航空機整備システムの認証統合

#### 9. 結論

Keycloakでの統合的なIdP・SP提供は：
- ✅ **推奨される標準的な使用方法**
- ✅ **多くの企業で実用されている**
- ✅ **豊富な機能と柔軟性を提供**
- ✅ **運用効率とセキュリティを向上**

**このプロジェクトでもKeycloak2がその役割を果たしており、実際の企業環境でも同様のパターンが広く使用されています。**

### App2でのユーザー情報取り込み・管理の詳細

#### 1. 認証フロー後のユーザー情報取得

**Keycloak1 → Keycloak2 → App2 の情報の流れ**：

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Keycloak1     │────▶│   Keycloak2     │────▶│     App2        │
│    (IdP)        │     │   (SP/IdP)      │     │     (SP)        │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ユーザー情報      │     │ユーザー情報      │     │ユーザー情報      │
│・username       │     │・username       │     │・username       │
│・email          │     │・email          │     │・email          │
│・name           │     │・name           │     │・name           │
│・roles          │     │・roles          │     │・roles          │
│・groups         │     │・groups         │     │・groups         │
│・custom attrs   │     │・custom attrs   │     │・custom attrs   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

#### 2. ユーザー情報の取得方法

**方法1: ID Token から取得**
```javascript
// App2での認証コールバック処理
app.get('/callback', async (req, res) => {
  try {
    // 認証コード取得
    const authCode = req.query.code;
    
    // トークン交換
    const tokenResponse = await axios.post(
      'http://localhost:8180/auth/realms/sp-realm/protocol/openid-connect/token',
      {
        grant_type: 'authorization_code',
        code: authCode,
        client_id: 'app2-client',
        client_secret: process.env.APP2_CLIENT_SECRET,
        redirect_uri: 'http://localhost:3001/callback'
      }
    );
    
    // ID Tokenからユーザー情報取得
    const idToken = tokenResponse.data.id_token;
    const userInfo = jwt.decode(idToken);
    
    console.log('取得したユーザー情報:', userInfo);
    /*
    {
      "sub": "user-uuid-from-keycloak1",
      "name": "Test User",
      "email": "testuser@example.com",
      "preferred_username": "testuser",
      "given_name": "Test",
      "family_name": "User",
      "realm_access": {
        "roles": ["user", "admin"]
      },
      "groups": ["developers", "managers"],
      "custom_attributes": {
        "department": "Engineering",
        "employee_id": "E001"
      }
    }
    */
    
    // ユーザー情報をセッションまたはアプリケーションに保存
    req.session.user = userInfo;
    
    // ユーザーデータベースへの登録・更新
    await handleUserRegistration(userInfo);
    
    res.redirect('/dashboard');
  } catch (error) {
    console.error('認証エラー:', error);
    res.redirect('/login?error=auth_failed');
  }
});
```

**方法2: UserInfo エンドポイントから取得**
```javascript
// より詳細なユーザー情報が必要な場合
async function getUserInfoFromKeycloak(accessToken) {
  try {
    const response = await axios.get(
      'http://localhost:8180/auth/realms/sp-realm/protocol/openid-connect/userinfo',
      {
        headers: {
          Authorization: `Bearer ${accessToken}`
        }
      }
    );
    
    return response.data;
  } catch (error) {
    console.error('ユーザー情報取得エラー:', error);
    throw error;
  }
}
```

#### 3. ユーザー登録・更新処理

**初回ログイン時の自動ユーザー登録**：
```javascript
// ユーザー登録・更新処理
async function handleUserRegistration(userInfo) {
  try {
    // ユーザーの存在確認
    let user = await db.query(
      'SELECT * FROM users WHERE keycloak_user_id = $1',
      [userInfo.sub]
    );
    
    if (user.rows.length === 0) {
      // 新規ユーザー登録
      console.log('新規ユーザーを登録:', userInfo.email);
      
      user = await db.query(`
        INSERT INTO users (
          keycloak_user_id,
          username,
          email,
          first_name,
          last_name,
          full_name,
          is_active,
          created_at,
          updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
        RETURNING *
      `, [
        userInfo.sub,
        userInfo.preferred_username,
        userInfo.email,
        userInfo.given_name,
        userInfo.family_name,
        userInfo.name,
        true
      ]);
      
      // ユーザーロールの設定
      await assignUserRoles(user.rows[0].id, userInfo.realm_access.roles);
      
      // ユーザーグループの設定
      await assignUserGroups(user.rows[0].id, userInfo.groups);
      
      // カスタム属性の保存
      await saveCustomAttributes(user.rows[0].id, userInfo.custom_attributes);
      
      // ウェルカムメール送信
      await sendWelcomeEmail(userInfo.email, userInfo.name);
      
    } else {
      // 既存ユーザー更新
      console.log('既存ユーザーを更新:', userInfo.email);
      
      await db.query(`
        UPDATE users SET
          username = $2,
          email = $3,
          first_name = $4,
          last_name = $5,
          full_name = $6,
          last_login = NOW(),
          updated_at = NOW()
        WHERE keycloak_user_id = $1
      `, [
        userInfo.sub,
        userInfo.preferred_username,
        userInfo.email,
        userInfo.given_name,
        userInfo.family_name,
        userInfo.name
      ]);
      
      // ロールとグループの更新
      await updateUserRoles(user.rows[0].id, userInfo.realm_access.roles);
      await updateUserGroups(user.rows[0].id, userInfo.groups);
      await updateCustomAttributes(user.rows[0].id, userInfo.custom_attributes);
    }
    
    return user.rows[0];
  } catch (error) {
    console.error('ユーザー登録・更新エラー:', error);
    throw error;
  }
}
```

#### 4. データベース設計

**ユーザー管理テーブル**：
```sql
-- メインユーザーテーブル
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  keycloak_user_id VARCHAR(255) UNIQUE NOT NULL, -- Keycloak1からのユーザーID
  username VARCHAR(100) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  full_name VARCHAR(200),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP
);

-- ユーザーロールテーブル
CREATE TABLE user_roles (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  role_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, role_name)
);

-- ユーザーグループテーブル
CREATE TABLE user_groups (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  group_name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, group_name)
);

-- カスタム属性テーブル
CREATE TABLE user_attributes (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  attribute_name VARCHAR(100) NOT NULL,
  attribute_value TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, attribute_name)
);

-- ユーザープロファイルテーブル（アプリ固有の情報）
CREATE TABLE user_profiles (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
  avatar_url VARCHAR(500),
  bio TEXT,
  preferences JSONB DEFAULT '{}',
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 5. 属性マッピング設定

**Keycloak2での属性マッピング**：
```javascript
// Keycloak2 Admin API を使用した属性マッピング設定
const mapperConfig = {
  name: "custom-attribute-mapper",
  protocol: "openid-connect",
  protocolMapper: "oidc-usermodel-attribute-mapper",
  config: {
    "user.attribute": "department",
    "claim.name": "department",
    "jsonType.label": "String",
    "id.token.claim": "true",
    "access.token.claim": "true",
    "userinfo.token.claim": "true"
  }
};

// Identity Provider からの属性マッピング
const identityProviderMapper = {
  name: "keycloak1-email-mapper",
  identityProviderAlias: "keycloak1-oidc",
  identityProviderMapper: "oidc-user-attribute-idp-mapper",
  config: {
    "claim": "email",
    "user.attribute": "email"
  }
};
```

#### 6. ユーザー情報の利用例

**ロールベースのアクセス制御**：
```javascript
// ミドルウェアでのロールチェック
function requireRole(requiredRoles) {
  return async (req, res, next) => {
    if (!req.session.user) {
      return res.redirect('/login');
    }
    
    const user = await db.query(
      'SELECT * FROM users WHERE keycloak_user_id = $1',
      [req.session.user.sub]
    );
    
    if (user.rows.length === 0) {
      return res.status(403).json({ error: 'ユーザーが見つかりません' });
    }
    
    const userRoles = await db.query(
      'SELECT role_name FROM user_roles WHERE user_id = $1',
      [user.rows[0].id]
    );
    
    const hasRequiredRole = requiredRoles.some(role => 
      userRoles.rows.some(ur => ur.role_name === role)
    );
    
    if (!hasRequiredRole) {
      return res.status(403).json({ error: '権限がありません' });
    }
    
    req.user = user.rows[0];
    next();
  };
}

// 使用例
app.get('/admin/users', requireRole(['admin']), async (req, res) => {
  // 管理者のみアクセス可能
  const users = await db.query('SELECT * FROM users');
  res.json(users.rows);
});
```

**パーソナライズされたコンテンツ**：
```javascript
// ユーザー情報に基づいたコンテンツ表示
app.get('/dashboard', async (req, res) => {
  if (!req.session.user) {
    return res.redirect('/login');
  }
  
  const user = await db.query(`
    SELECT u.*, up.preferences, up.settings
    FROM users u
    LEFT JOIN user_profiles up ON u.id = up.user_id
    WHERE u.keycloak_user_id = $1
  `, [req.session.user.sub]);
  
  if (user.rows.length === 0) {
    return res.redirect('/login');
  }
  
  const userData = user.rows[0];
  
  // ユーザーの部署に基づいた情報取得
  const departmentNews = await getDepartmentNews(userData.department);
  
  // ユーザーのロールに基づいた機能表示
  const userRoles = await getUserRoles(userData.id);
  const availableFeatures = getAvailableFeatures(userRoles);
  
  res.render('dashboard', {
    user: userData,
    departmentNews,
    availableFeatures,
    preferences: userData.preferences || {}
  });
});
```

#### 7. トークンリフレッシュと同期

**トークンリフレッシュ機能**：
```javascript
// トークンリフレッシュ機能
async function refreshTokenAndSyncUser(refreshToken) {
  try {
    const tokenResponse = await axios.post(
      'http://localhost:8180/auth/realms/sp-realm/protocol/openid-connect/token',
      {
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
        client_id: 'app2-client',
        client_secret: process.env.APP2_CLIENT_SECRET
      }
    );
    
    const newIdToken = tokenResponse.data.id_token;
    const userInfo = jwt.decode(newIdToken);
    
    // ユーザー情報を最新に更新
    await handleUserRegistration(userInfo);
    
    return {
      accessToken: tokenResponse.data.access_token,
      refreshToken: tokenResponse.data.refresh_token,
      userInfo
    };
  } catch (error) {
    console.error('トークンリフレッシュエラー:', error);
    throw error;
  }
}
```

#### 8. セキュリティ考慮事項

**データの検証と sanitization**：
```javascript
// ユーザー入力の検証
const { body, validationResult } = require('express-validator');

const validateUserRegistration = [
  body('email').isEmail().normalizeEmail(),
  body('username').isLength({ min: 3, max: 50 }).trim(),
  body('first_name').optional().isLength({ max: 100 }).trim(),
  body('last_name').optional().isLength({ max: 100 }).trim(),
  
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  }
];
```

**監査ログ**：
```javascript
// ユーザー操作の監査ログ
async function logUserActivity(userId, action, details) {
  await db.query(`
    INSERT INTO audit_logs (
      user_id,
      action,
      details,
      ip_address,
      user_agent,
      timestamp
    ) VALUES ($1, $2, $3, $4, $5, NOW())
  `, [userId, action, JSON.stringify(details), req.ip, req.headers['user-agent']]);
}
```

このように、App2では認証成功後に受け取ったユーザー情報を基に、自社サービス用のユーザー管理システムを構築し、パーソナライズされたサービスを提供することができます。

### 【重要】事前ユーザー登録は不要！自動ユーザー登録の仕組み

#### 1. 事前登録が不要な理由

**App2には事前にユーザーを登録する必要がありません**。これはSSO（Single Sign-On）の大きなメリットです。

```
【従来の方法】
1. App2にユーザー登録 ←── 事前作業が必要
2. App2でログイン
3. サービス利用

【SSO（このプロジェクト）】
1. App2にアクセス
2. 自動的にKeycloak1で認証
3. 初回ログイン時に自動でユーザー登録 ←── 自動！
4. サービス利用
```

#### 2. 自動ユーザー登録の仕組み

**Keycloak2の「First Login Flow」機能**を使用します：

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   新規ユーザー   │────▶│   Keycloak1     │────▶│   Keycloak2     │
│  (未登録)       │     │     (IdP)       │     │   (SP/IdP)      │
└─────────────────┘     │   認証成功       │     │                 │
                        └─────────────────┘     │ 1. ユーザー存在？│
                                               │    → いいえ      │
                                               │                 │
                                               │ 2. 自動ユーザー  │
                                               │    作成実行      │
                                               └─────────────────┘
                                                        │
                                                        ▼
                                               ┌─────────────────┐
                                               │     App2        │
                                               │  新規ユーザー    │
                                               │  として認識      │
                                               └─────────────────┘
```

#### 3. 実際の動作例

**初回ログイン時の処理**：
```javascript
// App2での認証コールバック処理
app.get('/callback', async (req, res) => {
  const userInfo = jwt.decode(req.body.id_token);
  
  // 既存ユーザーの確認
  let user = await db.query(
    'SELECT * FROM users WHERE keycloak_user_id = $1',
    [userInfo.sub]
  );
  
  if (user.rows.length === 0) {
    // 🎉 新規ユーザーを自動作成！
    console.log('新規ユーザーを自動登録:', userInfo.email);
    
    user = await db.query(`
      INSERT INTO users (
        keycloak_user_id,
        username,
        email,
        first_name,
        last_name,
        created_at
      ) VALUES ($1, $2, $3, $4, $5, NOW())
      RETURNING *
    `, [
      userInfo.sub,
      userInfo.preferred_username,
      userInfo.email,
      userInfo.given_name,
      userInfo.family_name
    ]);
    
    // 初回ログイン時の特別処理
    await setupNewUserDefaults(user.rows[0].id);
    await sendWelcomeEmail(userInfo.email);
  }
  
  req.session.user = userInfo;
  res.redirect('/dashboard');
});
```

#### 4. Keycloak2の設定

**Identity Provider設定で「First Login Flow」を有効化**：

```javascript
// Keycloak2 Admin APIでの設定
const identityProviderConfig = {
  alias: "keycloak1-oidc",
  providerId: "oidc",
  enabled: true,
  
  // 🔑 重要な設定
  config: {
    "syncMode": "IMPORT",           // ユーザー情報を取り込み
    "createUser": "true",           // ユーザー自動作成
    "updateProfileFirstLogin": "true", // プロファイル更新
    "trustEmail": "true",           // メール検証不要
    "storeToken": "true",           // トークン保存
    
    // 認証情報
    "authorizationUrl": "http://localhost:8080/auth/realms/idp-realm/protocol/openid-connect/auth",
    "tokenUrl": "http://localhost:8080/auth/realms/idp-realm/protocol/openid-connect/token",
    "clientId": "keycloak2-broker",
    "clientSecret": "${CLIENT_SECRET}"
  }
};
```

#### 5. 実際のUser Journey

**新規ユーザー「田中太郎」の例**：

```
Day 1: 田中太郎がApp2を初めて使用
├── 1. https://app2.example.com にアクセス
├── 2. 「ログインが必要です」→ Keycloak2にリダイレクト
├── 3. Keycloak2が「認証が必要です」→ Keycloak1にリダイレクト
├── 4. 田中太郎がKeycloak1でログイン（既存のアカウント）
├── 5. Keycloak1が「認証成功」→ Keycloak2にユーザー情報送信
├── 6. Keycloak2が「新規ユーザー検出」→ 自動でユーザー作成
│   ├── username: "tanaka.taro"
│   ├── email: "tanaka.taro@company.com"
│   ├── name: "田中太郎"
│   └── created_at: "2024-01-01 09:00:00"
├── 7. App2が「新規ユーザー」→ 自動でローカルユーザー作成
│   ├── デフォルトロール設定
│   ├── ウェルカムメール送信
│   └── 初回設定ガイド表示
└── 8. 田中太郎がApp2を問題なく利用開始！

Day 2以降: 田中太郎がApp2を使用
├── 1. https://app2.example.com にアクセス
├── 2. 既存ユーザーとして認識
├── 3. 通常の認証フロー
└── 4. 前回の設定・データが保持されている
```

#### 6. 管理者の作業

**管理者が行う作業**：
```
✅ 事前作業（1回のみ）
├── Keycloak1でユーザー作成（社員アカウント）
├── Keycloak2でIdentity Provider設定
└── App2でデータベース準備

❌ 不要な作業
├── App2への個別ユーザー登録
├── ユーザー毎の設定作業
└── 手動でのアカウント紐付け
```

#### 7. 一括ユーザー登録の場合

**HR部門が新入社員を一括登録する例**：

```javascript
// 新入社員の一括登録（Keycloak1のみ）
async function bulkRegisterNewEmployees(employeesCsv) {
  const employees = parseCsv(employeesCsv);
  
  for (const employee of employees) {
    // Keycloak1にユーザー作成
    await keycloak1Admin.createUser({
      username: employee.username,
      email: employee.email,
      firstName: employee.firstName,
      lastName: employee.lastName,
      enabled: true,
      attributes: {
        department: employee.department,
        employeeId: employee.employeeId,
        startDate: employee.startDate
      }
    });
    
    // App2には何もしない！
    // 新入社員が初回ログイン時に自動作成される
  }
  
  console.log(`${employees.length}名の新入社員をKeycloak1に登録完了`);
  console.log('App2への登録は初回ログイン時に自動実行されます');
}
```

#### 8. メリット・デメリット

**メリット**：
- ✅ **運用負荷軽減**: 管理者の作業が大幅に削減
- ✅ **ユーザー体験向上**: 即座にサービス利用開始
- ✅ **データ整合性**: 常に最新のユーザー情報を自動取得
- ✅ **スケーラビリティ**: 新しいアプリを追加してもユーザー登録不要
- ✅ **セキュリティ**: 中央集権的な認証管理

**デメリット**：
- ❌ **初回ログイン時の処理時間**: 若干の遅延が発生
- ❌ **属性マッピング設定**: 正確な設定が必要
- ❌ **エラーハンドリング**: 自動処理の失敗時対応が重要

#### 9. 実装上の注意点

**必須設定**：
```javascript
// 1. Keycloak2でのFirst Login Flow設定
const firstLoginFlowConfig = {
  "First Login Flow": "first broker login",
  "Post Login Flow": "browser",
  "Sync Mode": "IMPORT",
  "Create User": true,
  "Update Profile First Login": true,
  "Trust Email": true
};

// 2. App2でのエラーハンドリング
async function handleFirstLogin(userInfo) {
  try {
    // 自動ユーザー作成
    await createUserAccount(userInfo);
    
    // 初回設定
    await setupUserDefaults(userInfo.sub);
    
    // 成功ログ
    auditLog.info('新規ユーザー自動作成成功', { 
      userId: userInfo.sub,
      email: userInfo.email 
    });
    
  } catch (error) {
    // エラーログ
    auditLog.error('新規ユーザー自動作成失敗', { 
      error: error.message,
      userId: userInfo.sub 
    });
    
    // フォールバック処理
    await handleUserCreationFailure(userInfo);
  }
}
```

#### 10. 確認方法

**動作確認手順**：
1. App2のデータベースを確認 → ユーザーテーブルが空
2. 新規ユーザーでApp2にアクセス
3. 自動的にKeycloak1で認証
4. App2のデータベースを確認 → ユーザーが自動作成されている
5. 同じユーザーで再度アクセス → 既存ユーザーとして認識

**このように、SSO環境では事前のユーザー登録は不要で、初回ログイン時に自動的にユーザー情報が作成・同期されます！**

### レルム（Realm）とは？

#### 1. レルムの基本概念
レルムは、Keycloakにおける**独立した認証・認可の管理単位**です。わかりやすく例えると：

- **アパートの建物** = Keycloakサーバー
- **各部屋** = レルム
- **部屋の住人** = ユーザー
- **部屋の鍵** = 認証情報

それぞれの部屋（レルム）は完全に独立していて、別の部屋の住人（ユーザー）は入ることができません。

#### 2. レルムが管理するもの
```
レルム（例：company-realm）
├── ユーザー（社員アカウント）
│   ├── user1@company.com
│   ├── user2@company.com
│   └── admin@company.com
├── グループ（部署）
│   ├── 営業部
│   ├── 開発部
│   └── 管理部
├── ロール（権限）
│   ├── admin（管理者）
│   ├── user（一般ユーザー）
│   └── viewer（閲覧のみ）
├── クライアント（連携アプリ）
│   ├── 社内ポータル
│   ├── 勤怠管理システム
│   └── 経費精算システム
└── 認証設定
    ├── パスワードポリシー
    ├── 2要素認証設定
    └── セッションタイムアウト
```

#### 3. なぜレルムが必要？
1. **データの分離**: 会社Aのユーザーと会社Bのユーザーを完全に分離
2. **設定の独立性**: 会社ごとに異なるセキュリティポリシーを適用
3. **管理の簡素化**: 各テナントの管理者が自分のレルムだけを管理

### マルチテナントとは？

#### 1. シングルテナント vs マルチテナント
```
【シングルテナント】
┌─────────────────┐
│   会社A専用     │
│   Keycloak      │
│   サーバー      │
└─────────────────┘

【マルチテナント】
┌─────────────────┐
│   共有Keycloak  │
├─────────────────┤
│ 会社A用レルム   │
├─────────────────┤
│ 会社B用レルム   │
├─────────────────┤
│ 会社C用レルム   │
└─────────────────┘
```

#### 2. マルチテナントのメリット
- **コスト削減**: 1つのサーバーで複数の顧客に対応
- **運用効率化**: アップデートや保守を一括実施
- **リソース共有**: サーバーリソースを効率的に利用

### マルチテナントSSO認証の詳細実装

#### 1. テナント識別方法

**方法1: サブドメイン方式**
```
company-a.app.example.com → 会社Aのレルム
company-b.app.example.com → 会社Bのレルム

実装例（Node.js）:
app.use((req, res, next) => {
  const subdomain = req.hostname.split('.')[0];
  req.tenantId = subdomain; // company-a
  req.realmName = `${subdomain}-realm`; // company-a-realm
  next();
});
```

**方法2: パスベース方式**
```
app.example.com/company-a → 会社Aのレルム
app.example.com/company-b → 会社Bのレルム

実装例:
app.use('/:tenant/*', (req, res, next) => {
  req.tenantId = req.params.tenant;
  req.realmName = `${req.params.tenant}-realm`;
  next();
});
```

**方法3: カスタムドメイン方式**
```
app.company-a.com → 会社Aのレルム
portal.company-b.jp → 会社Bのレルム

実装例（ドメインマッピングテーブル）:
const domainMapping = {
  'app.company-a.com': 'company-a-realm',
  'portal.company-b.jp': 'company-b-realm'
};
```

#### 2. 動的なKeycloak設定

```javascript
// テナントごとのKeycloak設定を動的に生成
function getKeycloakConfig(tenantId) {
  return {
    realm: `${tenantId}-realm`,
    authServerUrl: 'http://localhost:8080/auth',
    clientId: `${tenantId}-app-client`,
    clientSecret: process.env[`${tenantId.toUpperCase()}_CLIENT_SECRET`],
    redirectUri: `https://${tenantId}.app.example.com/callback`
  };
}

// ミドルウェアでテナント別設定を適用
app.use((req, res, next) => {
  const config = getKeycloakConfig(req.tenantId);
  req.keycloakConfig = config;
  next();
});
```

#### 3. テナント管理API

```javascript
// テナント作成API
app.post('/api/tenants', async (req, res) => {
  const { tenantId, companyName, adminEmail } = req.body;
  
  // 1. 新しいレルムを作成
  const realm = await keycloakAdmin.createRealm({
    realm: `${tenantId}-realm`,
    displayName: companyName,
    enabled: true,
    loginTheme: 'custom-theme',
    emailTheme: 'custom-email'
  });
  
  // 2. デフォルトロールを作成
  await keycloakAdmin.createRole(realm, {
    name: 'admin',
    description: 'テナント管理者'
  });
  
  await keycloakAdmin.createRole(realm, {
    name: 'user',
    description: '一般ユーザー'
  });
  
  // 3. 管理者ユーザーを作成
  await keycloakAdmin.createUser(realm, {
    username: adminEmail,
    email: adminEmail,
    emailVerified: true,
    enabled: true,
    realmRoles: ['admin']
  });
  
  // 4. クライアント（アプリ）を登録
  await keycloakAdmin.createClient(realm, {
    clientId: `${tenantId}-app-client`,
    protocol: 'openid-connect',
    publicClient: false,
    redirectUris: [
      `https://${tenantId}.app.example.com/*`
    ]
  });
  
  res.json({ success: true, realmId: realm.id });
});
```

#### 4. データベース設計

```sql
-- テナント管理テーブル
CREATE TABLE tenants (
  id UUID PRIMARY KEY,
  tenant_id VARCHAR(50) UNIQUE NOT NULL,
  company_name VARCHAR(200) NOT NULL,
  realm_name VARCHAR(100) NOT NULL,
  subdomain VARCHAR(50),
  custom_domain VARCHAR(200),
  status VARCHAR(20) DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  settings JSONB DEFAULT '{}'
);

-- テナント別の設定
CREATE TABLE tenant_settings (
  tenant_id UUID REFERENCES tenants(id),
  key VARCHAR(100),
  value TEXT,
  PRIMARY KEY (tenant_id, key)
);

-- カスタムテーマ設定
CREATE TABLE tenant_themes (
  tenant_id UUID REFERENCES tenants(id),
  logo_url VARCHAR(500),
  primary_color VARCHAR(7),
  secondary_color VARCHAR(7),
  custom_css TEXT
);
```

#### 5. セキュリティ考慮事項

**1. テナント間のデータ分離**
```javascript
// 常にテナントIDでフィルタリング
app.get('/api/users', authenticate, async (req, res) => {
  const users = await db.query(
    'SELECT * FROM users WHERE tenant_id = $1',
    [req.user.tenantId]
  );
  res.json(users);
});
```

**2. クロステナントアクセス防止**
```javascript
// テナントIDの検証ミドルウェア
function validateTenant(req, res, next) {
  if (req.user.tenantId !== req.params.tenantId) {
    return res.status(403).json({ 
      error: '他のテナントへのアクセスは禁止されています' 
    });
  }
  next();
}
```

**3. レート制限**
```javascript
// テナント別レート制限
const rateLimiter = new RateLimiter({
  keyGenerator: (req) => `${req.tenantId}:${req.ip}`,
  max: 100, // 1時間あたり100リクエスト
  windowMs: 60 * 60 * 1000
});
```

#### 6. テナント別カスタマイズ

**ブランディング設定**
```javascript
// テナント別のUI設定を取得
app.get('/api/branding', async (req, res) => {
  const branding = await db.query(
    'SELECT * FROM tenant_themes WHERE tenant_id = $1',
    [req.tenantId]
  );
  
  res.json({
    logoUrl: branding.logo_url || '/default-logo.png',
    theme: {
      primaryColor: branding.primary_color || '#007bff',
      secondaryColor: branding.secondary_color || '#6c757d'
    },
    customCss: branding.custom_css
  });
});
```

**認証ポリシー設定**
```javascript
// テナント別の認証ルール
const authPolicies = {
  'enterprise-tenant': {
    passwordMinLength: 12,
    requireMFA: true,
    sessionTimeout: 30 * 60 * 1000, // 30分
    allowedDomains: ['@company.com']
  },
  'basic-tenant': {
    passwordMinLength: 8,
    requireMFA: false,
    sessionTimeout: 24 * 60 * 60 * 1000, // 24時間
    allowedDomains: [] // 制限なし
  }
};
```

#### 7. 運用・監視

**テナント別メトリクス**
```javascript
// Prometheusメトリクス例
const loginCounter = new Counter({
  name: 'tenant_login_total',
  help: 'Total number of logins per tenant',
  labelNames: ['tenant_id', 'status']
});

// ログイン時にメトリクスを記録
loginCounter.inc({ 
  tenant_id: req.tenantId, 
  status: 'success' 
});
```

**監査ログ**
```javascript
// テナント別の監査ログ
function auditLog(tenantId, userId, action, details) {
  logger.info({
    timestamp: new Date().toISOString(),
    tenantId,
    userId,
    action,
    details,
    ip: req.ip,
    userAgent: req.headers['user-agent']
  });
}
```

### まとめ
マルチテナントSSO実装では、レルムを使ってテナントを分離し、動的な設定管理、セキュリティ、カスタマイズ性を確保することが重要です。

### アーキテクチャ

#### 1. システム全体構成
```
┌─────────────────┐     1. 直接認証    ┌─────────────────┐
│   App1 (3000)   │ ──────────────────► │ Keycloak1 (8080)│
│      (SP)       │                     │     (IdP)       │
└─────────────────┘                     │  ・ユーザー管理  │
                                        │  ・認証処理     │
                                        │  ・トークン発行  │
                                        └─────────────────┘
                                                 ▲
                                                 │ 3. 認証委託
                                                 │   (OIDC/SAML)
┌─────────────────┐     2. SSO認証              │
│   App2 (3001)   │ ──────────────► ┌─────────────────┐
│      (SP)       │                  │ Keycloak2 (8180)│
└─────────────────┘                  │  (IdP/SP両方)   │
                                     │  ・認証仲介     │
                                     │  ・IdPへ委託    │
                                     └─────────────────┘
```

#### 2. 認証フロー詳細
```
【App1 → Keycloak1 (直接認証)】
User → App1 → Keycloak1 (IdP) → App1 → User
      ①請求  ②認証要求  ③認証  ④トークン  ⑤サービス提供

【App2 → Keycloak2 → Keycloak1 (SSO認証)】
User → App2 → Keycloak2 → Keycloak1 → Keycloak2 → App2 → User
      ①請求  ②認証要求   ③認証委託  ④認証   ⑤トークン  ⑥トークン ⑦サービス提供
             (SP)      (SP)      (IdP)     (IdP)     (SP)
```

#### 3. 役割分担
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   App1/App2     │     │   Keycloak2     │     │   Keycloak1     │
│      (SP)       │     │   (IdP/SP)      │     │     (IdP)       │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│・サービス提供   │     │・認証仲介       │     │・ユーザー管理   │
│・ユーザー管理   │     │・トークン発行   │     │・認証処理       │
│・認証委託       │     │・認証委託       │     │・セッション管理 │
│・アクセス制御   │     │・ID変換         │     │・パスワード検証 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
       ↑                        ↑                        ↑
   ビジネスロジック           認証ブローカー          認証基盤
```

#### 4. データフロー
```
┌─────────────────┐
│   User          │
│   ・ユーザー名   │
│   ・パスワード   │
└─────────────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   App2 (SP)     │────▶│ Keycloak2 (SP)  │────▶│ Keycloak1 (IdP) │
│   認証要求      │     │   認証委託      │     │   認証処理      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         ▲                        ▲                        │
         │                        │                        ▼
         │                        │               ┌─────────────────┐
         │                        │               │  認証結果       │
         │                        │               │  ・Access Token │
         │                        │               │  ・ID Token     │
         │                        │               │  ・User Info    │
         │                        │               └─────────────────┘
         │                        │                        │
         │                        │◄───────────────────────┘
         │                        │
         │               ┌─────────────────┐
         │               │  変換・発行     │
         │               │  ・新トークン   │
         │               │  ・属性マッピング│
         │               └─────────────────┘
         │                        │
         │◄───────────────────────┘
         │
┌─────────────────┐
│  サービス提供   │
│  ・ユーザー情報 │
│  ・アクセス制御 │
└─────────────────┘
```

## 詳細実装計画

### Phase 1: 環境構築
#### 1.1 Docker Compose設定
- **Keycloak1 (IdP)**
  - ポート: 8080
  - 管理者: admin/admin
  - データベース: PostgreSQL (54321)
  
- **Keycloak2 (SP)**
  - ポート: 8180
  - 管理者: admin/admin
  - データベース: PostgreSQL (54322)

#### 1.2 ディレクトリ構造
```
practice-sso-login/
├── docker-compose.yml
├── keycloak1/
│   ├── themes/
│   └── realm-export.json
├── keycloak2/
│   ├── themes/
│   └── realm-export.json
├── app1/
│   ├── package.json
│   ├── server.js
│   └── views/
├── app2/
│   ├── package.json
│   ├── server.js
│   └── views/
└── scripts/
    ├── setup-keycloak.sh
    └── test-sso.sh
```

### Phase 2: Keycloak設定

#### 2.1 Keycloak1 (IdP) の設定
1. **レルム作成**
   - レルム名: `idp-realm`
   - ログインテーマ: カスタマイズ可能

2. **ユーザー作成**
   - ユーザー名: `testuser`
   - メール: `testuser@example.com`
   - パスワード: `password123`
   - 追加ユーザー: `admin`, `developer`

3. **クライアント設定**
   - クライアントID: `app1-client`
   - クライアントプロトコル: `openid-connect`
   - アクセスタイプ: `confidential`
   - 有効なリダイレクトURI: `http://localhost:3000/*`
   
4. **OIDC設定**
   - クライアントID: `keycloak2-broker`
   - シークレット: 自動生成
   - リダイレクトURI: `http://localhost:8180/auth/realms/sp-realm/broker/keycloak1-oidc/endpoint`

#### 2.2 Keycloak2 (SP) の設定
1. **レルム作成**
   - レルム名: `sp-realm`

2. **Identity Provider設定**
   - プロバイダー: `OpenID Connect v1.0`
   - エイリアス: `keycloak1-oidc`
   - 認証URL: `http://localhost:8080/auth/realms/idp-realm/protocol/openid-connect/auth`
   - トークンURL: `http://localhost:8080/auth/realms/idp-realm/protocol/openid-connect/token`
   - クライアントID: `keycloak2-broker`
   - クライアントシークレット: Keycloak1で生成されたもの

3. **クライアント設定**
   - クライアントID: `app2-client`
   - アクセスタイプ: `confidential`
   - リダイレクトURI: `http://localhost:3001/*`

4. **First Login Flow設定**
   - 自動ユーザー作成: 有効
   - 信頼されたメール: 有効

### Phase 3: サンプルアプリケーション実装

#### 3.1 App1 (Keycloak1直接認証)
**技術スタック**: Node.js + Express + Passport.js

**主要機能**:
- `/`: ホームページ（未認証時はログインボタン表示）
- `/login`: Keycloak1へのリダイレクト
- `/callback`: 認証後のコールバック処理
- `/profile`: ユーザー情報表示
- `/logout`: ログアウト処理

**実装詳細**:
```javascript
// passport-keycloak-oauth2設定
{
  clientID: 'app1-client',
  realm: 'idp-realm',
  publicClient: false,
  clientSecret: process.env.APP1_CLIENT_SECRET,
  sslRequired: 'none',
  authServerURL: 'http://localhost:8080/auth'
}
```

#### 3.2 App2 (Keycloak2経由SSO)
**主要機能**:
- `/`: ホームページ
- `/login`: Keycloak2へのリダイレクト（自動的にKeycloak1へ）
- `/callback`: 認証後のコールバック
- `/profile`: ユーザー情報表示（SSO経由）
- `/token-info`: トークン情報の表示

### Phase 4: SSO連携フロー

#### 4.1 OIDC認証フロー詳細
1. **初回アクセス**
   ```
   User → App2 (GET /)
   App2 → User (302 Redirect to Keycloak2)
   ```

2. **Keycloak2での認証要求**
   ```
   User → Keycloak2 (GET /auth/realms/sp-realm/protocol/openid-connect/auth)
   パラメータ:
   - client_id=app2-client
   - redirect_uri=http://localhost:3001/callback
   - response_type=code
   - scope=openid profile email
   - state=<random_string>
   ```

3. **IdPへのリダイレクト**
   ```
   Keycloak2 → User (302 Redirect to Keycloak1)
   User → Keycloak1 (GET /auth/realms/idp-realm/protocol/openid-connect/auth)
   パラメータ:
   - client_id=keycloak2-broker
   - redirect_uri=http://localhost:8180/auth/realms/sp-realm/broker/keycloak1-oidc/endpoint
   - response_type=code
   - scope=openid profile email
   - state=<broker_state>
   ```

4. **ユーザー認証**
   ```
   User → Keycloak1 (POST /auth/realms/idp-realm/login-actions/authenticate)
   Body: username=testuser&password=password123
   Keycloak1 → User (302 Redirect with authorization code)
   ```

5. **トークン交換（Keycloak1 → Keycloak2）**
   ```
   Keycloak2 → Keycloak1 (POST /auth/realms/idp-realm/protocol/openid-connect/token)
   Body:
   - grant_type=authorization_code
   - code=<auth_code>
   - client_id=keycloak2-broker
   - client_secret=<secret>
   
   Response:
   {
     "access_token": "eyJhbGciOiJSUzI1NiIs...",
     "id_token": "eyJhbGciOiJSUzI1NiIs...",
     "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
     "token_type": "Bearer",
     "expires_in": 300
   }
   ```

6. **トークン交換（Keycloak2 → App2）**
   ```
   App2 → Keycloak2 (POST /auth/realms/sp-realm/protocol/openid-connect/token)
   Body:
   - grant_type=authorization_code
   - code=<auth_code_from_keycloak2>
   - client_id=app2-client
   - client_secret=<app2_secret>
   
   Response: JWT tokens
   ```

7. **ユーザー情報取得**
   ```
   App2 → Keycloak2 (GET /auth/realms/sp-realm/protocol/openid-connect/userinfo)
   Headers: Authorization: Bearer <access_token>
   
   Response:
   {
     "sub": "user-id",
     "name": "Test User",
     "email": "testuser@example.com",
     "preferred_username": "testuser"
   }
   ```

#### 4.2 SAML2.0認証フロー詳細
1. **SAML AuthnRequest**
   ```xml
   <samlp:AuthnRequest 
     xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
     ID="_8e8dc5f69a98cc4c1ff3427e5ce34606fd672f91e6"
     Version="2.0"
     IssueInstant="2024-01-01T00:00:00Z"
     Destination="http://localhost:8080/auth/realms/idp-realm/protocol/saml"
     AssertionConsumerServiceURL="http://localhost:8180/auth/realms/sp-realm/broker/keycloak1-saml/endpoint">
     <saml:Issuer>keycloak2-saml</saml:Issuer>
   </samlp:AuthnRequest>
   ```

2. **SAML Response**
   ```xml
   <samlp:Response
     xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"
     ID="_8e8dc5f69a98cc4c1ff3427e5ce34606fd672f91e7"
     InResponseTo="_8e8dc5f69a98cc4c1ff3427e5ce34606fd672f91e6">
     <saml:Assertion>
       <saml:Subject>
         <saml:NameID Format="urn:oasis:names:tc:SAML:2.0:nameid-format:persistent">
           testuser
         </saml:NameID>
       </saml:Subject>
       <saml:AttributeStatement>
         <saml:Attribute Name="email">
           <saml:AttributeValue>testuser@example.com</saml:AttributeValue>
         </saml:Attribute>
       </saml:AttributeStatement>
     </saml:Assertion>
   </samlp:Response>
   ```

#### 4.3 セッション管理
- **セッション同期**: Keycloak1でのログアウト時、全アプリケーションからログアウト
- **トークンリフレッシュ**: 自動リフレッシュ実装
- **セッションタイムアウト**: 30分（設定可能）

### Phase 5: セキュリティ設定

#### 5.1 HTTPS設定（本番環境）
- Let's Encrypt証明書の設定
- nginx リバースプロキシ設定

#### 5.2 CORS設定
```javascript
{
  origin: ['http://localhost:3000', 'http://localhost:3001'],
  credentials: true
}
```

#### 5.3 セキュリティヘッダー
- Content-Security-Policy
- X-Frame-Options
- X-Content-Type-Options

### Phase 6: テストと検証

#### 6.1 機能テスト
1. **基本認証フロー**
   - App1での直接ログイン
   - App2でのSSO経由ログイン
   - ログイン状態でのアプリ間遷移

2. **エッジケース**
   - セッションタイムアウト
   - 同時ログイン
   - ブラウザバック時の動作

#### 6.2 パフォーマンステスト
- 認証レスポンスタイム測定
- 同時接続数テスト

### Phase 7: 監視とログ

#### 7.1 ログ設定
- Keycloakイベントログ
- アプリケーションアクセスログ
- エラーログ

#### 7.2 メトリクス
- ログイン成功/失敗率
- レスポンスタイム
- アクティブセッション数

## 実行手順

### 1. 環境起動
```bash
docker-compose up -d
```

### 2. Keycloak初期設定
```bash
./scripts/setup-keycloak.sh
```

### 3. アプリケーション起動
```bash
# App1
cd app1 && npm install && npm start

# App2 (別ターミナル)
cd app2 && npm install && npm start
```

### 4. 動作確認
1. http://localhost:3000 にアクセス（App1）
2. ログインしてユーザー情報確認
3. http://localhost:3001 にアクセス（App2）
4. 自動的にログイン済み状態になることを確認

## トラブルシューティング

### よくある問題
1. **Keycloak起動エラー**
   - ポート競合確認: `lsof -i :8080`
   - Dockerログ確認: `docker logs keycloak1`

2. **SSO認証失敗**
   - リダイレクトURI設定確認
   - クライアントシークレット確認
   - ネットワーク接続確認

3. **セッション不整合**
   - ブラウザキャッシュクリア
   - Keycloakセッション確認

## 参考資料
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [OpenID Connect仕様](https://openid.net/connect/)
- [OAuth 2.0](https://oauth.net/2/)

## 拡張実装計画

### Phase 8: マルチテナント対応

#### 8.1 アーキテクチャ変更
```
┌─────────────────┐
│   テナントA     │
│  ┌──────────┐  │     ┌─────────────────┐
│  │  App1-A   │──┼────▶│                 │
│  └──────────┘  │     │   Keycloak1     │
│  ┌──────────┐  │     │  (Multi-IdP)    │
│  │  App2-A   │──┼────▶│                 │
│  └──────────┘  │     │  ├─ Realm-A    │
└─────────────────┘     │  ├─ Realm-B    │
                        │  └─ Realm-C    │
┌─────────────────┐     └─────────────────┘
│   テナントB     │              ▲
│  ┌──────────┐  │              │
│  │  App1-B   │──┼──────────────┘
│  └──────────┘  │
└─────────────────┘
```

#### 8.2 実装要件
1. **動的レルム作成**
   - テナント登録API
   - レルムテンプレート機能
   - 自動クライアント設定

2. **URLパターン設計**
   ```
   https://{tenant}.app.example.com/
   または
   https://app.example.com/{tenant}/
   ```

3. **データ分離**
   - テナント別データベーススキーマ
   - ユーザーデータの完全分離
   - 監査ログの分離

4. **カスタマイズ機能**
   - テナント別ブランディング
   - カスタムログインテーマ
   - 独自の認証ポリシー

### Phase 9: SAML2.0完全対応

#### 9.1 SAML設定追加
1. **メタデータ管理**
   ```xml
   <EntityDescriptor entityID="https://sp.example.com">
     <SPSSODescriptor>
       <AssertionConsumerService 
         Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
         Location="https://sp.example.com/saml/acs"/>
     </SPSSODescriptor>
   </EntityDescriptor>
   ```

2. **署名と暗号化**
   - X.509証明書管理
   - XMLデジタル署名
   - Assertion暗号化

3. **SAML属性マッピング**
   ```yaml
   attributes:
     - saml: "urn:oid:1.2.840.113549.1.9.1"
       oidc: "email"
     - saml: "urn:oid:2.5.4.42"
       oidc: "given_name"
     - saml: "urn:oid:2.5.4.4"
       oidc: "family_name"
   ```

### Phase 10: モバイルアプリSSO

#### 10.1 ネイティブアプリ認証フロー
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ iOS/Android │────▶│  AppAuth    │────▶│  Keycloak   │
│    App      │     │   Library   │     │    IdP      │
└─────────────┘     └─────────────┘     └─────────────┘
       │                                         │
       │         In-App Browser/ASWebAuth       │
       └─────────────────────────────────────────┘
```

#### 10.2 実装詳細
1. **iOS実装（Swift）**
   ```swift
   // AppAuth-iOS使用
   let configuration = OIDServiceConfiguration(
     authorizationEndpoint: authEndpoint,
     tokenEndpoint: tokenEndpoint
   )
   
   let request = OIDAuthorizationRequest(
     configuration: configuration,
     clientId: "mobile-client",
     scopes: ["openid", "profile", "email"],
     redirectURL: URL(string: "myapp://callback")!,
     responseType: OIDResponseTypeCode,
     additionalParameters: nil
   )
   ```

2. **Android実装（Kotlin）**
   ```kotlin
   // AppAuth-Android使用
   val serviceConfig = AuthorizationServiceConfiguration(
     Uri.parse(authEndpoint),
     Uri.parse(tokenEndpoint)
   )
   
   val authRequest = AuthorizationRequest.Builder(
     serviceConfig,
     "mobile-client",
     ResponseTypeValues.CODE,
     Uri.parse("myapp://callback")
   ).setScopes("openid", "profile", "email")
    .build()
   ```

3. **セキュア設定**
   - PKCE (Proof Key for Code Exchange) 必須
   - カスタムURLスキーム
   - バイオメトリクス連携

#### 10.3 トークン管理
1. **セキュアストレージ**
   - iOS: Keychain Services
   - Android: Android Keystore

2. **トークンリフレッシュ**
   - バックグラウンド更新
   - 自動再認証フロー

3. **ディープリンク処理**
   ```javascript
   // Universal Links / App Links設定
   {
     "applinks": {
       "apps": [],
       "details": [{
         "appID": "TEAM_ID.com.example.app",
         "paths": ["/auth/*", "/callback/*"]
       }]
     }
   }
   ```

### Phase 11: 高度なセキュリティ機能

#### 11.1 2要素認証（2FA）
1. **TOTP (Time-based One-Time Password)**
   - Google Authenticator連携
   - QRコード生成

2. **SMS/Email OTP**
   - Twilio/SendGrid連携
   - レート制限実装

3. **WebAuthn/FIDO2**
   - 生体認証対応
   - セキュリティキー対応

#### 11.2 適応型認証
1. **リスクベース認証**
   - IPアドレス検証
   - デバイスフィンガープリント
   - 異常検知

2. **条件付きアクセス**
   ```javascript
   // ポリシー例
   {
     "conditions": {
       "ipRange": ["10.0.0.0/8"],
       "deviceTrust": "managed",
       "location": "JP"
     },
     "requirements": {
       "mfa": true,
       "sessionTimeout": 3600
     }
   }
   ```

### Phase 12: エンタープライズ統合

#### 12.1 既存システム連携
1. **LDAP/Active Directory**
   - ユーザー同期
   - グループマッピング
   - パスワードポリシー同期

2. **SCIM対応**
   - 自動プロビジョニング
   - ユーザーライフサイクル管理

3. **API Gateway統合**
   - Kong/AWS API Gateway
   - トークン検証
   - レート制限

#### 12.2 監査とコンプライアンス
1. **詳細監査ログ**
   - 全認証イベント記録
   - 管理操作の追跡
   - SIEM連携

2. **コンプライアンス対応**
   - GDPR対応（データ削除権）
   - SOC2準拠
   - ISO27001対応

## 実装優先順位

1. **Phase 1-7**: 基本SSO実装（1-2週間）
2. **Phase 9**: SAML2.0対応（3-5日）
3. **Phase 10**: モバイルアプリ対応（1週間）
4. **Phase 8**: マルチテナント対応（2週間）
5. **Phase 11-12**: エンタープライズ機能（3-4週間）
