# warp-beacon

[![run-tests](https://github.com/rojosinalma/warp-beacon/actions/workflows/run-tests.yml/badge.svg)](https://github.com/rojosinalma/warp-beacon/actions/workflows/run-tests.yml)
[![publish-image](https://github.com/rojosinalma/warp-beacon/actions/workflows/publish-image.yml/badge.svg)](https://github.com/rojosinalma/warp-beacon/actions/workflows/publish-image.yml)
[![License: AGPL-3.0](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)

A [managed network](https://developers.cloudflare.com/cloudflare-one/team-and-resources/devices/cloudflare-one-client/configure/managed-networks/)
beacon for Cloudflare WARP: a tiny HTTPS endpoint that serves `200 ok` with one fixed, long-lived
self-signed certificate.

Cloudflare Zero Trust lets you pin the SHA-256 fingerprint of a TLS endpoint as a "managed network".
Whenever a device's network changes, the WARP client probes that `host:port`; if it answers and the
certificate matches, the client knows it is on that network and applies the device profile you
attached to it — for example one that keeps LAN traffic off the tunnel while you are at home, and
routes it through the tunnel everywhere else.

This container is the endpoint. It proxies nothing, authenticates nobody and stores no data; its
only job is to present the same certificate, on the same address, for years. The certificate is
generated once on first start and reused forever after.

## Requirements

1. Docker 24+ with Compose v2 (or any OCI runtime).
2. A Cloudflare Zero Trust account with WARP clients enrolled.
3. A host that is only reachable from the network you want to detect (a LAN IP, a private VLAN).
   The point of the check is that the beacon does *not* answer from anywhere else.

## Installation

```sh
git clone https://github.com/rojosinalma/warp-beacon.git
cd warp-beacon
cp .env.example .env     # set BEACON_BIND to the host's LAN IP, BEACON_PORT if 3333 is taken
docker compose up -d
```

The image is multi-arch (`linux/amd64`, `linux/arm64`) at `ghcr.io/rojosinalma/warp-beacon`.

Read the fingerprint from the first start:

```sh
docker compose logs warp-beacon | grep Fingerprint
# or from any machine on the same network:
bin/fingerprint 192.168.1.10:3333
```

Then in Zero Trust: **Settings → WARP Client → Device settings → Managed networks → Add**:

1. Name the network (e.g. `Home`).
2. Host and port: the beacon's LAN IP and published port, e.g. `192.168.1.10:3333`.
3. TLS certificate SHA-256: the fingerprint from above (hex, no colons).

Create (or edit) a **device profile** whose match expression is `network == "Home"` and give it
the split-tunnel settings you want while on that network. Device profiles are evaluated top-down;
place it above the default.

Two Cloudflare rules worth knowing:

1. The WARP client always excludes the beacon's IP from the tunnel so the probe reaches it
   directly. In **Include** mode, a split-tunnel entry that *contains* the beacon IP is dropped
   whole — split a `/24` into the CIDRs around the single address instead.
2. The certificate must carry a Common Name **and** a Subject Alternative Name; the entrypoint
   generates both from `BEACON_CN`.

## Usage

Environment variables (all optional):

| Variable | Default | Where | Meaning |
|---|---|---|---|
| `BEACON_BIND` | `0.0.0.0` | compose | Host interface the port is published on; use the LAN IP |
| `BEACON_PORT` | `3333` | compose | Host port; `host:port` in Zero Trust |
| `BEACON_CN` | `warp-beacon.internal` | container | CN and SAN of the generated certificate |
| `CERT_DAYS` | `3650` | container | Validity of the generated certificate, in days |
| `LISTEN_PORT` | `443` | container | Port nginx listens on inside the container |
| `CERT_DIR` | `/certs` | container | Where `cert.pem` and `key.pem` live |

The certificate pair lives in `./certs` (bind-mounted to `CERT_DIR`) and is **the beacon's
identity**. Back it up or at least keep the fingerprint: if `cert.pem`/`key.pem` are lost, the
next start generates a new pair with a new fingerprint and every device stops detecting the
network until you update the value in Zero Trust. Changing `BEACON_CN` or `CERT_DAYS` after the
first start has no effect on an existing certificate.

Every start logs the active fingerprint:

```
[cert] reusing existing certificate /certs/cert.pem
[cert] subject: CN=warp-beacon.internal
[cert] expires: Oct 14 12:42:59 2036 GMT
[cert] SHA256 Fingerprint=8511F52B…
[nginx] listening on port 443
```

`GET /` on the published port returns `200` with body `ok`. Any TCP or HTTPS monitor works as a
health check; the container also ships a Docker `HEALTHCHECK`.

## Development

```sh
bin/verify            # shellcheck, build, 200 check, logged == served fingerprint, idempotent restart, healthcheck
bin/fingerprint       # fingerprint of a running beacon (default 127.0.0.1:3333)
```

Layout: `entrypoint.sh` (certificate + nginx), `nginx.conf.template` (rendered with `envsubst`),
`Dockerfile`, `compose.yaml`, `bin/`. Design notes in [docs/SDD.md](docs/SDD.md); how to
contribute in [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[AGPL-3.0](LICENSE).
