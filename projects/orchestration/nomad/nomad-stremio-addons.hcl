job "media-stack-stremio-addons" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 50

  # Stremio Addons Group
  group "stremio-addons" {
    count = 1

    network {
      mode = "bridge"
      port "addon_manager" {
        to = 80
      }
      port "aiostremio" {
        to = 3000
      }
      port "anime_kitsu" {
        to = 3000
      }
      port "jackettio" {
        to = 4000
      }
      port "stremio_jackett" {
        to = 3000
      }
      port "stremio_server" {
        to = 11470
      }
      port "stremio_trakt" {
        to = 3000
      }
      port "stremthru" {
        to = 8080
      }
      port "tmdb_addon" {
        to = 3000
      }
      port "omg_tv" {
        to = 3000
      }
      port "catalog_providers" {
        to = 3000
      }
    }

    task "addon-manager" {
      driver = "docker"

      config {
        image = "reddravenn/stremio-addon-manager:latest"
        hostname = "addon-manager"
        ports = ["addon_manager"]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "addon-manager"
        port = "addon_manager"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.addon-manager.middlewares=nginx-auth@file",
          "traefik.http.routers.addon-manager.rule=Host(`addon-manager.${NOMAD_META_DOMAIN}`) || Host(`addon-manager.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`addon-manager.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.addon-manager.loadbalancer.server.port=80",
          "homepage.group=Stremio Addons",
          "homepage.name=Addon Manager",
          "homepage.icon=stremio.png",
          "homepage.href=https://addon-manager.${NOMAD_META_DOMAIN}/",
          "homepage.description=Stremio addon management interface"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "stremthru" {
      driver = "docker"

      config {
        image = "geek-cookbook/stremthru:latest"
        hostname = "stremthru"
        ports = ["stremthru"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/stremthru:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "stremthru"
        port = "stremthru"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.stremthru.rule=Host(`stremthru.${NOMAD_META_DOMAIN}`) || Host(`stremthru.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`stremthru.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.stremthru.loadbalancer.server.port=8080",
          "homepage.group=Stremio Addons",
          "homepage.name=StremThru",
          "homepage.icon=stremthru.png",
          "homepage.href=https://stremthru.${NOMAD_META_DOMAIN}/",
          "homepage.description=Stremio proxy service for debrid providers"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "aiostremio" {
      driver = "docker"

      config {
        image = "ghcr.io/viren070/aiostremio:latest"
        hostname = "aiostremio"
        ports = ["aiostremio"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/aiostremio:/app/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PORT = "3000"
        SECRET_KEY = "${NOMAD_META_AIOSTREMIO_SECRET_KEY}"
        API_KEY = "${NOMAD_META_AIOSTREMIO_API_KEY}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "aiostremio"
        port = "aiostremio"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.aiostremio.rule=Host(`aiostremio.${NOMAD_META_DOMAIN}`) || Host(`aiostremio.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`aiostremio.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.aiostremio.loadbalancer.server.port=3000",
          "homepage.group=Stremio Addons",
          "homepage.name=AIOStremio",
          "homepage.icon=stremio.png",
          "homepage.href=https://aiostremio.${NOMAD_META_DOMAIN}/",
          "homepage.description=All-in-one Stremio addon aggregator"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "anime-kitsu" {
      driver = "docker"

      config {
        image = "viren070/anime-kitsu:latest"
        hostname = "anime-kitsu"
        ports = ["anime_kitsu"]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PORT = "3000"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "anime-kitsu"
        port = "anime_kitsu"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.anime-kitsu.rule=Host(`anime-kitsu.${NOMAD_META_DOMAIN}`) || Host(`anime-kitsu.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`anime-kitsu.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.anime-kitsu.loadbalancer.server.port=3000",
          "homepage.group=Stremio Addons",
          "homepage.name=Anime Kitsu",
          "homepage.icon=kitsu.png",
          "homepage.href=https://anime-kitsu.${NOMAD_META_DOMAIN}/",
          "homepage.description=Anime metadata addon for Stremio"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "tmdb-addon" {
      driver = "docker"

      config {
        image = "viren070/tmdb-addon:latest"
        hostname = "tmdb-addon"
        ports = ["tmdb_addon"]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PORT = "3000"
        TMDB_API_KEY = "${NOMAD_META_TMDB_API_KEY}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "tmdb-addon"
        port = "tmdb_addon"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.tmdb-addon.rule=Host(`tmdb-addon.${NOMAD_META_DOMAIN}`) || Host(`tmdb-addon.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`tmdb-addon.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.tmdb-addon.loadbalancer.server.port=3000",
          "homepage.group=Stremio Addons",
          "homepage.name=TMDB Addon",
          "homepage.icon=tmdb.png",
          "homepage.href=https://tmdb-addon.${NOMAD_META_DOMAIN}/",
          "homepage.description=TMDB metadata addon for Stremio"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "stremio-trakt-addon" {
      driver = "docker"

      config {
        image = "viren070/stremio-trakt-addon:latest"
        hostname = "stremio-trakt"
        ports = ["stremio_trakt"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/stremio-trakt-addon:/app/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PORT = "3000"
        TRAKT_CLIENT_ID = "${NOMAD_META_TRAKT_CLIENT_ID}"
        TRAKT_CLIENT_SECRET = "${NOMAD_META_TRAKT_CLIENT_SECRET}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "stremio-trakt-addon"
        port = "stremio_trakt"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.stremio-trakt.rule=Host(`stremio-trakt.${NOMAD_META_DOMAIN}`) || Host(`stremio-trakt.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`stremio-trakt.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.stremio-trakt.loadbalancer.server.port=3000",
          "homepage.group=Stremio Addons",
          "homepage.name=Stremio Trakt",
          "homepage.icon=trakt.png",
          "homepage.href=https://stremio-trakt.${NOMAD_META_DOMAIN}/",
          "homepage.description=Trakt integration addon for Stremio"
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
    
    # API Keys
    TMDB_API_KEY = ""
    TRAKT_CLIENT_ID = ""
    TRAKT_CLIENT_SECRET = ""
    
    # AIOStremio configuration
    AIOSTREMIO_SECRET_KEY = ""
    AIOSTREMIO_API_KEY = ""
  }
} 