# Nomad job equivalent to compose/docker-compose.firecrawl.yml
# Extracted from docker-compose.nomad.hcl
# Variables are loaded from ../variables.nomad.hcl via -var-file
# This matches the include structure in docker-compose.yml

job "docker-compose.firecrawl" {
  datacenters = ["dc1"]
  type        = "service"

  # Note: Constraint removed - nodes may not expose consul.version attribute
  # Consul integration is verified via service discovery, not version constraint

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
        cpu        = 2000  # Reduced from 4000 to fit on node with other services
        memory     = 2048  # Reduced from 4096 to fit on node with other services
        memory_max = 4096  # Reduced from 8192 to fit on node with other services
      
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
}
