FROM nginx:1.29-alpine

LABEL org.opencontainers.image.source="https://github.com/rojosinalma/warp-beacon" \
      org.opencontainers.image.description="Cloudflare WARP managed-network beacon: HTTPS endpoint with one fixed self-signed certificate" \
      org.opencontainers.image.licenses="AGPL-3.0-only"

# openssl generates the certificate on first start; envsubst and curl ship with the base image.
RUN apk add --no-cache openssl \
 && rm -f /etc/nginx/conf.d/default.conf \
 && mkdir -p /certs \
 && chown nginx:nginx /certs

ENV BEACON_CN=warp-beacon.internal \
    LISTEN_PORT=443 \
    CERT_DAYS=3650 \
    CERT_DIR=/certs

COPY nginx.conf.template /etc/nginx/templates/beacon.conf.template
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

VOLUME ["/certs"]
EXPOSE 443

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -ksSf -o /dev/null "https://127.0.0.1:${LISTEN_PORT}/" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
