FROM caddy:builder AS builder
# Plugin versions pinned for reproducibility
# Update these periodically to get security fixes and new features
RUN xcaddy build \
    --with github.com/caddy-dns/cloudns@v0.0.6 \
    --with github.com/mholt/caddy-ratelimit@v1.10.2 \
    --with github.com/altcha-org/caddy-altcha@latest \
    --with github.com/hlts2/caddy-defender@latest

FROM caddy:latest
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
