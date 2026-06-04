job "media-stack-torrenting-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 60

  group "torrent-clients" {
    count = 1

    network {
      mode = "bridge"
      port "deluge_web" {
        to = 8112
      }
      port "qbittorrent_webui" {
        to = 8084
      }
      port "qbittorrent_torrenting_tcp" {
        to = 6881
      }
      port "qbittorrent_torrenting_udp" {
        to = 6881
        protocol = "udp"
      }
      port "transmission_webui" {
        to = 9091
      }
      port "transmission_peer" {
        to = 51413
        protocol = "udp"
      }
    }

    task "deluge" {
      driver = "docker"

      config {
        image = "linuxserver/deluge:latest"
        hostname = "deluge"
        ports = ["deluge_web"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/deluge:/config",
          "/mnt/data/downloads:/downloads"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
        DELUGE_LOGLEVEL = "${NOMAD_META_DELUGE_LOGLEVEL}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "deluge"
        port = "deluge_web"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.deluge.rule=Host(`deluge.${NOMAD_META_DOMAIN}`) || Host(`deluge.${NOMAD_META_SECOND_DOMAIN}`) || Host(`deluge.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`deluge.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.deluge.loadbalancer.server.port=8112",
          "homepage.group=BitTorrent Clients",
          "homepage.name=Deluge",
          "homepage.icon=deluge.png",
          "homepage.href=https://deluge.${NOMAD_META_DOMAIN}/",
          "homepage.description=A lightweight, cross-platform BitTorrent client designed for downloading files efficiently and securely from the internet."
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "qbittorrent" {
      driver = "docker"

      config {
        image = "linuxserver/qbittorrent"
        hostname = "qbittorrent"
        ports = ["qbittorrent_webui", "qbittorrent_torrenting_tcp", "qbittorrent_torrenting_udp"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/qbittorrent:/config",
          "/mnt/data/downloads:/downloads"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
        WEBUI_PORT = "${NOMAD_META_QB_WEBUI_PORT}"
        TORRENTING_PORT = "${NOMAD_META_QB_TORRENTING_PORT}"
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "qbittorrent"
        port = "qbittorrent_webui"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.qbittorrent.rule=Host(`qbittorrent.${NOMAD_META_DOMAIN}`) || Host(`qbittorrent.${NOMAD_META_SECOND_DOMAIN}`) || Host(`qbittorrent.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`qbittorrent.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.qbittorrent.loadbalancer.server.port=${NOMAD_META_QB_WEBUI_PORT}",
          "homepage.group=Download Clients",
          "homepage.name=qBittorrent Downloader",
          "homepage.icon=qbittorrent.png",
          "homepage.href=https://qbittorrent.${NOMAD_META_DOMAIN}/",
          "homepage.description=A user-friendly torrent client for downloading and managing files via BitTorrent, offering a clean interface and powerful features.",
          "homepage.widget.type=qbittorrent",
          "homepage.widget.url=http://qbittorrent:${NOMAD_META_QB_WEBUI_PORT}",
          "homepage.widget.username=${NOMAD_META_QBITTORRENT_USERNAME}",
          "homepage.widget.password=${NOMAD_META_QBITTORRENT_PASSWORD}"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "transmission" {
      driver = "docker"

      config {
        image = "linuxserver/transmission"
        hostname = "transmission"
        ports = ["transmission_webui", "transmission_peer"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/transmission:/config",
          "/mnt/data/watch:/watch",
          "/mnt/data/downloads/complete:/downloads/complete",
          "/mnt/data/downloads/incomplete:/downloads/incomplete"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
        USER = "${NOMAD_META_TRANSMISSION_USER}"
        PASS = "${NOMAD_META_TRANSMISSION_PASS}"
        PEERPORT = "${NOMAD_META_TRANSMISSION_PEERPORT}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "transmission"
        port = "transmission_webui"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.transmission.rule=Host(`transmission.${NOMAD_META_DOMAIN}`) || Host(`transmission.${NOMAD_META_SECOND_DOMAIN}`) || Host(`transmission.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`transmission.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.transmission.loadbalancer.server.port=9091",
          "homepage.group=BitTorrent Clients",
          "homepage.name=Transmission BitTorrent Client",
          "homepage.icon=transmission.png",
          "homepage.href=https://transmission.${NOMAD_META_DOMAIN}/",
          "homepage.description=A lightweight and efficient BitTorrent client for downloading and managing torrent files, known for its simplicity and speed.",
          "homepage.widget.type=transmission",
          "homepage.widget.url=http://transmission:9091",
          "homepage.widget.username=${NOMAD_META_TRANSMISSION_USER}",
          "homepage.widget.password=${NOMAD_META_TRANSMISSION_PASS}"
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
    TZ = "America/Chicago"
    PUID = "1002"
    PGID = "988"
    UMASK = "002"
    CONFIG_PATH = "./configs"
    DOMAIN = "example.com"
    SECOND_DOMAIN = "bocloud.org"
    DUCKDNS_SUBDOMAIN = "example"
    TS_HOSTNAME = "example"

    DELUGE_LOGLEVEL = "info"
    QB_TORRENTING_PORT = "6881"
    QB_WEBUI_PORT = "8084"
    QBITTORRENT_USERNAME = "admin"
    QBITTORRENT_PASSWORD = "adminadmin"
    TRANSMISSION_USER = "admin"
    TRANSMISSION_PASS = "admin"
    TRANSMISSION_PEERPORT = "51413"
  }
} 