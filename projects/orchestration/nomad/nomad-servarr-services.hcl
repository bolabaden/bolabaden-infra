job "media-stack-servarr-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 60

  # Servarr Services Group
  group "servarr-services" {
    count = 1

    network {
      mode = "bridge"
      port "radarr" {
        to = 7878
      }
      port "sonarr" {
        to = 8989
      }
      port "bazarr" {
        to = 6767
      }
      port "overseerr" {
        to = 5055
      }
      port "kometa" {
        to = 8080
      }
      port "recyclarr" {
        to = 8080
      }
      port "nzbhydra2" {
        to = 5076
      }
    }

    task "radarr" {
      driver = "docker"

      config {
        image = "linuxserver/radarr:latest"
        hostname = "radarr"
        ports = ["radarr"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/radarr:/config",
          "/mnt/user/movies:/movies",
          "/mnt/user/downloads:/downloads"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "radarr"
        port = "radarr"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.radarr.middlewares=nginx-auth@file",
          "traefik.http.routers.radarr.rule=Host(`radarr.${NOMAD_META_DOMAIN}`) || Host(`radarr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`radarr.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.radarr.loadbalancer.server.port=7878",
          "homepage.group=Media Management",
          "homepage.name=Radarr",
          "homepage.icon=radarr.png",
          "homepage.href=https://radarr.${NOMAD_META_DOMAIN}/",
          "homepage.description=Movie collection manager for Usenet and BitTorrent users"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "sonarr" {
      driver = "docker"

      config {
        image = "linuxserver/sonarr:latest"
        hostname = "sonarr"
        ports = ["sonarr"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/sonarr:/config",
          "/mnt/user/tv:/tv",
          "/mnt/user/downloads:/downloads"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "sonarr"
        port = "sonarr"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.sonarr.middlewares=nginx-auth@file",
          "traefik.http.routers.sonarr.rule=Host(`sonarr.${NOMAD_META_DOMAIN}`) || Host(`sonarr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`sonarr.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.sonarr.loadbalancer.server.port=8989",
          "homepage.group=Media Management",
          "homepage.name=Sonarr",
          "homepage.icon=sonarr.png",
          "homepage.href=https://sonarr.${NOMAD_META_DOMAIN}/",
          "homepage.description=TV series collection manager for Usenet and BitTorrent users"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "bazarr" {
      driver = "docker"

      config {
        image = "linuxserver/bazarr:latest"
        hostname = "bazarr"
        ports = ["bazarr"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/bazarr:/config",
          "/mnt/user/movies:/movies",
          "/mnt/user/tv:/tv"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "bazarr"
        port = "bazarr"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.bazarr.middlewares=nginx-auth@file",
          "traefik.http.routers.bazarr.rule=Host(`bazarr.${NOMAD_META_DOMAIN}`) || Host(`bazarr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`bazarr.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.bazarr.loadbalancer.server.port=6767",
          "homepage.group=Media Management",
          "homepage.name=Bazarr",
          "homepage.icon=bazarr.png",
          "homepage.href=https://bazarr.${NOMAD_META_DOMAIN}/",
          "homepage.description=Subtitle management for Sonarr and Radarr"
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
          "homepage.description=Plex Meta Manager for automated collection and metadata management"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "recyclarr" {
      driver = "docker"

      config {
        image = "ghcr.io/recyclarr/recyclarr:latest"
        hostname = "recyclarr"
        ports = ["recyclarr"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/recyclarr:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        CRON_SCHEDULE = "0 */6 * * *"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "recyclarr"
        port = "recyclarr"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.recyclarr.middlewares=nginx-auth@file",
          "traefik.http.routers.recyclarr.rule=Host(`recyclarr.${NOMAD_META_DOMAIN}`) || Host(`recyclarr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`recyclarr.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.recyclarr.loadbalancer.server.port=8080",
          "homepage.group=Media Management",
          "homepage.name=Recyclarr",
          "homepage.icon=recyclarr.png",
          "homepage.href=https://recyclarr.${NOMAD_META_DOMAIN}/",
          "homepage.description=Automatically sync TRaSH guides to Sonarr and Radarr"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "nzbhydra2" {
      driver = "docker"

      config {
        image = "linuxserver/nzbhydra2:latest"
        hostname = "nzbhydra2"
        ports = ["nzbhydra2"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/nzbhydra2:/config",
          "/mnt/user/downloads:/downloads"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "nzbhydra2"
        port = "nzbhydra2"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.nzbhydra2.middlewares=nginx-auth@file",
          "traefik.http.routers.nzbhydra2.rule=Host(`nzbhydra2.${NOMAD_META_DOMAIN}`) || Host(`nzbhydra2.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`nzbhydra2.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.nzbhydra2.loadbalancer.server.port=5076",
          "homepage.group=Indexers",
          "homepage.name=NZBHydra2",
          "homepage.icon=nzbhydra2.png",
          "homepage.href=https://nzbhydra2.${NOMAD_META_DOMAIN}/",
          "homepage.description=Meta search for NZB indexers"
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
    UMASK = "002"
    
    # Paths
    CONFIG_PATH = "./configs"
    
    # Domain configuration
    DOMAIN = "example.com"
    DUCKDNS_SUBDOMAIN = "example"
    TS_HOSTNAME = "example"
  }
} 