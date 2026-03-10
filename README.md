# Caddy Docker Setup

A production-ready Caddy web server setup with automatic HTTPS, DNS-01 challenge support, and comprehensive bot protection.

## Features

- 🔒 Automatic HTTPS with Let's Encrypt
- 🌐 DNS-01 challenge support (CloudNS)
- 🛡️ Built-in bot protection and rate limiting
- 🚀 Easy deployment with Docker
- 📝 Example configurations included

## Plugins Included

- **caddy-dns/cloudns**: DNS-01 challenge provider for CloudNS
- **caddy-ratelimit**: Advanced rate limiting and traffic control

## Quick Start

1. Set your environment variables:

    ```bash
    export ACME_EMAIL=your-email@example.com
    export CLOUDNS_AUTH_ID=your-auth-id
    export CLOUDNS_AUTH_PASSWORD=your-auth-password
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

## Reusable Snippets

The setup includes 30+ prebuilt snippets in `_snippets.inc` and pre-built matchers in `_matchers.inc`.

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

#### CORS

- `cors_permissive` - Allow all origins
- `cors_restricted` - Same-origin only

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

Pre-built matchers in `_matchers.inc` (optional - import in site blocks if needed):

- **Methods**: `@safe_methods`, `@unsafe_methods`
- **Content**: `@api_request`, `@form_submit`
- **Devices**: `@mobile`, `@desktop`
- **Paths**: `@admin`, `@api`, `@static_assets`, `@images`, `@media`, `@documents`
- **Security**: `@no_referer`, `@no_user_agent`, `@local`, `@external`
- **Bots**: `@search_engines`, `@social_media_bots`, `@monitoring_bots`

### Using Matchers

If you want to use the pre-built matchers, import them **inside your site block**:

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
- **example-with-snippets.caddy**: Complete examples using reusable snippets
- **_snippets.inc**: Reusable configuration snippets (import this file!)
- **_matchers.inc**: Pre-built request matchers

## Environment Variables

| Variable | Description | Required |
| --- | --- | --- |
| `ACME_EMAIL` | Email for Let's Encrypt | Yes |
| `CLOUDNS_AUTH_ID` | CloudNS authentication ID | Yes (if using DNS-01) |
| `CLOUDNS_AUTH_PASSWORD` | CloudNS authentication password | Yes (if using DNS-01) |

## File Structure

### Source Code Structure

```text
/
├── Caddyfile                       # Main Caddy configuration
├── Dockerfile                      # Multi-stage build with plugins
├── docker-entrypoint.sh            # Startup script
├── sites/                          # Site configurations (source)
│   ├── _snippets.inc              # 20+ reusable configuration snippets
│   ├── _matchers.inc              # Pre-built request matchers
│   ├── caddy.example              # Basic reverse proxy example
│   ├── redirect.example           # Simple redirects example
│   ├── bot-protection.example     # Bot protection examples
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
