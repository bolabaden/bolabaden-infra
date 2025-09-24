# Stremio Media Stack
# This job handles the complete Stremio media streaming stack including indexers and downloaders

job "stremio" {
  datacenters = ["dc1"]
  type        = "service"

  # Stremio application
  group "stremio" {
    count = 1

    network {
      mode = "bridge"
      port "stremio" {
        static = 11470
      }
    }

    service {
      name = "stremio"
      port = "stremio"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.stremio.rule=Host(`stremio.${var.domain}`)",
        "traefik.http.services.stremio.loadbalancer.server.port=11470"
      ]

      check {
        type     = "http"
        path     = "/"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "stremio" {
      driver = "docker"

      config {
        image = "stremio/stremio:latest"
        ports = ["stremio"]
        volumes = [
          "${var.config_path}/stremio:/root/.stremio-server:rw"
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

  # FlareSolverr for bypassing Cloudflare protection
  group "flaresolverr" {
    count = 1

    network {
      mode = "bridge"
      port "flaresolverr" {
        static = 8191
      }
    }

    service {
      name = "flaresolverr"
      port = "flaresolverr"

      tags = ["internal"]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "flaresolverr" {
      driver = "docker"

      config {
        image = "ghcr.io/flaresolverr/flaresolverr:latest"
        ports = ["flaresolverr"]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  # Jackett torrent indexer
  group "jackett" {
    count = 1

    network {
      mode = "bridge"
      port "jackett" {
        static = 9117
      }
    }

    service {
      name = "jackett"
      port = "jackett"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.jackett.rule=Host(`jackett.${var.domain}`)",
        "traefik.http.services.jackett.loadbalancer.server.port=9117"
      ]

      check {
        type     = "http"
        path     = "/healthz"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "jackett" {
      driver = "docker"

      config {
        image = "linuxserver/jackett:latest"
        ports = ["jackett"]
        volumes = [
          "${var.config_path}/jackett:/config:rw"
        ]
      }

      env {
        TZ   = var.tz
        PUID = var.puid
        PGID = var.pgid
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  # Prowlarr indexer manager
  group "prowlarr" {
    count = 1

    network {
      mode = "bridge"
      port "prowlarr" {
        static = 9696
      }
    }

    service {
      name = "prowlarr"
      port = "prowlarr"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prowlarr.rule=Host(`prowlarr.${var.domain}`)",
        "traefik.http.services.prowlarr.loadbalancer.server.port=9696"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "prowlarr" {
      driver = "docker"

      config {
        image = "linuxserver/prowlarr:latest"
        ports = ["prowlarr"]
        volumes = [
          "${var.config_path}/prowlarr:/config:rw"
        ]
      }

      env {
        TZ   = var.tz
        PUID = var.puid
        PGID = var.pgid
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  # AIOStreams for streaming aggregation
  group "aiostreams" {
    count = 1

    network {
      mode = "bridge"
      port "aiostreams" {
        static = 8080
      }
    }

    service {
      name = "aiostreams"
      port = "aiostreams"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.aiostreams.rule=Host(`aiostreams.${var.domain}`)",
        "traefik.http.services.aiostreams.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "aiostreams" {
      driver = "docker"

      config {
        image = "aiostreams/aiostreams:latest"
        ports = ["aiostreams"]
        volumes = [
          "${var.config_path}/aiostreams:/app/data:rw"
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

  # Comet downloader
  group "comet" {
    count = 1

    network {
      mode = "bridge"
      port "comet" {
        static = 8080
      }
    }

    service {
      name = "comet"
      port = "comet"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.comet.rule=Host(`comet.${var.domain}`)",
        "traefik.http.services.comet.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "comet" {
      driver = "docker"

      config {
        image = "comet/comet:latest"
        ports = ["comet"]
        volumes = [
          "${var.config_path}/comet:/app/data:rw"
        ]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  # MediaFusion for media discovery
  group "mediafusion" {
    count = 1

    network {
      mode = "bridge"
      port "mediafusion" {
        static = 8080
      }
    }

    service {
      name = "mediafusion"
      port = "mediafusion"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.mediafusion.rule=Host(`mediafusion.${var.domain}`)",
        "traefik.http.services.mediafusion.loadbalancer.server.port=8080"
      ]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "mediafusion" {
      driver = "docker"

      config {
        image = "mediafusion/mediafusion:latest"
        ports = ["mediafusion"]
        volumes = [
          "${var.config_path}/mediafusion:/app/data:rw"
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

  # MediaFlow Proxy for content delivery
  group "mediaflow-proxy" {
    count = 1

    network {
      mode = "bridge"
      port "mediaflow-proxy" {
        static = 8080
      }
    }

    service {
      name = "mediaflow-proxy"
      port = "mediaflow-proxy"

      tags = ["internal"]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "mediaflow-proxy" {
      driver = "docker"

      config {
        image = "mediaflow/proxy:latest"
        ports = ["mediaflow-proxy"]
        volumes = [
          "${var.config_path}/mediaflow-proxy:/app/config:rw"
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

  # StremThru for streaming optimization
  group "stremthru" {
    count = 1

    network {
      mode = "bridge"
      port "stremthru" {
        static = 8080
      }
    }

    service {
      name = "stremthru"
      port = "stremthru"

      tags = ["internal"]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "stremthru" {
      driver = "docker"

      config {
        image = "stremthru/stremthru:latest"
        ports = ["stremthru"]
        volumes = [
          "${var.config_path}/stremthru:/app/data:rw"
        ]
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu    = 300
        memory = 512
      }
    }
  }

  # RClone for cloud storage integration
  group "rclone" {
    count = 1

    network {
      mode = "bridge"
      port "rclone" {
        static = 8080
      }
    }

    service {
      name = "rclone"
      port = "rclone"

      tags = ["internal"]

      check {
        type     = "http"
        path     = "/health"
        interval = "30s"
        timeout  = "5s"
      }
    }

    task "rclone" {
      driver = "docker"

      config {
        image = "rclone/rclone:latest"
        ports = ["rclone"]
        volumes = [
          "${var.config_path}/rclone:/config:rw"
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
}
