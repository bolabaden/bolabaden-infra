# AGENTS.md

## Cursor Cloud specific instructions

### Codebase overview

This is a **Docker Compose infrastructure-as-code** project (`bolabaden.org`) — a multi-node homelab/media server stack. It is NOT a traditional application with a single build/run command. The main developable components are:

| Component | Path | Language | Build/Test |
|---|---|---|---|
| Constellation Agent (infra tooling) | `infra/` | Go 1.24 | `make build`, `make test` |
| Telemetry Auth Service | `projects/kotormodsync/telemetry-auth/` | Python 3 (stdlib only) | `python3 auth_service.py` |
| Docker Compose configs | `docker-compose.yml` + `compose/` | YAML | `docker compose config` |
| Root npm deps (audit tooling) | `package.json` | Node.js | `npm install`, `npm audit` |

### Key commands

- **Go infra build/test**: `cd infra && make build && make test`
- **Go lint**: `cd infra && go vet ./...`
- **npm install**: `cd /workspace && npm install`
- **npm audit**: `cd /workspace && npm audit`
- **Docker Compose validation**: requires many env vars and secrets. See `.env.example` for the full list. A minimal validation command needs ~50 env vars set and placeholder secret files at `$SECRETS_PATH`. Use `docker compose config --quiet` to validate.

### Gotchas

- The Go module requires **Go 1.24+** (`go.mod` specifies `go 1.24.0`). The system-installed Go may be older (1.22). Install Go 1.24+ to `/usr/local/go` and ensure `PATH=/usr/local/go/bin:$PATH`.
- Docker is required for compose validation and running services. The cloud VM needs Docker installed manually (see environment setup).
- Docker daemon in the cloud VM requires `fuse-overlayfs` storage driver and `iptables-legacy` due to nested container limitations. Config: `/etc/docker/daemon.json` with `{"storage-driver": "fuse-overlayfs"}`.
- The telemetry-auth service (`auth_service.py`) is pure Python stdlib — no `pip install` needed. Run with `REQUIRE_AUTH=false` for quick health-check testing, or set `KOTORMODSYNC_SIGNING_SECRET` for full HMAC testing.
- `docker compose config` requires `~/.docker/config.json` to exist (even if empty `{}`), because the watchtower service mounts it as a config.
- Some Go source files in `infra/` have formatting drift (per `gofmt -l`). This is a pre-existing repo state, not an error introduced by setup.
- The `npm audit` reports 1 high-severity vulnerability in `next-mdx-remote` — this is a pre-existing dependency issue in the root `package.json`.
