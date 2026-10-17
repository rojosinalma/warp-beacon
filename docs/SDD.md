# warp-beacon — software design document

## Purpose

Give Cloudflare WARP clients a way to tell whether they are on a specific physical network.
Zero Trust "managed networks" work by pinning the SHA-256 fingerprint of a TLS certificate served
at a `host:port`; the client probes it on every network change and, on a match, applies the device
profile bound to that network. warp-beacon is that TLS endpoint: one certificate, one address, for
years, nothing else.

Typical use: a device profile for "at home" that excludes the LAN from the tunnel so local
services (and protocols whose packets exceed the tunnel MTU) are reached directly, while the
default profile elsewhere routes everything through WARP.

## Components

| Component | Role |
|---|---|
| `entrypoint.sh` | POSIX sh. Ensures a certificate pair exists (generate once, else reuse), logs subject, expiry and fingerprint, renders the nginx config, `exec`s nginx |
| `nginx.conf.template` | one `server` block: `listen ${LISTEN_PORT} ssl`, HTTP/2, TLS 1.2+1.3 with nginx defaults, `return 200 'ok'`, access log off |
| `Dockerfile` | `nginx:1.28-alpine` + `openssl`; `HEALTHCHECK` curls `https://127.0.0.1:${LISTEN_PORT}/` |
| `compose.yaml` | publishes `${BEACON_BIND}:${BEACON_PORT}` → `443`, mounts `./certs:/certs` |
| `bin/verify` | test harness (see CONTRIBUTING) |
| `bin/fingerprint` | reads the fingerprint of a live beacon |

There is no application code: nginx's `return` directive is the whole HTTP layer.

## Certificate lifecycle

1. First start: `CERT_DIR` has no `cert.pem`/`key.pem` → `openssl req -x509 -newkey rsa:4096
   -sha256 -days CERT_DAYS -subj /CN=BEACON_CN -addext subjectAltName=DNS:BEACON_CN`. Key `0600`,
   cert `0644`, both owned by `nginx`.
2. Every start: both files present → reused unchanged. `BEACON_CN`/`CERT_DAYS` are ignored from
   now on. The fingerprint (`SHA256 Fingerprint=<hex>`, uppercase, no colons) is logged.
3. Exactly one file present → the entrypoint refuses to start rather than silently regenerate.
4. Rotation is a manual act: delete both files, restart, enter the new fingerprint in Zero Trust.
   The default validity of ten years is chosen so this is rare.

Cloudflare's requirements the certificate meets: CN and SAN set, SHA-256 signature, served on the
configured port by a server that completes a handshake with the WARP client's TLS stack (nginx
defaults, TLS 1.2/1.3, no exotic cipher restrictions).

## How WARP uses it

1. In Zero Trust a managed network is defined as `host:port` + certificate SHA-256.
2. A device profile matches `network == "<name>"` and sits above the default profile.
3. On a network change the client sends a TLS handshake to `host:port` and compares the leaf
   certificate's fingerprint. Match → that profile; no answer or mismatch → next profile.
4. The client always excludes the beacon IP from the tunnel so the probe is direct. In Include-mode
   split tunnels a CIDR containing the beacon IP is dropped whole, so the operator splits the range
   around it.

Because the beacon only answers on the LAN, reachability itself is the proof of presence; the
pinned certificate stops anyone from faking that proof with another server on another network.

## Configuration surface

| Variable | Default | Effect |
|---|---|---|
| `BEACON_CN` | `warp-beacon.internal` | CN/SAN at generation time |
| `CERT_DAYS` | `3650` | validity at generation time |
| `LISTEN_PORT` | `443` | nginx listen port inside the container |
| `CERT_DIR` | `/certs` | certificate directory |
| `BEACON_BIND`, `BEACON_PORT` | `0.0.0.0`, `3333` | compose publish address |

No database, no settings file, no secrets beyond the private key.

## Decisions

- **nginx + shell, no application runtime.** The only logic is "generate a certificate once";
  an interpreter would add size and attack surface without adding behaviour.
- **Self-signed, RSA-4096, 10 years.** Cloudflare pins the fingerprint, not a chain; a CA would
  add nothing and a short validity would force re-pinning. RSA over ECDSA for the broadest client
  compatibility.
- **Reuse is unconditional.** The fingerprint is the beacon's identity; code never rewrites it.
- **Root entrypoint, unprivileged workers.** The entrypoint runs as root to write into a bind
  mount on first start, then nginx drops its workers to the `nginx` user. Simpler and more
  portable than fixing host directory ownership before the first run.
- **No reverse proxy, no auth, no routes.** Putting the beacon behind a TLS-terminating proxy
  would replace the pinned certificate with the proxy's rotating one and break detection.
- **Access log off.** The client probes on every network change; the log would only record that.

## Current scope

One certificate, one listener, HTTP/2 over TLS 1.2/1.3, IPv4 and IPv6 inside the container.
Multi-arch image (`amd64`, `arm64`).

## Operations

- Health: `GET /` → `200` on the published port; Docker `HEALTHCHECK` built in. Any TCP or HTTPS
  monitor works.
- Logs: stdout, `[cert]` and `[nginx]` prefixes; nginx notices and errors follow.
- Backup: `certs/` (or just the fingerprint — losing the pair means re-pinning, not data loss).
- Upgrade: pull the new image tag, `docker compose up -d`; the certificate directory is untouched.
