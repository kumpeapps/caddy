#!/bin/bash
# Caddy Configuration Validator
# This script validates individual Caddy site configs before reloading
# to prevent one bad config from crashing the entire system.

set -euo pipefail

# Auto-detect if running in Docker container vs dev container
if [ -f "/.dockerenv" ] && [ -d "/sites" ]; then
    # Running in Docker container
    DEFAULT_SITES_DIR="/sites"
    DEFAULT_CADDYFILE="/etc/caddy/Caddyfile"
    DEFAULT_SNIPPETS_DIR="/usr/local/share/caddy"
    ADDITIONAL_SITES_DIRS="/home/kumpeapps-bot-deploy/caddy-sites"
else
    # Running in dev container or locally
    DEFAULT_SITES_DIR="/workspaces/caddy/sites"
    DEFAULT_CADDYFILE="/workspaces/caddy/Caddyfile"
    DEFAULT_SNIPPETS_DIR="/workspaces/caddy/sites"
    ADDITIONAL_SITES_DIRS=""
fi

CADDY_BINARY="${CADDY_BINARY:-caddy}"
SITES_DIR="${SITES_DIR:-$DEFAULT_SITES_DIR}"
MAIN_CADDYFILE="${MAIN_CADDYFILE:-$DEFAULT_CADDYFILE}"
SNIPPETS_DIR="${SNIPPETS_DIR:-$DEFAULT_SNIPPETS_DIR}"
# Space-separated list of additional directories to validate
EXTRA_DIRS="${EXTRA_DIRS:-$ADDITIONAL_SITES_DIRS}"
TEMP_DIR=$(mktemp -d)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if sites directory is read-only
check_readonly() {
    if [ -d "$SITES_DIR" ]; then
        touch "$SITES_DIR/.writetest" 2>/dev/null
        if [ $? -eq 0 ]; then
            rm -f "$SITES_DIR/.writetest"
            return 1  # writable
        else
            return 0  # read-only
        fi
    fi
    return 1  # assume writable if dir doesn't exist
}

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

echo "Validating Caddy configuration..."
echo "=================================="

# Check if sites directory is read-only
IS_READONLY=false
if check_readonly; then
    IS_READONLY=true
    echo -e "${BLUE}Note: Sites directory is read-only${NC}"
    echo ""
fi

# Validate main Caddyfile
echo -n "Checking main Caddyfile... "
if "$CADDY_BINARY" validate --config "$MAIN_CADDYFILE" --adapter caddyfile 2>/dev/null; then
    echo -e "${GREEN}✓ Valid${NC}"
else
    echo -e "${RED}✗ Invalid${NC}"
    echo "Main Caddyfile has errors. Running detailed validation:"
    "$CADDY_BINARY" validate --config "$MAIN_CADDYFILE" --adapter caddyfile
    exit 1
fi

# Build array of directories to validate
DIRS_TO_VALIDATE=()
if [ -d "$SITES_DIR" ]; then
    DIRS_TO_VALIDATE+=("$SITES_DIR")
fi

# Add additional directories if they exist
if [ -n "$EXTRA_DIRS" ]; then
    for dir in $EXTRA_DIRS; do
        if [ -d "$dir" ]; then
            DIRS_TO_VALIDATE+=("$dir")
        fi
    done
fi

# Validate each site config individually
if [ ${#DIRS_TO_VALIDATE[@]} -gt 0 ]; then
    echo ""
    echo "Validating individual site configs:"
    echo "-----------------------------------"

    invalid_count=0
    valid_count=0

    for dir in "${DIRS_TO_VALIDATE[@]}"; do
        echo ""
        echo "Directory: $dir"

        # Find all .caddy, .conf files, and files without extensions (excluding hidden files and examples)
        while IFS= read -r -d '' config_file; do
            # Skip example files
            if [[ "$config_file" == *.example ]] || [[ "$config_file" == *_snippets.inc ]] || [[ "$config_file" == *_matchers.inc ]]; then
                continue
            fi

            filename=$(basename "$config_file")
            echo -n "  $filename... "

        # Copy snippet files to temp directory so relative imports work
        cp "$SNIPPETS_DIR/_snippets.inc" "$TEMP_DIR/" 2>/dev/null || true
        cp "$SNIPPETS_DIR/_matchers.inc" "$TEMP_DIR/" 2>/dev/null || true

        # Copy the site config to temp directory (so imports are relative to same dir)
        cp "$config_file" "$TEMP_DIR/"

        # Create a temporary Caddyfile that imports everything
        # Include auto_error_pages snippet definition from main Caddyfile
        cat > "$TEMP_DIR/test.Caddyfile" <<EOF
{
    # Test validation
}

# Auto error pages snippet (from main Caddyfile)
(auto_error_pages) {
    handle_errors {
        @404 expression \{http.error.status_code} == 404
        @502 expression \{http.error.status_code} == 502
        @503 expression \{http.error.status_code} == 503
        @504 expression \{http.error.status_code} == 504

        handle @404 {
            rewrite * /404.html
            root * /usr/local/share/caddy/error-pages
            file_server
        }

        handle @502 {
            rewrite * /502.html
            root * /usr/local/share/caddy/error-pages
            file_server
        }

        handle @503 {
            rewrite * /503.html
            root * /usr/local/share/caddy/error-pages
            file_server
        }

        handle @504 {
            rewrite * /504.html
            root * /usr/local/share/caddy/error-pages
            file_server
        }
    }
}

import _snippets.inc
import $(basename "$config_file")
EOF

        if "$CADDY_BINARY" validate --config "$TEMP_DIR/test.Caddyfile" --adapter caddyfile 2>"$TEMP_DIR/error.log"; then
            echo -e "${GREEN}✓ Valid${NC}"
            ((valid_count++)) || true
        else
            echo -e "${RED}✗ Invalid${NC}"
            echo -e "${YELLOW}    Error details:${NC}"
            sed 's/^/    /' "$TEMP_DIR/error.log"
            echo ""
            ((invalid_count++))
        fi
        done < <(find "$dir" -type f \( -name "*.caddy" -o -name "*.conf" -o ! -name "*.*" \) -print0 2>/dev/null)
    done

    echo ""
    echo "=================================="
    echo "Summary:"
    echo "  Valid configs: $valid_count"
    echo "  Invalid configs: $invalid_count"

    if [ $invalid_count -gt 0 ]; then
        echo ""
        echo -e "${RED}WARNING: Some site configs have errors!${NC}"

        if [ "$IS_READONLY" = true ]; then
            echo ""
            echo -e "${YELLOW}Sites directory is read-only. To fix:${NC}"
            echo "  1. Fix the errors in your source repository"
            echo "  2. Commit and push the changes"
            echo "  3. Redeploy/remount the updated configs"
            echo ""
            echo "Invalid configs will be skipped when Caddy loads."
        else
            echo "These configs will be skipped when Caddy loads."
            echo ""
            echo "To exclude invalid configs from loading:"
            echo "  1. Move them to a backup directory"
            echo "  2. Rename them to have .example extension"
            echo "  3. Fix the errors and re-validate"
        fi
        exit 1
    else
        echo -e "${GREEN}All configurations are valid!${NC}"
    fi
else
    echo "Sites directory not found: $SITES_DIR"
fi

echo ""
echo "Ready to reload Caddy safely."
exit 0
