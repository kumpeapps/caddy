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
else
    # Running in dev container or locally
    DEFAULT_SITES_DIR="/workspaces/caddy/sites"
    DEFAULT_CADDYFILE="/workspaces/caddy/Caddyfile"
    DEFAULT_SNIPPETS_DIR="/workspaces/caddy/sites"
fi

CADDY_BINARY="${CADDY_BINARY:-caddy}"
SITES_DIR="${SITES_DIR:-$DEFAULT_SITES_DIR}"
MAIN_CADDYFILE="${MAIN_CADDYFILE:-$DEFAULT_CADDYFILE}"
SNIPPETS_DIR="${SNIPPETS_DIR:-$DEFAULT_SNIPPETS_DIR}"
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

# Validate each site config individually
if [ -d "$SITES_DIR" ]; then
    echo ""
    echo "Validating individual site configs:"
    echo "-----------------------------------"

    invalid_count=0
    valid_count=0

    # Find all .caddy, .conf files, and files without extensions (excluding hidden files and examples)
    while IFS= read -r -d '' config_file; do
        # Skip example files
        if [[ "$config_file" == *.example ]] || [[ "$config_file" == *_snippets.inc ]] || [[ "$config_file" == *_matchers.inc ]]; then
            continue
        fi

        filename=$(basename "$config_file")
        echo -n "  $filename... "

        # Create a temporary Caddyfile that imports snippets and this config
        cat > "$TEMP_DIR/test.Caddyfile" <<EOF
{
    # Test validation
}

import $SNIPPETS_DIR/_snippets.inc
import $SNIPPETS_DIR/_matchers.inc
import $config_file
EOF

        if "$CADDY_BINARY" validate --config "$TEMP_DIR/test.Caddyfile" --adapter caddyfile 2>"$TEMP_DIR/error.log"; then
            echo -e "${GREEN}✓ Valid${NC}"
            ((valid_count++))
        else
            echo -e "${RED}✗ Invalid${NC}"
            echo -e "${YELLOW}    Error details:${NC}"
            sed 's/^/    /' "$TEMP_DIR/error.log"
            echo ""
            ((invalid_count++))
        fi
    done < <(find "$SITES_DIR" -type f \( -name "*.caddy" -o -name "*.conf" -o ! -name "*.*" \) -print0 2>/dev/null)

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
