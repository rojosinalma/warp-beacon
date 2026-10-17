#!/bin/sh
# Generate the beacon certificate once, log its fingerprint on every start, then run nginx.
# The certificate is the beacon's identity: Cloudflare pins its SHA-256, so an existing pair
# is always reused. Regenerating it changes the fingerprint and breaks detection.
set -eu

: "${BEACON_CN:=warp-beacon.internal}"
: "${LISTEN_PORT:=443}"
: "${CERT_DAYS:=3650}"
: "${CERT_DIR:=/certs}"
export LISTEN_PORT CERT_DIR

cert="$CERT_DIR/cert.pem"
key="$CERT_DIR/key.pem"

log() { echo "[cert] $*"; }

mkdir -p "$CERT_DIR"

if [ -s "$cert" ] && [ -s "$key" ]; then
  log "reusing existing certificate $cert"
else
  if [ -e "$cert" ] || [ -e "$key" ]; then
    log "error: $CERT_DIR holds an incomplete certificate pair; remove both files to regenerate" >&2
    exit 1
  fi
  log "generating certificate CN=$BEACON_CN valid ${CERT_DAYS}d"
  umask 077
  openssl req -x509 -newkey rsa:4096 -sha256 -days "$CERT_DAYS" -nodes \
    -keyout "$key" -out "$cert" \
    -subj "/CN=$BEACON_CN" \
    -addext "subjectAltName=DNS:$BEACON_CN" 2>/dev/null
  umask 022
  chmod 0644 "$cert"
  chmod 0600 "$key"
fi

# nginx workers run as the unprivileged nginx user and must read the key.
chown nginx:nginx "$cert" "$key" 2>/dev/null || true

log "subject: $(openssl x509 -noout -subject -in "$cert" | sed 's/^subject=//')"
log "expires: $(openssl x509 -noout -enddate -in "$cert" | sed 's/^notAfter=//')"
log "SHA256 Fingerprint=$(openssl x509 -noout -fingerprint -sha256 -in "$cert" | tr -d : | sed 's/.*=//')"

# shellcheck disable=SC2016  # literal variable names are envsubst's allow-list
envsubst '${LISTEN_PORT} ${CERT_DIR}' \
  < /etc/nginx/templates/beacon.conf.template \
  > /etc/nginx/conf.d/default.conf

echo "[nginx] listening on port $LISTEN_PORT"
exec nginx -g 'daemon off;'
