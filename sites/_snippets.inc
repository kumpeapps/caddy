# Reusable Caddy Configuration Snippets
# Import these in your site configs with: import /sites/_snippets.caddy
# Then use individual snippets with: import snippet_name

# =============================================================================
# SECURITY HEADERS
# =============================================================================
(security_headers) {
    header {
        # Enable HSTS (HTTP Strict Transport Security)
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"

        # Prevent MIME type sniffing
        X-Content-Type-Options "nosniff"

        # Enable XSS protection
        X-XSS-Protection "1; mode=block"

        # Prevent clickjacking
        X-Frame-Options "SAMEORIGIN"

        # Referrer policy
        Referrer-Policy "strict-origin-when-cross-origin"

        # Permissions policy
        Permissions-Policy "geolocation=(), microphone=(), camera=()"

        # Remove server header
        -Server

        # Remove X-Powered-By
        -X-Powered-By
    }
}

# Strict security headers (for high-security sites)
(security_headers_strict) {
    header {
        Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        X-Frame-Options "DENY"
        Referrer-Policy "no-referrer"
        Permissions-Policy "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=(), accelerometer=()"
        Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'; frame-ancestors 'none';"
        -Server
        -X-Powered-By
    }
}

# =============================================================================
# BOT PROTECTION
# =============================================================================
(bot_protection) {
    # Block known bad bots
    @bad_bots {
        header User-Agent *AhrefsBot*
        header User-Agent *MJ12bot*
        header User-Agent *SemrushBot*
        header User-Agent *DotBot*
        header User-Agent *PetalBot*
        header User-Agent *BLEXBot*
        header User-Agent *Baiduspider*
        header User-Agent *YandexBot*
    }

    handle @bad_bots {
        abort
    }
}

(bot_protection_strict) {
    # Block all bots except whitelisted good bots
    @good_bots {
        header User-Agent *Googlebot*
        header User-Agent *bingbot*
        header User-Agent *Slackbot*
        header User-Agent *DuckDuckBot*
        header User-Agent *facebookexternalhit*
        header User-Agent *LinkedInBot*
        header User-Agent *TwitterBot*
    }

    @bad_bots {
        not header User-Agent *Googlebot*
        not header User-Agent *bingbot*
        not header User-Agent *Slackbot*
        not header User-Agent *DuckDuckBot*
        not header User-Agent *facebookexternalhit*
        not header User-Agent *LinkedInBot*
        not header User-Agent *TwitterBot*
        header User-Agent *bot*
        header User-Agent *spider*
        header User-Agent *crawler*
        header User-Agent *scraper*
    }

    @suspicious {
        not header User-Agent *
    }

    handle @bad_bots {
        abort
    }

    handle @suspicious {
        abort
    }
}

# Block exploit attempts
(exploit_protection) {
    @exploit_paths {
        path *.php
        path *.asp
        path *.aspx
        path *.jsp
        path *wp-admin*
        path *wp-login*
        path *phpmyadmin*
        path *.env*
        path *.git*
        path *.sql
        path *phpinfo*
        path */admin*
        path */login.php*
    }

    handle @exploit_paths {
        respond "Not Found" 404
    }
}

# =============================================================================
# RATE LIMITING
# =============================================================================
(rate_limit_general) {
    rate_limit {
        key {remote_host}
        events 300
        window 1m
    }
}

(rate_limit_api) {
    rate_limit {
        key {remote_host}
        events 100
        window 1m
    }
}

(rate_limit_login) {
    rate_limit {
        key {remote_host}
        events 5
        window 5m
    }
}

(rate_limit_strict) {
    rate_limit {
        key {remote_host}
        events 50
        window 1m
    }
}

(rate_limit_lenient) {
    rate_limit {
        key {remote_host}
        events 1000
        window 1m
    }
}

# Additional commonly-used rate limit patterns
(rate_limit_checkout) {
    rate_limit {
        key {remote_host}
        events 10
        window 5m
    }
}

(rate_limit_forms) {
    rate_limit {
        key {remote_host}
        events 5
        window 5m
    }
}

(rate_limit_contact) {
    rate_limit {
        key {remote_host}
        events 5
        window 5m
    }
}

(rate_limit_admin_login) {
    rate_limit {
        key {remote_host}
        events 3
        window 10m
    }
}

# =============================================================================
# CORS (Cross-Origin Resource Sharing)
# =============================================================================
(cors_permissive) {
    @cors_preflight {
        method OPTIONS
    }

    handle @cors_preflight {
        header Access-Control-Allow-Origin "*"
        header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        header Access-Control-Allow-Headers "Content-Type, Authorization"
        header Access-Control-Max-Age "3600"
        respond "" 204
    }

    header Access-Control-Allow-Origin "*"
}

(cors_restricted) {
    @cors_preflight {
        method OPTIONS
    }

    handle @cors_preflight {
        header Access-Control-Allow-Origin "{scheme}://{host}"
        header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE"
        header Access-Control-Allow-Headers "Content-Type, Authorization"
        header Access-Control-Allow-Credentials "true"
        header Access-Control-Max-Age "3600"
        respond "" 204
    }

    header Access-Control-Allow-Origin "{scheme}://{host}"
    header Access-Control-Allow-Credentials "true"
}

# =============================================================================
# LOGGING
# =============================================================================
(log_common) {
    log {
        output file /var/log/caddy/access.log {
            roll_size 100mb
            roll_keep 10
            roll_keep_for 720h
        }
        format json
    }
}

(log_detailed) {
    log {
        output file /var/log/caddy/access.log {
            roll_size 100mb
            roll_keep 10
            roll_keep_for 720h
        }
        format json
        level DEBUG
    }
}

# =============================================================================
# COMMON REDIRECTS
# =============================================================================
(www_to_apex) {
    @www host www.{host}
    redir @www https://{labels.1}.{labels.0}{uri} permanent
}

(apex_to_www) {
    @apex host {labels.1}.{labels.0}
    redir @apex https://www.{host}{uri} permanent
}

(force_https) {
    @http {
        protocol http
    }
    redir @http https://{host}{uri} permanent
}

# =============================================================================
# CLOUDNS DNS-01 CHALLENGE (common configuration)
# =============================================================================
(cloudns_dns) {
    tls {
        dns cloudns {
            auth_id {$CLOUDNS_AUTH_ID}
            auth_password {$CLOUDNS_AUTH_PASSWORD}
        }
        propagation_delay 2m
        propagation_timeout -1
        resolvers 1.1.1.1 8.8.8.8
    }
}

# =============================================================================
# FILE SERVER DEFAULTS
# =============================================================================
(file_server_defaults) {
    file_server {
        # Hide dotfiles
        hide .*
        # Enable browsing (remove if you don't want directory listings)
        browse
        # Set index files
        index index.html index.htm
    }
    encode gzip zstd
}

(file_server_no_browse) {
    file_server {
        hide .*
        index index.html index.htm
    }
    encode gzip zstd
}

# =============================================================================
# REVERSE PROXY DEFAULTS
# =============================================================================
(reverse_proxy_defaults) {
    # Common headers for reverse proxy
    header_up X-Real-IP {remote_host}
    header_up X-Forwarded-For {remote_host}
    header_up X-Forwarded-Proto {scheme}
    header_up X-Forwarded-Host {host}
}

# =============================================================================
# COMPRESSION
# =============================================================================
(compression) {
    encode gzip zstd {
        minimum_length 256
    }
}

# =============================================================================
# STATIC ASSET CACHING
# =============================================================================
(static_cache) {
    @static {
        path *.css *.js *.jpg *.jpeg *.png *.gif *.ico *.svg *.woff *.woff2 *.ttf *.eot *.webp *.avif
    }

    header @static {
        Cache-Control "public, max-age=31536000, immutable"
    }
}

(static_cache_moderate) {
    @static {
        path *.css *.js *.jpg *.jpeg *.png *.gif *.ico *.svg *.woff *.woff2 *.ttf *.eot *.webp *.avif
    }

    header @static {
        Cache-Control "public, max-age=86400"
    }
}

# =============================================================================
# MAINTENANCE MODE
# =============================================================================
(maintenance_mode) {
    respond "We're currently performing maintenance. Please check back soon!" 503 {
        header Retry-After "3600"
    }
}

# =============================================================================
# BASIC AUTH TEMPLATE
# =============================================================================
# (basic_auth_admin) {
#     basicauth {
#         # Generate with: caddy hash-password
#         # admin $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
#     }
# }

# =============================================================================
# ALTCHA (CAPTCHA-free spam protection)
# =============================================================================
# IMPORTANT: ALTCHA requires ALTCHA_HMAC_KEY environment variable
# Generate with: openssl rand -base64 32
# Plugin: https://github.com/stardothosting/caddy-altcha

# Challenge generation endpoint - provides cryptographic challenges to clients
(altcha_challenge_basic) {
    route /api/altcha/challenge {
        altcha_challenge {
            hmac_key {env.ALTCHA_HMAC_KEY}
            algorithm SHA-256
            max_number 100000
            expires 5m
        }
    }
}

(altcha_challenge_strict) {
    route /api/altcha/challenge {
        altcha_challenge {
            hmac_key {env.ALTCHA_HMAC_KEY}
            algorithm SHA-256
            max_number 1000000      # Higher difficulty ~200ms solve time
            expires 2m              # Shorter expiration
            rate_limit_requests 10  # Prevent DoS
            rate_limit_window 1m
        }
    }
}

# Challenge UI page - serves the ALTCHA widget HTML
(altcha_challenge_page) {
    route /captcha* {
        rewrite * /index.html
        root * /var/www/altcha
        file_server
    }
}

# Verification middleware - protects specific routes
# Use with matchers to specify which routes to protect
(altcha_verify_memory) {
    altcha_verify {
        hmac_key {env.ALTCHA_HMAC_KEY}
        session_backend memory://
        challenge_redirect /captcha
        preserve_post_data true
    }
}

(altcha_verify_redis) {
    altcha_verify {
        hmac_key {env.ALTCHA_HMAC_KEY}
        session_backend redis://localhost:6379/0
        session_ttl 5m
        challenge_redirect /captcha
        preserve_post_data true
        verified_cookie_ttl 3600
    }
}

# =============================================================================
# CADDY-DEFENDER (Block AI bots and cloud scrapers)
# =============================================================================
# Plugin: https://github.com/JasonLovesDoggo/caddy-defender
# Purpose: Block or manipulate requests from AI services training on your content

# Block common AI scrapers (OpenAI, DeepSeek, GitHub Copilot, etc.)
(defender_block_ai) {
    defender block {
        ranges openai deepseek githubcopilot
    }
}

# Block all major cloud providers and AI services
# WARNING: This includes aws, gcloud, and azurepubliccloud which may block
# legitimate human traffic (corporate VPNs, hosting, CDNs). Use with caution.
# Consider using defender_block_ai instead for AI-only blocking.
(defender_block_all_ai) {
    defender block {
        ranges openai deepseek githubcopilot aws gcloud azurepubliccloud
    }
}

# Return garbage data to pollute AI training
(defender_garbage_ai) {
    defender garbage {
        ranges openai deepseek githubcopilot
    }
}

# Redirect AI bots to a different page
(defender_redirect_ai) {
    defender redirect {
        ranges openai deepseek githubcopilot
        url /ai-bot-notice
    }
}

# Tarpit (slow down) AI bots
(defender_tarpit_ai) {
    defender tarpit {
        ranges openai deepseek githubcopilot aws gcloud
    }
}

# Drop connections from AI bots
(defender_drop_ai) {
    defender drop {
        ranges openai deepseek githubcopilot
    }
}
