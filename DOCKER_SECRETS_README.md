# Docker Secrets Setup - Quick Start Guide

This repository now uses Docker secrets for enhanced security. Follow these steps to get started.

## 🚀 Quick Start (3 Steps)

### Step 1: Configure Secrets

```bash
# Copy the example file
cp .secrets.example .secrets

# Edit with your credentials
nano .secrets
```

### Step 2: Generate Secret Files

```bash
# Make script executable (if not already)
chmod +x scripts/generate-secrets.sh

# Run the generator
./scripts/generate-secrets.sh -v
```

### Step 3: Start Services

```bash
# Start all services
docker compose up -d

# Or start specific compose file
docker compose -f compose/docker-compose.authentik.yml up -d
```

## 📁 Important Files

| File | Purpose | Commit to Git? |
|------|---------|----------------|
| `.secrets` | Your actual secrets | ❌ NO (gitignored) |
| `.secrets.example` | Template for configuration | ✅ Yes |
| `secrets/*.txt` | Generated secret files | ❌ NO (gitignored) |
| `.env` | Non-secret configuration | ⚠️ Caution (check first) |
| `.env.cleaned` | Reference for cleaned .env | ✅ Yes |
| `scripts/generate-secrets.sh` | Secret generator | ✅ Yes |

## 🔐 Security Benefits

- ✅ Secrets stored in separate, gitignored file
- ✅ Individual secret files with proper permissions (600)
- ✅ Docker secrets mounted as tmpfs (not written to disk in containers)
- ✅ Clear separation between config and sensitive data
- ✅ Automated generation with validation

## 📝 What's in .secrets?

Your `.secrets` file should contain:

```bash
# Passwords
SUDO_PASSWORD=your_secure_password

# API Keys
OPENAI_API_KEY=sk-proj-...
ANTHROPIC_API_KEY=sk-ant-...
REALDEBRID_API_KEY=...

# OAuth Secrets
TINYAUTH_GOOGLE_CLIENT_SECRET=...
TINYAUTH_GITHUB_CLIENT_SECRET=...

# Application Secrets
AUTHENTIK_SECRET_KEY=...
GRAFANA_SECRET_KEY=...

# ... and many more
```

See `.secrets.example` for complete list.

## 🔧 Maintenance

### Regenerate All Secrets

```bash
./scripts/generate-secrets.sh --force --verbose
```

### Update a Single Secret

```bash
# 1. Edit .secrets
nano .secrets

# 2. Regenerate
./scripts/generate-secrets.sh -f

# 3. Restart affected service
docker compose restart <service-name>
```

### Verify Secrets

```bash
# List all generated secrets
ls -la secrets/

# Check a specific secret (for debugging only!)
cat secrets/openai-api-key.txt
```

## ⚠️ Important Notes

### Never Commit These Files

- `.secrets` - Contains your actual credentials
- `secrets/` - Contains generated secret files
- `.env` if it contains sensitive data

These are all in `.gitignore` but **always verify** before committing:

```bash
git status
# Ensure .secrets and secrets/ are not listed
```

### File Permissions

The script automatically sets:
- `secrets/` directory: `700` (owner only)
- `secrets/*.txt` files: `600` (owner read/write only)

## 🆘 Troubleshooting

### Error: "secret file not found"

```bash
# Check SECRETS_PATH is set
echo $SECRETS_PATH

# Should output: /home/ubuntu/my-media-stack/secrets

# If not set, add to .env:
echo 'SECRETS_PATH="/home/ubuntu/my-media-stack/secrets"' >> .env

# Regenerate
./scripts/generate-secrets.sh -f
```

### Error: "permission denied"

```bash
# Fix permissions
chmod 700 secrets/
chmod 600 secrets/*.txt
```

### Service Won't Start

```bash
# Check logs
docker compose logs <service-name>

# Common issues:
# 1. Secret file empty - check .secrets has value
# 2. Wrong path - verify SECRETS_PATH
# 3. App doesn't support _FILE - see migration guide
```

## 📚 Documentation

For detailed information, see:

- **`MIGRATION_SUMMARY.md`** - What was changed and why
- **`SECRETS_MIGRATION_GUIDE.md`** - Comprehensive migration guide
- **`.secrets.example`** - All available secrets with descriptions

## 🔄 Migration Status

### ✅ Completed (Ready to Use)
- Authentik (authentication)
- Traefik (reverse proxy)
- TinyAuth (OAuth)
- Firecrawl (web scraping)
- LiteLLM (LLM gateway)
- Open WebUI (chat interface)
- MCPO (MCP orchestrator)
- GPTR (research wizard)
- Grafana (monitoring)

### ⚠️ Manual Review Needed
- Stremio Group (check MediaFusion docs)
- Rclone configs (consider external files)

### ℹ️ No Changes Needed
- Headscale
- WARP NAT Routing (unless using WARP+)

## 🎯 Best Practices

1. **Regular Rotation**:
   - Rotate API keys every 90 days
   - Change passwords every 60 days
   - Update after any security incident

2. **Secure Backups**:
   ```bash
   # Encrypt before backup
   tar czf - .secrets secrets/ | gpg -c > secrets-backup.tar.gz.gpg
   ```

3. **Access Control**:
   - Limit who can read `.secrets`
   - Use separate secrets for dev/staging/prod
   - Don't share secrets via chat/email

4. **Monitoring**:
   - Watch for authentication failures
   - Monitor Docker logs for secret-related errors
   - Set up alerts for unauthorized access

## 🚨 Security Checklist

Before deploying to production:

- [ ] `.secrets` is in `.gitignore`
- [ ] `secrets/` is in `.gitignore`
- [ ] All secret files have `600` permissions
- [ ] Secrets directory has `700` permissions
- [ ] No secrets in `.env` file
- [ ] `.secrets.example` has no real values
- [ ] All services start successfully
- [ ] Secrets are not in Docker Compose logs
- [ ] Backups are encrypted
- [ ] Access to server is restricted

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review `SECRETS_MIGRATION_GUIDE.md`
3. Verify application supports Docker secrets / `_FILE` suffix
4. Check Docker Compose logs for specific errors

---

**Quick Reference Commands**:

```bash
# Generate secrets
./scripts/generate-secrets.sh -f -v

# Start services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs --tail=50 -f

# Restart service
docker compose restart <service-name>
```

**Last Updated**: October 22, 2025

