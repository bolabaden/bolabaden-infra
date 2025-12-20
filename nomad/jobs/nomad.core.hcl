# Nomad job equivalent to docker-compose.yml (main file services)
# Extracted from nomad.hcl
# Variables are loaded from ../variables.nomad.hcl via -var-file
# This matches the include structure in docker-compose.yml

job "docker-compose.core" {
  datacenters = ["dc1"]
  type        = "service"

  # Note: Constraint removed - nodes may not expose consul.version attribute
  # Consul integration is verified via service discovery, not version constraint

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
          "traefik.http.routers.error-router.middlewares" = "error-mw@docker",
          # Main website router
          "traefik.http.routers.bolabaden-nextjs.rule" = "Host(`${var.domain}`) || Host(`${node.unique.name}.${var.domain}`)"
          "traefik.http.routers.bolabaden-nextjs.service" = "bolabaden-nextjs"
          "traefik.http.routers.bolabaden-nextjs.middlewares" = "error-mw@docker"
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
        # Service registered in Consul for service discovery only
        # Traefik configuration is handled by file provider (matches docker-compose.coolify-proxy.yml)
        # This ensures 1:1 parity - no Consul Catalog registration, only file provider
        name = "bolabaden-nextjs"
        port = "bolabaden_nextjs"
        tags = [
          # Only non-Traefik labels to avoid Consul Catalog registration
          # Traefik router/service defined in file provider (nomad.coolify-proxy.hcl)
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
DOZZLE_REMOTE_HOST="tcp://dockerproxy-ro:2375"
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
}
