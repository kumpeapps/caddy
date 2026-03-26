# Custom Error Pages

Professional, responsive error pages with modern design inspired by BunkerWeb.

## Available Error Pages

- **404.html** - Page or domain not found
- **502.html** - Bad Gateway (upstream server error)
- **503.html** - Service Unavailable (maintenance/high load)
- **504.html** - Gateway Timeout (upstream server timeout)

## Features

- 📱 **Fully responsive** - Works on all device sizes
- 🎨 **Modern gradient design** - Each error has a unique color scheme
- 🔄 **"Try Again" button** - Easy refresh functionality
- 💡 **User-friendly guidance** - Clear explanations and suggestions
- ⚡ **Zero dependencies** - All CSS is inline, no external resources needed

## Usage in Caddyfile

### Option 1: Backend Errors Only (Recommended)

Use this for sites with reverse proxy to show custom pages when the backend is down:

```caddyfile
example.com {
    import error_pages_backend
    reverse_proxy localhost:8080
}
```

### Option 2: All Error Codes

Use this to handle all common errors including 404:

```caddyfile
example.com {
    import error_pages_all
    reverse_proxy localhost:8080
}
```

### Option 3: Only 404 Errors

Use this separately if you want different handling for 404:

```caddyfile
example.com {
    import error_pages_404
    reverse_proxy localhost:8080
}
```

## Unconfigured Domains

The fallback handler (`000-fallback.caddy`) automatically shows the 404 error page for any domain not explicitly configured in your Caddy setup.

## Customization

Each error page is a standalone HTML file with inline CSS. To customize:

1. Edit the HTML files in this directory
2. Modify the gradient colors, text, or styles
3. Rebuild the Docker image to include your changes

## Color Schemes

- **404** - Blue gradient (`#4facfe` → `#00f2fe`)
- **502** - Purple gradient (`#667eea` → `#764ba2`)
- **503** - Pink gradient (`#f093fb` → `#f5576c`)
- **504** - Orange gradient (`#fa709a` → `#fee140`)

## Technical Details

- Location in container: `/usr/local/share/caddy/error-pages/`
- Served via: `file_server` directive
- Content-Type: `text/html; charset=utf-8` (automatic)
- No external dependencies or CDN links
