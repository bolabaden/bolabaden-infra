# Security Status

This page is a lightweight index for the repository's current security-oriented documentation.

## Current posture

bolabaden is a multi-node infrastructure repo with several security-relevant surfaces:

- public ingress through Traefik and Cloudflare
- secret distribution through `${SECRETS_PATH}`-backed files and Compose secrets
- internal node-to-node coordination over Tailscale / Headscale
- service-specific security hardening documented in feature-area docs

## Primary references

- [KotorModSync Security Summary](docs/KOTORMODSYNC_SECURITY_SUMMARY.md)
- [Docker Secrets Setup](DOCKER_SECRETS_README.md)
- `SECURITY.md` in the GitHub metadata for repository disclosure and reporting policy

## Important note

This page is intentionally short. It exists so the published docs navigation has a stable security entry point while deeper security guidance continues to live with the subsystems it describes.
