# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.1.0] - 2026-10-17

### Added

- HTTPS beacon on `nginx:1.28-alpine` answering `200 ok` on `/` over TLS 1.2/1.3 with HTTP/2.
- Self-signed RSA-4096 certificate (CN + SAN from `BEACON_CN`, `CERT_DAYS` validity) generated on
  first start and reused on every later start; SHA-256 fingerprint logged at each start.
- Configuration via `BEACON_CN`, `CERT_DAYS`, `LISTEN_PORT`, `CERT_DIR` (container) and
  `BEACON_BIND`, `BEACON_PORT` (compose).
- `bin/verify` test harness and `bin/fingerprint` helper.
- Multi-arch image (`linux/amd64`, `linux/arm64`) published to `ghcr.io/rojosinalma/warp-beacon`.

[Unreleased]: https://github.com/rojosinalma/warp-beacon/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/rojosinalma/warp-beacon/releases/tag/v0.1.0
