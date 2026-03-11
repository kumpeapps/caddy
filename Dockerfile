FROM caddy:2.11.2-builder AS builder
# Plugin versions pinned for reproducibility
# Update these periodically to get security fixes and new features
# Versions last checked: March 11, 2026
RUN xcaddy build \
    --with github.com/caddy-dns/cloudns@v1.1.0 \
    --with github.com/mholt/caddy-ratelimit@v0.1.0 \
    --with github.com/stardothosting/caddy-altcha@e4f123b \
    --with pkg.jsn.cam/caddy-defender=github.com/JasonLovesDoggo/caddy-defender@v0.10.0

FROM caddy:2.11.2
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
RUN mkdir -p /sites /usr/local/share/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY sites/caddy.example /usr/local/share/caddy/caddy.example
COPY sites/redirect.example /usr/local/share/caddy/redirect.example
COPY sites/bot-protection.example /usr/local/share/caddy/bot-protection.example
COPY sites/altcha.example /usr/local/share/caddy/altcha.example
COPY sites/defender.example /usr/local/share/caddy/defender.example
COPY sites/_snippets.inc /usr/local/share/caddy/_snippets.inc
COPY sites/_matchers.inc /usr/local/share/caddy/_matchers.inc
COPY sites/example-with-snippets.caddy.example /usr/local/share/caddy/example-with-snippets.caddy.example
COPY docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
RUN chmod +x /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
