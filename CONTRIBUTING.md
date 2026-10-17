# Contributing

## Running it locally

```sh
cp .env.example .env
docker compose up -d --build        # or: docker build -t warp-beacon . && docker run -p 3333:443 -v "$PWD/certs:/certs" warp-beacon
bin/fingerprint 127.0.0.1:3333
```

`./certs` is created on first start and gitignored. Delete it to get a fresh certificate (and a new
fingerprint).

## Tests

```sh
bin/verify
```

`bin/verify` is what CI runs (`.github/workflows/run-tests.yml`): shellcheck on every script, image
build, a throwaway container that must answer `200`, the served fingerprint must equal the logged
one, a restart on the same certificate directory must keep it, and the Docker healthcheck must go
`healthy`. It uses the local `shellcheck` when present, otherwise `koalaman/shellcheck:stable` via
Docker.

## Code style and layout

Everything is POSIX `sh` (the entrypoint, so it runs on Alpine's BusyBox) or `bash` (`bin/`).
Scripts in `bin/` carry no extension and are executable.

| Path | Content |
|---|---|
| `entrypoint.sh` | certificate generation/reuse, fingerprint log, `envsubst`, `exec nginx` |
| `nginx.conf.template` | the single `server` block; only `${LISTEN_PORT}` and `${CERT_DIR}` are substituted |
| `Dockerfile` | `nginx:<pinned>-alpine` + `openssl`, OCI labels, `HEALTHCHECK` |
| `compose.yaml` | pulls the published image; `BEACON_BIND`/`BEACON_PORT` from `.env` |
| `bin/verify`, `bin/fingerprint` | test harness and operator helper |
| `docs/SDD.md` | design document |

Conventions: every tunable is an environment variable with a default in both `entrypoint.sh` and
`.env.example`; log lines are prefixed `[cert]` or `[nginx]`; an existing certificate is never
touched by code. Keep the image minimal — no additional packages beyond `openssl`.

## Commits and PRs

1. Plain, descriptive commit messages in the imperative, one logical change per commit, no
   attribution trailers.
2. Every commit and tag is GPG-signed (`git config commit.gpgsign true`, `git tag -s`).
3. A PR describes the behaviour change and how it was verified; `bin/verify` must be green.
4. User-visible changes get a line under `[Unreleased]` in `CHANGELOG.md`.
5. Base image bumps are pinned tags (`nginx:1.28-alpine`), never `latest`; Dependabot proposes them.

## Documentation

The README has a fixed shape — badges, description, Requirements, Installation, Usage, Development,
License — and nothing else. Design and decisions live in `docs/SDD.md`.

## Releasing

1. Move the `[Unreleased]` entries in `CHANGELOG.md` under a new `## [X.Y.Z] - YYYY-MM-DD` heading
   and bump the image tag in `compose.yaml`.
2. Commit, then `git tag -s vX.Y.Z -m "vX.Y.Z"` and push the tag.
3. `publish-image.yml` builds and pushes `ghcr.io/rojosinalma/warp-beacon:{X.Y.Z, X.Y, latest, sha-<short>}`;
   `release.yml` creates the GitHub release from that changelog section.
