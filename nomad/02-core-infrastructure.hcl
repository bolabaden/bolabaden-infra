# Core Infrastructure Services
# This job handles the essential infrastructure services including Traefik, Redis, and databases
# Network isolation is handled through Nomad's service groups and networking policies

job "core-infrastructure" {
  datacenters = ["dc1"]
  type        = "service"

  # Traefik reverse proxy and load balancer
  group "traefik" {
    count = 1

    network {
      mode = "bridge"
      port "web" {
        static = 80
      }
      port "websecure" {
        static = 443
      }
      port "api" {
        static = 8080
      }
    }

    service {
      name = "traefik"
      port = "web"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.traefik.rule=Host(`traefik.${var.domain}`)",
        "traefik.http.services.traefik.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/ping"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "traefik:v3.1"
        ports = ["web", "websecure", "api"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro",
          "${var.config_path}/traefik:/etc/traefik:ro",
          "${var.config_path}/traefik/acme:/etc/traefik/acme:rw"
        ]
        command = [
          "--api.dashboard=true",
          "--api.insecure=true",
          "--providers.docker=true",
          "--providers.docker.exposedByDefault=false",
          "--entryPoints.web.address=:80",
          "--entryPoints.websecure.address=:443",
          "--certificatesResolvers.letsencrypt.acme.tlsChallenge=true",
          "--certificatesResolvers.letsencrypt.acme.email=boden.crouch@gmail.com",
          "--certificatesResolvers.letsencrypt.acme.storage=/etc/traefik/acme/acme.json",
          "--global.sendAnonymousUsage=false"
        ]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }

  # Redis cache and message broker
  group "redis" {
    count = 1

    network {
      mode = "bridge"
      port "redis" {
        static = 6379
      }
    }

    service {
      name = "redis"
      port = "redis"

      tags = ["internal"]

      check {
        type     = "script"
        command  = "/usr/local/bin/redis-cli"
        args     = ["ping"]
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:7-alpine"
        ports = ["redis"]
        volumes = [
          "${var.config_path}/redis:/data:rw"
        ]
        command = ["redis-server", "--appendonly", "yes"]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }

  # MongoDB database
  group "mongodb" {
    count = 1

    network {
      mode = "bridge"
      port "mongodb" {
        static = 27017
      }
    }

    service {
      name = "mongodb"
      port = "mongodb"

      tags = ["internal", "database"]

      check {
        type     = "script"
        command  = "/usr/bin/mongosh"
        args     = ["127.0.0.1:27017/test", "--quiet", "--eval", "db.runCommand('ping').ok"]
        interval = "30s"
        timeout  = "10s"
      }
    }

    task "mongodb" {
      driver = "docker"

      config {
        image = "mongo:latest"
        ports = ["mongodb"]
        volumes = [
          "${var.config_path}/mongodb:/data/db:rw"
        ]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 500
        memory = 1024
      }
    }
  }

  # Portainer container management
  group "portainer" {
    count = 1

    network {
      mode = "bridge"
      port "portainer" {
        static = 9000
      }
    }

    service {
      name = "portainer"
      port = "portainer"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.portainer.rule=Host(`portainer.${var.domain}`)",
        "traefik.http.services.portainer.loadBalancer.server.port=9000"
      ]

      check {
        type     = "http"
        path     = "/api/status"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "portainer" {
      driver = "docker"

      config {
        image = "portainer/portainer-ce:latest"
        ports = ["portainer"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro",
          "${var.config_path}/portainer:/data:rw"
        ]
        command = [
          "--http-enabled"
        ]
      }

      template {
        data = <<-EOF
        ${var.sudo_password}
        EOF
        destination = "tmp/portainer_password"
        perms       = "0400"
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 200
        memory = 512
      }
    }
  }

  # Docker socket proxy for secure Docker API access
  group "dockerproxy" {
    count = 1

    network {
      mode = "bridge"
      port "dockerproxy" {
        static = 2375
      }
    }

    service {
      name = "dockerproxy"
      port = "dockerproxy"

      tags = ["internal"]

      check {
        type     = "tcp"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "dockerproxy" {
      driver = "docker"

      config {
        image = "tecnativa/docker-socket-proxy"
        ports = ["dockerproxy"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ]
      }

      env {
        AUTH           = "1"
        BUILD          = "1"
        COMMIT         = "1"
        CONFIGS        = "1"
        CONTAINERS     = "1"
        DISTRIBUTION   = "1"
        EVENTS         = "1"
        EXEC           = "1"
        GRPC           = "1"
        IMAGES         = "1"
        NETWORKS       = "1"
        NODES          = "1"
        PLUGINS        = "1"
        POST           = "1"
        SECRETS        = "1"
        SERVICES       = "1"
        SESSION        = "1"
        SWARM          = "1"
        SYSTEM         = "1"
        TASKS          = "1"
        VOLUMES        = "1"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}