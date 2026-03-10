FROM caddy:builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudns

FROM caddy:latest
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
RUN mkdir -p /sites /usr/local/share/caddy
COPY Caddyfile /etc/caddy/Caddyfile
COPY sites/caddy.example /usr/local/share/caddy/caddy.example
COPY sites/redirect.example /usr/local/share/caddy/redirect.example
COPY docker-entrypoint.sh /usr/bin/docker-entrypoint.sh
RUN chmod +x /usr/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
