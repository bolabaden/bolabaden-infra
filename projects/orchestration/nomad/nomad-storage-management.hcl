job "media-stack-storage-management" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 60

  # Storage Services Group
  group "storage-services" {
    count = 1

    network {
      mode = "bridge"
      port "zurg" {
        to = 9999
      }
      port "rcloneui" {
        to = 5572
      }
      port "rclonefm" {
        to = 8080
      }
      port "filebrowser" {
        to = 8080
      }
      port "mediaflow_proxy" {
        to = 8080
      }
      port "stremthru" {
        to = 8080
      }
      port "symlink_cleaner" {
        to = 8080
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
        cpu    = 500
        memory = 1024
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
          "homepage.group=Storage Management",
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

    task "rcloneui" {
      driver = "docker"

      config {
        image = "rclone/rclone:latest"
        hostname = "rcloneui"
        ports = ["rcloneui"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/rclone:/config/rclone",
          "/mnt/user:/data"
        ]
        command = "rcd"
        args = [
          "--rc-web-gui",
          "--rc-addr=0.0.0.0:5572",
          "--rc-user=${NOMAD_META_RCLONE_USER}",
          "--rc-pass=${NOMAD_META_RCLONE_PASS}",
          "--config=/config/rclone/rclone.conf"
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
        name = "rcloneui"
        port = "rcloneui"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.rcloneui.middlewares=nginx-auth@file",
          "traefik.http.routers.rcloneui.rule=Host(`rcloneui.${NOMAD_META_DOMAIN}`) || Host(`rcloneui.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`rcloneui.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.rcloneui.loadbalancer.server.port=5572",
          "homepage.group=Storage Management",
          "homepage.name=RClone UI",
          "homepage.icon=rclone.png",
          "homepage.href=https://rcloneui.${NOMAD_META_DOMAIN}/",
          "homepage.description=RClone web interface"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "rclonefm" {
      driver = "docker"

      config {
        image = "ghcr.io/elfhosted/rclonefm:latest"
        hostname = "rclonefm"
        ports = ["rclonefm"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/rclone:/config/rclone",
          "/mnt/user:/data"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        RCLONE_CONFIG_PATH = "/config/rclone/rclone.conf"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "rclonefm"
        port = "rclonefm"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.rclonefm.middlewares=nginx-auth@file",
          "traefik.http.routers.rclonefm.rule=Host(`rclonefm.${NOMAD_META_DOMAIN}`) || Host(`rclonefm.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`rclonefm.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.rclonefm.loadbalancer.server.port=8080",
          "homepage.group=Storage Management",
          "homepage.name=RClone FM",
          "homepage.icon=rclone.png",
          "homepage.href=https://rclonefm.${NOMAD_META_DOMAIN}/",
          "homepage.description=RClone file manager"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "filebrowser" {
      driver = "docker"

      config {
        image = "filebrowser/filebrowser:latest"
        hostname = "filebrowser"
        ports = ["filebrowser"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/filebrowser:/config",
          "${NOMAD_META_CONFIG_PATH}/filebrowser/database.db:/database.db",
          "/mnt/user:/srv"
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
        name = "filebrowser"
        port = "filebrowser"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.filebrowser.middlewares=nginx-auth@file",
          "traefik.http.routers.filebrowser.rule=Host(`filebrowser.${NOMAD_META_DOMAIN}`) || Host(`filebrowser.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`filebrowser.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.filebrowser.loadbalancer.server.port=8080",
          "homepage.group=Storage Management",
          "homepage.name=File Browser",
          "homepage.icon=filebrowser.png",
          "homepage.href=https://filebrowser.${NOMAD_META_DOMAIN}/",
          "homepage.description=Web-based file manager"
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

    task "symlink-cleaner" {
      driver = "docker"

      config {
        image = "ghcr.io/elfhosted/symlink-cleaner:latest"
        hostname = "symlink-cleaner"
        volumes = [
          "/mnt/user/symlinks:/symlinks",
          "${NOMAD_META_CONFIG_PATH}/symlink-cleaner:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        CLEANUP_INTERVAL = "3600"
        DRY_RUN = "false"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "symlink-cleaner"
        
        tags = [
          "utility",
          "cleanup"
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

  # Premiumize and Torbox Group
  group "debrid-services" {
    count = 1

    network {
      mode = "bridge"
      port "torbox" {
        to = 3000
      }
      port "premiumize" {
        to = 8080
      }
    }

    task "torbox" {
      driver = "docker"

      config {
        image = "yoruio/torbox-manager:latest"
        hostname = "torbox"
        ports = ["torbox"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/torbox:/app/data"
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
        name = "torbox"
        port = "torbox"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.torbox.middlewares=nginx-auth@file",
          "traefik.http.routers.torbox.rule=Host(`torbox.${NOMAD_META_DOMAIN}`) || Host(`torbox.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`torbox.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.torbox.loadbalancer.server.port=3000",
          "homepage.group=Download Management",
          "homepage.name=TorBox",
          "homepage.icon=torbox.png",
          "homepage.href=https://torbox.${NOMAD_META_DOMAIN}/",
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

    task "premiumize" {
      driver = "docker"

      config {
        image = "ghcr.io/elfhosted/premiumize:latest"
        hostname = "premiumize"
        ports = ["premiumize"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/premiumize:/config"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        PREMIUMIZE_API_KEY = "${NOMAD_META_PREMIUMIZE_API_KEY}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "premiumize"
        port = "premiumize"
        
        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.premiumize.middlewares=nginx-auth@file",
          "traefik.http.routers.premiumize.rule=Host(`premiumize.${NOMAD_META_DOMAIN}`) || Host(`premiumize.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`premiumize.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.premiumize.loadbalancer.server.port=8080",
          "homepage.group=Download Management",
          "homepage.name=Premiumize",
          "homepage.icon=premiumize.png",
          "homepage.href=https://premiumize.${NOMAD_META_DOMAIN}/",
          "homepage.description=Premiumize account management"
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
    
    # RClone configuration
    RCLONE_USER = "admin"
    RCLONE_PASS = ""
    
    # MediaFlow configuration
    MEDIAFLOW_API_PASSWORD = ""
    
    # Debrid service configuration
    TORBOX_API_KEY = ""
    PREMIUMIZE_API_KEY = ""
  }
} 