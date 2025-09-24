# Authentik Authentication Services
# This job handles Authentik authentication and authorization services

job "authentik" {
  datacenters = ["dc1"]
  type        = "service"

  # Authentik PostgreSQL database
  group "authentik-postgresql" {
    count = 1

    network {
      mode = "bridge"
      port "postgres" {
        static = 5432
      }
    }

    service {
      name = "authentik-postgresql"
      port = "postgres"

      tags = ["internal", "database"]

      check {
        type     = "script"
        command  = "/usr/bin/pg_isready"
        args     = ["-d", "authentik", "-U", "authentik"]
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "authentik-postgresql" {
      driver = "docker"

      config {
        image = "postgres:16.3-alpine"
        ports = ["postgres"]
        volumes = [
          "${var.config_path}/authentik/postgresql:/var/lib/postgresql/data:rw"
        ]
      }

      env {
        POSTGRES_PASSWORD = "authentik"
        POSTGRES_USER     = "authentik"
        POSTGRES_DB       = "authentik"
        TZ                = var.tz
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  # Authentik server
  group "authentik-server" {
    count = 1

    network {
      mode = "bridge"
      port "authentik-server" {
        static = 9000
      }
    }

    service {
      name = "authentik-server"
      port = "authentik-server"

      tags = [
        "traefik.enable=true",
        "traefik.http.middlewares.gzip.compress=true",
        "traefik.http.routers.authentik-server.middlewares=gzip",
        "traefik.http.routers.authentik-server.service=authentik-server",
        "traefik.http.routers.authentik-server.rule=Host(`authentikserver.${var.domain}`)",
        "traefik.http.services.authentik-server.loadbalancer.server.port=9000"
      ]

      check {
        type     = "script"
        command  = "python3"
        args     = ["-c", "import socket; s=socket.socket(); s.settimeout(5); s.connect(('127.0.0.1', 9000)); s.close()"]
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "authentik-server" {
      driver = "docker"

      config {
        image = "ghcr.io/goauthentik/server:${var.authentik_tag}"
        ports = ["authentik-server"]
        volumes = [
          "${var.config_path}/authentik/media:/media:rw",
          "${var.config_path}/authentik/custom-templates:/templates:ro"
        ]
        command = ["server"]
      }

      env {
        AUTHENTIK_REDIS__HOST                    = var.redis_hostname
        AUTHENTIK_POSTGRESQL__HOST               = "authentik-postgresql"
        AUTHENTIK_POSTGRESQL__USER               = "authentik"
        AUTHENTIK_POSTGRESQL__NAME               = "authentik"
        AUTHENTIK_POSTGRESQL__PASSWORD           = "authentik"
        AUTHENTIK_SECRET_KEY                     = var.authentik_secret_key
        AUTHENTIK_ERROR_REPORTING__ENABLED       = "true"
        AUTHENTIK_EMAIL__HOST                    = "smtp.gmail.com"
        AUTHENTIK_EMAIL__PORT                    = "587"
        AUTHENTIK_EMAIL__USERNAME                = "boden.crouch@gmail.com"
        AUTHENTIK_EMAIL__PASSWORD                = var.gmail_app_password
        AUTHENTIK_EMAIL__USE_TLS                 = "true"
        AUTHENTIK_EMAIL__USE_SSL                 = "false"
        AUTHENTIK_EMAIL__TIMEOUT                 = "10"
        AUTHENTIK_EMAIL__FROM                    = "boden.crouch@gmail.com"
        AUTHENTIK_BOOTSTRAP__EMAIL               = "boden.crouch@gmail.com"
        AUTHENTIK_BOOTSTRAP__PASSWORD            = var.sudo_password
        AUTHENTIK_BOOTSTRAP_EMAIL                = "boden.crouch@gmail.com"
        AUTHENTIK_BOOTSTRAP_PASSWORD             = var.sudo_password
        TZ                                       = var.tz
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  # Authentik worker
  group "authentik-worker" {
    count = 1

    network {
      mode = "bridge"
      port "authentik-worker" {
        static = 9001
      }
    }

    service {
      name = "authentik-worker"
      port = "authentik-worker"

      tags = ["internal"]

      check {
        type     = "script"
        command  = "python3"
        args     = ["-c", "import socket; s=socket.socket(); s.settimeout(5); s.connect(('127.0.0.1', 9001)); s.close()"]
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "authentik-worker" {
      driver = "docker"

      config {
        image = "ghcr.io/goauthentik/server:${var.authentik_tag}"
        ports = ["authentik-worker"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:rw",
          "${var.config_path}/authentik/media:/media:rw",
          "${var.config_path}/authentik/certs:/certs:rw",
          "${var.config_path}/authentik/custom-templates:/templates:ro"
        ]
        command = ["worker"]
        user    = "root"
      }

      env {
        AUTHENTIK_REDIS__HOST                    = var.redis_hostname
        AUTHENTIK_POSTGRESQL__HOST               = "authentik-postgresql"
        AUTHENTIK_POSTGRESQL__USER               = "authentik"
        AUTHENTIK_POSTGRESQL__NAME               = "authentik"
        AUTHENTIK_POSTGRESQL__PASSWORD           = "authentik"
        AUTHENTIK_SECRET_KEY                     = var.authentik_secret_key
        AUTHENTIK_ERROR_REPORTING__ENABLED       = "true"
        AUTHENTIK_EMAIL__HOST                    = "smtp.gmail.com"
        AUTHENTIK_EMAIL__PORT                    = "587"
        AUTHENTIK_EMAIL__USERNAME                = "boden.crouch@gmail.com"
        AUTHENTIK_EMAIL__PASSWORD                = var.gmail_app_password
        AUTHENTIK_EMAIL__USE_TLS                 = "true"
        AUTHENTIK_EMAIL__USE_SSL                 = "false"
        AUTHENTIK_EMAIL__TIMEOUT                 = "10"
        AUTHENTIK_EMAIL__FROM                    = "boden.crouch@gmail.com"
        AUTHENTIK_BOOTSTRAP__EMAIL               = "boden.crouch@gmail.com"
        AUTHENTIK_BOOTSTRAP__PASSWORD            = var.sudo_password
        AUTHENTIK_BOOTSTRAP_EMAIL                = "boden.crouch@gmail.com"
        AUTHENTIK_BOOTSTRAP_PASSWORD             = var.sudo_password
        TZ                                       = var.tz
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }
}
