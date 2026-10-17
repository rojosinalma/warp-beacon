# Security policy

## Reporting a vulnerability

Report privately through
[GitHub Security Advisories](https://github.com/rojosinalma/warp-beacon/security/advisories/new)
(the **Security** tab → *Report a vulnerability*). Do not open a public issue. You will get an
acknowledgement within a week and a fix or a statement before any public disclosure.

## Supported versions

Only the latest release receives fixes. Upgrade `ghcr.io/rojosinalma/warp-beacon` to the newest
tag before reporting.

## What the service holds

The beacon has no users, no credentials and no data. The only sensitive file is the private key
in `CERT_DIR/key.pem` (mode `0600`): it signs nothing but this presence certificate, and leaking it
would let someone on another network impersonate the beacon — i.e. make a WARP client believe it
is at home. Keep in mind:

1. Publish the port on a LAN address only. The check is meaningful precisely because the endpoint
   does not answer from the internet or through the tunnel.
2. The certificate's public fingerprint is not a secret; Cloudflare holds it.
3. The container needs no capabilities, no host network and no Docker socket. Mount only the
   certificate directory.
4. nginx workers run as the unprivileged `nginx` user; the entrypoint needs root only to write the
   certificate pair on first start.
