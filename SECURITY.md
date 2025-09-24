# Security Guidelines

This repository has been secured to prevent accidental exposure of sensitive information. Please follow these guidelines when working with this infrastructure:

## Removed Security Issues

### 1. Hardcoded Password Hash
- **File**: `arbitrary-scripts/bootstrap/dont-run-directly.sh`
- **Issue**: Previously contained a hardcoded SHA-512 password hash
- **Solution**: Now requires `USER_PASSWORD_HASH` environment variable
- **Usage**: 
  ```bash
  # Generate a password hash
  python3 -c "import crypt; print(crypt.crypt('yourpassword', crypt.mksalt(crypt.METHOD_SHA512)))"
  
  # Export the hash and run the script
  export USER_PASSWORD_HASH="$6$salt$hashedpassword"
  ./arbitrary-scripts/bootstrap/dont-run-directly.sh hostname
  ```

### 2. Hardcoded API Key
- **File**: `reference/traefik/traefik_docker_provider_example.yaml`
- **Issue**: Previously contained a hardcoded CrowdSec LAPI key
- **Solution**: Now uses `${CROWDSEC_LAPI_KEY}` environment variable
- **Usage**:
  ```bash
  export CROWDSEC_LAPI_KEY="your-actual-api-key"
  ```

## Protected Directories and Files

The `.gitignore` has been updated to prevent accidental commits of:

- `secrets/` - Directory for secret files
- `*.key`, `*.pem`, `*.crt` - Certificate and key files
- `*.p12`, `*.pfx` - Certificate archive files
- `*.htpasswd` - Apache password files
- `acme.json` - Let's Encrypt certificate storage
- `*_key`, `*_secret`, `*_token`, `*_password` - Files with sensitive naming patterns
- `*.env.local`, `*.env.production`, `*.env.staging` - Environment-specific config files
- `configs/` - Runtime configuration directory
- `certs/` - Certificate storage directory

## Best Practices

1. **Never commit secrets**: Use environment variables or external secret management
2. **Generate unique passwords**: Don't reuse passwords across services
3. **Use proper file permissions**: Ensure secret files have restricted permissions (600 or 640)
4. **Regular security audits**: Periodically review the repository for any accidentally committed secrets
5. **Environment-specific configs**: Keep production configurations separate from development

## Emergency Response

If you accidentally commit a secret:

1. **Immediately revoke/rotate the exposed secret**
2. **Remove the secret from git history** using `git filter-branch` or BFG Repo-Cleaner
3. **Force push the cleaned history** (coordinate with team members)
4. **Update all systems using the old secret**

Remember: Once something is committed to git, assume it has been compromised, even if you remove it later.