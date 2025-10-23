# Nomad Template Syntax Guide

## Understanding Variables in Nomad

There are TWO completely different variable systems in the Nomad job file:

### 1. HCL Variables (`var.variable_name`)

**What it is:** Nomad job variables defined in `.hcl` files  
**When it's resolved:** At job submission time (before containers start)  
**Where values come from:**
- `variables.auto.tfvars.hcl` (auto-loaded)
- `secrets.auto.tfvars.hcl` (auto-loaded)
- `-var` command-line flags
- `NOMAD_VAR_*` environment variables
- Default values in variable declarations

**Syntax:**
```hcl
# Variable declaration
variable "domain" {
  type    = string
  default = "bolabaden.org"
}

# Usage in job file
env {
  DOMAIN = var.domain
}
```

**Example:**
```hcl
# In variables.auto.tfvars.hcl:
domain = "example.com"

# In docker-compose.nomad.hcl:
variable "domain" {
  type = string
}

task "web" {
  env {
    DOMAIN = var.domain  # ← Becomes "example.com" when job is submitted
  }
}
```

### 2. Go Template Variables (`{{ env "VAR" }}`)

**What it is:** Runtime environment variable access in Nomad template blocks  
**When it's resolved:** At container start time (inside the container)  
**Where values come from:**
- Environment variables set in the `env` block
- Nomad metadata variables (`NOMAD_ALLOC_ID`, etc.)
- Consul Key-Value store
- Vault secrets

**Syntax:**
```hcl
template {
  data = <<EOF
LOG_LEVEL={{ env "LOG_LEVEL" | or "info" }}
HOSTNAME={{ env "HOSTNAME" }}
EOF
  destination = "local/config.env"
  env         = true
}
```

**Example:**
```hcl
task "web" {
  env {
    LOG_LEVEL = "debug"
  }
  
  template {
    data = <<EOF
# This reads LOG_LEVEL from the container's environment
LOGGING={{ env "LOG_LEVEL" | or "info" }}
EOF
    destination = "local/app.conf"
  }
}
```

## Key Differences

| Feature | HCL Variables (`var.x`) | Go Templates (`{{ env "X" }}`) |
|---------|------------------------|--------------------------------|
| **Resolution Time** | Job submission | Container runtime |
| **Source** | `.tfvars` files, CLI flags | Container environment |
| **Usage** | Anywhere in job spec | Only in `template` blocks |
| **Syntax** | HCL syntax | Go template syntax |
| **Dynamic** | No (static at submission) | Yes (can change per allocation) |

## Common Use Cases

### Use HCL Variables (`var.x`) When:
- Setting container environment variables
- Configuring resource limits
- Defining service names/ports
- Setting volume paths
- Any static configuration

```hcl
env {
  DOMAIN = var.domain
  REDIS_HOST = var.redis_hostname
}

resources {
  cpu    = var.cpu_limit
  memory = var.memory_limit
}
```

### Use Go Templates (`{{ env "X" }}`) When:
- Generating configuration files dynamically
- Reading Nomad metadata
- Accessing Consul values
- Reading Vault secrets
- Need runtime environment fallbacks

```hcl
template {
  data = <<EOF
# Access Nomad metadata
ALLOC_ID={{ env "NOMAD_ALLOC_ID" }}

# Read from Consul
API_ENDPOINT={{ key "service/api/endpoint" }}

# Read from Vault (requires vault stanza)
{{ with secret "secret/api-keys" }}
API_KEY={{ .Data.data.key }}
{{ end }}

# Environment variable with fallback
LOG_LEVEL={{ env "LOG_LEVEL" | or "info" }}
EOF
  destination = "local/config.env"
  env         = true
}
```

## Why Both Systems Exist

**HCL Variables** are for deployment-time configuration:
- Different values for dev/staging/prod
- Infrastructure-specific settings
- Things that don't change per allocation

**Go Templates** are for runtime flexibility:
- Service discovery (reading Consul)
- Secrets management (reading Vault)
- Per-allocation configuration
- Dynamic environment-based config

## Important Notes

### Nomad Does NOT Read `.env` Files

Unlike Docker Compose, Nomad doesn't automatically load `.env` files. Instead:

- **Docker Compose**: Reads `.env` automatically
- **Nomad**: Reads `*.auto.tfvars.hcl` automatically

Both serve the same purpose but use different file formats.

### Template Delimiters

By default, templates use `{{ }}` delimiters:
```hcl
template {
  data = <<EOF
VALUE={{ env "MY_VAR" }}
EOF
}
```

You can change delimiters if your config uses `{{ }}`:
```hcl
template {
  left_delimiter  = "<<<<"
  right_delimiter = ">>>>"
  data = <<EOF
VALUE=<<<< env "MY_VAR" >>>>
EOF
}
```

### Escaping in Templates

In Go templates inside HCL, you need to escape:
- `$` → `$$` (for shell variables)
- `{{` → `{{` stays as-is (template syntax)

```hcl
template {
  data = <<EOF
#!/bin/bash
# Shell variable (escaped)
MY_VAR=$$HOME

# Template variable (not escaped)
API_KEY={{ env "API_KEY" }}
EOF
}
```

## Template Functions

Available in `template` blocks:

### Environment Variables
```hcl
{{ env "VAR" }}              # Read environment variable
{{ env "VAR" | or "default" }} # With fallback
```

### Consul Integration
```hcl
{{ key "path/to/key" }}      # Read from Consul KV
{{ service "redis" }}        # Service discovery
```

### Vault Integration
```hcl
{{ with secret "secret/path" }}
  {{ .Data.data.key }}
{{ end }}
```

### Iteration
```hcl
{{ range service "redis" }}
REDIS_HOST={{ .Address }}:{{ .Port }}
{{ end }}
```

### Conditionals
```hcl
{{ if env "DEBUG" }}
LOG_LEVEL=debug
{{ else }}
LOG_LEVEL=info
{{ end }}
```

## Real Example from docker-compose.nomad.hcl

```hcl
# Variable declaration (resolved at job submission)
variable "redis_hostname" {
  type    = string
  default = "redis"
}

variable "redis_port" {
  type    = number
  default = 6379
}

# Usage in env block (HCL variable)
task "app" {
  env {
    REDIS_HOST = var.redis_hostname
    REDIS_PORT = var.redis_port
  }
  
  # Dynamic template (Go template with env access)
  template {
    data = <<EOF
# This reads REDIS_HOST from the container's environment (set above)
REDIS_URL=redis://{{ env "REDIS_HOST" }}:{{ env "REDIS_PORT" }}

# This reads from Consul service discovery
{{ range service "redis" }}
REDIS_ADDR={{ .Address }}:{{ .Port }}
{{ end }}
EOF
    destination = "local/redis.conf"
  }
}
```

## Troubleshooting

### Error: "unknown variable"
- ✅ Add variable declaration to job file
- ✅ Add value to `variables.auto.tfvars.hcl` or `secrets.auto.tfvars.hcl`

### Error: "template: execution failed"
- ❌ Using `var.x` inside a `template` block (use `{{ env "X" }}` instead)
- ✅ Set the environment variable first in the `env` block

### Variables not being loaded
- ✅ Ensure files are named `*.auto.tfvars.hcl`
- ✅ Run from the directory containing the `.tfvars` files
- ✅ Or use `-var-file=path/to/file.hcl`

## Best Practices

1. **Keep secrets out of job files** - Use `.tfvars` files
2. **Use HCL variables for static config** - Cleaner and validated at submission
3. **Use templates for dynamic config** - Service discovery, vault, runtime env
4. **Document your variables** - Add descriptions to help future maintainers
5. **Separate sensitive from non-sensitive** - Use `secrets.auto.tfvars.hcl` and `variables.auto.tfvars.hcl`

## Quick Reference

```hcl
# ✅ DO: Use HCL variables for configuration
env {
  DOMAIN = var.domain
}

# ❌ DON'T: Hardcode secrets in job file
env {
  API_KEY = "sk-12345..."  # Never do this!
}

# ✅ DO: Use templates for dynamic config
template {
  data = <<EOF
HOST={{ env "NOMAD_ALLOC_ID" }}.example.com
EOF
}

# ❌ DON'T: Use var.x inside templates
template {
  data = <<EOF
DOMAIN=var.domain  # This won't work!
EOF
}

# ✅ DO: Pass var to env, then read with template
env {
  DOMAIN = var.domain
}
template {
  data = <<EOF
DOMAIN={{ env "DOMAIN" }}  # This works!
EOF
}
```

## Further Reading

- [Nomad Variables](https://developer.hashicorp.com/nomad/docs/job-specification/hcl2/variables)
- [Nomad Templates](https://developer.hashicorp.com/nomad/docs/job-specification/template)
- [Go Template Documentation](https://pkg.go.dev/text/template)

