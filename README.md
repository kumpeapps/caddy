# Caddy Docker Setup

A production-ready Caddy web server setup with automatic HTTPS, DNS-01 challenge support, comprehensive bot protection, CAPTCHA-free spam protection, and advanced security features.

## Features

- 🔒 Automatic HTTPS with Let's Encrypt
- 🌐 DNS-01 challenge support (CloudNS)
- 🛡️ Built-in bot protection and rate limiting
- 🤖 ALTCHA - Privacy-friendly CAPTCHA alternative
- 🔐 Caddy-Defender - Advanced threat detection and mitigation
- 🚀 Easy deployment with Docker
- 📝 Example configurations included
- 🔧 30+ reusable configuration snippets

## Plugins Included

- **caddy-dns/cloudns**: DNS-01 challenge provider for CloudNS
- **caddy-ratelimit**: Advanced rate limiting and traffic control
- **caddy-altcha**: CAPTCHA-free spam protection using cryptographic challenges
- **caddy-defender**: Advanced security and threat detection system

**Note**: Plugin versions are pinned in the [Dockerfile](Dockerfile) for reproducibility. Update the version tags periodically to get security fixes and new features. See each plugin's GitHub releases page for available versions.

## Quick Start

1. Set your environment variables:

    ```bash
    export ACME_EMAIL=your-email@example.com
    export CLOUDNS_AUTH_ID=your-auth-id
    export CLOUDNS_AUTH_PASSWORD=your-auth-password
    # Required if using ALTCHA spam protection
    export ALTCHA_HMAC_KEY=$(openssl rand -hex 32)
    ```

1. Copy and customize your site configuration:

    ```bash
    cp /usr/local/share/caddy/caddy.example /sites/mysite.caddy
    # Edit /sites/mysite.caddy with your domains and settings
    ```

1. Build and run:

    ```bash
    docker build -t caddy-custom .
    docker run -d \
      -p 80:80 \
      -p 443:443 \
      -e ACME_EMAIL=${ACME_EMAIL} \
      -e CLOUDNS_AUTH_ID=${CLOUDNS_AUTH_ID} \
      -e CLOUDNS_AUTH_PASSWORD=${CLOUDNS_AUTH_PASSWORD} \
      -e ALTCHA_HMAC_KEY=${ALTCHA_HMAC_KEY} \
      -v $(pwd)/sites:/sites \
      -v caddy_data:/data \
      -v caddy_config:/config \
      caddy-custom
    ```

**Tip:** If your site configurations are managed via Git or another version control system, you can mount `/sites` as read-only to prevent accidental modifications:

```bash
-v $(pwd)/sites:/sites:ro
```

## Bot Protection

The setup includes comprehensive bot protection features. See `sites/bot-protection.example` for detailed examples.

### Bot Protection Features

- **Bad Bot Blocking**: Blocks known malicious bots and scrapers
- **Good Bot Whitelisting**: Allows legitimate search engine bots- **Rate Limiting**: Configurable per-zone rate limits
- **Exploit Path Protection**: Blocks common attack vectors
- **Suspicious Request Filtering**: Blocks requests without proper headers

### Rate Limiting Zones

Different rate limits for different use cases:

- **General**: 300 requests/minute per IP
- **API**: 100 requests/minute per IP
- **Login**: 5 requests/5 minutes per IP
- **Checkout**: 10 requests/minute per IP
- **Products**: 200 requests/minute per IP

### Usage Example

```caddyfile
your-domain.com {
    # Import bot protection snippet
    import bot_protection

    # Apply general rate limiting
    rate_limit general

    # Your application
    reverse_proxy http://localhost:8080
}
```

### Customization

Edit the blocked bots list in `bot-protection.example`:

```caddyfile
(bot_protection) {
    @bad_bots {
        header User-Agent *YourBotToBlock*
    }

    handle @bad_bots {
        abort
    }
}
```

Adjust rate limits for your needs:

```caddyfile
rate_limit {
    zone custom {
        key {remote_host}
        events 500          # number of requests
        window 1m           # time window
    }
}
```

## ALTCHA (CAPTCHA-free Spam Protection)

ALTCHA provides privacy-friendly spam protection using cryptographic challenges instead of traditional CAPTCHAs. No user tracking, no privacy concerns, no accessibility issues.

See [sites/altcha.example](sites/altcha.example) for detailed configuration examples.

### ALTCHA Key Features

- **Privacy-Friendly**: No cookies, no tracking, no third-party services
- **Accessible**: No image recognition or audio challenges
- **Lightweight**: Pure cryptographic challenge-response
- **Customizable**: Adjustable difficulty levels for different use cases

### ALTCHA Quick Setup

1. Generate an HMAC key (required):

    ```bash
    export ALTCHA_HMAC_KEY=$(openssl rand -hex 32)
    ```

    **Important**: ALTCHA configurations will fail if `ALTCHA_HMAC_KEY` is not set. Always ensure this environment variable is defined before starting Caddy.

2. Use the ALTCHA snippet:

    ```caddyfile
    form.example.com {
        import cloudns_dns
        import altcha_basic

        # Verification endpoint
        import altcha_verify_endpoint

        # Protected form submission
        @form_submit {
            path /submit
            method POST
        }

        handle @form_submit {
            reverse_proxy http://localhost:8080
        }

        reverse_proxy http://localhost:8080
    }
    ```

### ALTCHA Variants

- **`altcha_basic`**: Standard protection (120s expiration, 50k max hashes)
- **`altcha_strict`**: High security for sensitive forms (60s expiration, 100k max hashes)
- **`altcha_lenient`**: Casual forms (300s expiration, 25k max hashes)

### Customizing ALTCHA

**Custom Verification Endpoint**: The default verification endpoint is `/.well-known/altcha`. To use a custom path:

1. Define your own handler instead of using `altcha_verify_endpoint`:

    ```caddyfile
    handle /custom/verify/path {
        altcha_verify
    }
    ```

2. Update the `verify_url` in your ALTCHA configuration:

    ```caddyfile
    altcha {
        hmac_key {$ALTCHA_HMAC_KEY}
        verify_url "/custom/verify/path"
        expires 120
        max_number 50000
    }
    ```

### Integration Example

```caddyfile
contact.example.com {
    import cloudns_dns
    import altcha_strict
    import security_headers

    # ALTCHA verification
    handle /.well-known/altcha {
        altcha_verify
    }

    # Protected contact form with rate limiting
    @contact path /contact/submit
    handle @contact {
        import rate_limit_contact
        reverse_proxy http://localhost:8080
    }

    reverse_proxy http://localhost:8080
}
```

## Caddy-Defender (Advanced Security)

Caddy-Defender provides enterprise-grade security with automatic threat detection, IP blacklisting, and real-time attack mitigation.

See [sites/defender.example](sites/defender.example) for comprehensive examples.

### Defender Key Features

- **Automatic Threat Detection**: Identifies suspicious patterns
- **IP Blacklisting/Whitelisting**: Dynamic IP management
- **Challenge Mode**: Alternative to blocking for suspicious traffic
- **Distributed Support**: Redis-backed for multi-instance deployments
- **Auto-Learning**: Adapts to your traffic patterns

### Defender Quick Setup

```caddyfile
secure.example.com {
    import cloudns_dns
    import defender_basic
    import security_headers

    reverse_proxy http://localhost:8080
}
```

### Defender Variants

- **`defender_basic`**: Standard protection (blocks threats for 1 hour)
- **`defender_strict`**: High security with auto-blacklist (24-hour blocks, no default whitelist)
- **`defender_lenient`**: Development mode (logging only, no blocks)
- **`defender_challenge`**: Challenge suspicious users instead of blocking

**Security Note**: The `defender_strict` variant no longer includes a default RFC1918 whitelist. If you need to whitelist private networks, define them explicitly in a custom defender block (see [sites/defender.example](sites/defender.example) Example 2b).

### Admin Panel Protection

```caddyfile
admin.example.com {
    import cloudns_dns
    import defender_strict
    import security_headers_strict

    # Extra protection for login with strict rate limiting
    @login path /login /auth/*
    handle @login {
        import rate_limit_admin_login
        reverse_proxy http://localhost:9000
    }

    reverse_proxy http://localhost:9000
}
```

### Advanced Configuration

For custom threat detection rules:

```caddyfile
enterprise.example.com {
    defender {
        enable true
        action block
        block_duration 21600  # 6 hours
        threshold 8
        window 60

        # Whitelist internal networks
        whitelist {
            10.0.0.0/8
            172.16.0.0/12
            192.168.0.0/16
        }

        # Enable auto-learning
        auto_learn true

        # Distributed mode with Redis
        distributed true
        redis_addr {$REDIS_ADDR}
    }

    reverse_proxy http://localhost:8080
}
```

## Combining Security Layers

For maximum protection, combine multiple security features:

```caddyfile
ultra-secure.example.com {
    import cloudns_dns
    import security_headers_strict
    import defender_strict
    import bot_protection
    import exploit_protection

    # ALTCHA on forms
    import altcha_strict
    handle /.well-known/altcha {
        altcha_verify
    }

    # Protected form submissions with rate limiting
    @forms {
        path /contact /register /reset-password
        method POST
    }

    handle @forms {
        import rate_limit_forms
        reverse_proxy http://localhost:8080
    }

    # Regular traffic with general rate limiting
    import rate_limit_general
    reverse_proxy http://localhost:8080
}
```

## Reusable Snippets

The setup includes 30+ prebuilt snippets in `_snippets.inc` and prebuilt matchers in `_matchers.inc`.

**Note:** Snippets are globally imported in the main Caddyfile from `/usr/local/share/caddy/`, so you can use them directly in any `.caddy` file. However, **matchers must be imported within individual site blocks** due to Caddy's scoping rules.

### Using Snippets

Simply use any snippet with the `import` directive in your .caddy files:

```caddyfile
your-domain.com {
    import cloudns_dns
    import security_headers
    import bot_protection
    import rate_limit_general

    reverse_proxy http://localhost:8080
}
```

### Available Snippets

#### Security

- `security_headers` - Standard security headers
- `security_headers_strict` - Strict security with CSP
- `bot_protection` - Block malicious bots
- `bot_protection_strict` - Strict bot filtering
- `exploit_protection` - Block common attack paths

#### Rate Limiting

- `rate_limit_general` - 300 req/min
- `rate_limit_api` - 100 req/min
- `rate_limit_login` - 5 req/5min
- `rate_limit_strict` - 50 req/min
- `rate_limit_lenient` - 1000 req/min
- `rate_limit_checkout` - 10 req/5min (for payment/checkout pages)
- `rate_limit_forms` - 5 req/5min (for form submissions)
- `rate_limit_contact` - 5 req/5min (for contact forms)
- `rate_limit_admin_login` - 3 req/10min (for admin login attempts)

#### CORS

- `cors_permissive` - Allow all origins
- `cors_restricted` - Same-origin only

#### ALTCHA (Spam Protection)

- `altcha_basic` - Basic ALTCHA protection
- `altcha_strict` - Strict ALTCHA for sensitive forms
- `altcha_lenient` - Lenient ALTCHA for casual forms
- `altcha_verify_endpoint` - ALTCHA verification endpoint handler

#### Caddy-Defender Snippets

- `defender_basic` - Basic threat detection
- `defender_strict` - Strict security with auto-blacklist (no default whitelist)
- `defender_lenient` - Lenient mode (logging only)
- `defender_challenge` - Challenge suspicious users

#### Redirects

- `www_to_apex` - Redirect www to apex domain
- `apex_to_www` - Redirect apex to www
- `force_https` - Force HTTPS

#### Other

- `cloudns_dns` - CloudNS DNS-01 configuration
- `compression` - Gzip/Zstd compression
- `static_cache` - Aggressive static asset caching
- `static_cache_moderate` - Moderate caching
- `log_common` - JSON logging
- `file_server_defaults` - File server configuration
- `reverse_proxy_defaults` - Common proxy headers

### Available Matchers

Prebuilt matchers in `_matchers.inc` (optional - import in site blocks if needed):

- **Methods**: `@safe_methods`, `@unsafe_methods`
- **Content**: `@api_request`, `@form_submit`
- **Devices**: `@mobile`, `@desktop`
- **Paths**: `@admin`, `@api`, `@static_assets`, `@images`, `@media`, `@documents`
- **Security**: `@no_referer`, `@no_user_agent`, `@local`, `@external`
- **Bots**: `@search_engines`, `@social_media_bots`, `@monitoring_bots`

### Using Matchers

If you want to use the prebuilt matchers, import them **inside your site block**:

```caddyfile
example.com {
    # Import matchers inside the site block
    import /usr/local/share/caddy/_matchers.inc

    import cloudns_dns
    import security_headers

    # Now you can use the matchers
    handle @admin {
        import rate_limit_strict
        reverse_proxy http://localhost:9000
    }

    handle @static_assets {
        import static_cache
        reverse_proxy http://localhost:8080
    }
}
```

### Example Usage (Without Matchers)

```caddyfile
example.com {
    import cloudns_dns
    import security_headers
    import compression

    # Block bots and exploits
    import bot_protection
    import exploit_protection

    # Different rate limits for different paths
    handle @admin {
        import rate_limit_strict
        reverse_proxy http://localhost:9000
    }

    handle @api {
        import cors_permissive
        import rate_limit_api
        reverse_proxy http://localhost:3000
    }

    # Static assets with caching
    handle @static_assets {
        import static_cache
        reverse_proxy http://localhost:8080
    }

    # Default
    import rate_limit_general
    reverse_proxy http://localhost:8080
}
```

See [sites/example-with-snippets.caddy](sites/example-with-snippets.caddy) for complete working examples.

## Example Files

- **caddy.example**: Basic reverse proxy with redirects
- **redirect.example**: Simple domain redirects
- **bot-protection.example**: Comprehensive bot protection examples
- **altcha.example**: ALTCHA integration examples for spam protection
- **defender.example**: Caddy-Defender advanced security examples
- **example-with-snippets.caddy**: Complete examples using reusable snippets
- **_snippets.inc**: Reusable configuration snippets (import this file!)
- **_matchers.inc**: Prebuilt request matchers

## Environment Variables

| Variable | Description | Required |
| --- | --- | --- |
| `ACME_EMAIL` | Email for Let's Encrypt | Yes |
| `CLOUDNS_AUTH_ID` | CloudNS authentication ID | Yes (if using DNS-01) |
| `CLOUDNS_AUTH_PASSWORD` | CloudNS authentication password | Yes (if using DNS-01) |
| `ALTCHA_HMAC_KEY` | HMAC key for ALTCHA (generate with `openssl rand -hex 32`) | Yes (if using ALTCHA) |

## File Structure

### Source Code Structure

```text
/
├── Caddyfile                       # Main Caddy configuration
├── Dockerfile                      # Multi-stage build with plugins
├── docker-entrypoint.sh            # Startup script
├── sites/                          # Site configurations (source)
│   ├── _snippets.inc              # 30+ reusable configuration snippets
│   ├── _matchers.inc              # Prebuilt request matchers
│   ├── caddy.example              # Basic reverse proxy example
│   ├── redirect.example           # Simple redirects example
│   ├── bot-protection.example     # Bot protection examples
│   ├── altcha.example             # ALTCHA spam protection examples
│   ├── defender.example           # Caddy-Defender security examples
│   └── example-with-snippets.caddy.example # Examples using snippets
└── README.md
```

### Container Structure

Inside the running container:

- **`/etc/caddy/Caddyfile`** - Main configuration
- **`/usr/local/share/caddy/`** - Shared resources (snippets, matchers, examples)
- **`/sites/`** - Your site configurations (mount your configs here)
- **`/data/`** - Caddy data (certificates, etc.)
- **`/config/`** - Caddy config cache

## Development

This project includes a VS Code devcontainer for easy development. See [.devcontainer/README.md](.devcontainer/README.md) for detailed instructions.

### Quick Start with DevContainer

1. **Open in VS Code**: Open this project in VS Code with the Dev Containers extension installed
2. **Reopen in Container**: Press `F1` → "Dev Containers: Reopen in Container"
3. **Start Developing**: All required tools and extensions are pre-installed

### Building the Docker Image

```bash
# Build the custom Caddy image
docker build -t caddy-custom .

# Run with your configurations
docker run -d \
  -p 80:80 \
  -p 443:443 \
  -v $PWD/sites:/sites:ro \
  -e ACME_EMAIL=your@email.com \
  caddy-custom
```

### Testing Configuration Changes

```bash
# Validate Caddy configuration
docker run --rm -v $PWD/sites:/sites caddy-custom caddy validate --config /etc/caddy/Caddyfile

# Check for syntax errors
docker run --rm -v $PWD/sites:/sites caddy-custom caddy fmt --overwrite /sites/yoursite.caddy
```

## Security Best Practices

1. **Always use HTTPS**: The setup automatically provisions SSL certificates
1. **Rate Limiting**: Use appropriate rate limits for your traffic patterns
1. **Monitor Logs**: Check Caddy logs for blocked requests
1. **Update Regularly**: Keep Caddy and plugins up to date
1. **Whitelist Carefully**: Only whitelist bots you actually want to allow
1. **Use Read-Only Mounts**: When managing configs via Git, mount `/sites` as read-only (`:ro`) to prevent accidental modifications

## Troubleshooting

### Container won't start with read-only /sites mount?

The entrypoint script gracefully handles read-only mounts. If you see this issue, ensure your .caddy files exist in the /sites directory before starting the container. Example files won't be copied to read-only mounts.

### Bot protection too strict?

Adjust the matchers in your bot_protection snippet to be less aggressive.

### Rate limits triggering for legitimate users?

Increase the `events` or `window` values in your rate_limit configuration.

### Need to allow a specific bot?

Add it to the `@good_bots` matcher in your configuration.

## License

MIT
