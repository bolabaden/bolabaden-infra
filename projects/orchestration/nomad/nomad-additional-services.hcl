job "media-stack-additional-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 55

  # Media Management Services Group
  group "media-management" {
    count = 1

    network {
      mode = "bridge"
      port "jellyseer" {
        to = 5055
      }
      port "seanime" {
        to = 43211
      }
      port "tautulli" {
        to = 8181
      }
      port "kometa" {
        to = 8080
      }
      port "overseerr" {
        to = 5055
      }
      port "radarr" {
        to = 7878
      }
      port "sonarr" {
        to = 8989
      }
      port "bazarr" {
        to = 6767
      }
      port "recyclarr" {
        to = 8080
      }
    }

    task "jellyseer" {
      driver = "docker"

      config {
        image = "fallenbagel/jellyseerr:latest"
        hostname = "jellyseer"
        ports = ["jellyseer"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/jellyseer:/app/config"
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
        name = "jellyseer"
        port = "jellyseer"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.jellyseer.rule=Host(`jellyseer.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.jellyseer.loadbalancer.server.port=5055",
          "homepage.group=Media Management",
          "homepage.name=Jellyseerr",
          "homepage.icon=jellyseerr.png",
          "homepage.href=https://jellyseer.${NOMAD_META_DOMAIN}/",
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

    task "seanime" {
      driver = "docker"

      config {
        image = "umagistr/seanime"
        hostname = "seanime"
        ports = ["seanime"]
        volumes = [
          "/mnt/user/anime:/anime",
          "/mnt/user/downloads:/downloads",
          "/mnt:/mnt",
          "${NOMAD_META_CONFIG_PATH}/seanime:/root/.config/Seanime"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "seanime"
        port = "seanime"
        
        check {
          type     = "http"
          path     = "/api/v1/status"
          interval = "5m"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.seanime.middlewares=nginx-auth@file",
          "traefik.http.routers.seanime.rule=Host(`seanime.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.seanime.loadbalancer.server.port=43211",
          "homepage.group=Media Management",
          "homepage.name=Seanime",
          "homepage.icon=seanime.png",
          "homepage.href=https://seanime.${NOMAD_META_DOMAIN}/",
          "homepage.description=Anime management and streaming platform"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "tautulli" {
      driver = "docker"

      config {
        image = "linuxserver/tautulli"
        hostname = "tautulli"
        ports = ["tautulli"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/tautulli:/config"
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
        name = "tautulli"
        port = "tautulli"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.tautulli.middlewares=nginx-auth@file",
          "traefik.http.routers.tautulli.rule=Host(`tautulli.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.tautulli.loadbalancer.server.port=8181",
          "homepage.group=Media Management",
          "homepage.name=Tautulli",
          "homepage.icon=tautulli.png",
          "homepage.href=https://tautulli.${NOMAD_META_DOMAIN}/",
          "homepage.description=Plex media server monitoring and statistics"
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

  # Security and Monitoring Group
  group "security-monitoring" {
    count = 1

    network {
      mode = "bridge"
      port "vaultwarden" {
        to = 80
      }
      port "uptime_kuma" {
        to = 3001
      }
      port "authelia" {
        to = 9091
      }
      port "portainer" {
        to = 9000
      }
      port "beszel" {
        to = 8090
      }
    }

    task "vaultwarden" {
      driver = "docker"

      config {
        image = "vaultwarden/server:latest"
        hostname = "vaultwarden"
        ports = ["vaultwarden"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/vaultwarden:/data/"
        ]
      }

      env {
        DOMAIN = "https://vaultwarden.${NOMAD_META_DOMAIN}"
        SIGNUPS_ALLOWED = "${NOMAD_META_VAULTWARDEN_SIGNUPS_ALLOWED}"
        ADMIN_TOKEN = "${NOMAD_META_VAULTWARDEN_ADMIN_TOKEN}"
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "vaultwarden"
        port = "vaultwarden"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.vaultwarden.rule=Host(`vaultwarden.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.vaultwarden.loadbalancer.server.port=80",
          "homepage.group=Security",
          "homepage.name=Vaultwarden",
          "homepage.icon=vaultwarden.png",
          "homepage.href=https://vaultwarden.${NOMAD_META_DOMAIN}/",
          "homepage.description=Self-hosted Bitwarden compatible password manager"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "uptime-kuma" {
      driver = "docker"

      config {
        image = "louislam/uptime-kuma:latest"
        hostname = "kuma"
        ports = ["uptime_kuma"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/uptime-kuma:/app/data",
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "uptime-kuma"
        port = "uptime_kuma"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.uptime-kuma.middlewares=nginx-auth@file",
          "traefik.http.routers.uptime-kuma.rule=Host(`uptime.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.uptime-kuma.loadbalancer.server.port=3001",
          "homepage.group=Monitoring",
          "homepage.name=Uptime Kuma",
          "homepage.icon=uptime-kuma.png",
          "homepage.href=https://uptime.${NOMAD_META_DOMAIN}/",
          "homepage.description=Self-hosted uptime monitoring tool"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "portainer" {
      driver = "docker"

      config {
        image = "portainer/portainer-ce:latest"
        hostname = "portainer"
        ports = ["portainer"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock",
          "${NOMAD_META_CONFIG_PATH}/portainer:/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "portainer"
        port = "portainer"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.portainer.middlewares=nginx-auth@file",
          "traefik.http.routers.portainer.rule=Host(`portainer.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.portainer.loadbalancer.server.port=9000",
          "homepage.group=Management",
          "homepage.name=Portainer",
          "homepage.icon=portainer.png",
          "homepage.href=https://portainer.${NOMAD_META_DOMAIN}/",
          "homepage.description=Docker container management interface"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "beszel" {
      driver = "docker"

      config {
        image = "henrygd/beszel"
        hostname = "beszel"
        ports = ["beszel"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/beszel:/beszel"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "beszel"
        port = "beszel"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.beszel.middlewares=nginx-auth@file",
          "traefik.http.routers.beszel.rule=Host(`beszel.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.beszel.loadbalancer.server.port=8090",
          "homepage.group=Monitoring",
          "homepage.name=Beszel",
          "homepage.icon=beszel.png",
          "homepage.href=https://beszel.${NOMAD_META_DOMAIN}/",
          "homepage.description=Lightweight server monitoring dashboard"
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
          "traefik.http.routers.addon-manager.rule=Host(`addon-manager.${NOMAD_META_DOMAIN}`)",
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
          "traefik.http.routers.stremthru.rule=Host(`stremthru.${NOMAD_META_DOMAIN}`)",
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
  }

  # Utility Services Group
  group "utility-services" {
    count = 1

    network {
      mode = "bridge"
      port "cloudflare_ddns" {
        to = 8080
      }
      port "zilean" {
        to = 8181
      }
      port "zipline" {
        to = 3000
      }
      port "plausible" {
        to = 8000
      }
      port "dash" {
        to = 3001
      }
      port "tweakio" {
        to = 3000
      }
      port "streamystats" {
        to = 3000
      }
      port "sshbot" {
        to = 3000
      }
    }

    task "cloudflare-ddns" {
      driver = "docker"

      config {
        image = "oznu/cloudflare-ddns:latest"
        hostname = "cloudflare-ddns"
      }

      env {
        API_KEY = "${NOMAD_META_CLOUDFLARE_API_KEY}"
        ZONE = "${NOMAD_META_CLOUDFLARE_ZONE}"
        SUBDOMAIN = "${NOMAD_META_CLOUDFLARE_SUBDOMAIN}"
        PROXIED = "${NOMAD_META_CLOUDFLARE_PROXIED}"
        RRTYPE = "A"
        DELETE_ON_STOP = "false"
        INTERFACE = "eth0"
        CUSTOM_LOOKUP_CMD = ""
        DNS_SERVER = "1.1.1.1"
        CRON = "*/5 * * * *"
      }

      resources {
        cpu    = 50
        memory = 64
      }

      service {
        name = "cloudflare-ddns"
        
        tags = [
          "utility",
          "ddns"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "zilean" {
      driver = "docker"

      config {
        image = "ipromknight/zilean:latest"
        hostname = "zilean"
        ports = ["zilean"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/zilean:/app/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        Zilean__Database__ConnectionString = "Data Source=/app/data/zilean.db"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "zilean"
        port = "zilean"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.zilean.middlewares=nginx-auth@file",
          "traefik.http.routers.zilean.rule=Host(`zilean.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.zilean.loadbalancer.server.port=8181",
          "homepage.group=Indexers",
          "homepage.name=Zilean",
          "homepage.icon=zilean.png",
          "homepage.href=https://zilean.${NOMAD_META_DOMAIN}/",
          "homepage.description=DMM hash list and torrent indexer"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "zipline" {
      driver = "docker"

      config {
        image = "ghcr.io/diced/zipline"
        hostname = "zipline"
        ports = ["zipline"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/zipline:/zipline/data",
          "${NOMAD_META_CONFIG_PATH}/zipline/uploads:/zipline/uploads",
          "${NOMAD_META_CONFIG_PATH}/zipline/public:/zipline/public"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        CORE_RETURN_HTTPS = "true"
        CORE_SECRET = "${NOMAD_META_ZIPLINE_SECRET}"
        CORE_HOST = "0.0.0.0"
        CORE_PORT = "3000"
        CORE_DATABASE_URL = "file:./data/zipline.db"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "zipline"
        port = "zipline"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.zipline.middlewares=nginx-auth@file",
          "traefik.http.routers.zipline.rule=Host(`zipline.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.zipline.loadbalancer.server.port=3000",
          "homepage.group=Utilities",
          "homepage.name=Zipline",
          "homepage.icon=zipline.png",
          "homepage.href=https://zipline.${NOMAD_META_DOMAIN}/",
          "homepage.description=File sharing and screenshot service"
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

  # Debrid and Download Management Group
  group "debrid-downloads" {
    count = 1

    network {
      mode = "bridge"
      port "torbox_manager" {
        to = 3000
      }
      port "torbox_media_center" {
        to = 8080
      }
      port "realdebrid_monitor" {
        to = 8080
      }
      port "zurg" {
        to = 9999
      }
      port "nzbhydra2" {
        to = 5076
      }
      port "mediaflow_proxy" {
        to = 8080
      }
    }

    task "torbox-manager" {
      driver = "docker"

      config {
        image = "yoruio/torbox-manager:latest"
        hostname = "torbox-manager"
        ports = ["torbox_manager"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/torbox-manager:/app/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        TORBOX_API_KEY = "${NOMAD_META_TORBOX_API_KEY}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "torbox-manager"
        port = "torbox_manager"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.torbox-manager.middlewares=nginx-auth@file",
          "traefik.http.routers.torbox-manager.rule=Host(`torbox-manager.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.torbox-manager.loadbalancer.server.port=3000",
          "homepage.group=Download Management",
          "homepage.name=TorBox Manager",
          "homepage.icon=torbox.png",
          "homepage.href=https://torbox-manager.${NOMAD_META_DOMAIN}/",
          "homepage.description=TorBox account and download management"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "zurg" {
      driver = "docker"

      config {
        image = "ghcr.io/debridmediamanager/zurg-testing:latest"
        hostname = "zurg"
        ports = ["zurg"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/zurg:/app/config"
        ]
        privileged = true
        devices = [
          "/dev/fuse:/dev/fuse:rwm"
        ]
        cap_add = ["SYS_ADMIN"]
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
        name = "zurg"
        port = "zurg"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.zurg.middlewares=nginx-auth@file",
          "traefik.http.routers.zurg.rule=Host(`zurg.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.zurg.loadbalancer.server.port=9999",
          "homepage.group=Download Management",
          "homepage.name=Zurg",
          "homepage.icon=zurg.png",
          "homepage.href=https://zurg.${NOMAD_META_DOMAIN}/",
          "homepage.description=Real-Debrid mount and streaming service"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "realdebrid-monitor" {
      driver = "docker"

      config {
        image = "realdebrid-account-monitor:latest"
        hostname = "realdebrid-monitor"
        ports = ["realdebrid_monitor"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/realdebrid-monitor:/app/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        RD_API_KEY = "${NOMAD_META_REALDEBRID_API_KEY}"
        CHECK_INTERVAL = "3600"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "realdebrid-monitor"
        port = "realdebrid_monitor"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.realdebrid-monitor.middlewares=nginx-auth@file",
          "traefik.http.routers.realdebrid-monitor.rule=Host(`rd-monitor.${NOMAD_META_DOMAIN}`)",
          "traefik.http.services.realdebrid-monitor.loadbalancer.server.port=8080",
          "homepage.group=Download Management",
          "homepage.name=RealDebrid Monitor",
          "homepage.icon=realdebrid.png",
          "homepage.href=https://rd-monitor.${NOMAD_META_DOMAIN}/",
          "homepage.description=Real-Debrid account monitoring and statistics"
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
    TS_HOSTNAME = "example"
    
    # Vaultwarden configuration
    VAULTWARDEN_SIGNUPS_ALLOWED = "true"
    VAULTWARDEN_ADMIN_TOKEN = ""
    
    # Cloudflare DDNS configuration
    CLOUDFLARE_API_KEY = ""
    CLOUDFLARE_ZONE = ""
    CLOUDFLARE_SUBDOMAIN = ""
    CLOUDFLARE_PROXIED = "false"
    
    # Zipline configuration
    ZIPLINE_SECRET = ""
    
    # Debrid service configuration
    TORBOX_API_KEY = ""
    REALDEBRID_API_KEY = ""
  }
} 