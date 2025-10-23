# Nomad Variables & Templates - Quick Reference Card

## 🔑 The Golden Rule

```
var.x           →  Job submission time  →  From .tfvars files
{{ env "X" }}   →  Container runtime    →  From container environment
```

## Two Different Systems

### System 1: HCL Variables (Static Config)

**Syntax:** `var.variable_name`  
**When:** Job submission (before containers exist)  
**Source:** `.tfvars` files, `-var` flags, `NOMAD_VAR_*`  

```hcl
# 1. Declare in job file
variable "domain" {
  type = string
}

# 2. Define value in variables.auto.tfvars.hcl
domain = "example.com"

# 3. Use in job
env {
  DOMAIN = var.domain  # ← "example.com"
}
```

### System 2: Go Templates (Dynamic Config)

**Syntax:** `{{ env "VAR" }}`  
**When:** Container startup (runtime)  
**Source:** Container env vars, Consul, Vault, Nomad metadata  

```hcl
# Must be in a template block
template {
  data = <<EOF
# Read env var set in env block
HOST={{ env "DOMAIN" }}

# With fallback
DEBUG={{ env "DEBUG" | or "false" }}

# Read Nomad metadata
ID={{ env "NOMAD_ALLOC_ID" }}
EOF
  destination = "local/app.conf"
}
```

## Common Mistakes

### ❌ WRONG: Using var.x in templates
```hcl
template {
  data = <<EOF
DOMAIN=var.domain  # ← Literal text "var.domain", not the value!
EOF
}
```

### ✅ CORRECT: Pass through env first
```hcl
env {
  DOMAIN = var.domain
}

template {
  data = <<EOF
DOMAIN={{ env "DOMAIN" }}  # ← Now it works!
EOF
}
```

### ❌ WRONG: Using {{ }} outside templates
```hcl
env {
  DOMAIN = {{ env "DOMAIN" }}  # ← Syntax error!
}
```

### ✅ CORRECT: Use var.x directly
```hcl
env {
  DOMAIN = var.domain  # ← HCL variable, works!
}
```

## File Loading

### Docker Compose
```bash
docker compose up
# Automatically reads: .env
```

### Nomad
```bash
nomad job run job.nomad.hcl
# Automatically reads: *.auto.tfvars.hcl
```

Both systems auto-load config, just different formats!

## Variable Priority (Highest to Lowest)

1. CLI `-var="x=value"`
2. `NOMAD_VAR_x=value`
3. `*.auto.tfvars.hcl` (alphabetical)
4. `-var-file="file.hcl"`
5. `default = "value"` in variable block

## Template Functions Cheat Sheet

```hcl
# Environment variable
{{ env "VAR" }}
{{ env "VAR" | or "default" }}

# Consul KV
{{ key "path/to/key" }}

# Consul service discovery
{{ range service "redis" }}
{{ .Address }}:{{ .Port }}
{{ end }}

# Vault secrets (requires vault stanza)
{{ with secret "secret/path" }}
{{ .Data.data.password }}
{{ end }}

# Conditionals
{{ if env "DEBUG" }}
debug: true
{{ else }}
debug: false
{{ end }}

# Nomad metadata
{{ env "NOMAD_ALLOC_ID" }}
{{ env "NOMAD_TASK_NAME" }}
{{ env "NOMAD_GROUP_NAME" }}
```

## When to Use Each

| Use Case | Use This |
|----------|----------|
| Set container environment | `env { X = var.y }` |
| Generate config file | `template { {{ env "X" }} }` |
| Read from Vault | `template { {{ secret "..." }} }` |
| Service discovery | `template { {{ service "..." }} }` |
| Static paths/hostnames | `var.variable_name` |
| Runtime metadata | `{{ env "NOMAD_*" }}` |

## Real Example

```hcl
# Variable declaration (schema only, no secret)
variable "redis_password" {
  type        = string
  description = "Redis password (SENSITIVE - in secrets.auto.tfvars.hcl)"
}

# In secrets.auto.tfvars.hcl:
# redis_password = "actual-secret-password"

# Usage in job
task "app" {
  # Set env var from HCL variable
  env {
    REDIS_PASSWORD = var.redis_password
  }
  
  # Generate config using Go template
  template {
    data = <<EOF
# Read from container env (set above)
redis:
  password: {{ env "REDIS_PASSWORD" }}
  
# Read from Consul service discovery
{{ range service "redis" }}
  host: {{ .Address }}
  port: {{ .Port }}
{{ end }}

# Read Nomad metadata
deployment:
  alloc_id: {{ env "NOMAD_ALLOC_ID" }}
EOF
    destination = "local/redis.yml"
  }
}
```

## Need More Detail?

See **[TEMPLATE_SYNTAX.md](TEMPLATE_SYNTAX.md)** for the complete guide with:
- Detailed explanations
- More examples
- Troubleshooting
- Best practices
- Common pitfalls

---

**Remember:** 
- `var.x` = From files (job submission time)
- `{{ env "X" }}` = From runtime (container environment)

