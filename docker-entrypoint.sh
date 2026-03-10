#!/bin/sh
set -eu

sites_dir="${CADDY_SITES_DIR:-/sites}"
example_src="/usr/local/share/caddy/caddy.example"
example_dst="${sites_dir}/caddy.example"

mkdir -p "${sites_dir}"

# Keep a default example config available, especially for newly mounted /sites volumes.
if [ ! -f "${example_dst}" ]; then
    cp "${example_src}" "${example_dst}"
fi

if [ "$#" -eq 0 ]; then
    set -- caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
fi

exec "$@"
