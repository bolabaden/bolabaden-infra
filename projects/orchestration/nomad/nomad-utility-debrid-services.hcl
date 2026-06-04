job "media-stack-utility-debrid-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 45

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
      port "librespeed" {
        to = 80
      }
      port "speedtest_tracker" {
        to = 80
      }
      port "dozzle" {
        to = 8080
      }
      port "watchtower" {
        to = 8080
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
          "traefik.http.routers.zilean.rule=Host(`zilean.${NOMAD_META_DOMAIN}`) || Host(`zilean.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`zilean.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
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
          "traefik.http.routers.zipline.rule=Host(`zipline.${NOMAD_META_DOMAIN}`) || Host(`zipline.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`zipline.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
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

    task "librespeed" {
      driver = "docker"

      config {
        image = "linuxserver/librespeed:latest"
        hostname = "librespeed"
        ports = ["librespeed"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/librespeed:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        PASSWORD = "${NOMAD_META_LIBRESPEED_PASSWORD}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "librespeed"
        port = "librespeed"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.librespeed.rule=Host(`speedtest.${NOMAD_META_DOMAIN}`) || Host(`speedtest.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`speedtest.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.librespeed.loadbalancer.server.port=80",
          "homepage.group=Utilities",
          "homepage.name=LibreSpeed",
          "homepage.icon=librespeed.png",
          "homepage.href=https://speedtest.${NOMAD_META_DOMAIN}/",
          "homepage.description=Self-hosted internet speed test"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "speedtest-tracker" {
      driver = "docker"

      config {
        image = "linuxserver/speedtest-tracker:latest"
        hostname = "speedtest-tracker"
        ports = ["speedtest_tracker"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/speedtest-tracker:/config",
          "${NOMAD_META_CONFIG_PATH}/speedtest-tracker/web:/app/web"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        APP_KEY = "${NOMAD_META_SPEEDTEST_TRACKER_APP_KEY}"
        DB_CONNECTION = "sqlite"
        SPEEDTEST_SCHEDULE = "0 */6 * * *"
        SPEEDTEST_SERVERS = ""
        PRUNE_RESULTS_OLDER_THAN = "0"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "speedtest-tracker"
        port = "speedtest_tracker"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.speedtest-tracker.middlewares=nginx-auth@file",
          "traefik.http.routers.speedtest-tracker.rule=Host(`speedtest-tracker.${NOMAD_META_DOMAIN}`) || Host(`speedtest-tracker.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`speedtest-tracker.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.speedtest-tracker.loadbalancer.server.port=80",
          "homepage.group=Monitoring",
          "homepage.name=Speedtest Tracker",
          "homepage.icon=speedtest-tracker.png",
          "homepage.href=https://speedtest-tracker.${NOMAD_META_DOMAIN}/",
          "homepage.description=Automated internet speed testing and tracking"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "dozzle" {
      driver = "docker"

      config {
        image = "amir20/dozzle:latest"
        hostname = "dozzle"
        ports = ["dozzle"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        DOZZLE_NO_ANALYTICS = "true"
        DOZZLE_LEVEL = "info"
        DOZZLE_TAILSIZE = "300"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "dozzle"
        port = "dozzle"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.dozzle.middlewares=nginx-auth@file",
          "traefik.http.routers.dozzle.rule=Host(`dozzle.${NOMAD_META_DOMAIN}`) || Host(`dozzle.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`dozzle.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.dozzle.loadbalancer.server.port=8080",
          "homepage.group=Management",
          "homepage.name=Dozzle",
          "homepage.icon=dozzle.png",
          "homepage.href=https://dozzle.${NOMAD_META_DOMAIN}/",
          "homepage.description=Real-time Docker log viewer"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "watchtower" {
      driver = "docker"

      config {
        image = "containrrr/watchtower:latest"
        hostname = "watchtower"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        WATCHTOWER_CLEANUP = "true"
        WATCHTOWER_POLL_INTERVAL = "86400"
        WATCHTOWER_INCLUDE_STOPPED = "true"
        WATCHTOWER_REVIVE_STOPPED = "false"
        WATCHTOWER_NOTIFICATIONS = "shoutrrr"
        WATCHTOWER_NOTIFICATION_URL = "${NOMAD_META_WATCHTOWER_NOTIFICATION_URL}"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "watchtower"
        
        tags = [
          "utility",
          "updater"
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
          "traefik.http.routers.torbox-manager.rule=Host(`torbox-manager.${NOMAD_META_DOMAIN}`) || Host(`torbox-manager.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`torbox-manager.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
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
          "traefik.http.routers.zurg.rule=Host(`zurg.${NOMAD_META_DOMAIN}`) || Host(`zurg.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`zurg.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
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
          "traefik.http.routers.realdebrid-monitor.rule=Host(`rd-monitor.${NOMAD_META_DOMAIN}`) || Host(`rd-monitor.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`rd-monitor.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
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

    task "mediaflow-proxy" {
      driver = "docker"

      config {
        image = "mhdzumair/mediaflow-proxy:latest"
        hostname = "mediaflow-proxy"
        ports = ["mediaflow_proxy"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/mediaflow-proxy:/app/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        API_PASSWORD = "${NOMAD_META_MEDIAFLOW_API_PASSWORD}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "mediaflow-proxy"
        port = "mediaflow_proxy"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.mediaflow-proxy.middlewares=nginx-auth@file",
          "traefik.http.routers.mediaflow-proxy.rule=Host(`mediaflow.${NOMAD_META_DOMAIN}`) || Host(`mediaflow.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`mediaflow.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.mediaflow-proxy.loadbalancer.server.port=8080",
          "homepage.group=Streaming",
          "homepage.name=MediaFlow Proxy",
          "homepage.icon=mediaflow.png",
          "homepage.href=https://mediaflow.${NOMAD_META_DOMAIN}/",
          "homepage.description=Proxy service for streaming media content"
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
    
    # Cloudflare DDNS configuration
    CLOUDFLARE_API_KEY = ""
    CLOUDFLARE_ZONE = ""
    CLOUDFLARE_SUBDOMAIN = ""
    CLOUDFLARE_PROXIED = "false"
    
    # Zipline configuration
    ZIPLINE_SECRET = ""
    
    # LibreSpeed configuration
    LIBRESPEED_PASSWORD = ""
    
    # Speedtest Tracker configuration
    SPEEDTEST_TRACKER_APP_KEY = ""
    
    # Watchtower configuration
    WATCHTOWER_NOTIFICATION_URL = ""
    
    # Debrid service configuration
    TORBOX_API_KEY = ""
    REALDEBRID_API_KEY = ""
    MEDIAFLOW_API_PASSWORD = ""
  }
} 