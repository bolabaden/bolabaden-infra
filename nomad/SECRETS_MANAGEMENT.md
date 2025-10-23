# Nomad Secrets Management Guide

## Overview

The Docker Compose to Nomad conversion separates configuration into two files for security:

1. **`variables.auto.tfvars.hcl`** - Non-sensitive configuration (safe to commit)
2. **`secrets.auto.tfvars.hcl`** - Sensitive data (NEVER commit)

Both files are automatically loaded by Nomad when running jobs.

**Important:** For understanding how variables and templates work in Nomad, see **[TEMPLATE_SYNTAX.md](TEMPLATE_SYNTAX.md)**. This covers the crucial difference between `var.variable_name` (HCL variables) and `{{ env "VAR" }}` (Go templates).

## File Structure

```
nomad/
├── variables.auto.tfvars.hcl    # ✅ Safe to commit - configuration only
├── secrets.auto.tfvars.hcl      # ⚠️ NEVER commit - contains secrets
├── .gitignore                   # Protects secrets.auto.tfvars.hcl
└── docker-compose.nomad.hcl     # Main Nomad job file
```

## Security Protection

### .gitignore Protection

The following patterns are in `.gitignore` and `nomad/.gitignore`:

```gitignore
# Secrets files
nomad/secrets.auto.tfvars.hcl
secrets.auto.tfvars.hcl
secrets.*.hcl
*.secret.hcl
*.secrets.hcl
```

### Verification

Check if your secrets file is protected:

```bash
cd /home/ubuntu/my-media-stack
git check-ignore nomad/secrets.auto.tfvars.hcl
# Should output: nomad/secrets.auto.tfvars.hcl
```

## Usage

### Local Development

```bash
cd nomad

# Both files are auto-loaded:
nomad job run docker-compose.nomad.hcl

# To override specific values:
nomad job run \
  -var="domain=example.com" \
  -var="sudo_password=newpass" \
  docker-compose.nomad.hcl
```

### Production Deployment

For production, use Nomad's native secrets management instead of files:

#### Option 1: Nomad Variables API (Recommended)

```bash
# Store secrets in Nomad's encrypted variables store
nomad var put \
  -namespace=default \
  secrets/my-media-stack \
  sudo_password="your-password" \
  openai_api_key="sk-..." \
  cloudflare_api_key="..."

# Reference in job file with:
# env {
#   SUDO_PASSWORD = {{ with nomadVar "secrets/my-media-stack" }}{{ .sudo_password }}{{ end }}
# }
```

#### Option 2: HashiCorp Vault Integration

```bash
# Enable Vault integration in Nomad
# nomad.hcl:
vault {
  enabled = true
  address = "https://vault.example.com"
}

# Store secrets in Vault
vault kv put secret/my-media-stack \
  sudo_password="your-password" \
  openai_api_key="sk-..."

# Reference in job with vault stanza:
# vault {
#   policies = ["my-media-stack"]
# }
# template {
#   data = <<EOF
# {{ with secret "secret/my-media-stack" }}
# SUDO_PASSWORD={{ .Data.data.sudo_password }}
# {{ end }}
# EOF
# }
```

#### Option 3: Environment Variables

```bash
# Export as Nomad vars (prefixed with NOMAD_VAR_)
export NOMAD_VAR_sudo_password="your-password"
export NOMAD_VAR_openai_api_key="sk-..."

nomad job run docker-compose.nomad.hcl
```

## Secrets in This File

The `secrets.auto.tfvars.hcl` file contains **461 lines** of sensitive data including:

### Critical Secrets
- Admin/sudo passwords
- OAuth client secrets
- JWT secrets
- Encryption keys

### API Keys (140+ providers)
- AI/LLM: OpenAI, Anthropic, Gemini, Groq, Mistral, DeepSeek, etc.
- Cloud: AWS, Cloudflare, Google
- Media: TMDB, Trakt, Plex
- Debrid: Real-Debrid, AllDebrid, Premiumize, TorBox
- Search: Brave, Tavily, SerpAPI, Perplexity
- Development: GitHub, GitLab, Docker Hub

### Service Passwords
- Database passwords (PostgreSQL, MariaDB, Redis)
- Service admin passwords (Grafana, Plex, etc.)
- VPN credentials
- Email/SMTP credentials

## Best Practices

### ✅ DO

- Keep `secrets.auto.tfvars.hcl` on your local machine only
- Use Nomad Variables API or Vault for production
- Rotate secrets regularly
- Use different secrets for dev/staging/prod
- Backup secrets securely (encrypted password manager)
- Use environment-specific secrets files:
  - `secrets.dev.hcl` (ignored)
  - `secrets.staging.hcl` (ignored)
  - `secrets.prod.hcl` (ignored)

### ❌ DON'T

- NEVER commit `secrets.auto.tfvars.hcl` to git
- NEVER share secrets in chat/email/Slack
- NEVER use production secrets in development
- NEVER hardcode secrets in job files
- NEVER store secrets in version control

## Emergency: Secrets Accidentally Committed

If you accidentally commit secrets:

```bash
# 1. Rotate ALL exposed secrets immediately
# 2. Remove from git history
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch nomad/secrets.auto.tfvars.hcl' \
  --prune-empty --tag-name-filter cat -- --all

# 3. Force push (⚠️ coordinate with team first)
git push origin --force --all
git push origin --force --tags

# 4. Verify removal
git log --all --full-history -- nomad/secrets.auto.tfvars.hcl
```

## Migration from Docker Compose .env

The separation maintains 1:1 parity with your original `.env` file:

- **685 total environment variables** from `.env`
- **461 secrets** → `secrets.auto.tfvars.hcl`
- **224 config values** → `variables.auto.tfvars.hcl`

All variables are mapped and ready to use with proper Nomad variable syntax.

## Variable Reference in Job Files

In `docker-compose.nomad.hcl`, variables are referenced in TWO different ways:

### HCL Variable References (var.x)
Used for static configuration resolved at job submission:
```hcl
env {
  DOMAIN = var.domain  # from variables.auto.tfvars.hcl
  SUDO_PASSWORD = var.sudo_password  # from secrets.auto.tfvars.hcl
}
```

### Go Template References ({{ env "X" }})
Used in `template` blocks for dynamic runtime configuration:
```hcl
template {
  data = <<EOF
# Read from container environment (set in env block above)
DOMAIN={{ env "DOMAIN" }}

# Read from Nomad metadata
ALLOC_ID={{ env "NOMAD_ALLOC_ID" }}

# With fallback
LOG_LEVEL={{ env "LOG_LEVEL" | or "info" }}
EOF
  destination = "local/config.env"
  env = true
}
```

**See [TEMPLATE_SYNTAX.md](TEMPLATE_SYNTAX.md) for complete documentation on these two systems.**

## Secrets Checklist

Before deployment:

- [ ] Verify `secrets.auto.tfvars.hcl` is in `.gitignore`
- [ ] Update all placeholder passwords/keys with real values
- [ ] Rotate any secrets that may have been exposed
- [ ] Test with `nomad job validate docker-compose.nomad.hcl`
- [ ] For production, migrate to Nomad Variables or Vault
- [ ] Document secret rotation procedures
- [ ] Set up secret backup strategy

## Support

For questions about Nomad secrets management:
- [Nomad Variables Documentation](https://developer.hashicorp.com/nomad/docs/concepts/variables)
- [Nomad Vault Integration](https://developer.hashicorp.com/nomad/docs/integrations/vault-integration)

