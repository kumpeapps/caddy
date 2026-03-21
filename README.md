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

- **[caddy-dns/cloudns](https://github.com/caddy-dns/cloudns)**: DNS-01 challenge provider for CloudNS
- **[caddy-ratelimit](https://github.com/mholt/caddy-ratelimit)**: Advanced rate limiting and traffic control
- **[caddy-altcha](https://github.com/stardothosting/caddy-altcha)**: CAPTCHA-free spam protection using cryptographic challenges
- **[caddy-defender](https://github.com/JasonLovesDoggo/caddy-defender)**: Blocks AI bots and cloud services from training on your content

**Note**: Plugin versions are pinned in the [Dockerfile](Dockerfile) for reproducibility. Update the version tags periodically to get security fixes and new features. See each plugin's GitHub releases page for available versions.

## Quick Start

1. Set your environment variables:

    ```bash
    export ACME_EMAIL=your-email@example.com
    export CLOUDNS_AUTH_ID=your-auth-id
    export CLOUDNS_AUTH_PASSWORD=your-auth-password
    # Required if using ALTCHA spam protection
    export ALTCHA_HMAC_KEY=$(openssl rand -base64 32)
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

ALTCHA provides privacy-friendly spam protection using cryptographic proof-of-work challenges instead of traditional CAPTCHAs. No user tracking, no privacy concerns, no accessibility issues.

See [sites/altcha.example](sites/altcha.example) for detailed configuration examples.

### ALTCHA Key Features

- **Privacy-Friendly**: No cookies, no tracking, no third-party services
- **Accessible**: No image recognition or audio challenges
- **Lightweight**: Pure cryptographic challenge-response
- **Customizable**: Adjustable difficulty levels for different use cases
- **Session Support**: Memory, Redis, or file-based session backends
- **POST Preservation**: Can restore POST data after verification

### ALTCHA Quick Setup

1. Generate an HMAC key (required):

    ```bash
    export ALTCHA_HMAC_KEY=$(openssl rand -base64 32)
    ```

    **Important**: ALTCHA configurations will fail if `ALTCHA_HMAC_KEY` is not set. Always ensure this environment variable is defined before starting Caddy.

2. Set the order directive and use ALTCHA handlers:

    ```caddyfile
    form.example.com {
        import cloudns_dns

        # REQUIRED: Set order for altcha_verify to run before reverse_proxy
        order altcha_verify before reverse_proxy

        # Challenge generation endpoint
        import altcha_challenge_basic

        # Challenge UI page
        import altcha_challenge_page

        # Protect form submissions
        @forms {
            path /contact /submit
            method POST
        }

        altcha_verify @forms {
            hmac_key {env.ALTCHA_HMAC_KEY}
            session_backend memory://
            challenge_redirect /captcha
            preserve_post_data true
        }

        reverse_proxy http://localhost:8080
    }
    ```

### ALTCHA Snippets

- **`altcha_challenge_basic`**: Challenge endpoint with 100k max_number (~20ms solve time)
- **`altcha_challenge_strict`**: Strict challenge with 1M max_number (~200ms solve time)
- **`altcha_challenge_page`**: Serves ALTCHA widget HTML at /captcha
- **`altcha_verify_memory`**: Verification with memory:// session backend
- **`altcha_verify_redis`**: Verification with redis://localhost:6379/0 backend

### ALTCHA Components

ALTCHA requires two handlers:

1. **Challenge Generation** (`altcha_challenge`): Creates cryptographic challenges
   - Route: `/api/altcha/challenge`
   - Returns JSON with challenge data
   - Configure: `hmac_key`, `algorithm`, `max_number`, `expires`

2. **Verification** (`altcha_verify`): Validates solutions
   - Applied to protected routes via matchers
   - Configure: `hmac_key`, `session_backend`, `challenge_redirect`, `preserve_post_data`

### Integration Example

```caddyfile
contact.example.com {
    import cloudns_dns
    order altcha_verify before reverse_proxy
    import security_headers

    # Challenge endpoint (strict protection)
    import altcha_challenge_strict

    # Challenge UI page
    import altcha_challenge_page

    # Protect contact form with Redis backend
    @contact {
        path /contact/submit
        method POST
    }

    altcha_verify @contact {
        hmac_key {env.ALTCHA_HMAC_KEY}
        session_backend redis://localhost:6379/0
        challenge_redirect /captcha
        preserve_post_data true
    }

    # Rate limit form submissions
    @contact_rate path /contact/submit
    handle @contact_rate {
        import rate_limit_contact
        reverse_proxy http://localhost:8080
    }

    reverse_proxy http://localhost:8080
}
```

## Caddy-Defender (AI Bot Protection)

Caddy-Defender blocks AI training bots and cloud scrapers that ignore robots.txt. It uses IP range lists to identify known AI bot networks (OpenAI, DeepSeek, AWS, etc.).

**Purpose**: This plugin protects your content from AI training scrapers. It is NOT for general security, malware, or DDoS protection.

See [sites/defender.example](sites/defender.example) for comprehensive examples.

### Defender Key Features

- **AI Bot Detection**: Blocks OpenAI, DeepSeek, GitHub Copilot, and other AI scrapers
- **Cloud Provider Ranges**: AWS, Google Cloud, Azure IP ranges
- **Multiple Actions**: Block, garbage data, redirect, tarpit, or drop connections
- **Custom Ranges**: Add your own IP ranges
- **robots.txt Enforcement**: Technical enforcement of robots.txt policy

### Defender Quick Setup

```caddyfile
blog.example.com {
    import cloudns_dns
    import security_headers

    # Block all major AI training bots
    import defender_block_ai

    reverse_proxy http://localhost:8080
}
```

### Defender Actions

- **`block`**: Return 403 Forbidden with optional message
- **`garbage`**: Return random garbage data to pollute AI training
- **`redirect`**: HTTP 302 redirect to specified URL
- **`tarpit`**: Slow response to waste bot resources
- **`drop`**: Silently drop connection (no response)

### Defender Snippets

- **`defender_block_ai`**: Block all AI bots (OpenAI, DeepSeek, GitHub Copilot, AWS, GCloud, Azure)
- **`defender_block_all_ai`**: Same as defender_block_ai with explicit ranges
- **`defender_garbage_ai`**: Return garbage data to poison AI training
- **`defender_redirect_ai`**: Redirect AI bots to /ai-bot-notice page
- **`defender_tarpit_ai`**: Slow down AI bot requests
- **`defender_drop_ai`**: Silently drop AI bot connections

### Available IP Ranges

Built-in ranges (updated regularly):

- `openai` - OpenAI GPT crawlers
- `deepseek` - DeepSeek AI training bots
- `githubcopilot` - GitHub Copilot training sources
- `aws` - Amazon Web Services
- `gcloud` - Google Cloud Platform
- `azurepubliccloud` - Microsoft Azure

### Selective Protection Example

```caddyfile
premium.example.com {
    import cloudns_dns
    import security_headers

    # Block AI bots on premium content only
    @premium {
        path /premium/* /members/*
    }

    handle @premium {
        defender block {
            ranges openai deepseek githubcopilot aws gcloud azurepubliccloud
            message "AI training bots not permitted on premium content."
        }
        reverse_proxy http://localhost:8080
    }

    # Allow public content
    handle {
        reverse_proxy http://localhost:8080
    }
}
```

### Advanced Configuration

Different actions for different bots:

```caddyfile
creative.example.com {
    import cloudns_dns
    import security_headers

    # Block specific AI companies
    defender block {
        ranges openai deepseek
        message "OpenAI and DeepSeek bots are not permitted."
    }

    # Return garbage to GitHub Copilot
    defender garbage {
        ranges githubcopilot
    }

    # Tarpit cloud providers
    defender tarpit {
        ranges aws gcloud azurepubliccloud
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
    order altcha_verify before reverse_proxy

    # Layer 1: Block AI training bots
    import defender_block_ai

    # Layer 2: Block malicious bots
    import bot_protection
    import exploit_protection

    # Layer 3: ALTCHA challenge endpoint
    import altcha_challenge_strict
    import altcha_challenge_page

    # Layer 4: ALTCHA verification on forms
    @forms {
        path /contact /register /reset-password
        method POST
    }

    altcha_verify @forms {
        hmac_key {env.ALTCHA_HMAC_KEY}
        session_backend redis://localhost:6379/0
        challenge_redirect /captcha
        preserve_post_data true
    }

    # Layer 5: Rate limiting on form submissions
    @forms_rate {
        path /contact /register /reset-password
        method POST
    }

    handle @forms_rate {
        import rate_limit_forms
        reverse_proxy http://localhost:8080
    }

    # Layer 6: General rate limiting
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

- `altcha_challenge_basic` - Basic challenge endpoint (100k max_number, ~20ms)
- `altcha_challenge_strict` - Strict challenge endpoint (1M max_number, ~200ms)
- `altcha_challenge_page` - Serves ALTCHA widget HTML at /captcha
- `altcha_verify_memory` - Verification with memory:// session backend
- `altcha_verify_redis` - Verification with Redis session backend

#### Caddy-Defender

- `defender_block_ai` - Block all AI bots with 403
- `defender_block_all_ai` - Same as defender_block_ai (explicit ranges)
- `defender_garbage_ai` - Return garbage data to poison AI training
- `defender_redirect_ai` - Redirect AI bots to /ai-bot-notice
- `defender_tarpit_ai` - Slow down AI bot requests
- `defender_drop_ai` - Silently drop AI bot connections

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

## Safe Configuration Management

Caddy validates all configuration files on startup. If any file has errors, Caddy will fail to start. This protects against misconfigurations but can be disruptive if you have multiple sites and one has an error.

### Validation Scripts

This repository includes helper scripts to validate configurations before reloading:

#### validate-config.sh

Validates all site configs individually and reports errors without making changes:

```bash
# Make the script executable
chmod +x validate-config.sh

# Validate all configurations
./validate-config.sh

# With custom paths (example)
SITES_DIR=/sites \
  MAIN_CADDYFILE=/etc/caddy/Caddyfile \
  ./validate-config.sh
```

#### safe-reload.sh

Validates configs, optionally backs up or deletes invalid ones, and reloads Caddy:

```bash
# Make the script executable
chmod +x safe-reload.sh

# Validate and prompt for action
./safe-reload.sh

# Automatically backup invalid configs and reload
./safe-reload.sh --auto-backup

# Automatically delete invalid configs and reload (no prompt)
./safe-reload.sh --auto-delete

# Delete invalid configs with confirmation prompt
./safe-reload.sh --delete

# Show help and all options
./safe-reload.sh --help
```

**Features:**

- ✅ Validates each site config individually
- ✅ Identifies which configs have errors
- ✅ Shows detailed error messages
- ✅ Multiple handling modes: backup, delete with prompt, or auto-delete
- ✅ Detects read-only mounts and adapts behavior
- ✅ Optionally moves invalid configs to backup directory with timestamps
- ✅ Optionally deletes invalid configs (with or without confirmation)
- ✅ Only reloads Caddy if all remaining configs are valid
- ✅ Keeps error logs alongside backups for troubleshooting

**Handling Modes:**

- **No flags** - Validates and reports errors, requires manual action
- **`--auto-backup`** - Automatically moves invalid configs to timestamped backup directory (safest)
- **`--delete`** - Deletes invalid configs after confirmation prompt
- **`--auto-delete`** - Automatically deletes invalid configs without prompt (use with caution)

**When to use each mode:**

- Use **`--auto-backup`** (recommended) when:
  - You want to keep invalid configs for reference
  - You're still developing/testing configurations
  - You need an audit trail of changes
  - You want the safest option with easy rollback

- Use **`--delete`** when:
  - You want to remove invalid configs but verify first
  - You're cleaning up old/unused configs
  - You're confident in your validation but want one last check

- Use **`--auto-delete`** when:
  - You're in an automated CI/CD pipeline
  - Invalid configs are definitely unwanted/obsolete
  - You have version control backups
  - You prioritize speed over safety (not recommended for production)

### Best Practices for Configuration Management

1. **Always Validate Before Deploying**

   ```bash
   # Test locally first
   ./validate-config.sh

   # Deploy only if validation passes
   if ./validate-config.sh; then
       docker-compose restart caddy
   fi
   ```

2. **Use Version Control**

   - Keep all configs in Git
   - Test in a staging environment first
   - Use pull requests for config changes

3. **Gradual Rollout**

   - Deploy one site config at a time
   - Monitor logs after each deployment
   - Keep backups of working configs

4. **Naming Conventions**

   - Use `.example` extension for templates (ignored by Caddy)
   - Use descriptive names: `sitename.caddy` or `sitename.conf`
   - Keep `_snippets.inc` and `_matchers.inc` for shared configs

5. **Testing New Configs**

   ```bash
   # Create a test file
   cp mysite.caddy mysite.caddy.example

   # Edit and test
   vim mysite.caddy.example
   ./validate-config.sh

   # When ready, activate it
   mv mysite.caddy.example mysite.caddy
   ./safe-reload.sh
   ```

6. **Automated Validation in CI/CD**

   ```yaml
   # Example GitHub Actions workflow
   - name: Validate Caddy Configs
     run: |
       chmod +x validate-config.sh
       ./validate-config.sh
   ```

### Handling Configuration Errors

If Caddy fails to start due to configuration errors:

1. **Check the logs** for specific error messages
2. **Use validate-config.sh** to identify which file has errors
3. **Fix the error** or move the file to `.example` extension
4. **Validate again** before restarting Caddy

**Pro Tip:** Set up a cron job to automatically validate configs:

```bash
# Add to crontab to validate configs daily
0 2 * * * /path/to/validate-config.sh && echo "Configs valid" || echo "Config errors detected!" | mail -s "Caddy Config Alert" admin@example.com
```

### Working with Read-Only Mounts

When using Docker with read-only volume mounts (`:ro`), the validation scripts detect this and adapt their behavior:

**Validation Script** (`validate-config.sh`)

- ✅ Works perfectly with read-only mounts
- Reports errors without attempting to modify files
- Provides guidance on fixing issues at the source

**Safe Reload Script** (`safe-reload.sh`)

- ✅ Detects read-only mounts automatically
- ❌ Cannot use `--auto-backup`, `--delete`, or `--auto-delete` flags (require write access)
- Provides clear error messages and remediation steps

#### Recommended Workflow for Read-Only Mounts

1. **Development/Testing:**

   ```bash
   # On your development machine (with write access)
   vim sites/mysite.caddy
   ./validate-config.sh

   # Fix any errors before committing
   git add sites/mysite.caddy
   git commit -m "Update site config"
   git push
   ```

2. **Production Deployment:**

   ```bash
   # Pull latest configs
   git pull

   # Validate before deploying
   ./validate-config.sh

   # If validation passes, deploy
   docker-compose up -d --force-recreate
   ```

3. **In Docker Compose:**

   ```yaml
   services:
     caddy:
       image: caddy-custom
       volumes:
         # Read-only mount prevents accidental modifications
         - ./sites:/sites:ro
         - caddy_data:/data
         - caddy_config:/config
   ```

4. **Handling Errors with Read-Only Mounts:**

   If `validate-config.sh` finds errors:

   ```bash
   # The script will output something like:
   # "Sites directory is read-only. To fix:"
   # "1. Fix the errors in your source repository"
   # "2. Commit and push the changes"
   # "3. Redeploy/remount the updated configs"

   # Fix in your source
   vim sites/problematic-site.caddy

   # Validate locally
   ./validate-config.sh

   # Commit and deploy
   git commit -am "Fix config errors"
   git push

   # On server: pull and restart
   git pull && docker-compose restart caddy
   ```

5. **CI/CD Pipeline Integration:**

   ```yaml
   # .github/workflows/deploy-caddy.yml
   name: Deploy Caddy Configs

   on:
     push:
       branches: [main]
       paths:
         - 'sites/**'

   jobs:
     validate-and-deploy:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v3

         - name: Validate Caddy Configs
           run: |
             chmod +x validate-config.sh
             ./validate-config.sh

         - name: Deploy to Production
           if: success()
           run: |
             # Your deployment commands here
             ssh production "cd /app && git pull && docker-compose restart caddy"
   ```

**Benefits of Read-Only Mounts:**

- ✅ Prevents accidental modifications in production
- ✅ Enforces GitOps workflow (all changes via source control)
- ✅ Clear audit trail of all configuration changes
- ✅ Easy rollback via Git
- ✅ Consistency across environments

**Trade-offs:**

- ❌ Cannot use `--auto-backup`, `--delete`, or `--auto-delete` flags
- ❌ Must fix errors at source and redeploy
- ℹ️ Slightly longer feedback loop for config changes

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
