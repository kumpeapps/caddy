#!/bin/sh
set -eu

sites_dir="${CADDY_SITES_DIR:-/sites}"
example_src="/usr/local/share/caddy/caddy.example"
example_dst="${sites_dir}/caddy.example"
redirect_src="/usr/local/share/caddy/redirect.example"
redirect_dst="${sites_dir}/redirect.example"

# Check if /sites is writable
if [ -w "${sites_dir}" ] || mkdir -p "${sites_dir}" 2>/dev/null; then
    # Keep a default example config available, especially for newly mounted /sites volumes.
    # Only copy if the directory is writable (not read-only mounted)
    if [ ! -f "${example_dst}" ]; then
        cp "${example_src}" "${example_dst}" 2>/dev/null || echo "Note: /sites is read-only, skipping example file copy"
    fi

    if [ ! -f "${redirect_dst}" ]; then
        cp "${redirect_src}" "${redirect_dst}" 2>/dev/null || echo "Note: /sites is read-only, skipping example file copy"
    fi

    # Create global-assets directory if it doesn't exist
    global_assets_dir="${sites_dir}/global-assets"
    if [ ! -d "${global_assets_dir}" ]; then
        mkdir -p "${global_assets_dir}" 2>/dev/null || echo "Note: Failed to create global-assets directory"
        echo "Created global-assets directory at ${global_assets_dir}"
    fi

    # Auto-inject error handling into site configs that don't already have it
    # This makes error pages automatic without needing manual configuration
    echo "Checking site configs for error handling..."
    for config_file in "${sites_dir}"/*.caddy; do
        # Skip if no .caddy files exist or if it's an example file
        if [ ! -f "$config_file" ] || [ "$config_file" = "${sites_dir}/*.caddy" ]; then
            continue
        fi

        filename=$(basename "$config_file")

        # Skip example files and special configs
        case "$filename" in
            *.example|000-fallback.caddy)
                continue
                ;;
        esac

        # Check if file already has error handling
        if ! grep -q "handle_errors\|import.*error_pages\|import auto_error_pages" "$config_file"; then
            echo "  Adding automatic error handling to: $filename"
            # Create temp file with error handling injected before the closing brace
            # Find the last closing brace and inject error handling before it
            awk '
            /^}$/ && !done {
                print "    # Auto-injected error handling (remove this and add your own if needed)"
                print "    import auto_error_pages"
                print ""
                done=1
            }
            { print }
            ' "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"
        fi
    done
else
    echo "Note: /sites is read-only, skipping example file creation and auto-injection"
fi

if [ "$#" -eq 0 ]; then
    set -- caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
fi

exec "$@"
