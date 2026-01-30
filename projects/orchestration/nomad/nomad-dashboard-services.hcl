job "media-stack-dashboard-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 50

  # Dashboard Services Group
  group "dashboard-services" {
    count = 1

    network {
      mode = "bridge"
      port "homer" {
        to = 8080
      }
      port "homepage" {
        to = 3000
      }
      port "wizarr" {
        to = 5690
      }
      port "flixio" {
        to = 8080
      }
      port "blackhole" {
        to = 8080
      }
    }

    task "homer" {
      driver = "docker"

      config {
        image = "b4bz/homer:latest"
        hostname = "homer"
        ports = ["homer"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/homer:/www/assets"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "homer"
        port = "homer"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.homer.rule=Host(`homer.${NOMAD_META_DOMAIN}`) || Host(`homer.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`homer.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.homer.loadbalancer.server.port=8080",
          "homepage.group=Dashboards",
          "homepage.name=Homer",
          "homepage.icon=homer.png",
          "homepage.href=https://homer.${NOMAD_META_DOMAIN}/",
          "homepage.description=Static dashboard for your services"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "homepage" {
      driver = "docker"

      config {
        image = "ghcr.io/gethomepage/homepage:latest"
        hostname = "homepage"
        ports = ["homepage"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/homepage:/app/config",
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        HOMEPAGE_VAR_TITLE = "Media Stack Dashboard"
        HOMEPAGE_VAR_SEARCH_PROVIDER = "duckduckgo"
        HOMEPAGE_VAR_HEADER_STYLE = "clean"
        HOMEPAGE_VAR_WEATHER_CITY = "${NOMAD_META_HOMEPAGE_WEATHER_CITY}"
        HOMEPAGE_VAR_WEATHER_LAT = "${NOMAD_META_HOMEPAGE_WEATHER_LAT}"
        HOMEPAGE_VAR_WEATHER_LONG = "${NOMAD_META_HOMEPAGE_WEATHER_LONG}"
        HOMEPAGE_VAR_WEATHER_UNIT = "metric"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "homepage"
        port = "homepage"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.homepage.rule=Host(`homepage.${NOMAD_META_DOMAIN}`) || Host(`homepage.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`homepage.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.homepage.loadbalancer.server.port=3000",
          "homepage.group=Dashboards",
          "homepage.name=Homepage",
          "homepage.icon=homepage.png",
          "homepage.href=https://homepage.${NOMAD_META_DOMAIN}/",
          "homepage.description=Modern dashboard with service integration"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "wizarr" {
      driver = "docker"

      config {
        image = "ghcr.io/wizarrrr/wizarr:latest"
        hostname = "wizarr"
        ports = ["wizarr"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/wizarr:/data/database"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        APP_URL = "https://wizarr.${NOMAD_META_DOMAIN}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "wizarr"
        port = "wizarr"
        
        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.wizarr.rule=Host(`wizarr.${NOMAD_META_DOMAIN}`) || Host(`wizarr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`wizarr.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.wizarr.loadbalancer.server.port=5690",
          "homepage.group=User Management",
          "homepage.name=Wizarr",
          "homepage.icon=wizarr.png",
          "homepage.href=https://wizarr.${NOMAD_META_DOMAIN}/",
          "homepage.description=User invitation and management for Plex/Jellyfin"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "flixio" {
      driver = "docker"

      config {
        image = "ghcr.io/elfhosted/flixio:latest"
        hostname = "flixio"
        ports = ["flixio"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/flixio:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "flixio"
        port = "flixio"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.flixio.middlewares=nginx-auth@file",
          "traefik.http.routers.flixio.rule=Host(`flixio.${NOMAD_META_DOMAIN}`) || Host(`flixio.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`flixio.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.flixio.loadbalancer.server.port=8080",
          "homepage.group=Media Discovery",
          "homepage.name=Flixio",
          "homepage.icon=flixio.png",
          "homepage.href=https://flixio.${NOMAD_META_DOMAIN}/",
          "homepage.description=Media discovery and recommendation engine"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "blackhole" {
      driver = "docker"

      config {
        image = "ghcr.io/elfhosted/blackhole:latest"
        hostname = "blackhole"
        ports = ["blackhole"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/blackhole:/config",
          "/mnt/user/downloads/blackhole:/downloads"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        BLACKHOLE_WATCH_DIRECTORY = "/downloads"
        BLACKHOLE_CLEANUP_INTERVAL = "300"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "blackhole"
        port = "blackhole"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.blackhole.middlewares=nginx-auth@file",
          "traefik.http.routers.blackhole.rule=Host(`blackhole.${NOMAD_META_DOMAIN}`) || Host(`blackhole.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`blackhole.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.blackhole.loadbalancer.server.port=8080",
          "homepage.group=Download Management",
          "homepage.name=Blackhole",
          "homepage.icon=blackhole.png",
          "homepage.href=https://blackhole.${NOMAD_META_DOMAIN}/",
          "homepage.description=Download directory monitor and cleanup"
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

  # Stremio Jackett Group
  group "stremio-jackett" {
    count = 1

    network {
      mode = "bridge"
      port "stremio_jackett" {
        to = 3000
      }
      port "riven_setup" {
        to = 8080
      }
    }

    task "stremio-jackett" {
      driver = "docker"

      config {
        image = "sleeyax/stremio-jackett-addon:latest"
        hostname = "stremio-jackett"
        ports = ["stremio_jackett"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/stremio-jackett:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        JACKETT_URL = "http://jackett:9117"
        JACKETT_API_KEY = "${NOMAD_META_JACKETT_API_KEY}"
        ADDON_NAME = "Jackett Addon"
        ADDON_ID = "stremio-jackett.${NOMAD_META_DOMAIN}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "stremio-jackett"
        port = "stremio_jackett"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.stremio-jackett.rule=Host(`stremio-jackett.${NOMAD_META_DOMAIN}`) || Host(`stremio-jackett.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`stremio-jackett.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.stremio-jackett.loadbalancer.server.port=3000",
          "homepage.group=Stremio Addons",
          "homepage.name=Stremio Jackett",
          "homepage.icon=stremio.png",
          "homepage.href=https://stremio-jackett.${NOMAD_META_DOMAIN}/",
          "homepage.description=Jackett integration for Stremio"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "riven-setup" {
      driver = "docker"

      config {
        image = "python:3.11-alpine"
        hostname = "riven-setup"
        ports = ["riven_setup"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/riven-setup:/app"
        ]
        command = "python"
        args = ["/app/setup.py"]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PYTHONPATH = "/app"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "riven-setup"
        
        tags = [
          "utility",
          "setup"
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
    
    # Homepage weather configuration
    HOMEPAGE_WEATHER_CITY = ""
    HOMEPAGE_WEATHER_LAT = ""
    HOMEPAGE_WEATHER_LONG = ""
    
    # Jackett API key
    JACKETT_API_KEY = ""
  }
} 