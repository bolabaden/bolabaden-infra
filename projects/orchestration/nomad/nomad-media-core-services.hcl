job "media-stack-core-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 70

  # Core Media Services Group
  group "media-core" {
    count = 1

    network {
      mode = "bridge"
      port "plex" {
        to = 32400
      }
      port "jellyfin" {
        to = 8096
      }
      port "riven" {
        to = 3001
      }
      port "riven_frontend" {
        to = 3000
      }
      port "overseerr" {
        to = 5055
      }
      port "jellyseerr" {
        to = 5055
      }
      port "jellystat" {
        to = 3000
      }
    }

    task "plex" {
      driver = "docker"

      config {
        image = "linuxserver/plex:latest"
        hostname = "plex"
        ports = ["plex"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/plex:/config",
          "/mnt/user/movies:/movies",
          "/mnt/user/tv:/tv",
          "/mnt/user/anime:/anime",
          "${NOMAD_META_CONFIG_PATH}/plex/transcode:/transcode"
        ]
        devices = [
          "/dev/dri:/dev/dri"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        VERSION = "docker"
        PLEX_CLAIM = "${NOMAD_META_PLEX_CLAIM}"
        ADVERTISE_IP = "https://plex.${NOMAD_META_DOMAIN}:443"
        PLEX_PREFERENCE_2 = "FSEventLibraryPartialScanEnabled=1"
        PLEX_PREFERENCE_3 = "FSEventLibraryUpdatesEnabled=1"
        PLEX_PREFERENCE_4 = "TranscoderPhotoFileSizeLimitMiB=5"
        PLEX_PREFERENCE_7 = "autoEmptyTrash=0"
        PLEX_PREFERENCE_8 = "BackgroundTranscodeLowPriority=1"
        PLEX_PREFERENCE_9 = "LongRunningJobThreads=1"
        PLEX_PREFERENCE_11 = "RelayEnabled=0"
        PLEX_PREFERENCE_12 = "TranscoderTempDirectory=/transcode"
        PLEX_PREFERENCE_13 = "MinutesAllowedPaused=30"
        PLEX_PREFERENCE_14 = "GenerateIntroMarkerBehavior=scheduled"
        PLEX_PREFERENCE_16 = "ButlerEndHour=10"
        PLEX_PREFERENCE_17 = "ButlerTaskDeepMediaAnalysis=0"
        PLEX_PREFERENCE_18 = "ButlerTaskUpgradeMediaAnalysis=0"
      }

      resources {
        cpu    = 2000
        memory = 4096
      }

      service {
        name = "plex"
        port = "plex"
        
        check {
          type     = "http"
          path     = "/web/index.html"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.plex.rule=Host(`plex.${NOMAD_META_DOMAIN}`) || Host(`plex.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`plex.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.plex.loadbalancer.server.port=32400",
          "homepage.group=Media Servers",
          "homepage.name=Plex",
          "homepage.icon=plex.png",
          "homepage.href=https://plex.${NOMAD_META_DOMAIN}/",
          "homepage.description=Media server for movies, TV shows, and music"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "jellyfin" {
      driver = "docker"

      config {
        image = "linuxserver/jellyfin:latest"
        hostname = "jellyfin"
        ports = ["jellyfin"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/jellyfin:/config",
          "/mnt/user/movies:/movies",
          "/mnt/user/tv:/tv",
          "/mnt/user/anime:/anime",
          "${NOMAD_META_CONFIG_PATH}/jellyfin/cache:/cache"
        ]
        devices = [
          "/dev/dri:/dev/dri"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        JELLYFIN_PublishedServerUrl = "https://jellyfin.${NOMAD_META_DOMAIN}"
      }

      resources {
        cpu    = 2000
        memory = 4096
      }

      service {
        name = "jellyfin"
        port = "jellyfin"
        
        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jellyfin.rule=Host(`jellyfin.${NOMAD_META_DOMAIN}`) || Host(`jellyfin.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`jellyfin.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.jellyfin.loadbalancer.server.port=8096",
          "homepage.group=Media Servers",
          "homepage.name=Jellyfin",
          "homepage.icon=jellyfin.png",
          "homepage.href=https://jellyfin.${NOMAD_META_DOMAIN}/",
          "homepage.description=Free software media server"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "riven" {
      driver = "docker"

      config {
        image = "spoked/riven:latest"
        hostname = "riven"
        ports = ["riven"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/riven:/riven/data",
          "/mnt/user/movies:/mnt/movies",
          "/mnt/user/tv:/mnt/tv",
          "/mnt/user/anime:/mnt/anime",
          "/mnt/user/downloads:/mnt/downloads",
          "${NOMAD_META_CONFIG_PATH}/riven/logs:/riven/data/logs"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        RIVEN_FORCE_ENV = "true"
      }

      resources {
        cpu    = 1000
        memory = 2048
      }

      service {
        name = "riven"
        port = "riven"
        
        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.riven.middlewares=nginx-auth@file",
          "traefik.http.routers.riven.rule=Host(`riven.${NOMAD_META_DOMAIN}`) || Host(`riven.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`riven.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.riven.loadbalancer.server.port=3001",
          "homepage.group=Media Management",
          "homepage.name=Riven",
          "homepage.icon=riven.png",
          "homepage.href=https://riven.${NOMAD_META_DOMAIN}/",
          "homepage.description=Next-generation media management system"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "riven-frontend" {
      driver = "docker"

      config {
        image = "spoked/riven-frontend:latest"
        hostname = "riven-frontend"
        ports = ["riven_frontend"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/riven-frontend:/app/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        ORIGIN = "https://riven-frontend.${NOMAD_META_DOMAIN}"
        BACKEND_URL = "http://riven:3001"
        DIALECT = "postgres"
        DATABASE_URL = "postgresql://riven:riven@riven-db:5432/riven"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "riven-frontend"
        port = "riven_frontend"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.riven-frontend.middlewares=nginx-auth@file",
          "traefik.http.routers.riven-frontend.rule=Host(`riven-frontend.${NOMAD_META_DOMAIN}`) || Host(`riven-frontend.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`riven-frontend.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.riven-frontend.loadbalancer.server.port=3000",
          "homepage.group=Media Management",
          "homepage.name=Riven Frontend",
          "homepage.icon=riven.png",
          "homepage.href=https://riven-frontend.${NOMAD_META_DOMAIN}/",
          "homepage.description=Riven frontend interface"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "overseerr" {
      driver = "docker"

      config {
        image = "sctx/overseerr:latest"
        hostname = "overseerr"
        ports = ["overseerr"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/overseerr:/app/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        LOG_LEVEL = "debug"
        PORT = "5055"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "overseerr"
        port = "overseerr"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.overseerr.rule=Host(`overseerr.${NOMAD_META_DOMAIN}`) || Host(`overseerr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`overseerr.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.overseerr.loadbalancer.server.port=5055",
          "homepage.group=Media Management",
          "homepage.name=Overseerr",
          "homepage.icon=overseerr.png",
          "homepage.href=https://overseerr.${NOMAD_META_DOMAIN}/",
          "homepage.description=Request management and media discovery tool"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "jellyseerr" {
      driver = "docker"

      config {
        image = "fallenbagel/jellyseerr:latest"
        hostname = "jellyseerr"
        ports = ["jellyseerr"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/jellyseerr:/app/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        LOG_LEVEL = "debug"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "jellyseerr"
        port = "jellyseerr"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jellyseerr.rule=Host(`jellyseerr.${NOMAD_META_DOMAIN}`) || Host(`jellyseerr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`jellyseerr.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.jellyseerr.loadbalancer.server.port=5055",
          "homepage.group=Media Management",
          "homepage.name=Jellyseerr",
          "homepage.icon=jellyseerr.png",
          "homepage.href=https://jellyseerr.${NOMAD_META_DOMAIN}/",
          "homepage.description=Request management for Jellyfin"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "jellystat" {
      driver = "docker"

      config {
        image = "cyfershepard/jellystat:latest"
        hostname = "jellystat"
        ports = ["jellystat"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/jellystat:/app/backend/backup-data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        POSTGRES_DB = "jfstat"
        POSTGRES_USER = "postgres"
        POSTGRES_PASSWORD = "${NOMAD_META_JELLYSTAT_DB_PASSWORD}"
        JWT_SECRET = "${NOMAD_META_JELLYSTAT_JWT_SECRET}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "jellystat"
        port = "jellystat"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jellystat.middlewares=nginx-auth@file",
          "traefik.http.routers.jellystat.rule=Host(`jellystat.${NOMAD_META_DOMAIN}`) || Host(`jellystat.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`jellystat.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.jellystat.loadbalancer.server.port=3000",
          "homepage.group=Monitoring",
          "homepage.name=Jellystat",
          "homepage.icon=jellystat.png",
          "homepage.href=https://jellystat.${NOMAD_META_DOMAIN}/",
          "homepage.description=Jellyfin statistics and monitoring"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }

  # Kometa and Maintenance Group
  group "media-maintenance" {
    count = 1

    network {
      mode = "bridge"
      port "kometa" {
        to = 8080
      }
    }

    task "kometa" {
      driver = "docker"

      config {
        image = "kometateam/kometa:latest"
        hostname = "kometa"
        ports = ["kometa"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/kometa:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        KOMETA_CONFIG = "/config/config.yml"
        KOMETA_TIME = "03:00"
        KOMETA_RUN = "false"
        KOMETA_TEST = "false"
        KOMETA_NO_MISSING = "false"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "kometa"
        port = "kometa"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.kometa.middlewares=nginx-auth@file",
          "traefik.http.routers.kometa.rule=Host(`kometa.${NOMAD_META_DOMAIN}`) || Host(`kometa.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`kometa.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.kometa.loadbalancer.server.port=8080",
          "homepage.group=Media Management",
          "homepage.name=Kometa",
          "homepage.icon=kometa.png",
          "homepage.href=https://kometa.${NOMAD_META_DOMAIN}/",
          "homepage.description=Plex Meta Manager for automated collection management"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }

  # Variable definitions
  meta {
    # Common environment variables
    TZ = "America/Chicago"
    PUID = "1002"
    PGID = "988"
    
    # Paths
    CONFIG_PATH = "./configs"
    
    # Domain configuration
    DOMAIN = "example.com"
    DUCKDNS_SUBDOMAIN = "example"
    TS_HOSTNAME = "example"
    
    # Plex configuration
    PLEX_CLAIM = ""
    
    # Jellystat configuration
    JELLYSTAT_DB_PASSWORD = ""
    JELLYSTAT_JWT_SECRET = ""
  }
} 