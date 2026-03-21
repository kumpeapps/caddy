#!/bin/bash
# Safe Caddy Reload Script
# This script validates configs, moves invalid ones to backup, and reloads Caddy
# Usage: ./safe-reload.sh [--auto-backup|--auto-delete|--delete]

set -euo pipefail

CADDY_BINARY="${CADDY_BINARY:-caddy}"
SITES_DIR="${SITES_DIR:-/workspaces/caddy/sites}"
BACKUP_DIR="${BACKUP_DIR:-/workspaces/caddy/sites-backup}"
MAIN_CADDYFILE="${MAIN_CADDYFILE:-/workspaces/caddy/Caddyfile}"
AUTO_BACKUP=false
AUTO_DELETE=false
DELETE_PROMPT=false
TEMP_DIR=$(mktemp -d)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-backup)
            AUTO_BACKUP=true
            shift
            ;;
        --auto-delete)
            AUTO_DELETE=true
            shift
            ;;
        --delete)
            DELETE_PROMPT=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --auto-backup    Automatically move invalid configs to backup directory"
            echo "  --auto-delete    Automatically delete invalid configs (no prompt)"
            echo "  --delete         Delete invalid configs (with confirmation prompt)"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  CADDY_BINARY     Path to caddy binary (default: caddy)"
            echo "  SITES_DIR        Path to sites directory (default: /workspaces/caddy/sites)"
            echo "  BACKUP_DIR       Path to backup directory (default: /workspaces/caddy/sites-backup)"
            echo "  MAIN_CADDYFILE   Path to main Caddyfile (default: /workspaces/caddy/Caddyfile)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check for conflicting options
if [[ "$AUTO_BACKUP" == true && "$AUTO_DELETE" == true ]]; then
    echo "Error: Cannot use both --auto-backup and --auto-delete"
    exit 1
fi

if [[ "$AUTO_BACKUP" == true && "$DELETE_PROMPT" == true ]]; then
    echo "Error: Cannot use both --auto-backup and --delete"
    exit 1
fi

if [[ "$AUTO_DELETE" == true && "$DELETE_PROMPT" == true ]]; then
    echo "Error: Cannot use both --auto-delete and --delete"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

echo -e "${BLUE}Safe Caddy Reload${NC}"
echo "=================================="

# Check if sites directory is read-only
IS_READONLY=false
if check_readonly; then
    IS_READONLY=true
    echo -e "${YELLOW}Note: Sites directory is read-only${NC}"

    if [ "$AUTO_BACKUP" = true ] || [ "$AUTO_DELETE" = true ] || [ "$DELETE_PROMPT" = true ]; then
        echo -e "${RED}ERROR: Cannot modify files with read-only mounts${NC}"
        echo "With read-only mounts, invalid configs must be fixed at the source."
        echo "Run without flags to validate and report errors only."
        exit 1
    fi
    echo ""
fi

# Create backup directory if it doesn't exist (only for writable mounts)
if [ "$IS_READONLY" = false ]; then
    mkdir -p "$BACKUP_DIR"
fi

# Validate main Caddyfile
echo -n "Validating main Caddyfile... "
if ! "$CADDY_BINARY" validate --config "$MAIN_CADDYFILE" --adapter caddyfile 2>"$TEMP_DIR/main_error.log"; then
    echo -e "${RED}✗ FAILED${NC}"
    echo "Main Caddyfile has critical errors:"
    cat "$TEMP_DIR/main_error.log"
    echo ""
    echo -e "${RED}Cannot proceed. Fix main Caddyfile first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Valid${NC}"

# Validate individual site configs
if [ ! -d "$SITES_DIR" ]; then
    echo "Sites directory not found: $SITES_DIR"
    exit 0
fi

echo ""
echo "Validating site configs..."
echo "-----------------------------------"

declare -a invalid_configs=()
declare -a valid_configs=()

while IFS= read -r -d '' config_file; do
    # Skip example files and snippets
    if [[ "$config_file" == *.example ]] || \
       [[ "$config_file" == *_snippets.inc ]] || \
       [[ "$config_file" == *_matchers.inc ]]; then
        continue
    fi

    filename=$(basename "$config_file")
    echo -n "  $filename... "

    # Create temporary test Caddyfile
    cat > "$TEMP_DIR/test.Caddyfile" <<EOF
{
    # Test validation
}

import $SITES_DIR/_snippets.inc
import $SITES_DIR/_matchers.inc
import $config_file
EOF

    if "$CADDY_BINARY" validate --config "$TEMP_DIR/test.Caddyfile" --adapter caddyfile 2>"$TEMP_DIR/${filename}.error"; then
        echo -e "${GREEN}✓ Valid${NC}"
        valid_configs+=("$config_file")
    else
        echo -e "${RED}✗ Invalid${NC}"
        invalid_configs+=("$config_file")
        # Store error for later display
        cp "$TEMP_DIR/${filename}.error" "$TEMP_DIR/${filename}.stored_error"
    fi
done < <(find "$SITES_DIR" -maxdepth 1 -type f \( -name "*.caddy" -o -name "*.conf" \) -print0 2>/dev/null)

echo ""
echo "=================================="
echo "Results:"
echo "  Valid configs: ${#valid_configs[@]}"
echo "  Invalid configs: ${#invalid_configs[@]}"

# Handle invalid configs
if [ ${#invalid_configs[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Invalid Configurations:${NC}"
    for config in "${invalid_configs[@]}"; do
        filename=$(basename "$config")
        echo -e "  ${RED}✗${NC} $filename"
        if [ -f "$TEMP_DIR/${filename}.stored_error" ]; then
            sed 's/^/    /' "$TEMP_DIR/${filename}.stored_error"
        fi
        echo ""
    done

    if [ "$IS_READONLY" = true ]; then
        echo -e "${RED}Cannot proceed with read-only mount.${NC}"
        echo ""
        echo "With read-only mounts, you must:"
        echo "  1. Fix the errors in your source repository"
        echo "  2. Commit and push the changes"
        echo "  3. Redeploy/remount the updated configs"
        echo "  4. Run this script again"
        echo ""
        echo "Alternatively, to temporarily exclude these configs:"
        echo "  - Rename them to *.example in your source"
        echo "  - Remove them from your source"
        echo "  - Use import globs that exclude them"
        exit 1
    elif [ "$AUTO_BACKUP" = true ]; then
        echo -e "${YELLOW}Auto-backup enabled. Moving invalid configs...${NC}"
        timestamp=$(date +%Y%m%d_%H%M%S)

        for config in "${invalid_configs[@]}"; do
            filename=$(basename "$config")
            backup_path="$BACKUP_DIR/${timestamp}_${filename}"
            mv "$config" "$backup_path"
            echo -e "  Moved: $filename → $(basename "$backup_path")"

            # Save error log alongside backup
            if [ -f "$TEMP_DIR/${filename}.stored_error" ]; then
                cp "$TEMP_DIR/${filename}.stored_error" "$backup_path.error"
            fi
        done
        echo ""
    elif [ "$AUTO_DELETE" = true ]; then
        echo -e "${RED}Auto-delete enabled. Deleting invalid configs...${NC}"

        for config in "${invalid_configs[@]}"; do
            filename=$(basename "$config")
            rm -f "$config"
            echo -e "  ${RED}Deleted:${NC} $filename"
        done
        echo ""
        echo -e "${YELLOW}Warning: ${#invalid_configs[@]} config(s) were permanently deleted${NC}"
    elif [ "$DELETE_PROMPT" = true ]; then
        echo ""
        echo -e "${YELLOW}Delete invalid configs?${NC}"
        echo -e "${RED}WARNING: This action cannot be undone!${NC}"
        echo ""
        echo "Invalid configs:"
        for config in "${invalid_configs[@]}"; do
            echo "  - $(basename "$config")"
        done
        echo ""
        read -p "Delete these files? [y/N]: " -n 1 -r
        echo ""

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${RED}Deleting invalid configs...${NC}"

            for config in "${invalid_configs[@]}"; do
                filename=$(basename "$config")
                rm -f "$config"
                echo -e "  ${RED}Deleted:${NC} $filename"
            done
            echo ""
        else
            echo "Deletion cancelled. Invalid configs were not removed."
            echo ""
            echo "Options:"
            echo "  1. Run with --auto-backup to move invalid configs to backup"
            echo "  2. Run with --auto-delete to delete without prompting"
            echo "  3. Manually fix or remove invalid configs"
            echo "  4. Rename them to *.example to exclude from loading"
            exit 1
        fi
    else
        echo -e "${YELLOW}Invalid configs found but auto-backup disabled.${NC}"
        echo "Options:"
        echo "  1. Run with --auto-backup to automatically move invalid configs"
        echo "  2. Run with --auto-delete to automatically delete invalid configs"
        echo "  3. Run with --delete to delete with confirmation prompt"
        echo "  4. Manually fix or remove invalid configs"
        echo "  5. Rename them to *.example to exclude from loading"
        exit 1
    fi
fi

# Reload Caddy
echo "Reloading Caddy..."
if "$CADDY_BINARY" reload --config "$MAIN_CADDYFILE" --adapter caddyfile; then
    echo -e "${GREEN}✓ Caddy reloaded successfully!${NC}"

    if [ ${#invalid_configs[@]} -gt 0 ]; then
        echo ""
        if [ "$AUTO_BACKUP" = true ]; then
            echo -e "${YELLOW}Note: ${#invalid_configs[@]} config(s) were backed up and excluded${NC}"
            echo "Backup location: $BACKUP_DIR"
        elif [ "$AUTO_DELETE" = true ] || [ "$DELETE_PROMPT" = true ]; then
            echo -e "${YELLOW}Note: ${#invalid_configs[@]} config(s) were deleted${NC}"
        fi
    fi
else
    echo -e "${RED}✗ Caddy reload failed${NC}"
    exit 1
fi
