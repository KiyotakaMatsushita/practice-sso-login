const express = require('express');
const session = require('express-session');
const { Issuer, generators } = require('openid-client');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });

const app = express();
const PORT = process.env.APP1_PORT || 3000;

// View engine setup
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static(path.join(__dirname, 'public')));

// Session configuration
app.use(session({
    secret: 'app1-secret-key-change-in-production',
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
            `${process.env.KEYCLOAK1_URL || 'http://localhost:8080'}/realms/idp-realm`
        );
        
        client = new keycloakIssuer.Client({
            client_id: 'app1-client',
            client_secret: process.env.APP1_CLIENT_SECRET,
            redirect_uris: ['http://localhost:3000/callback'],
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
        appName: 'Application 1',
        appDescription: 'Direct authentication with Keycloak1 (IdP)'
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
            'http://localhost:3000/callback',
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
            refreshToken: tokenSet.refresh_token
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
        appName: 'Application 1'
    });
});

app.get('/logout', (req, res) => {
    const logoutURL = client.endSessionUrl({
        post_logout_redirect_uri: 'http://localhost:3000'
    });
    
    req.session.destroy((err) => {
        if (err) {
            console.error('Session destroy error:', err);
        }
        res.redirect(logoutURL);
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
        console.log(`App1 is running on http://localhost:${PORT}`);
        console.log(`Connected to Keycloak1 at ${process.env.KEYCLOAK1_URL || 'http://localhost:8080'}`);
    });
});