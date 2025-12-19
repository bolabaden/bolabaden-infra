# Nomad job specification equivalent to docker-compose.yml and its includes
# 
# VARIABLE SYSTEM:
# - Variable declarations below define the schema (type, description)
# - Actual values come from variables.auto.tfvars.hcl and secrets.auto.tfvars.hcl
# - Both .tfvars files are automatically loaded by Nomad
# - Override at runtime: export NOMAD_VAR_domain="my-domain.com"
# - Or: nomad job run -var="domain=my-domain.com" docker-compose.nomad.hcl
#
# TEMPLATE SYNTAX IN THIS FILE:
# - {{ env "VAR" }} - reads runtime environment variable inside container
# - ${var.variable_name} or var.variable_name - reads Nomad job variable from .tfvars files
# - Templates in `template` blocks use Go template syntax for dynamic config generation

# Core Variables
variable "domain" {
  type    = string
  default = "bolabaden.org"
}
variable "config_path" {
  type    = string
  default = "/home/ubuntu/my-media-stack/volumes"
}

variable "root_path" {
  type    = string
  default = "/home/ubuntu/my-media-stack"
}

variable "docker_socket" {
  type    = string
  default = "/var/run/docker.sock"
}

variable "tz" {
  type    = string
  default = "America/Chicago"
}

variable "puid" {
  type    = number
  default = 1001
}

variable "pgid" {
  type    = number
  default = 121
}

variable "umask" {
  type    = string
  default = "002"
}

variable "sudo_password" {
  type        = string
  description = "Admin/sudo password (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "main_username" {
  type    = string
  default = "brunner56"
}

variable "require_auth" {
  type    = string
  default = "true"
}

variable "max_timestamp_drift" {
  type    = number
  default = 300
}

variable "log_level" {
  type    = string
  default = "info"
}

# Service-specific variables
variable "redis_hostname" {
  type    = string
  default = "redis"
}

variable "redis_port" {
  type    = number
  default = 6379
}

variable "redis_password" {
  type        = string
  description = "Redis password (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "redis_database" {
  type    = number
  default = 0
}

variable "redis_username" {
  type    = string
  default = "brunner56"
}

variable "searxng_secret" {
  type        = string
  description = "SearXNG secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "searxng_port" {
  type    = number
  default = 8080
}

variable "authentik_secret_key" {
  type        = string
  description = "Authentik secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "gmail_app_password" {
  type        = string
  description = "Gmail app password for SMTP (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
  default = "nbru aavt hmcx veqs"
}

variable "acme_resolver_email" {
  type    = string
  default = "boden.crouch@gmail.com"
}

variable "tinyauth_secret" {
  type        = string
  description = "TinyAuth secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_google_client_id" {
  type        = string
  description = "TinyAuth Google OAuth client ID (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_google_client_secret" {
  type        = string
  description = "TinyAuth Google OAuth client secret (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_github_client_id" {
  type        = string
  description = "TinyAuth GitHub OAuth client ID (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_github_client_secret" {
  type        = string
  description = "TinyAuth GitHub OAuth client secret (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_users" {
  type        = string
  description = "TinyAuth user credentials with bcrypt hashes (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_oauth_whitelist" {
  type    = string
  default = "boden.crouch@gmail.com,halomastar@gmail.com,athenajaguiar@gmail.com,dgorsch2@gmail.com,dgorsch4@gmail.com"
}

variable "cloudflare_email" {
  type    = string
  default = "boden.crouch@gmail.com"
}

variable "cloudflare_api_key" {
  type        = string
  description = "Cloudflare Global API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for DNS management (defined in secrets.auto.tfvars.hcl)"
}

variable "nginx_auth_api_key" {
  type        = string
  description = "Nginx auth middleware API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# API Keys
variable "openai_api_key" {
  type        = string
  description = "OpenAI API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "firecrawl_api_key" {
  type        = string
  description = "Firecrawl API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "anthropic_api_key" {
  type        = string
  description = "Anthropic/Claude API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "mcpo_api_key" {
  type        = string
  description = "MCPO API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "litellm_master_key" {
  type        = string
  description = "LiteLLM master key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "open_webui_secret_key" {
  type        = string
  description = "Open WebUI secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# WARP Variables
variable "warp_license_key" {
  type    = string
  default = ""
}

variable "gost_args" {
  type    = string
  default = "-L :1080"
}

variable "warp_enable_nat" {
  type    = string
  default = "false"
}

variable "warp_sleep" {
  type    = number
  default = 2
}

variable "docker_network_name" {
  type    = string
  default = "warp-nat-net"
}

variable "warp_nat_net_subnet" {
  type    = string
  default = "10.0.2.0/24"
}

variable "warp_nat_net_gateway" {
  type    = string
  default = "10.0.2.1"
}

# Stremio/Media Variables
variable "aiostreams_secret_key" {
  type        = string
  description = "AIOStreams secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "aiostreams_addon_password" {
  type        = string
  description = "AIOStreams addon password (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "stremthru_proxy_auth" {
  type        = string
  description = "StremThru proxy authentication credentials (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "stremthru_store_auth" {
  type        = string
  description = "StremThru store authentication with debrid API keys (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "rclone_port" {
  type    = number
  default = 5572
}

# Debrid Service Variables
variable "realdebrid_api_key" {
  type        = string
  description = "Real-Debrid API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "alldebrid_api_key" {
  type        = string
  description = "AllDebrid API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "premiumize_api_key" {
  type        = string
  description = "Premiumize API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "torbox_api_key" {
  type        = string
  description = "TorBox API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "debridlink_api_key" {
  type        = string
  description = "DebridLink API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "offcloud_api_key" {
  type        = string
  description = "Offcloud API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# *Arr Application Variables  
variable "prowlarr_api_key" {
  type        = string
  description = "Prowlarr API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "jackett_api_key" {
  type        = string
  description = "Jackett API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# TMDB Variables
variable "tmdb_api_key" {
  type        = string
  description = "TMDB API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tmdb_access_token" {
  type        = string
  description = "TMDB access token (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# Trakt Variables
variable "trakt_client_id" {
  type        = string
  description = "Trakt OAuth client ID (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "trakt_client_secret" {
  type        = string
  description = "Trakt OAuth client secret (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# CrowdSec Variables
variable "crowdsec_lapi_key" {
  type        = string
  description = "CrowdSec LAPI key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "crowdsec_bouncer_enabled" {
  type    = string
  default = "true"
}

# Traefik ACME Variables
variable "traefik_ca_server" {
  type    = string
  default = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "traefik_dns_challenge" {
  type    = string
  default = "true"
}

variable "traefik_dns_resolvers" {
  type    = string
  default = "1.1.1.1,1.0.0.1"
}

variable "traefik_http_challenge" {
  type    = string
  default = "false"
}

variable "traefik_tls_challenge" {
  type    = string
  default = "false"
}

job "docker-compose-stack" {
  datacenters = ["dc1"]
  type        = "service"

  # Ensure all task groups run on nodes with Consul (required for service discovery)
  # Note: Constraint removed - nodes may not expose consul.version attribute
  # Consul integration is verified via service discovery, not version constraint

  # Mongodb Group
  group "mongodb-group" {
    count = 1  # MongoDB: Single instance (replication handled at DB level if needed)

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "mongodb" { to = 27017 }
    }

    # 🔹🔹 MongoDB 🔹🔹
    task "mongodb" {
      driver = "docker"

      config {
        image = "docker.io/mongo"
        ports = ["mongodb"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        volumes = [
          "${var.config_path}/mongodb/data:/data/db"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "mongodb"
          "traefik.enable" = "true"
          "traefik.tcp.routers.mongodb.rule" = "HostSNI(`mongodb.${var.domain}`) || HostSNI(`mongodb.${node.unique.name}.${var.domain}`)"
          "traefik.tcp.routers.mongodb.service" = "mongodb@docker"
          "traefik.tcp.routers.mongodb.tls.domains[0].main" = "${var.domain}"
          "traefik.tcp.routers.mongodb.tls.domains[0].sans" = "*.${var.domain},${node.unique.name}.${var.domain}"
          "traefik.tcp.routers.mongodb.tls.passthrough" = "true"
          "traefik.tcp.services.mongodb.loadbalancer.server.port" = "27017"
          "traefik.tcp.services.mongodb.loadbalancer.server.tls" = "true"
        }
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu        = 300
        memory     = 512
        memory_max = 768
      
      }

      service {

        name = "mongodb"
        port = "mongodb"
        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.mongodb.rule=HostSNI(`mongodb.${var.domain}`) || HostSNI(`mongodb.${node.unique.name}.${var.domain}`)",
          "traefik.tcp.routers.mongodb.service=mongodb@consulcatalog",
          "traefik.tcp.routers.mongodb.tls.domains[0].main=${var.domain}",
          "traefik.tcp.routers.mongodb.tls.domains[0].sans=*.${var.domain},${node.unique.name}.${var.domain}",
          "traefik.tcp.routers.mongodb.tls.passthrough=true",
          "traefik.tcp.services.mongodb.loadbalancer.server.port=27017",
          "traefik.tcp.services.mongodb.loadbalancer.server.tls=true"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "mongosh 127.0.0.1:27017/test --quiet --eval 'db.runCommand(\"ping\").ok' > /dev/null 2>&1 || exit 1"]
          interval = "10s"
          timeout  = "10s"
        }
      }
    }
  }

  # Searxng Group
  group "searxng-group" {
    count = 2  # HA: Run on multiple nodes for failover

    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "searxng" { to = 8080 }
    }

    # SearxNG is a privacy-respecting, hackable, open-source metasearch engine.
    task "searxng" {
      driver = "docker"

      config {
        image = "docker.io/searxng/searxng"
        ports = ["searxng"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        volumes = [
          # touch ${CONFIG_PATH:-./volumes}/searxng/limiter.toml
          "${var.config_path}/searxng/config:/etc/searxng",
          "${var.config_path}/searxng/data:/var/cache/searxng"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "searxng"
          "traefik.enable" = "true"
          "traefik.http.services.searxng.loadbalancer.server.port" = "${var.searxng_port}"
          "homepage.group" = "Search"
          "homepage.name" = "SearxNG"
          "homepage.icon" = "searxng.png"
          "homepage.href" = "https://searxng.${var.domain}/"
          "homepage.description" = "Privacy-focused metasearch that aggregates results from many sources without tracking"
          "kuma.searxng.http.name" = "searxng.${node.unique.name}.${var.domain}"
          "kuma.searxng.http.url" = "https://searxng.${var.domain}"
          "kuma.searxng.http.interval" = "30"
        }
        logging {
          type = "json-file"
          config {
            max-size = "1m"
            max-file = "1"
          }
        }
      }

      template {
        data = <<EOF
SEARXNG_BASE_URL={{ env "SEARXNG_INTERNAL_URL" | or "http://searxng:8080" }}
SEARXNG_SECRET=${var.searxng_secret}
EOF
        destination = "local/searxng.env"
        env         = true
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "searxng"
        port = "searxng"
        tags = [
          "traefik.enable=true",
          "traefik.http.services.searxng.loadbalancer.server.port=${var.searxng_port}",
          "homepage.group=Search",
          "homepage.name=SearxNG",
          "homepage.icon=searxng.png",
          "homepage.href=https://searxng.${var.domain}/",
          "homepage.description=Privacy-focused metasearch that aggregates results from many sources without tracking",
          "kuma.searxng.http.name=searxng.${node.unique.name}.${var.domain}",
          "kuma.searxng.http.url=https://searxng.${var.domain}",
          "kuma.searxng.http.interval=30"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget --no-verbose --tries=1 --spider http://127.0.0.1:${var.searxng_port}/ || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Session Manager Group
  group "session-manager-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "session_manager" { to = 8080 }
    }

    task "session-manager" {
      driver = "docker"

      config {
        image = "alpine"
        ports = ["session_manager"]
        command = "sh"
        args    = [
          "-c",
          "apk add python3 py3-pip docker-cli zip unzip && pip install fastapi uvicorn httpx websockets docker jinja2 python-multipart --break-system-packages --root-user-action=ignore && mkdir -p /tmp/templates && python3 session_manager.py"
        ]
        volumes = [
          "${var.config_path}/extensions:${var.config_path}/extensions",
          # Mount session manager files from host
          "${var.root_path}/projects/kotor/kotorscript-session-manager/session_manager.py:/session_manager.py:ro",
          "${var.root_path}/projects/kotor/kotorscript-session-manager/index.html:/tmp/templates/index.html:ro",
          "${var.root_path}/projects/kotor/kotorscript-session-manager/waiting.html:/tmp/templates/waiting.html:ro"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "session-manager"
        }
      }

      env {
        TZ                     = var.tz
        DOMAIN                 = var.domain
        SESSION_MANAGER_PORT   = "8080"
        INACTIVITY_TIMEOUT     = "3600"
        DEFAULT_WORKSPACE      = "/workspace"
        EXT_PATH               = "${var.config_path}/extensions/holo-lsp-1.0.0.vsix"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "session-manager"
        port = "session_manager"
        tags = [
          "traefik.enable=true",
          "traefik.http.middlewares.holoscripter-redirect.redirectRegex.regex=^https?://holoscripter\\.((?:${var.domain}|${node.unique.name}\\.${var.domain}))(.*)$$",
          "traefik.http.middlewares.holoscripter-redirect.redirectRegex.replacement=https://holoscript.$$1$$2",
          "traefik.http.middlewares.holoscripter-redirect.redirectRegex.permanent=false",
          "traefik.http.middlewares.kotorscripter-redirect.redirectRegex.regex=^https?://kotorscripter\\.((?:${var.domain}|${node.unique.name}\\.${var.domain}))(.*)$$",
          "traefik.http.middlewares.kotorscripter-redirect.redirectRegex.replacement=https://holoscript.$$1$$2",
          "traefik.http.middlewares.kotorscripter-redirect.redirectRegex.permanent=false",
          "traefik.http.middlewares.kotorscript-redirect.redirectRegex.regex=^https?://kotorscript\\.((?:${var.domain}|${node.unique.name}\\.${var.domain}))(.*)$$",
          "traefik.http.middlewares.kotorscript-redirect.redirectRegex.replacement=https://holoscript.$$1$$2",
          "traefik.http.middlewares.kotorscript-redirect.redirectRegex.permanent=false",
          "traefik.http.middlewares.tslscript-redirect.redirectRegex.regex=^https?://tslscript\\.((?:${var.domain}|${node.unique.name}\\.${var.domain}))(.*)$$",
          "traefik.http.middlewares.tslscript-redirect.redirectRegex.replacement=https://holoscript.$$1$$2",
          "traefik.http.middlewares.tslscript-redirect.redirectRegex.permanent=false",
          "traefik.http.middlewares.kscript-redirect.redirectRegex.regex=^https?://kscript\\.((?:${var.domain}|${node.unique.name}\\.${var.domain}))(.*)$$",
          "traefik.http.middlewares.kscript-redirect.redirectRegex.replacement=https://holoscript.$$1$$2",
          "traefik.http.middlewares.kscript-redirect.redirectRegex.permanent=false",
          "traefik.http.middlewares.hololsp-redirect.redirectRegex.regex=^https?://hololsp\\.((?:${var.domain}|${node.unique.name}\\.${var.domain}))(.*)$$",
          "traefik.http.middlewares.hololsp-redirect.redirectRegex.replacement=https://holoscript.$$1$$2",
          "traefik.http.middlewares.hololsp-redirect.redirectRegex.permanent=false",
          "traefik.http.routers.holoscript.rule=Host(`holoscript.${var.domain}`) || Host(`holoscript.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.holoscript.loadbalancer.server.port=8080",
          "traefik.http.routers.holoscripter-redirect.rule=Host(`holoscripter.${var.domain}`) || Host(`holoscripter.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.holoscripter-redirect.middlewares=holoscripter-redirect@consulcatalog",
          "traefik.http.routers.holoscripter-redirect.service=holoscript@consulcatalog",
          "traefik.http.routers.kotorscripter-redirect.rule=Host(`kotorscripter.${var.domain}`) || Host(`kotorscripter.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.kotorscripter-redirect.middlewares=kotorscripter-redirect@consulcatalog",
          "traefik.http.routers.kotorscripter-redirect.service=holoscript@consulcatalog",
          "traefik.http.routers.kotorscript-redirect.rule=Host(`kotorscript.${var.domain}`) || Host(`kotorscript.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.kotorscript-redirect.middlewares=kotorscript-redirect@consulcatalog",
          "traefik.http.routers.kotorscript-redirect.service=holoscript@consulcatalog",
          "traefik.http.routers.tslscript-redirect.rule=Host(`tslscript.${var.domain}`) || Host(`tslscript.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.tslscript-redirect.middlewares=tslscript-redirect@consulcatalog",
          "traefik.http.routers.tslscript-redirect.service=holoscript@consulcatalog",
          "traefik.http.routers.kscript-redirect.rule=Host(`kscript.${var.domain}`) || Host(`kscript.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.kscript-redirect.middlewares=kscript-redirect@consulcatalog",
          "traefik.http.routers.kscript-redirect.service=holoscript@consulcatalog",
          "traefik.http.routers.hololsp-redirect.rule=Host(`hololsp.${var.domain}`) || Host(`hololsp.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.hololsp-redirect.middlewares=hololsp-redirect@consulcatalog",
          "traefik.http.routers.hololsp-redirect.service=holoscript@consulcatalog"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget -qO- http://127.0.0.1:8080/health > /dev/null 2>&1 || exit 1"]
          interval = "10s"
          timeout  = "10s"
        }
      }
    }
  }

  # Bolabaden Nextjs Group
  group "bolabaden-nextjs-group" {
    count = 2  # HA: Run on multiple nodes for failover

    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "bolabaden_nextjs" { to = 3000 }
    }

    # 🔹🔹 bolabaden.org nextJS main website 🔹🔹
    task "bolabaden-nextjs" {
      driver = "docker"

      config {
        image = "th3w1zard1/bolabaden-nextjs"
        ports = ["bolabaden_nextjs"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "bolabaden-nextjs"
          "deunhealth.restart.on.unhealthy" = "true"
          "traefik.enable" = "true"
          # Error middleware configuration
          "traefik.http.middlewares.error-mw.errors.query" = "/api/error/{status}.html"
          "traefik.http.middlewares.error-mw.errors.service" = "error-service"
          "traefik.http.middlewares.error-mw.errors.status" = "400-599"
          # Error service configuration
          "traefik.http.services.error-service.loadbalancer.server.port" = "3000"
          # Errors router
          "traefik.http.routers.error-router.rule" = "Host(`errors.${var.domain}`) || Host(`errors.${node.unique.name}.${var.domain}`)"
          "traefik.http.routers.error-router.service" = "error-service"
          # Main website router
          "traefik.http.routers.bolabaden-nextjs.rule" = "Host(`${var.domain}`) || Host(`${node.unique.name}.${var.domain}`)"
          "traefik.http.routers.bolabaden-nextjs.service" = "bolabaden-nextjs"
          # Bolabaden NextJS service configuration
          "traefik.http.services.bolabaden-nextjs.loadbalancer.server.port" = "3000"
          # Iframe embed service for other subdomains
          "traefik.http.routers.bolabaden-embed.rule" = "Host(`embed.${var.domain}`) || Host(`embed.${node.unique.name}.${var.domain}`)"
          "traefik.http.routers.bolabaden-embed.service" = "bolabaden-nextjs"
        }
      }

      env {
        TZ       = var.tz
        PUID     = var.puid
        PGID     = var.pgid
        UMASK    = var.umask
        NODE_ENV = "production"
        PORT     = "3000"
        HOSTNAME = "0.0.0.0"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "bolabaden-nextjs"
        port = "bolabaden_nextjs"
        tags = [
          "traefik.enable=true",
          # Error pages middleware (matches docker-compose.yml line 456-458)
          "traefik.http.middlewares.bolabaden-error-pages.errors.status=400-599",
          "traefik.http.middlewares.bolabaden-error-pages.errors.service=bolabaden-nextjs@consulcatalog",
          "traefik.http.middlewares.bolabaden-error-pages.errors.query=/api/error/{status}",
          # Router for bolabaden-nextjs (matches docker-compose.yml line 460)
          "traefik.http.routers.bolabaden-nextjs.rule=Host(`${var.domain}`) || Host(`${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.bolabaden-nextjs.service=bolabaden-nextjs",
          # bolabaden-nextjs Service definition (matches docker-compose.yml line 462)
          "traefik.http.services.bolabaden-nextjs.loadbalancer.server.port=3000",
          "kuma.bolabaden-nextjs.http.name=${node.unique.name}.${var.domain}",
          "kuma.bolabaden-nextjs.http.url=https://${var.domain}",
          "kuma.bolabaden-nextjs.http.interval=30"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget -qO- http://127.0.0.1:3000 > /dev/null 2>&1 || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Dozzle Group
  group "dozzle-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "dozzle" { to = 8080 }
    }

    # 🔹🔹 Dozzle 🔹🔹
    task "dozzle" {
      driver = "docker"

      config {
        image = "docker.io/amir20/dozzle"
        ports = ["dozzle"]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "dozzle"
        }
      }

      env {
        TZ                       = var.tz
        DOZZLE_NO_ANALYTICS      = "true"
        DOZZLE_FILTER            = ""
        DOZZLE_ENABLE_ACTIONS    = "false"
        DOZZLE_AUTH_HEADER_NAME  = ""
        DOZZLE_AUTH_HEADER_USER  = ""
        DOZZLE_AUTH_HEADER_EMAIL = ""
        DOZZLE_AUTH_PROVIDER     = "none"
        DOZZLE_LEVEL             = "info"  # default: info
        DOZZLE_HOSTNAME          = ""
        DOZZLE_BASE              = "/"
        DOZZLE_ADDR              = ":8080"
      }

      template {
        data = <<EOF
{{- if service "dockerproxy-ro" }}
{{- range service "dockerproxy-ro" }}
DOZZLE_REMOTE_HOST="tcp://{{ .Address }}:{{ .Port }}"
{{- end }}
{{- else }}
DOZZLE_REMOTE_HOST=""
{{- end }}
EOF
        destination = "secrets/docker-host.env"
        env         = true
        wait {
          min = "2s"
          max = "10s"
        }
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "dozzle"
        port = "dozzle"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.dozzle.middlewares=nginx-auth@file",
          "traefik.http.services.dozzle.loadbalancer.server.port=8080",
          "homepage.group=System Monitoring",
          "homepage.name=Dozzle",
          "homepage.icon=dozzle.png",
          "homepage.href=https://dozzle.${var.domain}",
          "homepage.description=Real-time web UI for viewing Docker container logs across the host",
          "kuma.dozzle.http.name=dozzle.${node.unique.name}.${var.domain}",
          "kuma.dozzle.http.url=https://dozzle.${var.domain}",
          "kuma.dozzle.http.interval=60"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Homepage Group
  group "homepage-group" {
    count = 2  # HA: Run on multiple nodes for failover

    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "homepage" { to = 3000 }
    }

    # 🔹🔹 Homepage 🔹🔹  # https://github.com/gethomepage/homepage
    task "homepage" {
      driver = "docker"

      config {
        image = "ghcr.io/gethomepage/homepage"
        ports = ["homepage"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        volumes = [
          # DO NOT create a bind mount to the entire /app/public/ directory.
          "/var/run/docker.sock:/var/run/docker.sock:ro",
          "${var.config_path}/homepage:/app/config"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "homepage"
          "deunhealth.restart.on.unhealthy" = "true"
          "traefik.enable" = "true"
          "traefik.http.routers.homepage.middlewares" = "nginx-auth@file"
          "traefik.http.routers.homepage.rule" = "Host(`homepage.${var.domain}`) || Host(`homepage.${node.unique.name}.${var.domain}`)"
          "traefik.http.services.homepage.loadbalancer.server.port" = "3000"
          "homepage.group" = "Dashboards"
          "homepage.name" = "Homepage"
          "homepage.icon" = "homepage.png"
          "homepage.href" = "https://homepage.${var.domain}/"
          "homepage.description" = "Homepage is a dashboard that displays all of your services."
        }
      }

      env {
        TZ                        = var.tz
        PUID                      = var.puid
        PGID                      = var.pgid
        UMASK                     = var.umask
        HOMEPAGE_ALLOWED_HOSTS    = "*"
        HOMEPAGE_VAR_TITLE        = "Bolabaden"
        HOMEPAGE_VAR_SEARCH_PROVIDER = "google"
        HOMEPAGE_VAR_HEADER_STYLE = ""
        HOMEPAGE_VAR_WEATHER_CITY = "Chicago"
        HOMEPAGE_VAR_WEATHER_LAT  = "41.8781"
        HOMEPAGE_VAR_WEATHER_LONG = "-87.6298"
        HOMEPAGE_VAR_WEATHER_UNIT = "fahrenheit"
      }

      resources {
        cpu        = 250
        memory     = 128
        memory_max = 1024
      
      }

      service {

        name = "homepage"
        port = "homepage"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.homepage.middlewares=nginx-auth@file",
          "traefik.http.routers.homepage.rule=Host(`homepage.${var.domain}`) || Host(`homepage.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.homepage.loadbalancer.server.port=3000",
          "homepage.group=Dashboards",
          "homepage.name=Homepage",
          "homepage.icon=homepage.png",
          "homepage.href=https://homepage.${var.domain}/",
          "homepage.description=Homepage is a dashboard that displays all of your services."
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget -qO- http://127.0.0.1:3000 > /dev/null 2>&1 || exit 1"]
          interval = "30s"
          timeout  = "15s"
        }
      }
    }
  }

  # Redis Group
  group "redis-group" {
    count = 1  # Single instance (static port 6379) - HA via node-level failover

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "redis" {
        static = 6379
        to = 6379
      }
    }

    # image: valkey/valkey:alpine
    task "redis" {
      driver = "docker"

      config {
        image = "docker.io/redis:alpine"
        ports = ["redis"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        volumes = [
          "${var.config_path}/redis:/data"
        ]
        privileged = true  # for `sysctl vm.overcommit_memory=1` to work
        command = "sh"
        args    = [
          "-c",
          "sysctl vm.overcommit_memory=1 &> /dev/null && redis-server --appendonly yes --save 60 1 --bind 0.0.0.0 --port ${var.redis_port} --requirepass ${var.redis_password}"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "redis"
          "traefik.enable" = "true"
          "traefik.tcp.routers.redis.rule" = "HostSNI(`redis.${var.domain}`) || HostSNI(`redis.${node.unique.name}.${var.domain}`)"
          "traefik.tcp.routers.redis.service" = "redis@docker"
          "traefik.tcp.routers.redis.tls.domains[0].main" = "${var.domain}"
          "traefik.tcp.routers.redis.tls.domains[0].sans" = "*.${var.domain},${node.unique.name}.${var.domain}"
          "traefik.tcp.routers.redis.tls.passthrough" = "true"
          "traefik.tcp.services.redis.loadbalancer.server.port" = "${var.redis_port}"
          "traefik.tcp.services.redis.loadbalancer.server.tls" = "true"
        }
        logging {
          type = "json-file"
          config {
            max-size = "1m"
            max-file = "1"
          }
        }
      }

      env {
        TZ             = var.tz
        REDIS_HOST     = var.redis_hostname
        REDIS_PORT     = var.redis_port
        REDIS_DATABASE = var.redis_database
        REDIS_USERNAME = var.redis_username
        REDIS_PASSWORD = var.redis_password
        #REDIS_TLS_CERT_FILE = "/data/redis.crt"
        #REDIS_TLS_KEY_FILE  = "/data/redis.key"
      }

      resources {
        cpu        = 500
        memory     = 4096
        memory_max = 0
      
      }

      service {

        name = "redis"
        port = "redis"
        tags = [
          "traefik.enable=true",
          "traefik.tcp.routers.redis.rule=HostSNI(`redis.${var.domain}`) || HostSNI(`redis.${node.unique.name}.${var.domain}`)",
          "traefik.tcp.routers.redis.service=redis@consulcatalog",
          "traefik.tcp.routers.redis.tls.domains[0].main=${var.domain}",
          "traefik.tcp.routers.redis.tls.domains[0].sans=*.${var.domain},${node.unique.name}.${var.domain}",
          "traefik.tcp.routers.redis.tls.passthrough=true",
          "traefik.tcp.services.redis.loadbalancer.server.port=${var.redis_port}",
          "traefik.tcp.services.redis.loadbalancer.server.tls=true"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "redis-cli -a ${var.redis_password} ping > /dev/null 2>&1 || exit 1"]
          interval = "10s"
          timeout  = "5s"
        }
      }
    }
  }

  # Portainer Group
  group "portainer-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "portainer_http" { to = 9000 }
      port "portainer_api" { to = 8000 }
      port "portainer_https" {
        static = 9443
        to = 9443
      }
    }

    task "portainer" {
      driver = "docker"

      config {
        image = "docker.io/portainer/portainer-ce"
        ports = ["portainer_api", "portainer_http", "portainer_https"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:rw",
          "${var.config_path}/portainer/data:/data"
        ]
        labels = {
          "com.docker.compose.project" = "portainer-group"
          "com.docker.compose.service" = "portainer"
        }
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "portainer"
        port = "portainer_http"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.portainer.middlewares=nginx-auth@file",
          "traefik.http.routers.portainer.service=portainer@consulcatalog",
          "traefik.http.services.portainer.loadbalancer.server.port=9000",
          "kuma.portainer.http.name=portainer.${node.unique.name}.${var.domain}",
          "kuma.portainer.http.url=https://portainer.${var.domain}",
          "kuma.portainer.http.interval=60"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Telemetry Auth Group
  group "telemetry-auth-group" {
    count = 0

    network {
      mode = "bridge"
      
      port "telemetry_auth" {
        static = 8080
        to = 8080
      }
    }

    # KotorModSync Telemetry Auth Service
    task "telemetry-auth" {
      driver = "docker"

      # Note: Docker has build context, but Nomad uses pre-built image
      config {
        image = "bolabaden/kotormodsync-telemetry-auth:latest"
        ports = ["telemetry_auth"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
      }

      env {
        AUTH_SERVICE_PORT = "8080"
        KOTORMODSYNC_SECRET_FILE = "/run/secrets/signing_secret"
        REQUIRE_AUTH = var.require_auth
        MAX_TIMESTAMP_DRIFT = var.max_timestamp_drift
        LOG_LEVEL = var.log_level
      }

      # Secret file template (from secrets.auto.tfvars.hcl)
      template {
        data = <<EOF
{{ with secret "secret/signing_secret" }}{{ .Data.data.value }}{{ end }}
EOF
        destination = "secrets/signing_secret"
        env         = false
      }

      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }

      service {
        name = "telemetry-auth"
        port = "telemetry_auth"
        tags = [
          "telemetry-auth",
          "${var.domain}"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1"]
          interval = "10s"
          timeout  = "3s"
        }
      }
    }
  }

  # Authentik  # Authentik services group
  group "authentik-services" {
    count = 0  # DISABLED: Commented out in docker-compose.yml (line 50)

    network {
      mode = "bridge"
      
      port "authentik" { to = 9000 }
      port "authentik_postgresql" { to = 5432 }
    }

    # Authentik PostgreSQL
    task "authentik-postgresql" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image = "docker.io/postgres:16.3-alpine"
        ports = ["authentik_postgresql"]
        volumes = [
          "${var.config_path}/authentik/postgresql:/var/lib/postgresql/data"
        ]
        labels = {
          "com.docker.compose.project" = "authentik-group"
          "com.docker.compose.service" = "authentik-services"
        }
      }

      env {
        TZ                = var.tz
        POSTGRES_PASSWORD = "authentik"
        POSTGRES_USER     = "authentik"
        POSTGRES_DB       = "authentik"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "authentik-postgresql"
        port = "authentik_postgresql"
        tags = [
          "authentik-postgresql",
          "${var.domain}"
        ]

        check {
          type     = "script"
          command  = "/usr/local/bin/pg_isready"
          args     = ["-d", "authentik", "-U", "authentik"]
          interval = "2s"
          timeout  = "10s"
        }
      }
    }

    # Authentik Server
    task "authentik" {
      driver = "docker"

      config {
        image = "ghcr.io/goauthentik/server:2025.8.3"
        ports = ["authentik"]
        command = "server"
        volumes = [
          "${var.config_path}/authentik/media:/media",
          "${var.config_path}/authentik/custom-templates:/templates"
        ]
        labels = {
          "com.docker.compose.project" = "authentik-group"
          "com.docker.compose.service" = "authentik"
        }
      }

      env {
        TZ                                 = var.tz
        AUTHENTIK_REDIS__HOST              = var.redis_hostname
        AUTHENTIK_POSTGRESQL__HOST         = "authentik-postgresql"
        AUTHENTIK_POSTGRESQL__USER         = "authentik"
        AUTHENTIK_POSTGRESQL__NAME         = "authentik"
        AUTHENTIK_POSTGRESQL__PASSWORD     = "authentik"
        AUTHENTIK_SECRET_KEY               = var.authentik_secret_key
        AUTHENTIK_ERROR_REPORTING__ENABLED = "true"
        AUTHENTIK_EMAIL__HOST              = "smtp.gmail.com"
        AUTHENTIK_EMAIL__PORT              = "587"
        AUTHENTIK_EMAIL__USERNAME          = var.acme_resolver_email
        AUTHENTIK_EMAIL__PASSWORD          = var.gmail_app_password
        AUTHENTIK_EMAIL__USE_TLS           = "true"
        AUTHENTIK_EMAIL__USE_SSL           = "false"
        AUTHENTIK_EMAIL__TIMEOUT           = "10"
        AUTHENTIK_EMAIL__FROM              = var.acme_resolver_email
        AUTHENTIK_BOOTSTRAP__EMAIL         = var.acme_resolver_email
        AUTHENTIK_BOOTSTRAP__PASSWORD      = var.sudo_password
        AUTHENTIK_BOOTSTRAP_EMAIL          = var.acme_resolver_email
        AUTHENTIK_BOOTSTRAP_PASSWORD       = var.sudo_password
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "authentik"
        port = "authentik"
        tags = [
          "traefik.enable=true",
          "traefik.http.middlewares.gzip.compress=true",
          # Redirect Middlewares
          "traefik.http.middlewares.authentik-server-redirect.redirectRegex.regex=^https?://authentik-server\\.((?:${var.domain}|${node.unique.name}\\.${var.domain}))(.*)$$",
          "traefik.http.middlewares.authentik-server-redirect.redirectRegex.replacement=https://authentik.$$1$$2",
          "traefik.http.middlewares.authentik-server-redirect.redirectRegex.permanent=false",
          "traefik.http.middlewares.authentikserver-redirect.redirectRegex.regex=^https?://authentikserver\\.((?:${var.domain}|${node.unique.name}\\.${var.domain}))(.*)$$",
          "traefik.http.middlewares.authentikserver-redirect.redirectRegex.replacement=https://authentik.$$1$$2",
          "traefik.http.middlewares.authentikserver-redirect.redirectRegex.permanent=false",
          # Redirect Routers
          "traefik.http.routers.authentik-server-redirect.service=authentik@consulcatalog",
          "traefik.http.routers.authentik-server-redirect.rule=Host(`authentik-server.${var.domain}`) || Host(`authentik-server.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.authentik-server-redirect.middlewares=authentik-server-redirect@consulcatalog",
          "traefik.http.routers.authentikserver-redirect.service=authentik@consulcatalog",
          "traefik.http.routers.authentikserver-redirect.rule=Host(`authentikserver.${var.domain}`) || Host(`authentikserver.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.authentikserver-redirect.middlewares=authentikserver-redirect@consulcatalog",
          # Main Router
          "traefik.http.routers.authentik.service=authentik",
          "traefik.http.routers.authentik.rule=Host(`authentik.${var.domain}`) || Host(`authentik.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.authentik.middlewares=gzip",
          "traefik.http.services.authentik.loadbalancer.server.port=9000",
          "kuma.authentik.http.name=authentik.${node.unique.name}.${var.domain}",
          "kuma.authentik.http.url=https://authentik.${var.domain}",
          "kuma.authentik.http.interval=60"
        ]

        check {
          type     = "script"
          command  = "/usr/local/bin/python3"
          args     = ["-c", "import socket; s=socket.socket(); s.settimeout(5); s.connect(('127.0.0.1', 9000)); s.close()"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }

    # Authentik Worker
    task "authentik-worker" {
      driver = "docker"

      config {
        image = "ghcr.io/goauthentik/server:2025.8.3"
        command = "worker"
        volumes = [
          "${var.config_path}/authentik/media:/media",
          "${var.config_path}/authentik/certs:/certs",
          "${var.config_path}/authentik/custom-templates:/templates"
        ]
        labels = {
          "com.docker.compose.project" = "authentik-group"
          "com.docker.compose.service" = "authentik-worker"
        }
      }

      user = "root"

      env {
        TZ                                 = var.tz
        AUTHENTIK_REDIS__HOST              = var.redis_hostname
        AUTHENTIK_POSTGRESQL__HOST         = "authentik-postgresql"
        AUTHENTIK_POSTGRESQL__USER         = "authentik"
        AUTHENTIK_POSTGRESQL__NAME         = "authentik"
        AUTHENTIK_POSTGRESQL__PASSWORD     = "authentik"
        AUTHENTIK_SECRET_KEY               = var.authentik_secret_key
        AUTHENTIK_ERROR_REPORTING__ENABLED = "true"
        AUTHENTIK_EMAIL__HOST              = "smtp.gmail.com"
        AUTHENTIK_EMAIL__PORT              = "587"
        AUTHENTIK_EMAIL__USERNAME          = var.acme_resolver_email
        AUTHENTIK_EMAIL__PASSWORD          = var.gmail_app_password
        AUTHENTIK_EMAIL__USE_TLS           = "true"
        AUTHENTIK_EMAIL__USE_SSL           = "false"
        AUTHENTIK_EMAIL__TIMEOUT           = "10"
        AUTHENTIK_EMAIL__FROM              = var.acme_resolver_email
        AUTHENTIK_BOOTSTRAP__EMAIL         = var.acme_resolver_email
        AUTHENTIK_BOOTSTRAP__PASSWORD      = var.sudo_password
        AUTHENTIK_BOOTSTRAP_EMAIL          = var.acme_resolver_email
        AUTHENTIK_BOOTSTRAP_PASSWORD       = var.sudo_password
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }

  # Infrastructure services group
  group "infrastructure-services" {
    count = 1

    network {
      mode = "bridge"
      
      port "dockerproxy_ro" { to = 2375 }
      
      # dockerproxy-rw has ports: 127.0.0.1:2375:2375 in docker-compose.yml
      port "dockerproxy_rw" { to = 2375 }
    }

    # 🔹🔹 Docker Socket Proxy (Read-Only) 🔹🔹
    task "dockerproxy-ro" {
      driver = "docker"

      config {
        image = "docker.io/tecnativa/docker-socket-proxy"
        ports = ["dockerproxy_ro"]
        privileged = true
        userns_mode = "host"  # needed if userns-remap is enabled on the host
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "dockerproxy-ro"
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      env {
        TZ           = var.tz
        PUID         = var.puid
        PGID         = var.pgid
        UMASK        = var.umask
        CONTAINERS   = "1"
        EVENTS       = "1"
        INFO         = "1"
        DISABLE_IPV6 = "0"
      }

      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }

      service {
        name = "dockerproxy-ro"
        port = "dockerproxy_ro"
        tags = ["dockerproxy-ro"]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget --no-verbose --tries=1 --spider http://127.0.0.1:2375/_ping || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }

    # 🔹🔹 Docker Socket Proxy (Read-Write) 🔹🔹
    task "dockerproxy-rw" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/socket-proxy"
        ports = ["dockerproxy_rw"]  # Has ports: 127.0.0.1:2375:2375 in docker-compose.yml
        privileged = true
        userns_mode = "host"  # this is needed if https://docs.docker.com/engine/security/userns-remap/#enable-userns-remap-on-the-daemon is setup
        volumes = [
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "dockerproxy-rw"
        }
      }

      env {
        TZ           = var.tz
        PUID         = var.puid
        PGID         = var.pgid
        UMASK        = var.umask
        # Controls /containers/{id}/start (POST).
        # Set 1 to allow starting containers even if POST=0.
        # Useful for selective starts in read-only mode.
        ALLOW_START  = "1"
        # Controls /containers/{id}/stop (POST).
        # Set 1 to allow stopping containers even if POST=0. Enables remote shutdown without broad write access.
        ALLOW_STOP   = "1"
        # Enables /containers/{id}/stop, /restart, /kill (POST).
        # Set 1 to allow restarts/kills even if POST=0. Useful for health checks and auto-scaling.
        ALLOW_RESTARTS = "1"
        # Controls /auth (POST) for registry authentication.
        # Set 1 to allow credential handling for private image pulls.
        AUTH         = "1"
        # Controls /build (POST) for building images.
        # Set 1 to allow image builds, e.g. for CI tools.
        BUILD        = "1"
        # Controls /commit (POST) to save container changes as new image.
        # Set 1 to allow ad-hoc image creation.
        COMMIT       = "1"
        # Controls /configs endpoints (Swarm).
        # Set 1 to allow config management (create/list/delete).
        CONFIGS      = "1"
        # Controls /containers endpoints.
        # Set 1 to allow list, inspect, create, and manage containers.
        CONTAINERS   = "1"
        # Set 1 to prevent proxy from binding to IPv6 interfaces. Useful for legacy systems.
        DISABLE_IPV6 = "0"
        # Controls /distribution endpoints for image metadata.
        # Set 1 to allow inspection of image distribution info.
        DISTRIBUTION = "1"
        # Enables /events (GET) for real-time Docker event streaming.
        # Set 1 to allow monitoring.
        EVENTS       = "1"
        # Controls /exec and /containers/{id}/exec.
        # Set 1 to allow running commands in containers (shell access).
        EXEC         = "1"
        # Controls /images endpoints.
        # Set 1 to allow image list, pull, remove, etc.
        IMAGES       = "1"
        # Enables /info (GET) for daemon diagnostics.
        # Set 1 to allow health/status queries.
        INFO         = "1"
        # Sets NGINX error_log level (debug, info, warning, etc). Affects proxy logging verbosity.
        LOG_LEVEL    = "info"
        # Controls /networks endpoints.
        # Set 1 to allow network management (create/list/delete).
        NETWORKS     = "1"
        # Controls /nodes endpoints (Swarm).
        # Set 1 to allow node management.
        NODES        = "1"
        # Enables /_ping (GET) for daemon health checks.
        # Set 1 to allow.
        PING         = "1"
        # Controls /plugins endpoints.
        # Set 1 to allow plugin management (enable/disable/list).
        PLUGINS      = "1"
        # Toggles all write methods (POST/PUT/DELETE) globally.
        # Set 0 for read-only except for specific overrides.
        POST         = "1"
        # Controls /secrets endpoints (Swarm).
        # Set 1 to allow secret management.
        SECRETS      = "1"
        # Controls /services endpoints (Swarm).
        # Set 1 to allow service management.
        SERVICES     = "1"
        # Enables /session for interactive protocols (attach/exec).
        # Set 1 to allow.
        SESSION      = "1"
        # Controls /swarm endpoints.
        # Set 1 to allow Swarm cluster management.
        SWARM        = "1"
        # Controls /system subpaths (info, version, df).
        # Set 1 to allow system queries.
        SYSTEM       = "1"
        # Controls /tasks endpoints (Swarm).
        # Set 1 to allow task inspection.
        TASKS        = "1"
        # Enables /version (GET) for daemon/client version info.
        # Set 1 to allow.
        VERSION      = "1"
        # Controls /volumes endpoints.
        # Set 1 to allow volume management (create/list/delete).
        VOLUMES      = "1"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {
        name = "dockerproxy-rw"
        port = "dockerproxy_rw"
        tags = ["dockerproxy-rw"]
      }
    }

    # 🔹🔹 Watchtower 🔹🔹
    task "watchtower" {
      driver = "docker"

      config {
        image = "docker.io/containrrr/watchtower"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:rw"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "watchtower"
        }
      }

      # Watchtower needs Docker credentials config
      # docker credentials acquired through `docker login` on host!
      template {
        data = <<EOF
{
  "auths": {}
}
EOF
        destination = "local/config.json"
        perms       = "0444"
      }

      env {
        # --------------------------------------------------------------------------
        # Docker Host Configuration
        # --------------------------------------------------------------------------
        # Docker daemon socket to connect to. Can be pointed at a remote Docker host
        # by specifying a TCP endpoint as "tcp://hostname:port".
        # Default: "unix:///var/run/docker.sock"
        DOCKER_HOST                        = "unix:///var/run/docker.sock"
        # Docker API version to use by the Docker client for connecting to the Docker daemon.
        # Default: "1.24"
        DOCKER_API_VERSION                 = "1.52"
        # Use TLS when connecting to the Docker socket and verify the server's certificate.
        # Default: false
        DOCKER_TLS_VERIFY                  = "false"
        # --------------------------------------------------------------------------
        # Timezone
        # --------------------------------------------------------------------------
        # Sets the time zone to be used by WatchTower's logs and scheduling.
        # Default: "UTC"
        TZ                                 = var.tz
        # --------------------------------------------------------------------------
        # Registry Authentication (for private image pulls)
        # --------------------------------------------------------------------------
        # Docker registry username for private image pulls (if required).
        # Default: "username"
        REPO_USER                          = "bolabaden"
        # Docker registry password for private image pulls (if required).
        # Default: "password"
        REPO_PASS                          = var.sudo_password
        # --------------------------------------------------------------------------
        # Watchtower Container Filtering and Behavior
        # --------------------------------------------------------------------------
        # Will also include restarting containers.
        # Default: false
        WATCHTOWER_INCLUDE_RESTARTING      = "true"
        # Will also include created and exited containers.
        # Default: false
        WATCHTOWER_INCLUDE_STOPPED         = "true"
        # Start any stopped containers that have had their image updated. Only usable with --include-stopped.
        # Default: false
        WATCHTOWER_REVIVE_STOPPED          = "false"
        # Monitor and update containers that have a com.centurylinklabs.watchtower.enable label set to true.
        # Default: false
        WATCHTOWER_LABEL_ENABLE            = "false"
        # Monitor and update containers whose names are not in a given set of names (comma- or space-separated).
        # Default: ""
        WATCHTOWER_DISABLE_CONTAINERS      = ""
        # By default, arguments will take precedence over labels. If set to true, labels take precedence.
        # Default: false
        WATCHTOWER_LABEL_TAKE_PRECEDENCE   = "true"
        # Update containers that have a com.centurylinklabs.watchtower.scope label set with the same value as the given argument.
        # Default: unset
        WATCHTOWER_SCOPE                   = ""
        # --------------------------------------------------------------------------
        # Update and Polling Behavior
        # --------------------------------------------------------------------------
        # Poll interval (in seconds). Controls how frequently watchtower will poll for new images.
        # Default: 86400 (24 hours)
        WATCHTOWER_POLL_INTERVAL           = "86400"
        # Cron expression in 6 fields which defines when and how often to check for new images.
        # Default: unset
        WATCHTOWER_SCHEDULE                = "0 0 6 * * *"  # Run at 6am daily
        # Will only monitor for new images, send notifications and invoke the pre-check/post-check hooks, but will not update the containers.
        # Default: false
        WATCHTOWER_MONITOR_ONLY            = "false"
        # Do not restart containers after updating.
        # Default: false
        WATCHTOWER_NO_RESTART              = "false"
        # Do not pull new images. Only monitor the local image cache for changes.
        # Default: false
        WATCHTOWER_NO_PULL                 = "false"
        # Removes old images after updating to prevent accumulation of orphaned images.
        # Default: false
        WATCHTOWER_CLEANUP                 = "true"
        # Removes anonymous volumes after updating.
        # Default: false
        WATCHTOWER_REMOVE_VOLUMES          = "false"
        # Restart one image at time instead of stopping and starting all at once.
        # Default: false
        WATCHTOWER_ROLLING_RESTART         = "false"
        # Timeout before the container is forcefully stopped. Example: 30s
        # Default: 10s
        WATCHTOWER_TIMEOUT                 = "10s"
        # Run an update attempt against a container name list one time immediately and exit.
        # Default: false
        WATCHTOWER_RUN_ONCE                = "false"
        # Do not send a message after watchtower started.
        # Default: false
        WATCHTOWER_NO_STARTUP_MESSAGE      = "false"
        # When to warn about HEAD pull requests failing. Possible values: always, auto, never
        # Default: auto
        WATCHTOWER_WARN_ON_HEAD_FAILURE    = "auto"
        # --------------------------------------------------------------------------
        # HTTP API Mode
        # --------------------------------------------------------------------------
        # Runs Watchtower in HTTP API mode, only allowing image updates to be triggered by an HTTP request.
        # Default: false
        WATCHTOWER_HTTP_API_UPDATE         = "false"
        # Sets an authentication token to HTTP API requests. Can also reference a file.
        # Default: unset
        WATCHTOWER_HTTP_API_TOKEN          = ""
        # Keep running periodic updates if the HTTP API mode is enabled.
        # Default: false
        WATCHTOWER_HTTP_API_PERIODIC_POLLS = "false"
        # Enables a metrics endpoint, exposing prometheus metrics via HTTP.
        # NOTE: Requires an API token to be set for WATCHTOWER_HTTP_API_TOKEN (above).
        # Default: false
        WATCHTOWER_HTTP_API_METRICS        = "false"
        # --------------------------------------------------------------------------
        # Logging and Output
        # --------------------------------------------------------------------------
        # Enable debug mode with verbose logging.
        # Default: false
        WATCHTOWER_DEBUG                   = "true"
        # Enable trace mode with very verbose logging. Caution: exposes credentials!
        # Default: false
        WATCHTOWER_TRACE                   = "false"
        # The maximum log level that will be written to STDERR. Possible values: panic, fatal, error, warn, info, debug, trace.
        # Default: info
        WATCHTOWER_LOG_LEVEL               = "debug"
        # Sets what logging format to use for console output. Possible values: Auto, LogFmt, Pretty, JSON.
        # Default: Auto
        WATCHTOWER_LOG_FORMAT              = "Auto"
        # Disable ANSI color escape codes in log output.
        # Default: false
        NO_COLOR                           = "false"
        # Enable programmatic output (porcelain). Possible values: v1
        # Default: unset
        WATCHTOWER_PORCELAIN               = ""
        # --------------------------------------------------------------------------
        # Notification and Reporting
        # --------------------------------------------------------------------------
        # Notification URL(s) for sending update reports (e.g. shoutrrr URLs, email, Slack, etc).
        # Default: unset
        WATCHTOWER_NOTIFICATION_URL        = ""
        # Send a notification report after each update cycle.
        # Default: false
        WATCHTOWER_NOTIFICATION_REPORT     = "true"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }

  # Nginx Traefik Extensions Group
  group "nginx-traefik-extensions-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "nginx_extensions" { to = 80 }
    }

    # Nginx Traefik Extensions (Auth Middleware)
    task "nginx-traefik-extensions" {
      driver = "docker"

      config {
        image = "docker.io/nginx:alpine"
        ports = ["nginx_extensions"]
        volumes = [
          "${var.config_path}/traefik/nginx-middlewares/auth:/etc/nginx/auth:ro"
        ]
        args = ["nginx", "-c", "/local/nginx.conf", "-g", "daemon off;"]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "nginx-traefik-extensions"
        }
      }

      # Nginx configuration template
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
user nginx;
worker_processes auto;

error_log /dev/stderr warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '\n\r$time_iso8601 | $status | $remote_addr | $http_host | $request | ${request_time}ms | '
                    'auth_method="$auth_method" | $http_user_agent | '
                    'request_method=$request_method | '
                    'request_uri=$request_uri | '
                    'query_string=$query_string | '
                    'content_type=$content_type | '
                    'server_protocol=$server_protocol | '
                    'request_scheme=$scheme | '
                    '\n\rheaders: {'
                      '"accept":"$http_accept",'
                      '"accept_encoding":"$http_accept_encoding",'
                      '"cookie":"$http_cookie",'
                      '"x_forwarded_for":"$http_x_forwarded_for",'
                      '"x_forwarded_port":"$http_x_forwarded_port",'
                      '"x_forwarded_proto":"$http_x_forwarded_proto",'
                      '"x_forwarded_host":"$http_x_forwarded_host",'
                      '"x_real_ip":"$http_x_real_ip",'
                      '"x_api_key":"$http_x_api_key",'
                    '}';

    # Output all access logs to stdout for Docker console visibility
    access_log /dev/stdout main;
    error_log /dev/stderr warn;

    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Fix for long API keys in map module
    map_hash_bucket_size 128;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=auth:10m rate=10r/s;

    set_real_ip_from <<<< env "CROWDSEC_GF_SUBNET" | or "10.0.6.0/24" >>>>;
    set_real_ip_from <<<< env "BACKEND_SUBNET" | or "10.0.7.0/24" >>>>;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;

    geo $ip_whitelisted {
        default 0;
        <<<< env "CROWDSEC_GF_SUBNET" | or "10.0.6.0/24" >>>> 1;
        <<<< env "BACKEND_SUBNET" | or "10.0.7.0/24" >>>>     1;
    }

    map $http_x_api_key $api_key_valid {
        default 0;
        "${ var.nginx_auth_api_key }" 1;
        # Add more API keys here as needed
    }

    upstream tinyauth {
        server auth:3000;
    }

    server {
        listen 80 default_server;
        server_name _;

        set $auth_passed 0;
        set $auth_method "none";

        if ($api_key_valid = 1) {
            set $auth_passed 1;
            set $auth_method "api_key";
        }

        if ($ip_whitelisted = 1) {
            set $auth_passed 1;
            set $auth_method "ip_whitelist";
        }

        location /auth {
            limit_req zone=auth burst=20 nodelay;
            if ($auth_passed = 1) {
                add_header X-Auth-Method "$auth_method" always;
                add_header X-Auth-Passed "true" always;
                return 200 "OK";
            }

            proxy_pass http://tinyauth/api/auth/traefik;
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
            proxy_set_header X-Original-URI $http_x_original_uri;
            proxy_set_header X-Original-Method $http_x_original_method;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $http_x_forwarded_host;
            add_header X-Auth-Method "tinyauth" always;
            access_log /dev/stdout main;
        }

        location /health {
            access_log /dev/stdout main;
            return 200 "nginx service healthy\n";
            add_header Content-Type text/plain;
        }

        location / {
            access_log /dev/stdout main;
            return 200 "nginx service healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF
        destination = "local/nginx.conf"
      }

      env {
        TZ                 = var.tz
        NGINX_ACCESS_LOG   = "/dev/stdout"
        NGINX_ERROR_LOG    = "/dev/stderr"
        NGINX_LOG_LEVEL    = "debug"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "nginx-traefik-extensions"
        port = "nginx_extensions"
        tags = [
          "nginx-traefik-extensions",
          "${var.domain}"
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Tinyauth Group
  group "tinyauth-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "tinyauth" { to = 3000 }
    }

    # TinyAuth
    task "tinyauth" {
      driver = "docker"

      config {
        image = "ghcr.io/steveiliop56/tinyauth:v3"
        ports = ["tinyauth"]
        volumes = [
          "${var.config_path}/traefik/tinyauth:/data"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "tinyauth"
        }
      }

      env {
        TZ                     = var.tz
        SECRET                 = var.tinyauth_secret
        APP_URL                = "https://auth.${var.domain}"
        USERS                  = var.tinyauth_users
        GOOGLE_CLIENT_ID       = var.tinyauth_google_client_id
        GOOGLE_CLIENT_SECRET   = var.tinyauth_google_client_secret
        GITHUB_CLIENT_ID       = var.tinyauth_github_client_id
        GITHUB_CLIENT_SECRET   = var.tinyauth_github_client_secret
        SESSION_EXPIRY         = "604800"
        COOKIE_SECURE          = "true"
        APP_TITLE              = var.domain
        LOGIN_MAX_RETRIES      = "15"
        LOGIN_TIMEOUT          = "300"
        OAUTH_AUTO_REDIRECT    = "none"
        OAUTH_WHITELIST        = var.tinyauth_oauth_whitelist
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "tinyauth"
        port = "tinyauth"
        tags = [
          "tinyauth",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.tinyauth.rule=Host(`auth.${var.domain}`) || Host(`auth.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.tinyauth.loadbalancer.server.port=3000"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Traefik Group
  # Crowdsec Group
  group "crowdsec-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "crowdsec_lapi" {
        static = 9876
        to = 8080
      }
      port "crowdsec_appsec" { to = 7422 }
      port "crowdsec_metrics" { to = 6060 }
    }

    # 🔹🔹 CrowdSec 🔹🔹
    # Highly recommend this guide: https://blog.lrvt.de/configuring-crowdsec-with-traefik/
    task "crowdsec" {
      driver = "docker"

      config {
        image = "docker.io/crowdsecurity/crowdsec:v1.7.0"
        ports = ["crowdsec_lapi", "crowdsec_appsec", "crowdsec_metrics"]
        volumes = [
          "${var.config_path}/traefik/crowdsec/data:/var/lib/crowdsec/data:rw",
          "${var.config_path}/traefik/crowdsec/etc/crowdsec:/etc/crowdsec:rw",
          "${var.config_path}/traefik/crowdsec/plugins:/usr/local/lib/crowdsec/plugins:rw",
          # Log bind mounts into crowdsec
          "${var.config_path}/traefik/logs:/var/log/traefik:ro"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "crowdsec"
        }
      }

      env {
        TZ          = var.tz
        UID         = var.puid
        GID         = var.pgid
        COLLECTIONS = "crowdsecurity/appsec-crs crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching crowdsecurity/whitelist-good-actors crowdsecurity/base-http-scenarios crowdsecurity/http-cve crowdsecurity/linux crowdsecurity/sshd"
      }

      # CrowdSec Config Templates
      # CrowdSec files are typically access restricted (644) by the root user.
      # If your log files are stored onto an NFS share, you may want to use poll_without_inotify: true for each log source
      
      # docker exec crowdsec cscli notifications list
      
      # crowdsec-config.yaml
      template {
        data = <<EOF
common:
  log_media: stdout
  log_level: info
  log_dir: /var/log/
config_paths:
  config_dir: /etc/crowdsec/
  data_dir: /var/lib/crowdsec/data/
  simulation_path: /etc/crowdsec/simulation.yaml
  hub_dir: /etc/crowdsec/hub/
  index_path: /etc/crowdsec/hub/.index.json
  notification_dir: /etc/crowdsec/notifications/
  plugin_dir: /usr/local/lib/crowdsec/plugins/
crowdsec_service:
  acquisition_path: /etc/crowdsec/acquis.yaml
  acquisition_dir: /etc/crowdsec/acquis.d
  parser_routines: 1
plugin_config:
  user: nobody
  group: nobody
cscli:
  output: human
db_config:
  log_level: info
  type: sqlite
  db_path: /var/lib/crowdsec/data/crowdsec.db
  flush:
    max_items: 5000
    max_age: 7d
  use_wal: false
api:
  client:
    insecure_skip_verify: false
    credentials_path: /etc/crowdsec/local_api_credentials.yaml
  server:
    log_level: info
    listen_uri: 0.0.0.0:8080
    profiles_path: /etc/crowdsec/profiles.yaml
    trusted_ips:
      - 127.0.0.1
      - ::1
      - 172.16.0.0/12
      - 10.0.0.0/8
    online_client:
      credentials_path: /etc/crowdsec//online_api_credentials.yaml
    enable: true
prometheus:
  enabled: true
  level: full
  listen_addr: 0.0.0.0
  listen_port: 6060
EOF
        destination = "local/config.yaml"
        perms       = "0644"
      }
      
      # crowdsec-acquis.yaml
      template {
        data = <<EOF
filenames:
  - /var/log/auth.log
  - /var/log/syslog
labels:
  type: syslog
---
poll_without_inotify: false
filenames:
  - {{ env "TRAEFIK_INTERNAL_LOG_DIR" | or "/var/log/traefik" }}/*.log
#  - {{ env "TRAEFIK_INTERNAL_LOG_DIR" | or "/var/log/traefik" }}/access.log
labels:
  type: traefik
EOF
        destination = "local/acquis.yaml"
        perms       = "0644"
      }

      # crowdsec-profiles.yaml
      # If you are already using other custom notification channels, make sure to only add `http_victoriametrics` to the mix.
      # Your already existing notification channels should remain unchanged.
      template {
        data = <<EOF
name: default_ip_remediation
#debug: true
filters:
- Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
- type: ban
  duration: 4h
#duration_expr: Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 4)
#notifications:
#   - email_default         # Set the required email parameters in /etc/crowdsec/notifications/email.yaml before enabling this.
#   - http_victoriametrics  # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
#   - slack_default         # Set the webhook in /etc/crowdsec/notifications/slack.yaml before enabling this.
#   - splunk_default        # Set the splunk url and token in /etc/crowdsec/notifications/splunk.yaml before enabling this.
#   - http_default          # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
on_success: break
---
name: default_range_remediation
#debug: true
filters:
- Alert.Remediation == true && Alert.GetScope() == "Range"
decisions:
- type: ban
  duration: 4h
#duration_expr: Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 4)
#notifications:
#   - email_default         # Set the required email parameters in /etc/crowdsec/notifications/email.yaml before enabling this.
#   - http_victoriametrics  # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
#   - slack_default         # Set the webhook in /etc/crowdsec/notifications/slack.yaml before enabling this.
#   - splunk_default        # Set the splunk url and token in /etc/crowdsec/notifications/splunk.yaml before enabling this.
#   - http_default          # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
on_success: break
EOF
        destination = "local/profiles.yaml"
        perms       = "0644"
      }

      # crowdsec-victoriametrics.yaml  
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: http
name: http_victoriametrics
log_level: debug
format: >
  {{- range $$Alert := . -}}
  {{- $$traefikRouters := GetMeta . "traefik_router_name" -}}
  {{- range .Decisions -}}
  {"metric":{"__name__":"cs_lapi_decision","instance":"my-instance","country":"{{$$Alert.Source.Cn}}","asname":"{{$$Alert.Source.AsName}}","asnumber":"{{$$Alert.Source.AsNumber}}","latitude":"{{$$Alert.Source.Latitude}}","longitude":"{{$$Alert.Source.Longitude}}","iprange":"{{$$Alert.Source.Range}}","scenario":"{{.Scenario}}","type":"{{.Type}}","duration":"{{.Duration}}","scope":"{{.Scope}}","ip":"{{.Value}}","traefik_routers":{{ printf "%q" ($$traefikRouters | uniq | join ",")}}},"values": [1],"timestamps":[{{now|unixEpoch}}000]}
  {{- end }}
  {{- end -}}
url: http://victoriametrics:<<<< env "VICTORIAMETRICS_PORT" | or "8428" >>>>/api/v1/import
method: POST
headers:
  Content-Type: application/json
  # if you use vmauth as proxy, please uncomment next line and add your token
  # If you would like to add authentication, please read about vmauth.
  # https://docs.victoriametrics.com/victoriametrics/vmauth/?ref=blog.lrvt.de#bearer-token-auth-proxy
  # It's basically another Docker container service, which acts as proxy in front of VictoriaMetrics and enforces Bearer HTTP Authentication.
  # Authorization: "<<<< env "VICTORIAMETRICS_AUTH_TOKEN" | or "" >>>>"
EOF
        destination = "local/notifications/victoriametrics.yaml"
        perms       = "0644"
      }

      # crowdsec-email.yaml - docker exec crowdsec cscli notifications test email_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: email           # Don't change
name: email_default   # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: info

# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
timeout: 20s          # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the email message body
format: |
  <html><body>
  {{range . -}}
    {{$$alert := . -}}
    {{range .Decisions -}}
      <p><a href="https://www.whois.com/whois/{{.Value}}">{{.Value}}</a> will get <b>{{.Type}}</b> for next <b>{{.Duration}}</b> for triggering <b>{{.Scenario}}</b> on machine <b>{{$$alert.MachineID}}</b>.</p> <p><a href="https://app.crowdsec.net/cti/{{.Value}}">CrowdSec CTI</a></p>
    {{end -}}
  {{end -}}
  </body></html>

smtp_host: <<<< env "CROWDSEC_SMTP_HOST" | or "smtp.gmail.com" >>>>  # example: smtp.gmail.com
smtp_username: <<<< with (env "CROWDSEC_SMTP_USERNAME") >>>><<<< . >>>><<<< else >>>>${ var.acme_resolver_email }<<<< end >>>>
smtp_password: <<<< with (env "CROWDSEC_SMTP_PASSWORD") >>>><<<< . >>>><<<< else >>>>${ var.gmail_app_password }<<<< end >>>>
smtp_port: <<<< env "CROWDSEC_SMTP_PORT" | or "587" >>>>   # Common values are any of [25, 465, 587, 2525]
auth_type: <<<< env "CROWDSEC_SMTP_AUTH_TYPE" | or "login" >>>>   # Valid choices are "none", "crammd5", "login", "plain"
sender_name: "CrowdSec"
sender_email: <<<< with (env "CROWDSEC_SENDER_EMAIL") >>>><<<< . >>>><<<< else >>>>${ var.acme_resolver_email }<<<< end >>>>
email_subject: "CrowdSec Security Alert"
receiver_emails:
  - <<<< env "CROWDSEC_RECEIVER_EMAIL" | or "admin@localhost" >>>>
  - <<<< env "ACME_RESOLVER_EMAIL" >>>>
# - email1@gmail.com
# - email2@gmail.com

# One of "ssltls", "starttls", "none"
encryption_type: "ssltls"

# If you need to set the HELO hostname:
# helo_host: "localhost"

# If the email server is hitting the default timeouts (10 seconds), you can increase them here
#
# connect_timeout: 10s
# send_timeout: 10s

---

# type: email
# name: email_second_notification
# ...
EOF
        destination = "local/email.yaml"
        perms       = "0644"
      }

      # crowdsec-file.yaml - docker exec crowdsec cscli notifications test file_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
# Don't change this
type: file

name: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_NAME" | or "file_default" >>>>  # this must match with the registered plugin in the profile
log_level: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_LOG_LEVEL" | or "info" >>>>  # Options include: trace, debug, info, warn, error, off

# This template render all events as ndjson
format: |
  {{range . -}}
  { "time": "{{.StopAt}}", "program": "crowdsec", "alert": {{. | toJSON >>>> }
  {{ end -}}

group_wait: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_GROUP_WAIT" | or "30s" >>>>  # duration to wait collecting alerts before sending to this plugin
group_threshold: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_GROUP_THRESHOLD" | or "10" >>>>  # if alerts exceed this, then the plugin will be sent the message

# Use full path EG /tmp/crowdsec_alerts.json or %TEMP%\crowdsec_alerts.json
log_path: "<<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_LOG_PATH" | or "/tmp/crowdsec_alerts.json" >>>>"
rotate:
  enabled: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_ROTATE_ENABLED" | or "true" >>>>  # Change to false if you want to handle log rotate on system basis
  max_size: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_MAX_SIZE" | or "500" >>>>  # in MB
  max_files: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_MAX_FILES" | or "5" >>>>
  max_age: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_MAX_AGE" | or "5" >>>>
  compress: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_COMPRESS" | or "true" >>>>
EOF
        destination = "local/file.yaml"
        perms       = "0644"
      }

      # crowdsec-http.yaml - docker exec crowdsec cscli notifications test http_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: http          # Don't change
name: http_default  # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: <<<< env "CROWDSEC_HTTP_LOG_LEVEL" | or "info" >>>>

# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
# timeout:            # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the http request body
format: |
  {{.|toJSON}}

# The plugin will make requests to this url, eg:  https://www.cloudflare.com/
url: <<<< env "CROWDSEC_HTTP_URL" | or "https://grafana.${var.domain}/api/annotations" >>>>

# Any of the http verbs: "POST", "GET", "PUT"...
method: <<<< env "CROWDSEC_HTTP_METHOD" | or "POST" >>>>

# headers:
#   Authorization: token 0x64312313
#   Content-Type: application/json

skip_tls_verification: <<<< env "CROWDSEC_HTTP_SKIP_TLS_VERIFICATION" | or "false" >>>>  # true or false. Default is false

---

# type: http
# name: http_second_notification
# ...
EOF
        destination = "local/http.yaml"
        perms       = "0644"
      }

      # crowdsec-slack.yaml - docker exec crowdsec cscli notifications test slack_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: slack           # Don't change
name: slack_default   # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: info

# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
# timeout:            # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the slack message
format: |
  {{range . -}}
  {{$$alert := . -}}
  {{range .Decisions -}}
  {{if $$alert.Source.Cn -}}
  :flag-{{$$alert.Source.Cn}}: <https://www.whois.com/whois/{{.Value}}|{{.Value}}> will get {{.Type}} for next {{.Duration}} for triggering {{.Scenario}} on machine '{{$$alert.MachineID}}'. <https://app.crowdsec.net/cti/{{.Value}}|CrowdSec CTI>{{end}}
  {{if not $$alert.Source.Cn -}}
  :pirate_flag: <https://www.whois.com/whois/{{.Value}}|{{.Value}}> will get {{.Type}} for next {{.Duration}} for triggering {{.Scenario}} on machine '{{$$alert.MachineID}}'.  <https://app.crowdsec.net/cti/{{.Value}}|CrowdSec CTI>{{end}}
  {{end -}}
  {{end -}}


webhook: <<<< env "CROWDSEC_SLACK_WEBHOOK_URL" | or "<SLACK_WEBHOOK_URL>" >>>>

# API request data as defined by the Slack webhook API.
#channel: <CHANNEL_NAME>
#username: <USERNAME>
#icon_emoji: <ICON_EMOJI>
#icon_url: <ICON_URL>

---

# type: slack
# name: slack_second_notification
# ...
EOF
        destination = "local/slack.yaml"
        perms       = "0644"
      }

      # crowdsec-splunk.yaml - docker exec crowdsec cscli notifications test splunk_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: splunk          # Don't change
name: <<<< env "CROWDSEC_SPLUNK_FIRST_NOTIFICATION_NAME" | or "splunk_default" >>>>  # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: <<<< env "CROWDSEC_SPLUNK_FIRST_NOTIFICATION_LOG_LEVEL" | or "info" >>>>

# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
# timeout:            # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the splunk notification
format: |
  {{.|toJSON}}

url: <<<< env "CROWDSEC_SPLUNK_FIRST_NOTIFICATION_HTTP_URL" | or "<SPLUNK_HTTP_URL>" >>>>
token: <<<< env "CROWDSEC_SPLUNK_FIRST_NOTIFICATION_TOKEN" | or "<SPLUNK_TOKEN>" >>>>

---

# type: splunk
# name: splunk_second_notification
# ...
EOF
        destination = "local/splunk.yaml"
        perms       = "0644"
      }

      # crowdsec-sentinel.yaml - docker exec crowdsec cscli notifications test sentinel_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: sentinel          # Don't change
name: <<<< env "CROWDSEC_SENTINEL_FIRST_NOTIFICATION_NAME" | or "sentinel_default" >>>>  # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: <<<< env "CROWDSEC_SENTINEL_FIRST_NOTIFICATION_LOG_LEVEL" | or "info" >>>>
# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
# timeout:            # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the http request body
format: |
  {{.|toJSON}}

customer_id: <<<< env "CROWDSEC_SENTINEL_FIRST_NOTIFICATION_CUSTOMER_ID" | or "XXX-XXX" >>>>
shared_key: <<<< env "CROWDSEC_SENTINEL_FIRST_NOTIFICATION_SHARED_KEY" | or "XXXXXXX" >>>>
EOF
        destination = "local/sentinel.yaml"
        perms       = "0644"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "crowdsec"
        port = "crowdsec_lapi"
        tags = [
          "crowdsec",
          "${var.domain}"
        ]

        check {
          type     = "script"
          command  = "/usr/local/bin/cscli"
          args     = ["version"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  group "traefik-group" {
    count = 3  # HA: Run on multiple nodes for failover


    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "traefik_api" { to = 8080 }
      port "traefik_http" {
        static = 80
        to = 80
      }
      port "traefik_https" {
        static = 443
        to = 443
      }
    }

    # https://doc.traefik.io
    task "traefik" {
      driver = "docker"

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"

      config {
        image = "docker.io/traefik:latest"
        ports = ["traefik_api", "traefik_http", "traefik_https"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        cap_add = ["NET_ADMIN"]
        volumes = [
          # Dynamic config is now generated via template in /local/dynamic/
          "${var.config_path}/traefik/certs:/certs",
          "${var.config_path}/traefik/plugins-local:/plugins-local",
          "${var.config_path}/traefik/logs:/var/log/traefik:rw"
        ]
        command = "--accessLog=true"
        args = [
          "--accessLog.bufferingSize=0",
          "--accessLog.fields.headers.defaultMode=drop",
          "--accessLog.fields.headers.names.User-Agent=keep",
          "--accessLog.fields.names.StartUTC=drop",
          "--accessLog.filePath=/var/log/traefik/traefik.log",
          "--accessLog.filters.statusCodes=100-999",
          "--accessLog.format=json",
          "--metrics.prometheus.buckets=0.1,0.3,1.2,5.0",
          "--api.dashboard=true",
          "--api.debug=true",
          "--api.disableDashboardAd=true",
          "--api.insecure=true",
          "--api=true",
          "--certificatesResolvers.letsencrypt.acme.caServer=${var.traefik_ca_server}",
          "--certificatesResolvers.letsencrypt.acme.dnsChallenge=${var.traefik_dns_challenge}",
          "--certificatesResolvers.letsencrypt.acme.dnsChallenge.provider=cloudflare",
          "--certificatesResolvers.letsencrypt.acme.dnsChallenge.resolvers=${var.traefik_dns_resolvers}",
          "--certificatesResolvers.letsencrypt.acme.email=${var.acme_resolver_email}",
          "--certificatesResolvers.letsencrypt.acme.httpChallenge=${var.traefik_http_challenge}",
          "--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=web",
          "--certificatesResolvers.letsencrypt.acme.tlsChallenge=${var.traefik_tls_challenge}",
          "--certificatesResolvers.letsencrypt.acme.storage=/certs/acme.json",
          "--entryPoints.web.address=:80",
          "--entryPoints.web.http.redirections.entryPoint.scheme=https",
          "--entryPoints.web.http.redirections.entryPoint.to=websecure",
          "--entryPoints.web.forwardedHeaders.trustedIPs=103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,104.16.0.0/13,104.24.0.0/14,108.162.192.0/18,131.0.72.0/22,141.101.64.0/18,162.158.0.0/15,172.64.0.0/13,173.245.48.0/20,188.114.96.0/20,190.93.240.0/20,197.234.240.0/22,198.41.128.0/17,2400:cb00::/32,2405:8100::/32,2405:b500::/32,2606:4700::/32,2803:f800::/32,2a06:98c0::/29,2c0f:f248::/32",
          "--entryPoints.websecure.forwardedHeaders.trustedIPs=103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,104.16.0.0/13,104.24.0.0/14,108.162.192.0/18,131.0.72.0/22,141.101.64.0/18,162.158.0.0/15,172.64.0.0/13,173.245.48.0/20,188.114.96.0/20,190.93.240.0/20,197.234.240.0/22,198.41.128.0/17,2400:cb00::/32,2405:8100::/32,2405:b500::/32,2606:4700::/32,2803:f800::/32,2a06:98c0::/29,2c0f:f248::/32",
          "--entryPoints.websecure.address=:443",
          "--entryPoints.websecure.http.encodeQuerySemiColons=true",
          "--entryPoints.websecure.http.middlewares=bolabaden-error-pages@file,crowdsec@file,strip-www@file",
          "--entryPoints.websecure.http.tls=true",
          "--entryPoints.websecure.http.tls.certResolver=letsencrypt",
          "--entryPoints.websecure.http.tls.domains[0].main=${var.domain}",
          "--entryPoints.websecure.http.tls.domains[0].sans=www.${var.domain},*.${var.domain},*.${node.unique.name}.${var.domain}",
          "--entryPoints.websecure.http2.maxConcurrentStreams=100",
          "--entryPoints.websecure.http3",
          "--global.checkNewVersion=true",
          "--global.sendAnonymousUsage=false",
          "--log.level=INFO",
          "--ping=true",
          "--providers.consulCatalog=true",
          "--providers.consulCatalog.endpoint.address=172.26.64.1:8500",
          "--providers.consulCatalog.exposedByDefault=false",
          "--providers.consulCatalog.defaultRule=Host(`{{ normalize .Name }}.${var.domain}`) || Host(`{{ normalize .Name }}.${node.unique.name}.${var.domain}`)",
          "--providers.consulCatalog.watch=true",
          "--providers.consulCatalog.prefix=traefik",
          "--providers.file.directory=/local/dynamic/",
          "--providers.file.watch=true",
          "--experimental.plugins.bouncer.modulename=github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin",
          "--experimental.plugins.bouncer.version=v1.4.5",
          "--experimental.plugins.traefikerrorreplace.modulename=github.com/PseudoResonance/traefikerrorreplace",
          "--experimental.plugins.traefikerrorreplace.version=v1.0.1",
          "--serversTransport.insecureSkipVerify=true"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "traefik"
          "traefik.enable" = "true"
          "traefik.http.routers.traefik.service" = "api@internal"
          "traefik.http.routers.traefik.rule" = "Host(`traefik.${var.domain}`) || Host(`traefik.${node.unique.name}.${var.domain}`)"
          "traefik.http.services.traefik.loadbalancer.server.port" = "8080"
          "homepage.group" = "Infrastructure"
          "homepage.name" = "Traefik"
          "homepage.icon" = "traefik.png"
          "homepage.href" = "https://traefik.${var.domain}/dashboard"
          "homepage.widget.type" = "traefik"
          "homepage.widget.url" = "http://traefik:8080"
          "homepage.description" = "Reverse proxy entrypoint for all services with TLS, Cloudflare integration, and auth middleware"
          "kuma.traefik.http.name" = "traefik.${node.unique.name}.${var.domain}"
          "kuma.traefik.http.url" = "https://traefik.${var.domain}/dashboard"
          "kuma.traefik.http.interval" = "20"
        }
      }

      env {
        TZ                  = var.tz
        LETS_ENCRYPT_EMAIL  = var.acme_resolver_email
        CLOUDFLARE_EMAIL    = var.cloudflare_email
        CLOUDFLARE_API_KEY  = var.cloudflare_api_key
        CLOUDFLARE_ZONE_ID  = var.cloudflare_zone_id
        CROWDSEC_LAPI_KEY   = var.crowdsec_lapi_key
        CROWDSEC_BOUNCER_ENABLED = var.crowdsec_bouncer_enabled
      }

      template {
        data = <<EOF
{{ range service "crowdsec" -}}
CROWDSEC_LAPI_HOST="{{ .Address }}:{{ .Port }}"
{{ end -}}
{{ range service "crowdsec" }}{{ range .Tags }}{{ if . | contains "crowdsec_appsec" -}}
CROWDSEC_APPSEC_HOST="{{ .Address }}:{{ .Port }}"
{{ end }}{{ end }}{{ end -}}
EOF
        destination = "secrets/crowdsec-endpoints.env"
        env         = true
      }

      # traefik-dynamic.yaml - Core dynamic configuration
      template {
        data = <<EOF
# yaml-language-server: $schema=https://www.schemastore.org/traefik-v3-file-provider.json
http:
  routers:
    nomad-ui:
      entryPoints:
        - web
        - websecure
      service: nomad-ui@file
      rule: Host(`nomad.${var.domain}`) || Host(`nomad.${node.unique.name}.${var.domain}`)
      middlewares:
        - nginx-auth@file
      priority: 100
    consul-ui:
      entryPoints:
        - web
        - websecure
      service: consul-ui@file
      rule: Host(`consul.${var.domain}`) || Host(`consul.${node.unique.name}.${var.domain}`)
      middlewares:
        - nginx-auth@file
      priority: 100
    catchall:
      entryPoints:
        - web
        - websecure
      service: noop@internal
      rule: Host(`${var.domain}`) || Host(`${node.unique.name}.${var.domain}`) || HostRegexp(`^(.+)$`)
      priority: 1
      middlewares:
        - traefikerrorreplace@file
  services:
    nomad-ui:
      loadBalancer:
        servers:
          - url: http://172.26.64.1:4646
    consul-ui:
      loadBalancer:
        servers:
          - url: http://172.26.64.1:8500
    nginx-traefik-extensions:
      loadBalancer:
        servers:
          - url: http://nginx-traefik-extensions:80
    bolabaden-nextjs:
      loadBalancer:
        servers:
          - url: http://bolabaden-nextjs:3000
  serversTransports:
    default:
      insecureSkipVerify: true
  middlewares:
    traefikerrorreplace:
      plugin:
        traefikerrorreplace:
          matchStatus:
            - 418
          replaceStatus: 404
    bolabaden-error-pages:
      errors:
        status:
          - 400-599
        service: bolabaden-nextjs@file
        query: /api/error/{status}
    nginx-auth:
      forwardAuth:
        address: http://nginx-traefik-extensions:80/auth
        trustForwardHeader: true
        authResponseHeaders: ["X-Auth-Method", "X-Auth-Passed", "X-Middleware-Name"]
    strip-www:
      redirectRegex:
        regex: '^(http|https)?://www\.(.+)$'
        replacement: '$1://$2'
        permanent: false
    crowdsec:
      plugin:
        bouncer:
          # Enable the plugin (default: false)
          enabled: {{ env "CROWDSEC_BOUNCER_ENABLED" | or "false" }}

          # Log level (default: INFO, expected: INFO, DEBUG, ERROR)
          logLevel: {{ env "CROWDSEC_BOUNCER_LOG_LEVEL" | or "INFO" }}

          # File path to write logs (default: "")
          logFilePath: "{{ env "CROWDSEC_BOUNCER_LOG_FILE_PATH" | or "" }}"

          # Interval in seconds between metrics updates to Crowdsec (default: 600, <=0 disables metrics)
          metricsUpdateIntervalSeconds: {{ env "CROWDSEC_BOUNCER_METRICS_UPDATE_INTERVAL_SECONDS" | or "600" }}

          # Mode for Crowdsec integration (default: live, expected: none, live, stream, alone, appsec)
          crowdsecMode: {{ env "CROWDSEC_BOUNCER_MODE" | or "live" }}

          # Enable Crowdsec Appsec Server (WAF) (default: false)
          crowdsecAppsecEnabled: {{ env "CROWDSEC_APPSEC_ENABLED" | or "false" }}

          # Crowdsec Appsec Server host and port (default: "crowdsec:7422")
          crowdsecAppsecHost: {{ env "CROWDSEC_APPSEC_HOST" | or "10.16.1.78:23733" }}

          # Crowdsec Appsec Server path (default: "/")
          crowdsecAppsecPath: {{ env "CROWDSEC_APPSEC_PATH" | or "/" }}

          # Block request when Crowdsec Appsec Server returns 500 (default: true)
          crowdsecAppsecFailureBlock: {{ env "CROWDSEC_APPSEC_FAILURE_BLOCK" | or "true" }}

          # Block request when Crowdsec Appsec Server is unreachable (default: true)
          crowdsecAppsecUnreachableBlock: {{ env "CROWDSEC_APPSEC_UNREACHABLE_BLOCK" | or "true" }}

          # Transmit only the first number of bytes to Crowdsec Appsec Server (default: 10485760 = 10MB)
          crowdsecAppsecBodyLimit: {{ env "CROWDSEC_APPSEC_BODY_LIMIT" | or "10485760" }}

          # Scheme for Crowdsec LAPI (default: http, expected: http, https)
          crowdsecLapiScheme: {{ env "CROWDSEC_LAPI_SCHEME" | or "http" }}

          # Crowdsec LAPI host and port (default: "crowdsec:8080")
          crowdsecLapiHost: {{ env "CROWDSEC_LAPI_HOST" | or "10.16.1.78:9876" }}

          # Crowdsec LAPI path (default: "/")
          crowdsecLapiPath: {{ env "CROWDSEC_LAPI_PATH" | or "/" }}

          # Crowdsec LAPI key for the bouncer (default: "")
          crowdsecLapiKey: {{ env "CROWDSEC_LAPI_KEY" | or "" }}

          # Disable TLS verification for Crowdsec LAPI (default: false)
          crowdsecLapiTlsInsecureVerify: {{ env "CROWDSEC_LAPI_TLS_INSECURE_VERIFY" | or "false" }}

          # PEM-encoded CA for Crowdsec LAPI (default: "")
          crowdsecLapiTlsCertificateAuthority: "{{ env "CROWDSEC_LAPI_TLS_CA" | or "" }}"

          # PEM-encoded client certificate for the Bouncer (default: "")
          crowdsecLapiTlsCertificateBouncer: "{{ env "CROWDSEC_LAPI_TLS_CERT" | or "" }}"

          # PEM-encoded client key for the Bouncer (default: "")
          crowdsecLapiTlsCertificateBouncerKey: "{{ env "CROWDSEC_LAPI_TLS_KEY" | or "" }}"

          # Name of the header in response when requests are cancelled (default: "")
          remediationHeadersCustomName: "{{ env "CROWDSEC_BOUNCER_REMEDIATION_HEADER_NAME" | or "" }}"

          # Name of the header where real client IP is retrieved (default: "X-Forwarded-For")
          forwardedHeadersCustomName: "{{ env "CROWDSEC_BOUNCER_FORWARDED_HEADER_NAME" | or "X-Forwarded-For" }}"      

          # Enable Redis cache (default: false)
          redisCacheEnabled: {{ env "CROWDSEC_BOUNCER_REDIS_ENABLED" | or "false" }}

          # Redis hostname and port (default: "redis:6379")
          redisCacheHost: {{ env "CROWDSEC_BOUNCER_REDIS_HOST" | or "redis:6379" }}

          # Redis password (default: "")
          redisCachePassword: "{{ env "CROWDSEC_BOUNCER_REDIS_PASSWORD" | or "" }}"

          # Redis database selection (default: "")
          redisCacheDatabase: "{{ env "CROWDSEC_BOUNCER_REDIS_DB" | or "" }}"

          # Block request when Redis is unreachable (default: true, adds 1s delay)
          redisCacheUnreachableBlock: {{ env "CROWDSEC_BOUNCER_REDIS_UNREACHABLE_BLOCK" | or "true" }}

          # Default timeout in seconds for contacting Crowdsec LAPI (default: 10)
          httpTimeoutSeconds: {{ env "CROWDSEC_BOUNCER_HTTP_TIMEOUT_SECONDS" | or "10" }}

          # Interval between LAPI fetches in stream mode (default: 60)
          updateIntervalSeconds: {{ env "CROWDSEC_BOUNCER_UPDATE_INTERVAL_SECONDS" | or "60" }}

          # Max failures before blocking traffic in stream/alone mode (default: 0, -1 = never block)
          updateMaxFailure: {{ env "CROWDSEC_BOUNCER_UPDATE_MAX_FAILURE" | or "0" }}

          # Maximum decision duration in live mode (default: 60)
          defaultDecisionSeconds: {{ env "CROWDSEC_BOUNCER_DEFAULT_DECISION_SECONDS" | or "60" }}

          # HTTP status code for banned user (default: 403)
          remediationStatusCode: {{ env "CROWDSEC_BOUNCER_REMEDIATION_STATUS_CODE" | or "403" }}

          # CAPI Machine ID (used only in alone mode)
          crowdsecCapiMachineId: {{ env "CROWDSEC_CAPI_MACHINE_ID" | or "" }}

          # CAPI Password (used only in alone mode)
          crowdsecCapiPassword: "{{ env "CROWDSEC_CAPI_PASSWORD" | or "" }}"

          # CAPI Scenarios (used only in alone mode)
          crowdsecCapiScenarios: {{ env "CROWDSEC_CAPI_SCENARIOS" | or "[]" }}

          # Captcha provider (expected: hcaptcha, recaptcha, turnstile)
          captchaProvider: "{{ env "CROWDSEC_BOUNCER_CAPTCHA_PROVIDER" | or "" }}"

          # Captcha site key
          captchaSiteKey: "{{ env "CROWDSEC_BOUNCER_CAPTCHA_SITE_KEY" | or "" }}"

          # Captcha secret key
          captchaSecretKey: "{{ env "CROWDSEC_BOUNCER_CAPTCHA_SECRET_KEY" | or "" }}"

          # Grace period after captcha validation before revalidation required (default: 1800s = 30m)
          captchaGracePeriodSeconds: {{ env "CROWDSEC_BOUNCER_CAPTCHA_GRACE_PERIOD_SECONDS" | or "1800" }}

          # Path to captcha template (default: /captcha.html)
          captchaHTMLFilePath: {{ env "CROWDSEC_BOUNCER_CAPTCHA_HTML_FILE_PATH" | or "/captcha.html" }}

          # Path to ban HTML file (default: "", disabled if empty)
          banHTMLFilePath: "{{ env "CROWDSEC_BOUNCER_BAN_HTML_FILE_PATH" | or "" }}"

          # List of trusted proxies in front of Traefik (default: [])
          # As can be seen in the middleware declaration, we are actively defining all private class IPv4/IPv6 subnets as trusted IPs.
          # This is necessary, as we want to trust our Traefik reverse proxy's HTTP headers like X-Forwarded-For and X-Real-IP.
          # Those headers typically define the real IP address of our website visitors and threat actors, used by CrowdSec for decision making and banning.
          forwardedHeadersTrustedIPs:
            - "127.0.0.1/32"    # Loopback addresses
            - "10.0.0.0/8"      # RFC1918 private network
            - "100.64.0.0/10"   # Carrier-grade NAT (RFC6598)
            - "127.0.0.0/8"     # Loopback addresses
            - "169.254.0.0/16"  # Link-local addresses (RFC3927)
            - "172.16.0.0/12"   # RFC1918 private network
            - "192.168.0.0/16"  # RFC1918 private network
            - "::1/128"         # IPv6 loopback address
            - "2002::/16"       # 6to4 IPv6 addresses
            - "fc00::/7"        # Unique local IPv6 unicast (RFC4193)
            - "fe80::/10"       # IPv6 link-local addresses

          # List of client IPs to trust (default: [])
          clientTrustedIPs:
            - "127.0.0.1/32"    # Loopback addresses
            - "10.0.0.0/8"      # RFC1918 private network
            - "100.64.0.0/10"   # Carrier-grade NAT (RFC6598)
            - "127.0.0.0/8"     # Loopback addresses
            - "169.254.0.0/16"  # Link-local addresses (RFC3927)
            - "172.16.0.0/12"   # RFC1918 private network
            - "192.168.0.0/16"  # RFC1918 private network
            - "::1/128"         # IPv6 loopback address
            - "2002::/16"       # 6to4 IPv6 addresses
            - "fc00::/7"        # Unique local IPv6 unicast (RFC4193)
            - "fe80::/10"       # IPv6 link-local addresses
EOF
        destination = "local/dynamic/core.yaml"
        perms       = "0644"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "traefik"
        port = "traefik_api"
        tags = [
          "traefik",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.traefik.service=api@internal",
          "traefik.http.routers.traefik.rule=Host(`traefik.${var.domain}`) || Host(`traefik.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.traefik.loadbalancer.server.port=8080",
          "homepage.group=Infrastructure",
          "homepage.name=Traefik",
          "homepage.icon=traefik.png",
          "homepage.href=https://traefik.${var.domain}/dashboard",
          "homepage.widget.type=traefik",
          "homepage.description=Reverse proxy entrypoint for all services with TLS, Cloudflare integration, and auth middleware",
          "kuma.traefik.http.name=traefik.${node.unique.name}.${var.domain}",
          "kuma.traefik.http.url=https://traefik.${var.domain}/dashboard",
          "kuma.traefik.http.interval=20"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "traefik healthcheck --ping > /dev/null 2>&1 || exit 1"]
          interval = "10s"
          timeout  = "3s"
        }
      }
    }
  }

  # Whoami Group
  group "whoami-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "whoami" { to = 80 }
    }

    # Whoami
    task "whoami" {
      driver = "docker"

      config {
        image = "docker.io/traefik/whoami:v1.11"
        ports = ["whoami"]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "whoami"
        }
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "whoami"
        port = "whoami"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.whoami.service=whoami@consulcatalog",
          "traefik.http.services.whoami.loadbalancer.server.port=80",
          "homepage.group=Web Services",
          "homepage.name=whoami",
          "homepage.icon=whoami.png",
          "homepage.href=https://whoami.${var.domain}",
          "homepage.description=Request echo service used to verify reverse-proxy, headers, and auth middleware",
          "kuma.whoami.http.name=whoami.${node.unique.name}.${var.domain}",
          "kuma.whoami.http.url=https://whoami.${var.domain}",
          "kuma.whoami.http.interval=60"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Autokuma Group
  group "autokuma-group" {
    count = 1

    network {
      mode = "bridge"
      
    }

    # Autokuma
    task "autokuma" {
      driver = "docker"

      config {
        image = "ghcr.io/bigboot/autokuma:latest"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "autokuma"
        }
      }

      template {
        data = <<EOF
AUTOKUMA__KUMA__URL={{ env "AUTOKUMA__KUMA__URL" | or "https://uptimekuma.${var.domain}" }}
AUTOKUMA__KUMA__USERNAME={{ env "AUTOKUMA__KUMA__USERNAME" | or "admin" }}
AUTOKUMA__KUMA__PASSWORD={{ with (env "AUTOKUMA__KUMA__PASSWORD") }}{{ . }}{{ else }}${ var.sudo_password }{{ end }}
AUTOKUMA__KUMA__CALL_TIMEOUT={{ env "AUTOKUMA__KUMA__CALL_TIMEOUT" | or "5" }}
AUTOKUMA__KUMA__CONNECT_TIMEOUT={{ env "AUTOKUMA__KUMA__CONNECT_TIMEOUT" | or "5" }}
EOF
        destination = "local/autokuma.env"
        env         = true
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }

  # Docker Gen Failover Group
  group "docker-gen-failover-group" {
    count = 1

    network {
      mode = "bridge"
      
    }

    # Docker Gen for Traefik Failover Configuration
    task "docker-gen-failover" {
      driver = "docker"

      config {
        image = "docker.io/nginxproxy/docker-gen:latest"
        volumes = [
          "${var.config_path}/traefik/dynamic:/traefik/dynamic"
        ]
        args = [
          "-endpoint", "tcp://dockerproxy-rw:2375",
          "-only-exposed",
          "-include-stopped",
          "-event-filter", "event=start",
          "-event-filter", "event=create",
          "-event-filter", "event=expose",
          "-event-filter", "event=update",
          "-event-filter", "event=connect",
          "-event-filter", "label=traefik.enable=true",
          "-container-filter", "label=traefik.enable=true",
          "-watch", "/templates/traefik-failover-dynamic.conf.tmpl", "/traefik/dynamic/failover-fallbacks.yaml"
        ]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
      }

      # Traefik failover template
      template {
        data = <<EOF
# NOTE: This template is a placeholder - the actual template content 
# should be copied from compose/docker-compose.coolify-proxy.yml config section
# for traefik-failover-dynamic.conf.tmpl
# 
# This generates dynamic Traefik configuration for container failover
EOF
        destination = "local/templates/traefik-failover-dynamic.conf.tmpl"
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }

      service {
        name = "docker-gen-failover"
        tags = [
          "docker-gen-failover",
          "${var.domain}"
        ]
      }

      restart {
        attempts = 0
        mode     = "fail"
      }
    }
  }

  # Logrotate Traefik Group
  group "logrotate-traefik-group" {
    count = 1

    # Task uses network_mode = "none", so we don't need a network block

    # Logrotate for Traefik
    task "logrotate-traefik" {
      driver = "docker"

      config {
        image = "docker.io/bolabaden/logrotate-traefik:latest"
        network_mode = "none"
        volumes = [
          "${var.config_path}/traefik/logs:/var/log/traefik"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "logrotate-traefik"
        }
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }

  # Nuq Postgres Group
  group "nuq-postgres-group" {
    count = 1  # Single instance (static port, DB replication handled at DB level if needed)

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "micklethefickle"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "nuq_postgres" { to = 5432 }
    }

    # Nuq PostgreSQL
    task "nuq-postgres" {
      driver = "docker"

      config {
        image = "my-media-stack-nuq-postgres:local"
        force_pull = false
        ports = ["nuq_postgres"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        volumes = [
          "${var.config_path}/nuq-postgres/data:/var/lib/postgresql/data"
        ]
        labels = {
          "com.docker.compose.project" = "firecrawl-group"
          "com.docker.compose.service" = "nuq-postgres"
        }
      }

      env {
        TZ                = var.tz
        POSTGRES_USER     = "postgres"
        POSTGRES_PASSWORD = "postgres"
        POSTGRES_DB       = "postgres"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "nuq-postgres"
        port = "nuq_postgres"
        tags = [
          "nuq-postgres",
          "${var.domain}"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
          interval = "10s"
          timeout  = "5s"
        }
      }
    }
  }

  # Playwright Service Group
  group "playwright-service-group" {
    count = 1  # ENABLED: Builds locally for ARM64 compatibility
    # Note: Constraint for ARM64 compatibility - consider removing if image available for all archs

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "micklethefickle"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "playwright" { to = 3000 }
    }

    # Playwright Service
    task "playwright-service" {
      driver = "docker"

      config {
        image = "my-media-stack-playwright-service:local"
        force_pull = false
        ports = ["playwright"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        labels = {
          "com.docker.compose.project" = "firecrawl-group"
          "com.docker.compose.service" = "playwright-service"
        }
      }

      env {
        TZ             = var.tz
        PORT           = "3000"
        PROXY_SERVER   = ""
        PROXY_USERNAME = ""
        PROXY_PASSWORD = ""
        BLOCK_MEDIA    = "false"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }

  # Firecrawl Group
  group "firecrawl-group" {
    count = 1  # ENABLED: Builds locally for ARM64 compatibility
    # Constraint required: depends on playwright-service and nuq-postgres which are on micklethefickle

    constraint {
      attribute = "${node.unique.name}"
      operator  = "="
      value     = "micklethefickle"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "firecrawl" { to = 3002 }
      port "firecrawl_extract" { to = 3004 }
      port "firecrawl_worker" { to = 3005 }
    }

    # Firecrawl API
    task "firecrawl" {
      driver = "docker"

      config {
        image = "ghcr.io/firecrawl/firecrawl"
        ports = ["firecrawl", "firecrawl_extract", "firecrawl_worker"]
        command = "node"
        args    = ["dist/src/harness.js", "--start-docker"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        ulimit {
          nofile = "65535"
        }
        volumes = [
          "${var.root_path}/secrets:/run/secrets:ro"
        ]
        labels = {
          "com.docker.compose.project" = "firecrawl-group"
          "com.docker.compose.service" = "firecrawl"
        }
      }

      env {
        TZ                        = var.tz
        REDIS_URL                 = "redis://redis:6379"
        REDIS_RATE_LIMIT_URL      = "redis://redis:6379"
        PLAYWRIGHT_MICROSERVICE_URL = "http://playwright-service:3000/scrape"
        NUQ_DATABASE_URL          = "postgres://postgres:postgres@nuq-postgres:5432/postgres"
        EXTRACT_WORKER_PORT       = "3004"
        USE_DB_AUTHENTICATION     = ""
        OPENAI_API_KEY_FILE       = "/run/secrets/openai-api-key.txt"
        OPENAI_BASE_URL           = ""
        MODEL_NAME                = ""
        MODEL_EMBEDDING_NAME      = ""
        OLLAMA_BASE_URL           = ""
        BULL_AUTH_KEY_FILE        = "/run/secrets/firecrawl-api-key.txt"
        TEST_API_KEY_FILE         = "/run/secrets/firecrawl-api-key.txt"
        SEARXNG_ENDPOINT          = "https://searxng.${var.domain}"
        HOST                      = "0.0.0.0"
        PORT                      = "3002"
        WORKER_PORT               = "3005"
        ENV                       = "local"
      }

      resources {
        cpu        = 4000  # 1:1 with docker-compose: cpus: 4.0
        memory     = 4096  # 1:1 with docker-compose: mem_reservation: 4G
        memory_max = 4096  # 1:1 with docker-compose: mem_reservation: 4G
      
      }

      service {

        name = "firecrawl"
        port = "firecrawl"
        tags = [
          "firecrawl",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.firecrawl.rule=Host(`firecrawl-api.${var.domain}`) || Host(`firecrawl-api.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.firecrawl.loadbalancer.server.port=3002"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget --no-verbose --tries=1 --spider http://127.0.0.1:3002/health > /dev/null 2>&1 || curl -fs http://127.0.0.1:3002/health > /dev/null 2>&1 || exit 1"]
          interval = "30s"
          timeout  = "15s"
        }
      }
    }
  }

  # Headscale Server Group
  group "headscale-server-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "headscale_stun" { to = 3478 }
      port "headscale_http" { to = 8081 }
      port "headscale_metrics" { to = 8080 }
      port "headscale_grpc" { to = 50443 }
    }

    # Headscale Server
    task "headscale-server" {
      driver = "docker"

      config {
        image = "docker.io/headscale/headscale:latest"
        ports = ["headscale_stun", "headscale_http", "headscale_metrics", "headscale_grpc"]
        command = "serve"
        args    = ["--config", "/etc/headscale/config.yaml"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        volumes = [
          "${var.root_path}/certs/private/${var.domain}.key:/var/lib/headscale/private.key",
          "${var.config_path}/headscale/config:/etc/headscale",
          "${var.config_path}/headscale/lib:/var/lib/headscale",
          "${var.config_path}/headscale/run:/var/run/headscale"
        ]
        labels = {
          "com.docker.compose.project" = "headscale-group"
          "com.docker.compose.service" = "headscale-server"
        }
      }

      # Headscale configuration template
      template {
        data = <<EOF
---
# headscale will look for a configuration file named `config.yaml` (or `config.json`) in the following order:
#
# - `/etc/headscale`
# - `~/.headscale`
# - current working directory

# The url clients will connect to.
# Typically this will be a domain like:
#
# https://myheadscale.example.com:443
#
#server_url: https://headscale-server.${var.domain}:443
server_url: http://headscale-server:{{ env "HEADSCALE_PORT" | or "8080" }}

# Address to listen to / bind to on the server
#
listen_addr: 0.0.0.0:{{ env "HEADSCALE_HTTP_PORT" | or "8081" }}

# Address to listen to /metrics and /debug, you may want
# to keep this endpoint private to your internal network
metrics_listen_addr: 127.0.0.1:{{ env "HEADSCALE_PORT" | or "8080" }}

# Address to listen for gRPC.
# gRPC is used for controlling a headscale server
# remotely with the CLI
# Note: Remote access _only_ works if you have
# valid certificates.

grpc_listen_addr: 0.0.0.0:{{ env "HEADSCALE_GRPC_PORT" | or "9090" }}

# Allow the gRPC admin interface to run in INSECURE
# mode. This is not recommended as the traffic will
# be unencrypted. Only enable if you know what you
# are doing.
grpc_allow_insecure: false

# Private key used encrypt the traffic between headscale
# and Tailscale clients.
# The private key file which will be
# autogenerated if it's missing
private_key_path: /var/lib/headscale/private.key

# The Noise section includes specific configuration for the
# TS2021 Noise protocol
noise:
  # The Noise private key is used to encrypt the traffic between headscale and
  # Tailscale clients when using the new Noise-based protocol. A missing key
  # will be automatically generated.
  private_key_path: /var/lib/headscale/noise_private.key

# List of IP prefixes to allocate tailaddresses from.
# Each prefix consists of either an IPv4 or IPv6 address,
# and the associated prefix length, delimited by a slash.
# It must be within IP ranges supported by the Tailscale
# client - i.e., subnets of 100.64.0.0/10 and fd7a:115c:a1e0::/48.
# See below:
# IPv6: https://github.com/tailscale/tailscale/blob/22ebb25e833264f58d7c3f534a8b166894a89536/net/tsaddr/tsaddr.go#LL81C52-L81C71
# IPv4: https://github.com/tailscale/tailscale/blob/22ebb25e833264f58d7c3f534a8b166894a89536/net/tsaddr/tsaddr.go#L33
# Any other range is NOT supported, and it will cause unexpected issues.
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48

  # Strategy used for allocation of IPs to nodes, available options:
  # - sequential (default): assigns the next free IP from the previous given IP.
  # - random: assigns the next free IP from a pseudo-random IP generator (crypto/rand).
  allocation: random

# DERP is a relay system that Tailscale uses when a direct
# connection cannot be established.
# https://tailscale.com/blog/how-tailscale-works/#encrypted-tcp-relays-derp
#
# headscale needs a list of DERP servers that can be presented
# to the clients.
derp:
  server:
    # If enabled, runs the embedded DERP server and merges it into the rest of the DERP config
    # The Headscale server_url defined above MUST be using https, DERP requires TLS to be in place
    enabled: false

    # Region ID to use for the embedded DERP server.
    # The local DERP prevails if the region ID collides with other region ID coming from
    # the regular DERP config.
    region_id: 999

    # Region code and name are displayed in the Tailscale UI to identify a DERP region
    region_code: "headscale"
    region_name: "Headscale Embedded DERP"

    # Listens over UDP at the configured address for STUN connections - to help with NAT traversal.
    # When the embedded DERP server is enabled stun_listen_addr MUST be defined.
    #
    # For more details on how this works, check this great article: https://tailscale.com/blog/how-tailscale-works/
    stun_listen_addr: "0.0.0.0:{{ env "HEADSCALE_STUN_PORT" | or "3478" }}"

    # Private key used to encrypt the traffic between headscale DERP and
    # Tailscale clients. A missing key will be automatically generated.
    private_key_path: /var/lib/headscale/derp_server_private.key

    # This flag can be used, so the DERP map entry for the embedded DERP server is not written automatically,
    # it enables the creation of your very own DERP map entry using a locally available file with the parameter DERP.paths
    # If you enable the DERP server and set this to false, it is required to add the DERP server to the DERP map using DERP.paths
    automatically_add_embedded_derp_region: true

    # For better connection stability (especially when using an Exit-Node and DNS is not working),
    # it is possible to optionally add the public IPv4 and IPv6 address to the Derp-Map using:
    ipv4: 100.64.0.2
    ipv6: fd7a:115c:a1e0::2

  # List of externally available DERP maps encoded in JSON
  urls:
    - https://controlplane.tailscale.com/derpmap/default

  # Locally available DERP map files encoded in YAML
  #
  # This option is mostly interesting for people hosting
  # their own DERP servers:
  # https://tailscale.com/kb/1118/custom-derp-servers/
  #
  # paths:
  #   - /etc/headscale/derp-example.yaml
  paths: []

  # If enabled, a worker will be set up to periodically
  # refresh the given sources and update the derpmap
  # will be set up.
  auto_update_enabled: true

  # How often should we check for DERP updates?
  update_frequency: 24h

# Disables the automatic check for headscale updates on startup
disable_check_updates: false

# Time before an inactive ephemeral node is deleted?
ephemeral_node_inactivity_timeout: 30m

database:
  # Database type. Available options: sqlite, postgres
  # Please note that using Postgres is highly discouraged as it is only supported for legacy reasons.
  # All new development, testing and optimisations are done with SQLite in mind.
  type: sqlite

  # Enable debug mode. This setting requires the log.level to be set to "debug" or "trace".
  debug: {{ env "HEADSCALE_DEBUG" | or "false" }}

  # GORM configuration settings.
  gorm:
    # Enable prepared statements.
    prepare_stmt: {{ env "HEADSCALE_PREPARE_STMT" | or "true" }}

    # Enable parameterized queries.
    parameterized_queries: {{ env "HEADSCALE_PARAMETERIZED_QUERIES" | or "true" }}

    # Skip logging "record not found" errors.
    skip_err_record_not_found: {{ env "HEADSCALE_SKIP_ERR_RECORD_NOT_FOUND" | or "true" }}

    # Threshold for slow queries in milliseconds.
    slow_threshold: {{ env "HEADSCALE_SLOW_THRESHOLD" | or "1000" }}

  # SQLite config
  sqlite:
    path: /var/lib/headscale/db.sqlite

    # Enable WAL mode for SQLite. This is recommended for production environments.
    # https://www.sqlite.org/wal.html
    write_ahead_log: {{ env "HEADSCALE_WRITE_AHEAD_LOG" | or "true" }}

    # Maximum number of WAL file frames before the WAL file is automatically checkpointed.
    # https://www.sqlite.org/c3ref/wal_autocheckpoint.html
    # Set to 0 to disable automatic checkpointing.
    wal_autocheckpoint: {{ env "HEADSCALE_WAL_AUTOCHECKPOINT" | or "1000" }}

log:
  # Output formatting for logs: text or json
  format: {{ env "HEADSCALE_LOG_FORMAT" | or "text" }}
  level: {{ env "HEADSCALE_LOG_LEVEL" | or "info" }}

## Policy
# headscale supports Tailscale's ACL policies.
# Please have a look to their KB to better
# understand the concepts: https://tailscale.com/kb/1018/acls/
policy:
  # The mode can be "file" or "database" that defines
  # where the ACL policies are stored and read from.
  mode: {{ env "HEADSCALE_POLICY_MODE" | or "file" }}
  # If the mode is set to "file", the path to a
  # HuJSON file containing ACL policies.
  path: {{ env "HEADSCALE_POLICY_PATH" | or "" }}

## DNS
#
# headscale supports Tailscale's DNS configuration and MagicDNS.
# Please have a look to their KB to better understand the concepts:
#
# - https://tailscale.com/kb/1054/dns/
# - https://tailscale.com/kb/1081/magicdns/
# - https://tailscale.com/blog/2021-09-private-dns-with-magicdns/
#
# Please note that for the DNS configuration to have any effect,
# clients must have the `--accept-dns=true` option enabled. This is the
# default for the Tailscale client. This option is enabled by default
# in the Tailscale client.
#
# Setting _any_ of the configuration and `--accept-dns=true` on the
# clients will integrate with the DNS manager on the client or
# overwrite /etc/resolv.conf.
# https://tailscale.com/kb/1235/resolv-conf
#
# If you want stop Headscale from managing the DNS configuration
# all the fields under `dns` should be set to empty values.
dns:
  # Whether to use [MagicDNS](https://tailscale.com/kb/1081/magicdns/).
  magic_dns: {{ env "HEADSCALE_MAGIC_DNS" | or "true" }}

  # Defines the base domain to create the hostnames for MagicDNS.
  # This domain _must_ be different from the server_url domain.
  # `base_domain` must be a FQDN, without the trailing dot.
  # The FQDN of the hosts will be
  # `hostname.base_domain` (e.g., _myhost.example.com_).
  base_domain: myscale.${var.domain}

  # Whether to use the local DNS settings of a node (default) or override the
  # local DNS settings and force the use of Headscale's DNS configuration.
  override_local_dns: {{ env "HEADSCALE_OVERRIDE_LOCAL_DNS" | or "false" }}

  # List of DNS servers to expose to clients.
  nameservers:
    global:
      - 1.1.1.1
      - 1.0.0.1
      - 2606:4700:4700::1111
      - 2606:4700:4700::1001

      # NextDNS (see https://tailscale.com/kb/1218/nextdns/).
      # "abc123" is example NextDNS ID, replace with yours.
      # - https://dns.nextdns.io/abc123

    # Split DNS (see https://tailscale.com/kb/1054/dns/),
    # a map of domains and which DNS server to use for each.
    split:
      {
#        "headscale.${var.domain}": [
#          "1.1.1.1",
#          "1.0.0.1",
#          "2606:4700:4700::1111",
#          "2606:4700:4700::1001"
#        ]
      }
      # foo.bar.com:
      #   - 1.1.1.1
      # darp.headscale.net:
      #   - 1.1.1.1
      #   - 8.8.8.8

  # Set custom DNS search domains. With MagicDNS enabled,
  # your tailnet base_domain is always the first search domain.
  search_domains: []

  # Extra DNS records
  # so far only A and AAAA records are supported (on the tailscale side)
  # See: docs/ref/dns.md
  extra_records: []
  #   - name: "grafana.myvpn.example.com"
  #     type: "A"
  #     value: "100.64.0.3"
  #
  #   # you can also put it in one line
  #   - { name: "prometheus.myvpn.example.com", type: "A", value: "100.64.0.3" }
  #
  # Alternatively, extra DNS records can be loaded from a JSON file.
  # Headscale processes this file on each change.
  # extra_records_path: /var/lib/headscale/extra-records.json

# Unix socket used for the CLI to connect without authentication
# Note: for production you will want to set this to something like:
unix_socket: /var/run/headscale/headscale.sock
unix_socket_permission: "0770"

# Logtail configuration
# Logtail is Tailscales logging and auditing infrastructure, it allows the control panel
# to instruct tailscale nodes to log their activity to a remote server.
logtail:
  # Enable logtail for this headscales clients.
  # As there is currently no support for overriding the log server in headscale, this is
  # disabled by default. Enabling this will make your clients send logs to Tailscale Inc.
  enabled: {{ env "HEADSCALE_LOGTAIL_ENABLED" | or "false" }}

# Enabling this option makes devices prefer a random port for WireGuard traffic over the
# default static port 41641. This option is intended as a workaround for some buggy
# firewall devices. See https://tailscale.com/kb/1181/firewalls/ for more information.
randomize_client_port: {{ env "HEADSCALE_RANDOMIZE_CLIENT_PORT" | or "false" }}
EOF
        destination = "local/config.yaml"
        perms       = "0644"
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {
        name = "headscale-server"
        port = "headscale_http"
        tags = [
          "traefik.enable=true",
          "traefik.http.middlewares.headscale-admin-redirect.redirectRegex.regex=^https?://headscale(-server)?\\.(${var.domain}|${node.unique.name}\\.${var.domain})/admin(.*)$$",
          "traefik.http.middlewares.headscale-admin-redirect.redirectRegex.replacement=https://headscale.${var.domain}/web$$3",
          "traefik.http.middlewares.headscale-admin-redirect.redirectRegex.permanent=false",
          "traefik.http.middlewares.headscale-server-redirect.redirectRegex.regex=^https?://headscale-server\\.((?:${var.domain}|${node.unique.name}\\.${var.domain}))(.*)$$",
          "traefik.http.middlewares.headscale-server-redirect.redirectRegex.replacement=https://headscale.$$1$$2",
          "traefik.http.middlewares.headscale-server-redirect.redirectRegex.permanent=false",
          "traefik.http.routers.headscale-server.service=headscale-server@consulcatalog",
          "traefik.http.routers.headscale-server.rule=Host(`headscale-server.${var.domain}`) || Host(`headscale-server.${node.unique.name}.${var.domain}`) || Host(`headscale.${var.domain}`) || Host(`headscale.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.headscale-server.middlewares=headscale-admin-redirect@consulcatalog,headscale-server-redirect@consulcatalog",
          "traefik.http.services.headscale-server.loadbalancer.server.port=8081",
          "traefik.http.routers.headscale-metrics.service=headscale-metrics@consulcatalog",
          "traefik.http.routers.headscale-metrics.rule=(Host(`headscale.${var.domain}`) || Host(`headscale.${node.unique.name}.${var.domain}`)) && PathPrefix(`/metrics`)",
          "traefik.http.services.headscale-metrics.loadbalancer.server.port=8080"
        ]
      }
    }
  }

  # Headscale Group (UI) - 1:1 naming with Docker
  group "headscale-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "headscale" { to = 8080 }
      
      # DNS configuration from Docker
      dns {
        servers = [
          "1.1.1.1",
          "1.0.0.1",
          "2606:4700:4700::1111",
          "2606:4700:4700::1001",
          "9.9.9.9",
          "2620:fe::fe",
          "8.8.8.8",
          "2001:4860:4860::8888",
          "2001:4860:4860::8844"
        ]
      }
    }

    # Headscale UI (named "headscale" to match Docker naming)
    task "headscale" {
      driver = "docker"

      config {
        image = "ghcr.io/gurucomputing/headscale-ui:latest"
        ports = ["headscale"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        volumes = [
          "${var.config_path}/headscale/config:/etc/headscale"
        ]
        labels = {
          "com.docker.compose.project" = "headscale-group"
          "com.docker.compose.service" = "headscale"
        }
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {
        name = "headscale"
        port = "headscale"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.headscale.service=headscale",
          "traefik.http.routers.headscale.rule=(Host(`headscale.${var.domain}`) || Host(`headscale.${node.unique.name}.${var.domain}`)) && (PathPrefix(`/web`) || PathPrefix(`/web/users.html`) || PathPrefix(`/web/groups.html`) || PathPrefix(`/web/devices.html`) || PathPrefix(`/web/settings.html`))",
          "traefik.http.services.headscale.loadbalancer.server.port=8080",
          "homepage.group=Networking",
          "homepage.name=Headscale UI",
          "homepage.icon=headscale.png",
          "homepage.href=https://headscale.${var.domain}/",
          "homepage.description=Headscale UI is a web interface for Headscale, an open source implementation of Tailscale's Admin control panel."
        ]

        check {
          type     = "http"
          path     = "/web"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Litellm Postgres Group
  group "litellm-postgres-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "litellm_postgres" { to = 5432 }
    }

    # LiteLLM PostgreSQL
    task "litellm-postgres" {
      driver = "docker"

      config {
        image = "docker.io/postgres:16.3-alpine3.20"
        ports = ["litellm_postgres"]
        volumes = [
          "${var.config_path}/litellm/pgdata:/var/lib/postgresql/data"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "litellm-postgres"
        }
      }

      env {
        TZ                = var.tz
        POSTGRES_DB       = "litellm"
        POSTGRES_PASSWORD = "litellm"
        POSTGRES_USER     = "litellm"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "litellm-postgres"
        port = "litellm_postgres"
        tags = [
          "litellm-postgres",
          "${var.domain}"
        ]

        check {
          type     = "script"
          command  = "/usr/local/bin/pg_isready"
          args     = ["-h", "localhost", "-U", "litellm", "-d", "litellm"]
          interval = "5s"
          timeout  = "5s"
        }
      }
    }
  }

  # Litellm Group
  group "litellm-group" {
    count = 2  # HA: Run on multiple nodes for failover

    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "litellm" { to = 4000 }
    }

    # LiteLLM
    task "litellm" {
      driver = "docker"

      config {
        image = "ghcr.io/berriai/litellm-database:main-stable"
        ports = ["litellm"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        volumes = [
          "${var.config_path}/litellm:/app/config:ro",
          "${var.root_path}/secrets:/run/secrets-src:ro"
        ]
        entrypoint = ["/bin/sh", "-c"]
        args = [
          "mkdir -p /run/secrets && for f in /run/secrets-src/*.txt; do ln -sf \"$$f\" \"/run/secrets/$$(basename \"$$f\" .txt)\" 2>/dev/null || true; done && exec litellm --config /app/config/litellm_config.yaml --port 4000 --host 0.0.0.0"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "litellm"
          "traefik.enable" = "true"
          "homepage.group" = "AI"
          "homepage.name" = "Litellm"
          "homepage.icon" = "litellm.png"
          "homepage.href" = "https://litellm.${var.domain}/"
          "homepage.description" = "LLM gateway/router with provider failover, caching, rate limits, and analytics"
          "kuma.litellm.http.name" = "litellm.${node.unique.name}.${var.domain}"
          "kuma.litellm.http.url" = "https://litellm.${var.domain}"
          "kuma.litellm.http.interval" = "60"
        }
      }

      template {
        data = <<EOF
{{ range service "litellm-postgres" -}}
DATABASE_URL=postgresql://litellm:litellm@{{ .Address }}:{{ .Port }}/litellm
{{ end -}}
REDIS_HOST=redis
REDIS_PORT=6379
LITELLM_LOG={{ env "LITELLM_LOG" | or "INFO" }}
LITELLM_MASTER_KEY_FILE=/run/secrets/litellm-master-key
LITELLM_MODE={{ env "LITELLM_MODE" | or "PRODUCTION" }}
UI_USERNAME={{ env "LITELLM_UI_USERNAME" | or "admin" }}
UI_PASSWORD_FILE=/run/secrets/litellm-master-key
POSTGRES_USER=litellm
POSTGRES_PASSWORD=litellm
POSTGRES_DB=litellm
ANTHROPIC_API_KEY_FILE=/run/secrets/anthropic-api-key
OPENAI_API_KEY_FILE=/run/secrets/openai-api-key
OPENROUTER_API_KEY_FILE=/run/secrets/openrouter-api-key
GROQ_API_KEY_FILE=/run/secrets/groq-api-key
DEEPSEEK_API_KEY_FILE=/run/secrets/deepseek-api-key
GEMINI_API_KEY_FILE=/run/secrets/gemini-api-key
MISTRAL_API_KEY_FILE=/run/secrets/mistral-api-key
PERPLEXITY_API_KEY_FILE=/run/secrets/perplexity-api-key
REPLICATE_API_KEY_FILE=/run/secrets/replicate-api-key
SAMBANOVA_API_KEY_FILE=/run/secrets/sambanova-api-key
TOGETHERAI_API_KEY_FILE=/run/secrets/togetherai-api-key
HF_TOKEN_FILE=/run/secrets/hf-token
LANGCHAIN_API_KEY_FILE=/run/secrets/langchain-api-key
SERPAPI_API_KEY_FILE=/run/secrets/serpapi-api-key
SEARCH1API_KEY_FILE=/run/secrets/search1api-key
UPSTAGE_API_KEY_FILE=/run/secrets/upstage-api-key
JINA_API_KEY_FILE=/run/secrets/jina-api-key
KAGI_API_KEY_FILE=/run/secrets/kagi-api-key
GLAMA_API_KEY_FILE=/run/secrets/glama-api-key
EOF
        destination = "secrets/litellm.env"
        env         = true
      }

      resources {
        cpu        = 1000
        memory     = 2048
        memory_max = 4096
      
      }

      service {

        name = "litellm"
        port = "litellm"
        tags = [
          "litellm",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.litellm.rule=Host(`litellm.${var.domain}`) || Host(`litellm.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.litellm.loadbalancer.server.port=4000"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget -qO- http://127.0.0.1:4000/health/liveliness > /dev/null 2>&1 || exit 1"]
          interval = "30s"
          timeout  = "15s"
        }
      }
    }
  }

  # Mcpo Group
  group "mcpo-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "mcpo" { to = 8000 }
    }

    # MCPO
    task "mcpo" {
      driver = "docker"

      config {
        image = "ghcr.io/open-webui/mcpo:main"
        ports = ["mcpo"]
        args = [
          "--api-key", "${var.mcpo_api_key}",
          "--host", "0.0.0.0",
          "--port", "8000",
          "--cors-allow-origins", "*",
          "--config", "/local/mcp_servers.json"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "mcpo"
        }
      }

      # MCP servers configuration
      template {
        data = <<EOF
{
  "mcpServers": {
    "firecrawl": {
      "command": "npx",
      "args": ["-y", "firecrawl-mcp"],
      "env": {
        "FIRECRAWL_API_KEY": "${var.firecrawl_api_key}",
        "FIRECRAWL_API_URL": "https://firecrawl-api.${var.domain}"
      }
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "{{ env "GITHUB_TOKEN" | or "" }}"
      }
    }
  }
}
EOF
        destination = "local/mcp_servers.json"
      }

      env {
        TZ           = var.tz
        MCPO_API_KEY = var.mcpo_api_key
      }

      resources {
        cpu        = 500
        memory     = 512
        memory_max = 0
      
      }

      service {

        name = "mcpo"
        port = "mcpo"
        tags = [
          "mcpo",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.mcpo.middlewares=nginx-auth@file",
          "traefik.http.routers.mcpo.rule=Host(`mcpo.${var.domain}`) || Host(`mcpo.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.mcpo.loadbalancer.server.port=8000"
        ]

        check {
          type     = "http"
          path     = "/openapi.json"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Open Webui Group
  group "open-webui-group" {
    count = 0

    network {
      mode = "bridge"
      
      port "open_webui" { to = 8080 }
    }

    # Open WebUI
    task "open-webui" {
      driver = "docker"

      config {
        image = "ghcr.io/open-webui/open-webui:main"
        ports = ["open_webui"]
        command = "bash"
        args    = ["start.sh"]
        work_dir = "/app/backend"
        volumes = [
          "${var.config_path}/open-webui/uploads:/app/backend/data/uploads",
          "${var.config_path}/open-webui/vector_db:/app/backend/data/vector_db:rw",
          "${var.config_path}/open-webui/webui.db:/app/backend/data/webui.db:rw"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "open-webui"
        }
      }

      env {
        TZ                                      = var.tz
        ENABLE_ADMIN_EXPORT                     = "True"
        ENABLE_ADMIN_CHAT_ACCESS                = "True"
        BYPASS_MODEL_ACCESS_CONTROL             = "True"
        ENV                                     = "prod"
        ENABLE_PERSISTENT_CONFIG                = "True"
        PORT                                    = "8080"
        ENABLE_REALTIME_CHAT_SAVE               = "True"
        WEBUI_BUILD_HASH                        = "dev-build"
        AIOHTTP_CLIENT_TIMEOUT                  = "300"
        AIOHTTP_CLIENT_TIMEOUT_MODEL_LIST       = "10"
        AIOHTTP_CLIENT_TIMEOUT_OPENAI_MODEL_LIST = "10"
        DATA_DIR                                = "./data"
        FRONTEND_BUILD_DIR                      = "../build"
        STATIC_DIR                              = "./static"
        OLLAMA_BASE_URL                         = "/ollama"
        USE_OLLAMA_DOCKER                       = "false"
        K8S_FLAG                                = "False"
        ENABLE_FORWARD_USER_INFO_HEADERS        = "False"
        WEBUI_SESSION_COOKIE_SAME_SITE          = "lax"
        WEBUI_SESSION_COOKIE_SECURE             = "False"
        WEBUI_AUTH_COOKIE_SAME_SITE             = "lax"
        WEBUI_AUTH_COOKIE_SECURE                = "False"
        WEBUI_AUTH                              = "True"
        WEBUI_SECRET_KEY                        = var.open_webui_secret_key
        ENABLE_VERSION_UPDATE_CHECK             = "True"
        OFFLINE_MODE                            = "False"
        RESET_CONFIG_ON_START                   = "False"
        SAFE_MODE                               = "False"
        CORS_ALLOW_ORIGIN                       = "*"
        RAG_EMBEDDING_MODEL_TRUST_REMOTE_CODE   = "True"
        RAG_RERANKING_MODEL_TRUST_REMOTE_CODE   = "True"
        RAG_EMBEDDING_MODEL_AUTO_UPDATE         = "True"
        RAG_RERANKING_MODEL_AUTO_UPDATE         = "True"
        VECTOR_DB                               = "chroma"
        TIKTOKEN_CACHE_DIR                      = "/app/backend/data/cache/tiktoken"
        RAG_EMBEDDING_OPENAI_BATCH_SIZE         = "1"
        DOCKER                                  = "true"
        HOME                                    = "/root"
        HF_HOME                                 = "/app/backend/data/cache/embedding/models"
        SENTENCE_TRANSFORMERS_HOME              = "/app/backend/data/cache/embedding/models"
        USE_CUDA_DOCKER_VER                     = "cu128"
        USE_EMBEDDING_MODEL_DOCKER              = "sentence-transformers/all-MiniLM-L6-v2"
        ANONYMIZED_TELEMETRY                    = "false"
        DO_NOT_TRACK                            = "true"
        SCARF_NO_ANALYTICS                      = "true"
      }

      resources {
        cpu        = 400
        memory     = 1024
        memory_max = 1536
      
      }

      service {

        name = "open-webui"
        port = "open_webui"
        tags = [
          "open-webui",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.open-webui.rule=Host(`open-webui.${var.domain}`) || Host(`open-webui.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.open-webui.loadbalancer.server.port=8080"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "5s"
          timeout  = "30s"
        }
      }
    }
  }

  # Gptr Group
  group "gptr-group" {
    count = 0

    network {
      mode = "bridge"
      
      port "gptr_nginx" { to = 3000 }
      port "gptr_nextjs" { to = 3001 }
      port "gptr_static" { to = 8000 }
      port "gptr_mcp" { to = 8080 }
    }

    # GPTR (AI Research Wizard)
    task "gptr" {
      driver = "docker"

      config {
        image = "docker.io/bolabaden/ai-researchwizard-aio-fullstack:master"
        ports = ["gptr_nginx", "gptr_nextjs", "gptr_static", "gptr_mcp"]
        tty = true
        interactive = true
        volumes = [
          "${var.config_path}/gptr/logs:/usr/src/app/logs",
          "${var.config_path}/gptr/outputs:/usr/src/app/outputs",
          "${var.config_path}/gptr/reports:/usr/src/app/reports"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "gptr"
        }
      }

      template {
        data = <<EOF
ANTHROPIC_API_KEY=${var.anthropic_api_key}
BRAVE_API_KEY={{ env "BRAVE_API_KEY" | or "" }}
DEEPSEEK_API_KEY={{ env "DEEPSEEK_API_KEY" | or "" }}
EXA_API_KEY={{ env "EXA_API_KEY" | or "" }}
FIRECRAWL_API_KEY=${var.firecrawl_api_key}
FIRE_CRAWL_API_KEY=${var.firecrawl_api_key}
GEMINI_API_KEY={{ env "GEMINI_API_KEY" | or "" }}
GLAMA_API_KEY={{ env "GLAMA_API_KEY" | or "" }}
GROQ_API_KEY={{ env "GROQ_API_KEY" | or "" }}
HF_TOKEN={{ env "HF_TOKEN" | or "" }}
HUGGINGFACE_ACCESS_TOKEN={{ env "HUGGINGFACE_ACCESS_TOKEN" | or "" }}
HUGGINGFACE_API_TOKEN={{ env "HF_TOKEN" | or "" }}
LANGCHAIN_API_KEY={{ env "LANGCHAIN_API_KEY" | or "" }}
LANGSMITH_API_KEY={{ env "LANGCHAIN_API_KEY" | or "" }}
MISTRAL_API_KEY={{ env "MISTRAL_API_KEY" | or "" }}
MISTRALAI_API_KEY={{ env "MISTRAL_API_KEY" | or "" }}
OPENAI_API_KEY=${var.openai_api_key}
OPENROUTER_API_KEY={{ env "OPENROUTER_API_KEY" | or "" }}
PERPLEXITY_API_KEY={{ env "PERPLEXITY_API_KEY" | or "" }}
PERPLEXITYAI_API_KEY={{ env "PERPLEXITY_API_KEY" | or "" }}
REPLICATE_API_KEY={{ env "REPLICATE_API_KEY" | or "" }}
REVID_API_KEY={{ env "REVID_API_KEY" | or "" }}
SAMBANOVA_API_KEY={{ env "SAMBANOVA_API_KEY" | or "" }}
SEARCH1API_KEY={{ env "SEARCH1API_KEY" | or "" }}
SERPAPI_API_KEY={{ env "SERPAPI_API_KEY" | or "" }}
TAVILY_API_KEY={{ env "TAVILY_API_KEY" | or "" }}
TOGETHERAI_API_KEY={{ env "TOGETHERAI_API_KEY" | or "" }}
UNIFY_API_KEY={{ env "UNIFY_API_KEY" | or "" }}
UPSTAGE_API_KEY={{ env "UPSTAGE_API_KEY" | or "" }}
UPSTAGEAI_API_KEY={{ env "UPSTAGE_API_KEY" | or "" }}
YOU_API_KEY={{ env "YOU_API_KEY" | or "" }}
CHOKIDAR_USEPOLLING=true
LOGGING_LEVEL=DEBUG
NEXT_PUBLIC_GPTR_API_URL=https://gptr.${var.domain}
LANGSMITH_TRACING=true
LANGSMITH_ENDPOINT=https://api.smith.langchain.com
EOF
        destination = "secrets/gptr.env"
        env         = true
      }

      resources {
        cpu        = 400
        memory     = 1024
        memory_max = 1536
      
      }

      service {

        name = "gptr"
        port = "gptr_static"
        tags = [
          "gptr",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.gptr-legacy.service=gptr-legacy@consulcatalog",
          "traefik.http.routers.gptr-legacy.rule=Host(`gptr.${var.domain}`) || Host(`gptr.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.gptr-legacy.loadbalancer.server.port=8000"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "(wget -qO- http://127.0.0.1:3000 && wget -qO- http://127.0.0.1:8000) || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Qdrant Group
  group "qdrant-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "qdrant" { to = 6333 }
    }

    # 🔹🔹 Qdrant 🔹🔹
    task "qdrant" {
      driver = "docker"

      config {
        image = "docker.io/qdrant/qdrant"
        ports = ["qdrant"]
        volumes = [
          "${var.config_path}/qdrant/storage:/qdrant/storage"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "qdrant"
        }
      }

      env {
        QDRANT_STORAGE_PATH      = "/qdrant/storage"
        QDRANT_STORAGE_TYPE      = "disk"
        QDRANT_STORAGE_DISK_PATH = "/qdrant/storage"
        QDRANT_STORAGE_DISK_TYPE = "disk"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      }

      service {
        name = "qdrant"
        port = "qdrant"
        tags = [
          "traefik.enable=true",
          "traefik.http.services.qdrant.loadbalancer.server.port=6333",
          "homepage.group=AI",
          "homepage.name=Qdrant",
          "homepage.icon=qdrant.png",
          "homepage.href=https://qdrant.${var.domain}",
          "homepage.description=Qdrant is a vector database for storing and querying vectors."
        ]
      }
    }
  }

  # Mcp Proxy Group
  group "mcp-proxy-group" {
    count = 0

    network {
      mode = "bridge"
      
      port "mcp_proxy" { to = 9090 }
    }

    # MCP Proxy
    task "mcp-proxy" {
      driver = "docker"

      config {
        image = "ghcr.io/tbxark/mcp-proxy"
        ports = ["mcp_proxy"]
        args = [
          "--config", "/local/config.json",
          "-expand-env"
        ]
        labels = {
          "com.docker.compose.project" = "llm-group"
          "com.docker.compose.service" = "mcp-proxy"
        }
      }

      template {
        data = <<EOF
{
  "mcpProxy": {
    "baseURL": "https://mcp.${var.domain}",
    "addr": ":9090",
    "name": "MCP Proxy",
    "version": "1.0.0",
    "type": "streamable-http",
    "options": {
      "panicIfInvalid": false,
      "logEnabled": true,
      "authTokens": []
    }
  },
  "mcpServers": {}
}
EOF
        destination = "local/config.json"
      }

      resources {
        cpu        = 250
        memory     = 512
        memory_max = 0
      }

      service {
        name = "mcp-proxy"
        port = "mcp_proxy"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.mcp-proxy.rule=Host(`mcp.${var.domain}`) || Host(`mcp.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.mcp-proxy.loadbalancer.server.port=9090",
          "homepage.group=MCP",
          "homepage.name=MCP Proxy",
          "homepage.icon=mcp-proxy.png",
          "homepage.href=https://mcp.${var.domain}",
          "homepage.description=MCP Proxy is a tool for proxying MCP servers."
        ]
      }
    }
  }

  # Stremio Group
  group "stremio-group" {
    count = 2  # HA: Run on multiple nodes for failover

    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "stremio_webui" { to = 8080 }
      port "stremio_http" {
        static = 11470
        to = 11470
      }
      port "stremio_https" {
        static = 12470
        to = 12470
      }
    }

    # Stream Movies/TV over debrid instantly.
    task "stremio" {
      driver = "docker"

      config {
        image = "ghcr.io/tsaridas/stremio-docker:main"
        ports = ["stremio_webui", "stremio_http", "stremio_https"]
        volumes = [
          "${var.config_path}/stremio/root/.stremio-server:/root/.stremio-server"
        ]
        labels = {
          "com.docker.compose.project" = "stremio-group"
          "com.docker.compose.service" = "stremio"
        }
      }

      env {
        IPADDRESS        = "127.0.0.1"
        AUTO_SERVER_URL  = "1"
        SERVER_URL       = "https://stremio.${var.domain}/"
        WEBUI_LOCATION   = "https://stremio.${var.domain}/shell/"
        NO_CORS          = "0"
        CASTING_DISABLED = "1"
      }

      resources {
        cpu        = 2000
        memory     = 2048
        memory_max = 0
      
      }

      service {

        name = "stremio"
        port = "stremio_webui"
        tags = [
          "stremio",
          "${var.domain}",
          "traefik.enable=true",
          # Redirect stremio-web.$DOMAIN to stremio.$DOMAIN
          "traefik.http.middlewares.stremio-web-redirect.redirectRegex.regex=^(http|https)://stremio(-web)\\.(${var.domain}|${node.unique.name}\\.${var.domain})(.*)$$",
          "traefik.http.middlewares.stremio-web-redirect.redirectRegex.replacement=$$1://stremio.$$3$$4",
          "traefik.http.middlewares.stremio-web-redirect.redirectRegex.permanent=false",
          # Redirect stremio.$DOMAIN/shell-v4.4 to /shell
          "traefik.http.middlewares.stremio-shell-redirect.redirectRegex.regex=^(http|https)://stremio\\.(${var.domain}|${node.unique.name}\\.${var.domain})(.*)$$",
          "traefik.http.middlewares.stremio-shell-redirect.redirectRegex.replacement=$$1://stremio.$$2$$3",
          "traefik.http.middlewares.stremio-shell-redirect.redirectRegex.permanent=false",
          # Redirect to add/replace streamingServer parameter for shell URLs
          "traefik.http.middlewares.stremio-streaming-server-redirect.redirectRegex.regex=^(http|https)://stremio\\.(${var.domain}|${node.unique.name}\\.${var.domain})(/shell[^#?]*)(\\\\?[^#]*?streamingServer=[^&#]*)?([^#]*)(#.*)?$$",
          "traefik.http.middlewares.stremio-streaming-server-redirect.redirectRegex.replacement=$$1://stremio.$$2$$3?streamingServer=https%3A%2F%2Fstremio.$$2$$5$$6",
          "traefik.http.middlewares.stremio-streaming-server-redirect.redirectRegex.permanent=false",
          # Stremio Web UI
          "traefik.http.routers.stremio.service=stremio",
          "traefik.http.routers.stremio.rule=Host(`stremio-web.${var.domain}`) || Host(`stremio-web.${node.unique.name}.${var.domain}`) || Host(`stremio.${var.domain}`) || Host(`stremio.${node.unique.name}.${var.domain}`)",
          "traefik.http.routers.stremio.middlewares=stremio-web-redirect@docker,stremio-shell-redirect@docker,stremio-streaming-server-redirect@docker",
          "traefik.http.services.stremio.loadbalancer.server.scheme=https",
          "traefik.http.services.stremio.loadbalancer.server.port=8080",
          # Stremio HTTP Streaming Server (port 11470)
          "traefik.http.routers.stremio-http11470.service=stremio-http11470",
          "traefik.http.services.stremio-http11470.loadbalancer.server.scheme=http",
          "traefik.http.services.stremio-http11470.loadbalancer.server.port=11470",
          # Stremio API/streaming routes to 11470
          "traefik.http.routers.stremio-http11470.rule=(Host(`stremio.${var.domain}`) || Host(`stremio.${node.unique.name}.${var.domain}`)) && ( PathPrefix(`/hlsv2`) || PathPrefix(`/casting`) || PathPrefix(`/local-addon`) || PathPrefix(`/proxy`) || PathPrefix(`/rar`) || PathPrefix(`/zip`) || PathPrefix(`/settings`) || PathPrefix(`/create`) || PathPrefix(`/removeAll`) || PathPrefix(`/samples`) || PathPrefix(`/probe`) || PathPrefix(`/subtitlesTracks`) || PathPrefix(`/opensubHash`) || PathPrefix(`/subtitles`) || PathPrefix(`/network-info`) || PathPrefix(`/device-info`) || PathPrefix(`/get-https`) || PathPrefix(`/hwaccel-profiler`) || PathPrefix(`/status`) || PathPrefix(`/exec`) || PathPrefix(`/stream`) || PathRegexp(`^/[^/]+/(stats\\\\.json|create|remove|destroy)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stats\\\\.json|hls\\\\.m3u8|master\\\\.m3u8|stream\\\\.m3u8|dlna|thumb\\\\.jpg)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stream-q-[^/]+\\\\.m3u8|stream-[^/]+\\\\.m3u8|subs-[^/]+\\\\.m3u8)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stream-q-[^/]+|stream-[^/]+)/[^/]+\\\\.(ts|mp4)$$`) || PathRegexp(`^/yt/[^/]+(\\\\.json)?$$`) || Path(`/thumb.jpg`) || Path(`/stats.json`) )",
          # Stremio HTTPS Streaming Server (port 12470)
          "traefik.http.routers.stremio-https12470.service=stremio-https12470",
          "traefik.http.services.stremio-https12470.loadbalancer.server.scheme=https",
          "traefik.http.services.stremio-https12470.loadbalancer.server.port=12470",
          # Stremio API/streaming routes to 12470
          "traefik.http.routers.stremio-https12470.rule=(Host(`stremio.${var.domain}`) || Host(`stremio.${node.unique.name}.${var.domain}`)) && ( PathPrefix(`/hlsv2`) || PathPrefix(`/casting`) || PathPrefix(`/local-addon`) || PathPrefix(`/proxy`) || PathPrefix(`/rar`) || PathPrefix(`/zip`) || PathPrefix(`/settings`) || PathPrefix(`/create`) || PathPrefix(`/removeAll`) || PathPrefix(`/samples`) || PathPrefix(`/probe`) || PathPrefix(`/subtitlesTracks`) || PathPrefix(`/opensubHash`) || PathPrefix(`/subtitles`) || PathPrefix(`/network-info`) || PathPrefix(`/device-info`) || PathPrefix(`/get-https`) || PathPrefix(`/hwaccel-profiler`) || PathPrefix(`/status`) || PathPrefix(`/exec`) || PathPrefix(`/stream`) || PathRegexp(`^/[^/]+/(stats\\\\.json|create|remove|destroy)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stats\\\\.json|hls\\\\.m3u8|master\\\\.m3u8|stream\\\\.m3u8|dlna|thumb\\\\.jpg)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stream-q-[^/]+\\\\.m3u8|stream-[^/]+\\\\.m3u8|subs-[^/]+\\\\.m3u8)$$`) || PathRegexp(`^/[^/]+/[^/]+/(stream-q-[^/]+|stream-[^/]+)/[^/]+\\\\.(ts|mp4)$$`) || PathRegexp(`^/yt/[^/]+(\\\\.json)?$$`) || Path(`/thumb.jpg`) || Path(`/stats.json`) )",
          "homepage.group=Media Streaming Platforms",
          "homepage.name=Stremio",
          "homepage.icon=stremio.png",
          "homepage.href=https://stremio.${var.domain}/",
          "homepage.description=A one-stop hub for video content aggregation, allowing you to stream movies, series, and more from various sources",
          "kuma.stremio.http.name=stremio.${node.unique.name}.${var.domain}",
          "kuma.stremio.http.url=https://stremio.${var.domain}",
          "kuma.stremio.http.interval=60"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "command -v curl >/dev/null || (apk add --no-cache curl >/dev/null 2>&1 || apt-get update >/dev/null 2>&1 && apt-get install -y curl >/dev/null 2>&1); (curl -fs http://127.0.0.1:11470/ >/dev/null 2>&1 || curl -fsk https://127.0.0.1:12470/ >/dev/null 2>&1) || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Flaresolverr Group
  group "flaresolverr-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "flaresolverr" { to = 8191 }
    }

    # Headless anti-bot proxy to bypass Cloudflare/JS challenges for indexers and scrapers
    task "flaresolverr" {
      driver = "docker"

      config {
        image = "ghcr.io/flaresolverr/flaresolverr:latest"
        ports = ["flaresolverr"]
        labels = {
          "com.docker.compose.project" = "indexers-group"
          "com.docker.compose.service" = "flaresolverr"
        }
      }

      env {
        TZ                = var.tz
        PUID              = var.puid
        PGID              = "988"
        UMASK             = var.umask
        LOG_LEVEL         = "debug"
        LOG_HTML          = "false"
        CAPTCHA_SOLVER    = "none"
        PORT              = "8191"
        HOST              = "0.0.0.0"
        HEADLESS          = "true"
        BROWSER_TIMEOUT   = "120000"
        TEST_URL          = "https://www.google.com"
        PROMETHEUS_ENABLED = "true"
        PROMETHEUS_PORT   = "9090"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "flaresolverr"
        port = "flaresolverr"
        tags = [
          "flaresolverr",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.flaresolverr.middlewares=nginx-auth@file",
          "traefik.http.routers.flaresolverr.rule=Host(`flaresolverr.${var.domain}`) || Host(`flaresolverr.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.flaresolverr.loadbalancer.server.port=8191",
          "homepage.group=Infrastructure",
          "homepage.name=Flaresolverr",
          "homepage.icon=flaresolverr.png",
          "homepage.href=https://flaresolverr.${var.domain}/",
          "homepage.description=Headless anti-bot proxy to bypass Cloudflare/JS challenges for indexers and scrapers"
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "15s"
        }
      }
    }
  }

  # Jackett Group
  group "jackett-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "jackett" {
        static = 9117
        to = 9117
      }
    }

    # 🔹🔹 Jackett 🔹🔹
    task "jackett" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/jackett:latest"
        ports = ["jackett"]
        volumes = [
          "${var.config_path}/jackett/config:/config",
          "/mnt/remote/blackhole:/blackhole"
        ]
        labels = {
          "com.docker.compose.project" = "indexers-group"
          "com.docker.compose.service" = "jackett"
        }
      }

      env {
        TZ               = var.tz
        PUID             = var.puid
        PGID             = "988"
        UMASK            = var.umask
        AUTO_UPDATE      = "true"
        RUN_OPTS         = ""
        JACKETT_API_KEY  = var.jackett_api_key
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "jackett"
        port = "jackett"
        tags = [
          "jackett",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.jackett.rule=Host(`jackett.${var.domain}`) || Host(`jackett.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.jackett.loadbalancer.server.port=9117",
          "homepage.group=Source Aggregator",
          "homepage.name=Jackett Indexer",
          "homepage.icon=jackett.png",
          "homepage.href=https://jackett.${var.domain}/",
          "homepage.description=Connects your download applications with various source providers and indexers",
          "homepage.weight=1"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "curl -fs http://127.0.0.1:9117/api/v2.0/indexers/all/results/torznab?t=indexers&apikey=${var.jackett_api_key} > /dev/null 2>&1 || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Prowlarr Group
  group "prowlarr-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "prowlarr" {
        static = 9696
        to = 9696
      }
    }

    # 🔹🔹 Prowlarr 🔹🔹
    task "prowlarr" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/prowlarr:latest"
        ports = ["prowlarr"]
        volumes = [
          "${var.config_path}/prowlarr/config:/config:rw"
        ]
        labels = {
          "com.docker.compose.project" = "indexers-group"
          "com.docker.compose.service" = "prowlarr"
        }
      }

      env {
        TZ   = var.tz
        PUID = var.puid
        PGID = "988"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "prowlarr"
        port = "prowlarr"
        tags = [
          "prowlarr",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.prowlarr.rule=Host(`prowlarr.${var.domain}`) || Host(`prowlarr.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.prowlarr.loadbalancer.server.port=9696",
          "homepage.group=Indexers",
          "homepage.name=Prowlarr",
          "homepage.icon=prowlarr.png",
          "homepage.href=https://prowlarr.${var.domain}/",
          "homepage.description=Indexer proxy and manager; normalizes indexers and feeds PVR apps like Sonarr/Radarr",
          "homepage.weight=1"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "curl -fs -H \"Authorization: Bearer ${var.prowlarr_api_key}\" http://127.0.0.1:9696/api/v1/system/status || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Aiostreams Group
  group "aiostreams-group" {
    count = 2  # HA: Run on multiple nodes for failover

    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "aiostreams" { to = 3000 }
    }

    # 🔹🔹 AIOStreams 🔹🔹
    task "aiostreams" {
      driver = "docker"

      config {
        image = "ghcr.io/viren070/aiostreams:v2.12.2"
        ports = ["aiostreams"]
        volumes = [
          "${var.config_path}/stremio/addons/aiostreams/data:/app/data",
          "${var.root_path}/secrets:/run/secrets-src:ro"
        ]
        entrypoint = ["/bin/sh", "-c"]
        args = [
          "mkdir -p /run/secrets && for f in /run/secrets-src/*.txt; do ln -sf \"$$f\" \"/run/secrets/$$(basename \"$$f\" .txt)\" 2>/dev/null || true; done && exec node /app/dist/index.js"
        ]
        labels = {
          "com.docker.compose.project" = "stremio-group"
          "com.docker.compose.service" = "aiostreams"
        }
      }

      template {
        data = <<EOF
# ==============================================================================
#                         ESSENTIAL ADDON SETUP
# ==============================================================================
TZ=${var.tz}
PUID=${var.puid}
PGID=988
UMASK=${var.umask}

# --- Addon Identification ---
ADDON_NAME={{ env "AIOSTREAMS_ADDON_NAME" | or "BadenAIO" }}
ADDON_ID=aiostreams.${var.domain}

# --- Network Configuration ---
PORT={{ env "AIOSTREAMS_PORT" | or "3000" }}
BASE_URL=https://aiostreams.${var.domain}

# --- Security ---
SECRET_KEY=${var.aiostreams_secret_key}
ADDON_PASSWORD=${var.aiostreams_addon_password}

# --- Database ---
DATABASE_URI=sqlite://./data/db.sqlite

# ==============================================================================
#                     BUILT-IN ADDON CONFIGURATION
# ==============================================================================
BUILTIN_STREMTHRU_URL=https://stremthru.13377001.xyz
BUILTIN_DEBRID_INSTANT_AVAILABILITY_CACHE_TTL=1800
BUILTIN_DEBRID_PLAYBACK_LINK_CACHE_TTL=3600
BUILTIN_GET_TORRENT_TIMEOUT=5000
BUILTIN_GET_TORRENT_CONCURRENCY=100
BUILTIN_PROWLARR_SEARCH_TIMEOUT={{ env "BUILTIN_PROWLARR_SEARCH_TIMEOUT" | or "" }}
BUILTIN_PROWLARR_SEARCH_CACHE_TTL=604800
BUILTIN_PROWLARR_INDEXERS_CACHE_TTL=1209600

# ==============================================================================
#                     DEBRID & OTHER SERVICE API KEYS
# ==============================================================================
TMDB_ACCESS_TOKEN_FILE=/run/secrets/tmdb-access-token
TMDB_API_KEY_FILE=/run/secrets/tmdb-api-key
TRAKT_CLIENT_ID={{ env "TRAKT_CLIENT_ID" | or "" }}

DEFAULT_REALDEBRID_API_KEY_FILE=/run/secrets/realdebrid-api-key
DEFAULT_ALLDEBRID_API_KEY_FILE=/run/secrets/alldebrid-api-key
DEFAULT_PREMIUMIZE_API_KEY_FILE=/run/secrets/premiumize-api-key
DEFAULT_DEBRIDLINK_API_KEY_FILE=/run/secrets/debridlink-api-key
DEFAULT_TORBOX_API_KEY_FILE=/run/secrets/torbox-api-key
DEFAULT_OFFCLOUD_API_KEY_FILE=/run/secrets/offcloud-api-key
DEFAULT_OFFCLOUD_EMAIL={{ env "OFFCLOUD_EMAIL" | or "" }}
DEFAULT_OFFCLOUD_PASSWORD_FILE=/run/secrets/offcloud-password

# ==============================================================================
#                           CACHE CONFIGURATION
# ==============================================================================
DEFAULT_MAX_CACHE_SIZE=100000
PROXY_IP_CACHE_TTL=900
MANIFEST_CACHE_TTL=300
SUBTITLE_CACHE_TTL=300
STREAM_CACHE_TTL=1
CATALOG_CACHE_TTL=300
META_CACHE_TTL=300
ADDON_CATALOG_CACHE_TTL=300
RPDB_API_KEY_VALIDITY_CACHE_TTL=604800

# ==============================================================================
#                             FEATURE CONTROL
# ==============================================================================
DISABLE_SELF_SCRAPING=true

# ==============================================================================
#                                 LOGGING
# ==============================================================================
LOG_LEVEL=info
LOG_FORMAT=text
LOG_SENSITIVE_INFO=true
LOG_TIMEZONE=Etc/UTC

# ==============================================================================
#                         INACTIVE USER PRUNING
# ==============================================================================
PRUNE_INTERVAL=86400
PRUNE_MAX_DAYS=-1

# ==============================================================================
#                      DEFAULT/FORCED STREAM PROXY (MediaFlow, StremThru)
# ==============================================================================
FORCE_PROXY_ENABLED=true
DEFAULT_PROXY_ID=stremthru
DEFAULT_PROXY_CREDENTIALS={{ env "STREMTHRU_CREDENTIALS" | or "bolabaden:duckdns" }}
FORCE_PROXY_DISABLE_PROXIED_ADDONS=false
ENCRYPT_MEDIAFLOW_URLS=true
ENCRYPT_STREMTHRU_URLS=true

# ==============================================================================
#                       ADVANCED CONFIGURATION & LIMITS
# ==============================================================================
DEFAULT_TIMEOUT=15000
MAX_ADDONS=100
MAX_GROUPS=50
MAX_KEYWORD_FILTERS=50
MAX_STREAM_EXPRESSION_FILTERS=200
MAX_TIMEOUT=50000
MIN_TIMEOUT=1000
PRECACHE_NEXT_EPISODE_MIN_INTERVAL=86400

# ==============================================================================
#                           RATE LIMIT CONFIGURATION
# ==============================================================================
DISABLE_RATE_LIMITS=false
STATIC_RATE_LIMIT_WINDOW=5
STATIC_RATE_LIMIT_MAX_REQUESTS=75
USER_API_RATE_LIMIT_WINDOW=5
USER_API_RATE_LIMIT_MAX_REQUESTS=5
STREAM_API_RATE_LIMIT_WINDOW=5
STREAM_API_RATE_LIMIT_MAX_REQUESTS=10
FORMAT_API_RATE_LIMIT_WINDOW=5
FORMAT_API_RATE_LIMIT_MAX_REQUESTS=30
CATALOG_API_RATE_LIMIT_WINDOW=5
CATALOG_API_RATE_LIMIT_MAX_REQUESTS=5
ANIME_API_RATE_LIMIT_WINDOW=60
ANIME_API_RATE_LIMIT_MAX_REQUESTS=120
STREMIO_STREAM_RATE_LIMIT_WINDOW=15
STREMIO_STREAM_RATE_LIMIT_MAX_REQUESTS=10
STREMIO_CATALOG_RATE_LIMIT_WINDOW=5
STREMIO_CATALOG_RATE_LIMIT_MAX_REQUESTS=30
STREMIO_MANIFEST_RATE_LIMIT_WINDOW=5
STREMIO_MANIFEST_RATE_LIMIT_MAX_REQUESTS=5
STREMIO_SUBTITLE_RATE_LIMIT_WINDOW=5
STREMIO_SUBTITLE_RATE_LIMIT_MAX_REQUESTS=10
STREMIO_META_RATE_LIMIT_WINDOW=5
STREMIO_META_RATE_LIMIT_MAX_REQUESTS=15

# Anime Database
ANIME_DB_LEVEL_OF_DETAIL=required
ANIME_DB_FRIBB_MAPPINGS_REFRESH_INTERVAL=86400000
ANIME_DB_MANAMI_DB_REFRESH_INTERVAL=604800000
ANIME_DB_KITSU_IMDB_MAPPING_REFRESH_INTERVAL=86400000
ANIME_DB_EXTENDED_ANITRAKT_MOVIES_REFRESH_INTERVAL=86400000
ANIME_DB_EXTENDED_ANITRAKT_TV_REFRESH_INTERVAL=86400000

# External Addon URLs
STREMTHRU_STORE_URL=https://stremthru.${var.domain}/stremio/store/
STREMTHRU_TORZ_URL=https://stremthru.${var.domain}/stremio/torz/
DEFAULT_JACKETTIO_INDEXERS='["animetosho", "anirena", "bitsearch", "eztv", "nyaasi", "thepiratebay", "therarbg", "yts"]'
EOF
        destination = "secrets/aiostreams.env"
        env         = true
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "aiostreams"
        port = "aiostreams"
        tags = [
          "aiostreams",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.aiostreams.rule=Host(`aiostreams.${var.domain}`) || Host(`aiostreams.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.aiostreams.loadbalancer.server.port=3000",
          "homepage.group=Stremio Addons",
          "homepage.name=AIOStreams",
          "homepage.icon=aiostreams.png",
          "homepage.href=https://aiostreams.${var.domain}/",
          "homepage.description=Stremio add-on that aggregates multiple sources into a single unified stream catalog"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/manifest.json > /dev/null 2>&1 || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  # Stremthru Group
  group "stremthru-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "stremthru" { to = 8080 }
    }

    # 🔹🔹 StremThru 🔹🔹
    task "stremthru" {
      driver = "docker"

      config {
        image = "docker.io/muniftanjim/stremthru:latest"
        ports = ["stremthru"]
        volumes = [
          "${var.config_path}/stremio/addons/stremthru/app/data:/app/data"
        ]
        labels = {
          "com.docker.compose.project" = "stremio-group"
          "com.docker.compose.service" = "stremthru"
        }
      }

      template {
        data = <<EOF
TZ=${var.tz}
PUID=${var.puid}
PGID=988
UMASK=${var.umask}

# The base URL of the StremThru instance.
# Required for the StremThru Lists addon to work correctly with Trakt OAuth.
STREMTHRU_BASE_URL=https://stremthru.${var.domain}

# =============================
#     LOGGING CONFIGURATION
# ================================
STREMTHRU_LOG_LEVEL=INFO
STREMTHRU_LOG_FORMAT=text

# ============================
#       PROXY CONFIGURATION
# ================================
# A list of user credentials for the proxy. In a comma separated list of username:password pairs.
STREMTHRU_PROXY_AUTH=${var.stremthru_proxy_auth}

# A list of admin users. Should be a comma separated list of usernames.
STREMTHRU_AUTH_ADMIN=${var.main_username}

# A list of store credentials per user. In a comma separated list of username:store_name:store_token.
STREMTHRU_STORE_AUTH=${var.stremthru_store_auth}

# A list of proxy configurations per store.
STREMTHRU_STORE_CONTENT_PROXY=*:true,premiumize:false

# This is the maximum number of connections to the proxy per user.
STREMTHRU_CONTENT_PROXY_CONNECTION_LIMIT=*:10

# ============================================================
#                   INTEGRATION CONFIGURATION
# ============================================================
# Trakt.tv Integration
STREMTHRU_INTEGRATION_TRAKT_CLIENT_ID=${var.trakt_client_id}
STREMTHRU_INTEGRATION_TRAKT_CLIENT_SECRET=${var.trakt_client_secret}
STREMTHRU_INTEGRATION_TRAKT_LIST_STALE_TIME=12h

# TMDB Integration
STREMTHRU_INTEGRATION_TMDB_ACCESS_TOKEN=${var.tmdb_access_token}
STREMTHRU_INTEGRATION_TMDB_LIST_STALE_TIME=12h

# GitHub Integration
STREMTHRU_INTEGRATION_GITHUB_USER=th3w1zard1
STREMTHRU_INTEGRATION_GITHUB_TOKEN={{ env "GITHUB_TOKEN" | or "" }}

# ================================
#             OTHER
# ================================
STREMTHRU_STREMIO_TORZ_LAZY_PULL=true

# =============================
#      FEATURE CONFIGURATION
# ================================
STREMTHRU_FEATURE=+anime,-stremio_p2p

# =============================
#    DATABASE CONFIGURATION
# ================================
STREMTHRU_DATABASE_URI=sqlite://./data/stremthru.db
STREMTHRU_REDIS_URI=redis://${var.redis_hostname}:${var.redis_port}
EOF
        destination = "secrets/stremthru.env"
        env         = true
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "stremthru"
        port = "stremthru"
        tags = [
          "stremthru",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.stremthru.rule=Host(`stremthru.${var.domain}`) || Host(`stremthru.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.stremthru.loadbalancer.server.port=8080",
          "homepage.group=Stremio Addons",
          "homepage.name=StremThru",
          "homepage.icon=stremthru.png",
          "homepage.href=https://stremthru.${var.domain}/",
          "homepage.description=Tunnel/proxy bridge for Debrid services to unify access of streaming links through a single host."
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "1m"
          timeout  = "5s"
        }
      }
    }
  }

  # Rclone Group
  group "rclone-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "rclone" { to = 5572 }
    }

    # 🔹🔹 Rclone 🔹🔹
    task "rclone" {
      driver = "docker"

      config {
        image = "docker.io/rclone/rclone:1.71"
        ports = ["rclone"]
        devices = [
          {
            host_path      = "/dev/fuse"
            container_path = "/dev/fuse"
          }
        ]
        cap_add = ["SYS_ADMIN"]
        security_opt = ["apparmor:unconfined"]
        volumes = [
          "/:/hostfs:rshared",
          "/etc/group:/etc/group:ro",
          "/etc/passwd:/etc/passwd:ro",
          "/mnt/remote:/mnt/remote:rshared",
          "${var.config_path}/rclone/.cache:/.cache",
          "${var.config_path}/rclone/config/rclone:/config/rclone",
          "${var.config_path}/rclonefm/js:/var/lib/rclonefm/js"
        ]
        command = "rcd"
        args = [
          "--rc-web-gui",
          "--rc-web-gui-no-open-browser",
          "--rc-addr=:5572",
          "--log-level=INFO",
          "--rc-no-auth",
          "--config=/config/rclone/rclone.conf",
          "--cache-dir=/.cache/rclone"
        ]
        labels = {
          "com.docker.compose.project" = "rclone-group"
          "com.docker.compose.service" = "rclone"
        }
      }

      # Rclone config template
      template {
        data = <<EOF
[gcache]
type = cache
remote = gdrive:x-san
plex_url = http://plex:32400
plex_username = {{ env "PLEX_EMAIL" | or "" }}
plex_password = ${var.sudo_password}
chunk_size = 16M
plex_token = {{ env "PLEX_TOKEN" | or "" }}
db_path = /config/rclone/rclone-cache
chunk_path = /config/rclone/rclone-cache
info_age = 2d
chunk_total_size = 20G
db_purge = true

[zurg]
type = webdav
url = http://zurg:9999/dav
vendor = other
pacer_min_sleep = 0

[zurghttp]
type = http
url = http://zurg:9999/http/
no_head = false
no_slash = false

[alldebrid]
type = webdav
url = {{ env "ALLDEBRID_WEBDAV_URL" | or "https://webdav.debrid.it/" }}
vendor = other
user = {{ env "ALLDUBRID_RCLONE_USER" | or "" }}

[pm]
type = premiumizeme
token: {"access_token":"{{ env "PREMIUMIZE_RCLONE_ACCESS_TOKEN" | or "" }}","token_type":"Bearer","refresh_token":"{{ env "PREMIUMIZE_RCLONE_REFRESH_TOKEN" | or "" }}","expiry":"2035-08-29T06:37:06.7039897-05:00","expires_in":315360000}
EOF
        destination = "local/rclone.conf"
      }

      # Rclone mounts JSON template
      template {
        data = <<EOF
[
  {
    "fs": "pm:",
    "mountPoint": "/mnt/remote/premiumize",
    "LogLevel": "DEBUG",
    "mainOpt": {
      "LogLevel": "DEBUG"
    },
    "mountOpt": {
      "AllowNonEmpty": true,
      "AllowOther": true,
      "AttrTimeout": "87600h",
      "DirCacheTime": "60s",
      "DirPerms": "0777",
      "ExtraFlags": [
        "--config=/config/rclone/rclone.conf",
        "--log-level=DEBUG",
        "--log-file=/config/rclone/rclone.log"
      ],
      "FilePerms": "0666",
      "GID": 1000,
      "PollInterval": "30s",
      "UID": 1000
    },
    "vfsOpt": {
      "BufferSize": "128M",
      "CacheMaxAge": "2m",
      "CacheMaxSize": "100G",
      "CacheMode": "full",
      "CachePollInterval": "30s",
      "ChunkSize": "2M",
      "ChunkSizeLimit": "64M",
      "DiskSpaceTotalSize": "1T",
      "ExtraOptions": [
        "--vfs-refresh",
        "--transfers=16",
        "--checkers=16",
        "--multi-thread-streams=4",
        "--cache-dir=/mnt/remote/cache/realdebrid"
      ],
      "FastFingerprint": true,
      "MinFreeSpace": "1G",
      "ReadAhead": "128M",
      "ReadWait": "40ms"
    }
  },
  {
    "fs": "alldebrid:",
    "mountPoint": "/mnt/remote/alldebrid",
    "LogLevel": "DEBUG",
    "mainOpt": {
      "ExtraFlags": [
        "--cutoff-mode=cautious",
        "--network-mode",
        "--config=/config/rclone/rclone.conf",
        "--log-level=DEBUG",
        "--log-file=/config/rclone/rclone.log"
      ],
      "LogLevel": "DEBUG",
      "MultiThreadStreams": 0,
      "TPSLimit": 12,
      "Transfers": 8
    },
    "mountOpt": {
      "AllowNonEmpty": true,
      "AllowOther": true,
      "DirPerms": "0777",
      "ExtraFlags": [
        "--cache-dir=/mnt/remote/cache/alldebrid"
      ],
      "FilePerms": "0666",
      "VolumeName": "AllDebrid"
    },
    "vfsOpt": {
      "BufferSize": "128M",
      "CacheMaxAge": "1h",
      "CacheMaxSize": "100G",
      "CacheMode": "full",
      "ChunkSize": "128M",
      "ChunkSizeLimit": "0",
      "DirCacheTime": "160h",
      "ExtraOptions": [],
      "ReadAhead": "0"
    }
  }
]
EOF
        destination = "local/rclone-mounts.json"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "rclone"
        port = "rclone"
        tags = [
          "rclone",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.rclone.middlewares=nginx-auth@file",
          "traefik.http.routers.rclone.rule=Host(`rclone.${var.domain}`) || Host(`rclone.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.rclone.loadbalancer.server.port=5572",
          "homepage.group=Cloud",
          "homepage.name=Rclone",
          "homepage.icon=rclone.png",
          "homepage.href=https://rclone.${var.domain}/",
          "homepage.description=A web interface for Rclone.",
          "homepage.weight=0"
        ]

        check {
          type     = "script"
          command  = "/bin/mountpoint"
          args     = ["-q", "/mnt/remote"]
          interval = "5s"
          timeout  = "3s"
        }
      }
    }
  }

  # Rclone Init Group
  group "rclone-init-group" {
    count = 1

    network {
      mode = "bridge"
    }

    # Rclone Init container
    task "rclone-init" {
      driver = "docker"

      config {
        image = "ghcr.io/coanghel/rclone-docker-automount/rclone-init:latest"
        network_mode = "bridge"
        volumes = [
          "/mnt/remote:/mnt/remote:rshared"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "rclone-init"
        }
      }

      # Mount configuration template
      template {
        data = <<EOF
[
  {
    "fs": "pm:",
    "mountPoint": "/mnt/remote/premiumize",
    "LogLevel": "DEBUG",
    "mainOpt": {
      "LogLevel": "DEBUG"
    },
    "mountOpt": {
      "AllowNonEmpty": true,
      "AllowOther": true,
      "AttrTimeout": "87600h",
      "DirCacheTime": "60s",
      "DirPerms": "0777",
      "ExtraFlags": [
        "--config=/config/rclone/rclone.conf",
        "--log-level=DEBUG",
        "--log-file=/config/rclone/rclone.log"
      ],
      "FilePerms": "0666",
      "GID": 1000,
      "PollInterval": "30s",
      "UID": 1000
    },
    "vfsOpt": {
      "BufferSize": "128M",
      "CacheMaxAge": "2m",
      "CacheMaxSize": "100G",
      "CacheMode": "full",
      "CachePollInterval": "30s",
      "ChunkSize": "2M",
      "ChunkSizeLimit": "64M",
      "DiskSpaceTotalSize": "1T",
      "ExtraOptions": [
        "--vfs-refresh",
        "--transfers=16",
        "--checkers=16",
        "--multi-thread-streams=4",
        "--cache-dir=/mnt/remote/cache/realdebrid"
      ],
      "FastFingerprint": true,
      "MinFreeSpace": "1G",
      "ReadAhead": "128M",
      "ReadWait": "40ms"
    }
  }
]
EOF
        destination = "local/mounts.json"
      }

      env {
        RCLONE_USERNAME    = ""
        RCLONE_PASSWORD    = ""
        RCLONE_PORT        = var.rclone_port
        RCLONE_CONFIG_PATH = "/config/rclone/rclone.conf"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }

  # Warp Net Init Group - 1:1 with Docker (separate service, runs once)
  group "warp-nat-routing-group" {
    count = 0  # DISABLED: Complex networking setup, optional service

    network {
      mode = "host"
    }

    # Network Initialization Task
    task "warp-net-init" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = false  # Run once before other tasks
      }

      config {
        image = "docker:cli"
        network_mode = "host"
        command = "sh"
        args = [
          "-c",
          <<EOF
# Create network if it doesn't exist
if ! docker network inspect $${DOCKER_NETWORK_NAME:-warp-nat-net} >/dev/null 2>&1; then
  echo "Creating network $${DOCKER_NETWORK_NAME:-warp-nat-net}..."
  docker network create \
    --driver=bridge \
    --attachable \
    -o com.docker.network.bridge.name=br_$${DOCKER_NETWORK_NAME:-warp-nat-net} \
    -o com.docker.network.bridge.enable_ip_masquerade=false \
    --subnet=$${WARP_NAT_NET_SUBNET:-10.0.2.0/24} \
    --gateway=$${WARP_NAT_NET_GATEWAY:-10.0.2.1} \
    $${DOCKER_NETWORK_NAME:-warp-nat-net}
  echo "Network created successfully"
else
  echo "Network $${DOCKER_NETWORK_NAME:-warp-nat-net} already exists"
fi
EOF
        ]
        volumes = [
          "${var.docker_socket}:/var/run/docker.sock:ro"
        ]
        labels = {
          "com.docker.compose.project" = "warp-nat-routing-group"
          "com.docker.compose.service" = "warp-net-init"
        }
      }

      env {
        DOCKER_NETWORK_NAME  = var.docker_network_name
        WARP_NAT_NET_SUBNET  = var.warp_nat_net_subnet
        WARP_NAT_NET_GATEWAY = var.warp_nat_net_gateway
      }

      resources {
        cpu        = 100
        memory     = 128
        memory_max = 0
      }

      service {
        name = "warp-net-init"
        tags = [
          "warp-net-init",
          "${var.domain}"
        ]
      }

      restart {
        attempts = 0
        mode     = "fail"
      }
    }
  }

  # WARP NAT Routing Group
  group "warp-nat-routing" {
    count = 0  # DISABLED: Complex networking setup, optional service

    network {
      mode = "host"
    }

    # 🔹🔹 WARP in Docker (with NAT) 🔹🔹
    task "warp-nat-gateway" {
      driver = "docker"

      lifecycle {
        hook    = "prestart"
        sidecar = true
      }

      config {
        image = "docker.io/caomingjun/warp:latest"
        network_mode = "bridge"
        # add removed rule back (https://github.com/opencontainers/runc/pull/3468)
        devices = [
          {
            host_path      = "/dev/net/tun"
            container_path = "/dev/net/tun"
          }
        ]
        cap_add = ["MKNOD", "AUDIT_WRITE", "NET_ADMIN"]
        sysctl = {
          "net.ipv6.conf.all.disable_ipv6"     = "0"
          "net.ipv4.conf.all.src_valid_mark"   = "1"
          "net.ipv4.ip_forward"                = "1"
          "net.ipv6.conf.all.forwarding"       = "1"
          "net.ipv6.conf.all.accept_ra"        = "2"
        }
        volumes = [
          "warp-config-data:/var/lib/cloudflare-warp"
        ]
        labels = {
          "com.docker.compose.project" = "warp-nat-routing-group"
          "com.docker.compose.service" = "warp-nat-gateway"
        }
      }

      env {
        # If set, will add checks for host connectivity into healthchecks and automatically fix it if necessary.
        # See https://github.com/cmj2002/warp-docker/blob/main/docs/host-connectivity.md for more information.
        BETA_FIX_HOST_CONNECTIVITY = "false"
        # The arguments passed to GOST. The default is -L :1080, which means to listen on port 1080 in the container at the same time through HTTP and SOCKS5 protocols.
        # If you want to have UDP support or use advanced features provided by other protocols, you can modify this parameter. For more information, refer to https://v2.gost.run/en/.
        GOST_ARGS = var.gost_args
        # If set, will work as warp mode and turn NAT on.
        # You can route L3 traffic through warp-docker to Warp.
        # See https://github.com/cmj2002/warp-docker/blob/main/docs/nat-gateway.md for more information.
        WARP_ENABLE_NAT = var.warp_enable_nat
        # The license key of the WARP client, which is optional.
        WARP_LICENSE_KEY = var.warp_license_key
        # The time to wait for the WARP daemon to start, in seconds.
        WARP_SLEEP = var.warp_sleep
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "warp-nat-gateway"
        tags = ["warp-nat-gateway"]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "if curl -s https://cloudflare.com/cdn-cgi/trace | grep -qE '^warp=on|warp=plus$'; then echo \"Cloudflare WARP is active.\" && exit 0; else echo \"Cloudflare WARP is not active.\" && exit 1; fi"]
          interval = "10s"
          timeout  = "5s"
        }
      }
    }

    # WARP Router
    task "warp_router" {
      driver = "docker"

      config {
        image = "alpine:latest"
        command = "/bin/bash"
        args    = ["/usr/local/bin/warp-monitor.sh"]
        privileged = true
        network_mode = "host"
        volumes = [
          "/etc/iproute2/rt_tables:/etc/iproute2/rt_tables:rw",
          "/proc:/proc:rw",
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
        labels = {
          "com.docker.compose.project" = "warp-nat-routing-group"
          "com.docker.compose.service" = "warp_router"
        }
      }

      # WARP NAT Setup Script template
      template {
        data = <<EOF
#!/bin/bash
set -xe

# Defaults (configurable via env)
DOCKER_HOST="$${DOCKER_HOST:-unix:///var/run/docker.sock}"
ROUTER_CONTAINER_NAME="$${ROUTER_CONTAINER_NAME:-warp_router}"
DOCKER_NETWORK_NAME="$${DOCKER_NETWORK_NAME:-warp-nat-net}"
WARP_CONTAINER_NAME="$${WARP_CONTAINER_NAME:-warp-nat-gateway}"
HOST_VETH_IP="$${HOST_VETH_IP:-169.254.100.1}"
CONT_VETH_IP="$${CONT_VETH_IP:-169.254.100.2}"
ROUTING_TABLE="$${ROUTING_TABLE:-warp-nat-routing}"
VETH_HOST="$${VETH_HOST:-veth-warp}" 

# VETH_CONT is derived from VETH_HOST
VETH_CONT="$${VETH_HOST#veth-}-nat-cont"
DOCKER="docker -H $$DOCKER_HOST"
DEFAULT_DOCKER_NETWORK_NAME="warp-nat-net"

# Pick a free routing table id dynamically (start at 110)
pick_table_id() {
    local id=110
    while grep -q "^$$id " /etc/iproute2/rt_tables 2>/dev/null; do
        id=$$((id+1))
    done
    echo $$id
}

# Get existing routing table ID if name exists, else pick new and add
if grep -q " $$ROUTING_TABLE$$" /etc/iproute2/rt_tables 2>/dev/null; then
    ROUTING_TABLE_ID=$$(awk "/ $$ROUTING_TABLE\$$/ {print \$$1}" /etc/iproute2/rt_tables)
    echo "Routing table id acquired: \`$$ROUTING_TABLE_ID\`"
else
    ROUTING_TABLE_ID=$$(pick_table_id)
    echo "$$ROUTING_TABLE_ID $$ROUTING_TABLE" >> /etc/iproute2/rt_tables
fi

if docker ps -a --format '{{.Names}}' | grep -w "$${ROUTER_CONTAINER_NAME}" >/dev/null 2>&1; then
    echo "Container '$${ROUTER_CONTAINER_NAME}' exists."
    # Determine docker network name and subnet dynamically if not provided
    if [[ -z "$${DOCKER_NETWORK_NAME:-}" ]]; then
        echo "Trying to find the network that $${ROUTER_CONTAINER_NAME} is connected to..."
        warp_router_networks="$$($$DOCKER inspect -f '{{range $$k,$$v := .NetworkSettings.Networks}}{{printf \"%s\n\" $$k}}{{end}}' $${ROUTER_CONTAINER_NAME} 2>/dev/null || true)"
        if [[ -n "$$warp_router_networks" ]]; then
            # Use the first network found (get first line)
            DOCKER_NETWORK_NAME="$$(echo "$$warp_router_networks" | head -n1)"
            echo "DOCKER_NETWORK_NAME: '$$DOCKER_NETWORK_NAME'"
        else
            echo "DOCKER_NETWORK_NAME: not found nor set"
        fi
    fi
fi

# If not set, fallback to default
if [[ -z "$${DOCKER_NETWORK_NAME:-}" ]]; then
    echo "DOCKER_NETWORK_NAME: \`$$DOCKER_NETWORK_NAME\` not set, using default \`$$DEFAULT_DOCKER_NETWORK_NAME\`"
    DOCKER_NETWORK_NAME="$$DEFAULT_DOCKER_NETWORK_NAME"
fi

# Create docker network if it doesn't exist
if $$DOCKER network inspect $$DOCKER_NETWORK_NAME --format '{{.Name}}' | grep -q "^$$DOCKER_NETWORK_NAME$$"; then
    echo "Docker network \`$$DOCKER_NETWORK_NAME\` already exists, recreating it"
    RECREATED_WARP_NETWORK=1

    # Store original gw_priority for each container
    CONTAINERS_USING_WARP_NETWORK=$$($$DOCKER network inspect $$DOCKER_NETWORK_NAME -f '{{range $$k, $$v := .Containers}}{{$$v.Name}} {{end}}')
    CONTAINERS_USING_WARP_NETWORK_COUNT=$$(echo "$$CONTAINERS_USING_WARP_NETWORK" | wc -w)
    CONTAINER_INDEX=0

    # Map: container_name:gw_priority
    declare -A ORIGINAL_GW_PRIORITY

    # Get original gw_priority for each container
    for container in $$CONTAINERS_USING_WARP_NETWORK; do
        # Get the container's network info as JSON
        set +x
        container_json="$$($$DOCKER inspect "$$container" 2>/dev/null)"
        set -x
        # Extract the gw_priority for this network
        gw_priority=$$(echo "$$container_json" | jq -r --arg net "$$DOCKER_NETWORK_NAME" '.[0].NetworkSettings.Networks[$$net].GwPriority // empty')
        ORIGINAL_GW_PRIORITY["$$container"]="$$gw_priority"
    done

    for container in $$CONTAINERS_USING_WARP_NETWORK; do
        CONTAINER_INDEX=$$((CONTAINER_INDEX + 1))
        echo "Disconnecting \`$$container\` from \`$$DOCKER_NETWORK_NAME\` ($$CONTAINER_INDEX out of $$CONTAINERS_USING_WARP_NETWORK_COUNT )"
        $$DOCKER network disconnect $$DOCKER_NETWORK_NAME "$$container"
    done

    $$DOCKER network rm $$DOCKER_NETWORK_NAME 2>/dev/null || true
fi

echo "Creating docker network \`$$DOCKER_NETWORK_NAME\`"
$$DOCKER network create --driver=bridge \
    --attachable \
    -o com.docker.network.bridge.name=br_$$DOCKER_NETWORK_NAME \
    -o com.docker.network.bridge.enable_ip_masquerade=false \
    $$DOCKER_NETWORK_NAME --subnet=$${WARP_NAT_NET_SUBNET:-10.0.2.0/24} --gateway=$${WARP_NAT_NET_GATEWAY:-10.0.2.1} || true

if [[ -n "$${RECREATED_WARP_NETWORK:-}" ]]; then
    echo "Connecting containers to \`$$DOCKER_NETWORK_NAME\`"
    CONTAINER_INDEX=0
    for container in $$CONTAINERS_USING_WARP_NETWORK; do
        CONTAINER_INDEX=$$((CONTAINER_INDEX + 1))
        # Use original gw_priority if available, else fallback to 0x7FFFFFFFFFFFFFFF
        gw_priority="$${ORIGINAL_GW_PRIORITY[$$container]}"
        if [[ -n "$$gw_priority" && "$$gw_priority" != "null" ]]; then
            echo "Connecting \`$$container\` to \`$$DOCKER_NETWORK_NAME\` with original gw_priority=$$gw_priority ($$CONTAINER_INDEX out of $$CONTAINERS_USING_WARP_NETWORK_COUNT )"
            $$DOCKER network connect --gw-priority "$$gw_priority" "$$DOCKER_NETWORK_NAME" "$$container" || true
        else
            echo "Connecting \`$$container\` to \`$$DOCKER_NETWORK_NAME\` with default gw_priority ($$CONTAINER_INDEX out of $$CONTAINERS_USING_WARP_NETWORK_COUNT )"
            $$DOCKER network connect --gw-priority 0x7FFFFFFFFFFFFFFF "$$DOCKER_NETWORK_NAME" "$$container" || true
        fi
    done
fi

# Get stack name from eithe warp_router, or if script was ran on host, get from warp-nat-gateway
STACK_NAME="$$(
    $$DOCKER inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$$ROUTER_CONTAINER_NAME" 2>/dev/null \
    || $$DOCKER inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$$WARP_CONTAINER_NAME" 2>/dev/null
)"
# Strip project prefix (handles both prefixed and non-prefixed names)
# Pattern includes trailing '_' for Compose-managed networks
BASE_NETWORK_NAME="$${DOCKER_NETWORK_NAME#$$STACK_NAME_}"
STACK_NETWORK_NAME="$$STACK_NAME_$${BASE_NETWORK_NAME:-$$DOCKER_NETWORK_NAME}"
BRIDGE_NAME="br_$${BASE_NETWORK_NAME:-$$DOCKER_NETWORK_NAME}"

# Dynamically get DOCKER_NET from network
DOCKER_NET="$$(
    (
        $$DOCKER network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "$$STACK_NETWORK_NAME" 2>/dev/null \
        || $$DOCKER network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "$$BASE_NETWORK_NAME" 2>/dev/null
    ) | tr -d '[:space:]'
)"
if [[ -z "$$DOCKER_NET" ]]; then
    echo "Error: \`\$$DOCKER_NET\` not found"
    exit 1
fi

# Remove existing veth if present (handles restarts/crashes)
ip link del "$$VETH_HOST" 2>/dev/null || true

# Create veth pair
ip link add "$$VETH_HOST" type veth peer name "$$VETH_CONT"

warp_pid="$$($$DOCKER inspect -f '{{.State.Pid}}' $$WARP_CONTAINER_NAME || echo \"\")"
if [[ -z "$$warp_pid" ]]; then
    echo ""
    echo "Error: \`$$WARP_CONTAINER_NAME\` container not found"
    echo "\`$$WARP_CONTAINER_NAME\` container not found" >> /var/log/warp-nat-routing.log
    echo ""
    exit 1
fi

if [[ ! -e "/proc/$$warp_pid/ns/net" ]]; then
    echo ""
    echo "Error: \`$$WARP_CONTAINER_NAME\` container network namespace not ready"
    echo "\`$$WARP_CONTAINER_NAME\` container network namespace not ready" >> /var/log/warp-nat-routing.log
    echo ""
    exit 1
fi

# Clean orphan ip rules for this routing table
ip rule show | grep "lookup $$ROUTING_TABLE" | while read -r line; do
    from_cidr=$$(echo "$$line" | awk '{for (i=1;i<=NF;i++) if ($$i=="from") print $$(i+1)}')
    if [[ -z "$$from_cidr" ]]; then continue; fi
    if [[ "$$from_cidr" == "$$DOCKER_NET" ]]; then continue; fi
    route_line=$$(ip route show exact "$$from_cidr" 2>/dev/null)
    if [[ -z "$$route_line" ]]; then
        echo "Removing orphan rule for non-existing network: $$from_cidr"
        ip rule del from "$$from_cidr" table "$$ROUTING_TABLE" 2>/dev/null || true
        continue
    fi
    dev=$$(echo "$$route_line" | awk '{print $$3}')
    state=$$(ip link show "$$dev" 2>/dev/null | grep -E -o 'state \K\w+' || echo "DOWN")
    if [[ "$$state" != "UP" ]]; then
        echo "Removing orphan rule for down interface $$dev: $$from_cidr"
        ip rule del from "$$from_cidr" table "$$ROUTING_TABLE" 2>/dev/null || true
    fi
done

# Clean orphan NAT rules on host
iptables -t nat -S POSTROUTING | grep -- '-j MASQUERADE' | grep ' ! -d ' | while read -r rule; do
    s_net=$$(echo "$$rule" | sed -n 's/.*-s \([^ ]*\) .*/\1/p')
    d_net=$$(echo "$$rule" | sed -n 's/.*! -d \([^ ]*\) .*/\1/p')
    if [[ "$$s_net" != "$$d_net" || -z "$$s_net" ]]; then continue; fi
    if [[ "$$s_net" == "$$DOCKER_NET" ]]; then continue; fi
    route_line=$$(ip route show exact "$$s_net" 2>/dev/null)
    if [[ -z "$$route_line" ]]; then
        echo "Removing orphan NAT rule for non-existing network: $$s_net"
        del_rule=$$(echo "$$rule" | sed 's/^-A/-D/')
        iptables -t nat $$del_rule 2>/dev/null || true
        continue
    fi
    dev=$$(echo "$$route_line" | awk '{print $$3}')
    state=$$(ip link show "$$dev" 2>/dev/null | grep -E -o 'state \K\w+' || echo "DOWN")
    if [[ "$$state" != "UP" ]]; then
        echo "Removing orphan NAT rule for down interface $$dev: $$s_net"
        del_rule=$$(echo "$$rule" | sed 's/^-A/-D/')
        iptables -t nat $$del_rule 2>/dev/null || true
    fi
done

# Clean orphan NAT rules inside warp container
nsenter -t "$$warp_pid" -n iptables -t nat -S POSTROUTING | grep -- '-j MASQUERADE' | while read -r rule; do
    s_net=$$(echo "$$rule" | sed -n 's/.*-s \([^ ]*\) -j MASQUERADE.*/\1/p')
    if [[ -z "$$s_net" ]]; then continue; fi
    if [[ "$$s_net" == "$$DOCKER_NET" ]]; then continue; fi
    route_line=$$(ip route show exact "$$s_net" 2>/dev/null)
    if [[ -z "$$route_line" ]]; then
        echo "Removing orphan NAT rule inside warp for non-existing network: $$s_net"
        del_rule=$$(echo "$$rule" | sed 's/^-A/-D/')
        nsenter -t "$$warp_pid" -n iptables -t nat $$del_rule 2>/dev/null || true
        continue
    fi
    dev=$$(echo "$$route_line" | awk '{print $$3}')
    state=$$(ip link show "$$dev" 2>/dev/null | grep -E -o 'state \K\w+' || echo "DOWN")
    if [[ "$$state" != "UP" ]]; then
        echo "Removing orphan NAT rule inside warp for down interface $$dev: $$s_net"
        del_rule=$$(echo "$$rule" | sed 's/^-A/-D/')
        nsenter -t "$$warp_pid" -n iptables -t nat $$del_rule 2>/dev/null || true
    fi
done

# Set up cleanup function
cleanup() {
    echo "⚠️ Error occurred. Rolling back..."

    # Remove host veth
    remove_host_veth_cmd="ip link del $$VETH_HOST"
    echo "Removing host veth: '$$remove_host_veth_cmd'"
    eval "$$remove_host_veth_cmd 2>/dev/null || true"

    # Remove ip rules
    remove_ip_rules_cmd="ip rule del from $$DOCKER_NET table $$ROUTING_TABLE"
    echo "Removing ip rules: '$$remove_ip_rules_cmd'"
    eval "$$remove_ip_rules_cmd 2>/dev/null || true"

    # Flush routing table if exists
    if ip route show table "$$ROUTING_TABLE" >/dev/null 2>&1; then
        flush_routing_table_cmd="ip route flush table $$ROUTING_TABLE"
        echo "Flushing routing table: '$$flush_routing_table_cmd'"
        eval "$$flush_routing_table_cmd"
    fi

    # Remove NAT rules on host
    remove_nat_rules_on_host_cmd="iptables -t nat -D POSTROUTING -s $$DOCKER_NET ! -d $$DOCKER_NET -j MASQUERADE"
    echo "Removing NAT rules on host: '$$remove_nat_rules_on_host_cmd'"
    eval "$$remove_nat_rules_on_host_cmd 2>/dev/null || true"

    # Remove NAT rules inside warp container
    remove_nat_rules_inside_warp_cmd="nsenter -t $$warp_pid -n iptables -t nat -D POSTROUTING -s $$DOCKER_NET -j MASQUERADE"
    echo "Removing NAT rules inside warp container: '$$remove_nat_rules_inside_warp_cmd'"
    eval "$$remove_nat_rules_inside_warp_cmd 2>/dev/null || true"
}

# Trap any error in the critical section
trap cleanup ERR

# --- Critical setup section ---
# Remove existing veth if present (handles restarts/crashes)
ip link del "$$VETH_HOST" 2>/dev/null || true

# Create veth pair
ip link add "$$VETH_HOST" type veth peer name "$$VETH_CONT"

# Move container end into warp namespace
ip link set "$$VETH_CONT" netns "$$warp_pid"

# Assign host end
ip addr add "$$HOST_VETH_IP/30" dev "$$VETH_HOST"
ip link set "$$VETH_HOST" up

# Assign container end
nsenter -t "$$warp_pid" -n ip addr add "$$CONT_VETH_IP/30" dev "$$VETH_CONT"
nsenter -t "$$warp_pid" -n ip link set "$$VETH_CONT" up
nsenter -t "$$warp_pid" -n sysctl -w net.ipv4.ip_forward=1
#nsenter -t "$$warp_pid" -n sysctl -w net.ipv4.conf.all.rp_filter=2
#nsenter -t "$$warp_pid" -n sysctl -w net.ipv4.conf.default.rp_filter=2

# NAT inside warp (add if not exists)
nsenter -t "$$warp_pid" -n iptables -t nat -C POSTROUTING -s "$$DOCKER_NET" -j MASQUERADE 2>/dev/null || \
nsenter -t "$$warp_pid" -n iptables -t nat -A POSTROUTING -s "$$DOCKER_NET" -j MASQUERADE

# Routing rules (del if exists, then add)
ip rule del from "$$DOCKER_NET" table "$$ROUTING_TABLE" 2>/dev/null || true
ip rule add from "$$DOCKER_NET" table "$$ROUTING_TABLE"

# Ensure routing table exists before flushing
if ip route show table "$$ROUTING_TABLE" >/dev/null 2>&1; then
    ip route flush table "$$ROUTING_TABLE"
fi
echo "Using bridge device: \`$$BRIDGE_NAME\`"

# Default route(s)
ip route add "$$DOCKER_NET" dev "$$BRIDGE_NAME" table "$$ROUTING_TABLE"  # Add network route using stripped bridge name
ip route add default via "$$CONT_VETH_IP" dev "$$VETH_HOST" table "$$ROUTING_TABLE"  # Add default route

# NAT on host (add if not exists)
iptables -t nat -C POSTROUTING -s "$$DOCKER_NET" ! -d "$$DOCKER_NET" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -s "$$DOCKER_NET" ! -d "$$DOCKER_NET" -j MASQUERADE

# Confirmation
echo "✅ Warp setup complete"
echo " Network: \`$$DOCKER_NETWORK_NAME\`"
echo " Veth host: \`$$VETH_HOST\` ($$HOST_VETH_IP)"
echo " Veth cont: \`$$VETH_CONT\` ($$CONT_VETH_IP)"
echo " Docker net: \`$$DOCKER_NET\`"
echo " Routing table: \`$$ROUTING_TABLE\` ($$ROUTING_TABLE_ID)"
EOF
        destination = "local/warp-nat-setup.sh"
        perms       = "0700"
      }

      # WARP Monitor Script template
      template {
        data = <<EOF
#!/usr/bin/env bash
set -euo pipefail

# Configurable via env
DOCKER_CMD="$${DOCKER_CMD:-docker -H $${DOCKER_HOST:-unix:///var/run/docker.sock}}"
CHECK_IMAGE="$${CHECK_IMAGE:-curlimages/curl}"   # image that includes curl
NETWORK="$${NETWORK:-warp-nat-net}"
SLEEP_INTERVAL="$${SLEEP_INTERVAL:-5}"                  # seconds between checks

# Healthcheck command to run inside the ephemeral container.
# This mirrors your warp-healthcheck logic: exit 0 when WARP active, nonzero otherwise.
HEALTHCHECK_INSIDE='sh -c "if curl -s --max-time 4 https://cloudflare.com/cdn-cgi/trace | grep -qE \"^warp=on|warp=plus$$\"; then echo WARP_OK && exit 0; else echo WARP_NOT_OK && exit 1; fi"'

echo "warp-monitor: checking WARP via ephemeral container on network '$${NETWORK}'."
echo "Using image: $${CHECK_IMAGE}"
prev_ok=1  # assume healthy initially so we don't run setup at startup

while true; do
  echo "[$$(date -u +'%Y-%m-%dT%H:%M:%SZ')] running health probe..."
  if $${DOCKER_CMD} run --rm --network "$${NETWORK}" --entrypoint sh "$${CHECK_IMAGE}" -c "$${HEALTHCHECK_INSIDE}"; then
    # check succeeded
    if [[ "$${prev_ok}" -eq 0 ]]; then
      echo "[$$(date -u +'%Y-%m-%dT%H:%M:%SZ')] health probe recovered -> marking healthy"
    fi
    prev_ok=1
  else
    echo "[$$(date -u +'%Y-%m-%dT%H:%M:%SZ')] health probe failed"
    # Only run the setup if this is a transition from healthy -> unhealthy
    if [[ "$${prev_ok}" -eq 1 ]]; then
      echo "[$$(date -u +'%Y-%m-%dT%H:%M:%SZ')] detected healthy->unhealthy transition; running /usr/local/bin/warp-nat-setup.sh"
      # Run setup, but do not let its failure kill the monitor. Log failures.
      if /usr/local/bin/warp-nat-setup.sh; then
        echo "[$$(date -u +'%Y-%m-%dT%H:%M:%SZ')] warp-nat-setup.sh completed"
      else
        echo "[$$(date -u +'%Y-%m-%dT%H:%M:%SZ')] warp-nat-setup.sh failed (exit nonzero)."
      fi
      # mark as unhealthy until probe says otherwise
      prev_ok=0
      # Wait a little before probing again to avoid tight loops
      sleep "$${SLEEP_INTERVAL}"
      # continue to next iteration (which will probe again and wait for recovery)
    else
      echo "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] still unhealthy; skipping additional setup runs"
    fi
  fi

  sleep "${SLEEP_INTERVAL}"
done
EOF
        destination = "local/warp-monitor.sh"
        perms       = "0700"
      }

      env {
        DOCKER_NETWORK_NAME  = "warp-nat-net"
        WARP_CONTAINER_NAME  = "warp-nat-gateway"
        HOST_VETH_IP         = "169.254.100.1"
        CONT_VETH_IP         = "169.254.100.2"
        ROUTING_TABLE        = "warp-nat-routing"
        VETH_HOST            = "veth-warp"
        CONTAINER_NAME       = "warp_router"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }

    # IP Checker WARP
    task "ip-checker-warp" {
      driver = "docker"

      config {
        image = "docker.io/alpine:latest"
        command = "/bin/sh"
        args = [
          "-c",
          "apk add --no-cache curl ipcalc && while true; do echo \"$(date): $(curl -s --max-time 4 ifconfig.me)\"; sleep 5; done"
        ]
        labels = {
          "com.docker.compose.project" = "warp-nat-routing-group"
          "com.docker.compose.service" = "ip-checker-warp"
        }
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "ip-checker-warp"
        tags = ["ip-checker-warp"]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "if curl -s https://cloudflare.com/cdn-cgi/trace | grep -qE '^warp=on|warp=plus$'; then echo \"Cloudflare WARP is active.\" && exit 0; else echo \"Cloudflare WARP is not active.\" && exit 1; fi"]
          interval = "10s"
          timeout  = "5s"
        }
      }
    }
  }
}

