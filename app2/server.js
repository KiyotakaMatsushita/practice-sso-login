const express = require('express');
const session = require('express-session');
const { Issuer, generators } = require('openid-client');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const app = express();
const PORT = process.env.APP2_PORT || 3001;

// View engine setup
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static(path.join(__dirname, 'public')));

// Session configuration
app.use(session({
    secret: 'app2-secret-key-change-in-production',
    resave: false,
    saveUninitialized: false,
    cookie: {
        secure: false, // Set to true in production with HTTPS
        httpOnly: true,
        maxAge: 30 * 60 * 1000 // 30 minutes
    }
}));

// OpenID Client setup
let client;

async function setupOIDC() {
    try {
        const keycloakIssuer = await Issuer.discover(
            `${process.env.KEYCLOAK2_URL || 'http://localhost:8180'}/realms/sp-realm`
        );
        
        client = new keycloakIssuer.Client({
            client_id: 'app2-client',
            client_secret: process.env.APP2_CLIENT_SECRET,
            redirect_uris: ['http://localhost:3001/callback'],
            response_types: ['code']
        });
        
        console.log('OIDC client configured successfully');
    } catch (error) {
        console.error('Failed to setup OIDC client:', error);
        process.exit(1);
    }
}

// Middleware to check authentication
const isAuthenticated = (req, res, next) => {
    if (req.session.user) {
        return next();
    }
    res.redirect('/login');
};

// Routes
app.get('/', (req, res) => {
    res.render('index', { 
        user: req.session.user,
        appName: 'Application 2',
        appDescription: 'SSO authentication via Keycloak2 (SP) → Keycloak1 (IdP)'
    });
});

app.get('/login', (req, res) => {
    const code_verifier = generators.codeVerifier();
    const code_challenge = generators.codeChallenge(code_verifier);
    
    req.session.code_verifier = code_verifier;
    
    const authUrl = client.authorizationUrl({
        scope: 'openid profile email',
        code_challenge,
        code_challenge_method: 'S256',
    });
    
    res.redirect(authUrl);
});

app.get('/callback', async (req, res) => {
    try {
        const params = client.callbackParams(req);
        const tokenSet = await client.callback(
            'http://localhost:3001/callback',
            params,
            { code_verifier: req.session.code_verifier }
        );
        
        const userinfo = await client.userinfo(tokenSet);
        
        req.session.user = {
            id: userinfo.sub,
            username: userinfo.preferred_username,
            email: userinfo.email,
            firstName: userinfo.given_name,
            lastName: userinfo.family_name,
            name: userinfo.name,
            accessToken: tokenSet.access_token,
            refreshToken: tokenSet.refresh_token,
            authFlow: 'SSO via Keycloak2 → Keycloak1'
        };
        
        delete req.session.code_verifier;
        res.redirect('/profile');
    } catch (error) {
        console.error('Callback error:', error);
        res.redirect('/login?error=auth_failed');
    }
});

app.get('/profile', isAuthenticated, (req, res) => {
    res.render('profile', { 
        user: req.session.user,
        appName: 'Application 2'
    });
});

app.get('/logout', (req, res) => {
    const logoutURL = client.endSessionUrl({
        post_logout_redirect_uri: 'http://localhost:3001'
    });
    
    req.session.destroy((err) => {
        if (err) {
            console.error('Session destroy error:', err);
        }
        res.redirect(logoutURL);
    });
});

// SSO flow information endpoint
app.get('/sso-info', isAuthenticated, (req, res) => {
    res.render('sso-info', {
        user: req.session.user,
        appName: 'Application 2',
        flowDetails: {
            step1: 'User accesses App2',
            step2: 'App2 redirects to Keycloak2 (SP)',
            step3: 'Keycloak2 detects no local session',
            step4: 'Keycloak2 redirects to Keycloak1 (IdP)',
            step5: 'User authenticates at Keycloak1',
            step6: 'Keycloak1 returns token to Keycloak2',
            step7: 'Keycloak2 creates local session',
            step8: 'Keycloak2 returns token to App2',
            step9: 'App2 creates user session'
        }
    });
});

// Error handling
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).render('error', { 
        message: 'Something went wrong!',
        error: process.env.NODE_ENV === 'development' ? err : {}
    });
});

// Start server
setupOIDC().then(() => {
    app.listen(PORT, () => {
        console.log(`App2 is running on http://localhost:${PORT}`);
        console.log(`Connected to Keycloak2 at ${process.env.KEYCLOAK2_URL || 'http://localhost:8180'}`);
        console.log(`SSO flow: App2 → Keycloak2 (SP) → Keycloak1 (IdP)`);
    });
});