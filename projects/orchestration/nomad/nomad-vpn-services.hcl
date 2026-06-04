job "media-stack-vpn-services" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 75

  variable "tz" {
    type    = string
    default = "America/Chicago"
  }

  variable "config_path" {
    type    = string
    default = "./configs"
  }

  variable "src_path" {
    type    = string
    default = "./src"
  }

  variable "warp_ipv4_address" {
    type    = string
    default = "10.76.128.97"
  }

  variable "external_ip" {
    type    = string
    default = "149.130.221.93"
  }

  variable "domain" {
    type = string
  }

  variable "duckdns_subdomain" {
    type = string
  }

  variable "ts_hostname" {
    type = string
  }

  # VPN Services Group
  group "vpn-services" {
    count = 1

    network {
      mode = "bridge"
      port "warp_socks5" {
        static = 1080
        to = 1080
      }
      port "warp_http_proxy" {
        to = 3128
      }
      port "stremio_http" {
        static = 11470
        to = 11470
      }
      port "stremio_https" {
        static = 12470
        to = 12470
      }
      port "stremio_web" {
        to = 8080
      }
      port "comet" {
        to = 2020
      }
      port "aiostreams" {
        to = 3005
      }
      port "jackett" {
        to = 9117
      }
      port "prowlarr" {
        static = 9696
        to = 9696
      }
      port "mediafusion" {
        to = 8000
      }
      port "jackettio" {
        to = 4000
      }
      port "https_udp" {
        static = 443
        to = 443
      }
    }

    task "warp" {
      driver = "docker"

      config {
        image = "caomingjun/warp:latest"
        hostname = "warp"
        ports = [
          "warp_socks5", "warp_http_proxy", "stremio_http", "stremio_https", 
          "stremio_web", "comet", "aiostreams", "jackett", "prowlarr", 
          "mediafusion", "jackettio", "https_udp"
        ]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/warp/data:/var/lib/cloudflare-warp"
        ]
        cap_add = ["MKNOD", "AUDIT_WRITE", "NET_ADMIN"]
        sysctl = {
          "net.ipv6.conf.all.disable_ipv6" = "1"
          "net.ipv4.conf.all.src_valid_mark" = "1"
        }
        device_cgroup_rules = ["c 10:200 rwm"]
      }

      env {
        WARP_SLEEP = "2"
        WARP_LICENSE_KEY = "${NOMAD_META_WARP_LICENSE_KEY}"
        TUNNEL_TOKEN = "${NOMAD_META_TUNNEL_TOKEN}"
      }

      resources {
        cpu    = 300
        memory = 256
      }

      service {
        name = "warp"
        port = "warp_socks5"
        
        check {
          type     = "tcp"
          interval = "30s"
          timeout  = "10s"
        }

        tags = [
          "vpn",
          "warp",
          "traefik.enable=true",
          "traefik.http.routers.warp-proxy.service=warp-proxy",
          "traefik.http.routers.warp-proxy.middlewares=nginx-auth@file",
          "traefik.http.routers.warp-proxy.rule=Host(`warp-proxy.${NOMAD_META_DOMAIN}`) || Host(`warp-proxy.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`)",
          "traefik.http.services.warp-proxy.loadbalancer.server.port=3128",
          "traefik.http.routers.aiostreams.service=aiostreams",
          "traefik.http.routers.aiostreams.rule=Host(`aiostreams.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`aiostreams.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.aiostreams.loadbalancer.server.port=3005",
          "traefik.http.routers.comet.service=comet",
          "traefik.http.routers.comet.middlewares=nginx-auth@file",
          "traefik.http.routers.comet.rule=Host(`comet.${NOMAD_META_DOMAIN}`) || Host(`comet.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`)",
          "traefik.http.services.comet.loadbalancer.server.port=2020",
          "traefik.http.routers.jackett.service=jackett",
          "traefik.http.routers.jackett.middlewares=nginx-auth@file",
          "traefik.http.routers.jackett.rule=Host(`jackett.${NOMAD_META_DOMAIN}`) || Host(`jackett.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`)",
          "traefik.http.services.jackett.loadbalancer.server.port=9117",
          "traefik.http.routers.mediafusion.rule=Host(`mediafusion.${NOMAD_META_DOMAIN}`) || Host(`mediafusion.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`)",
          "traefik.http.routers.mediafusion.service=mediafusion",
          "traefik.http.services.mediafusion.loadbalancer.server.port=8000",
          "traefik.http.routers.prowlarr.service=prowlarr",
          "traefik.http.routers.prowlarr.middlewares=nginx-auth@file",
          "traefik.http.routers.prowlarr.rule=Host(`prowlarr.${NOMAD_META_DOMAIN}`) || Host(`prowlarr.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`)",
          "traefik.http.services.prowlarr.loadbalancer.server.port=9696",
          "traefik.http.routers.stremio-web.service=stremio-web",
          "traefik.http.routers.stremio-web.rule=Host(`stremio-web.${NOMAD_META_DOMAIN}`) || Host(`stremio-web.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`)",
          "traefik.http.services.stremio-web.loadbalancer.server.scheme=https",
          "traefik.http.services.stremio-web.loadbalancer.server.port=8080",
          "traefik.http.routers.stremio-http-server.service=stremio-http-server",
          "traefik.http.routers.stremio-http-server.rule=Host(`stremio-fallback.${NOMAD_META_DOMAIN}`) || Host(`stremio-fallback.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`)",
          "traefik.http.services.stremio-http-server.loadbalancer.server.scheme=http",
          "traefik.http.services.stremio-http-server.loadbalancer.server.port=11470",
          "traefik.http.routers.stremio-https-server.service=stremio-https-server",
          "traefik.http.routers.stremio-https-server.rule=Host(`stremio.${NOMAD_META_DOMAIN}`) || Host(`stremio.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`)",
          "traefik.http.services.stremio-https-server.loadbalancer.server.scheme=https",
          "traefik.http.services.stremio-https-server.loadbalancer.server.port=12470"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "warp-fetch-proxy" {
      driver = "docker"

      config {
        image = "custom/warp-fetch-proxy:latest"
        network_mode = "service:warp"
      }

      resources {
        cpu    = 100
        memory = 128
      }

      service {
        name = "warp-fetch-proxy"
        
        check {
          type     = "http"
          path     = "/health"
          port     = 3128
          interval = "30s"
          timeout  = "10s"
        }
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "tailscale-warp" {
      driver = "docker"

      config {
        image = "tailscale/tailscale"
        network_mode = "service:warp"
        devices = [
          "${NOMAD_META_WARP_TUN_DEVICE}:/dev/net/tun"
        ]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/tailscale/warp/volumes/var/lib/tailscale:${NOMAD_META_TS_STATE_DIR}",
          "${NOMAD_META_CONFIG_PATH}/tailscale/warp/volumes/tmp:/tmp"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        TS_ACCEPT_DNS = "false"
        TS_AUTH_ONCE = "true"
        TS_AUTHKEY = "${NOMAD_META_TS_AUTHKEY}"
        TS_ENABLE_HEALTH_CHECK = "true"
        TS_ENABLE_METRICS = "true"
        TS_HOSTNAME = "tailscale-warp-${NOMAD_META_TS_HOSTNAME}-docker"
        TS_LOCAL_ADDR_PORT = "0.0.0.0:41641"
        TS_OUTBOUND_HTTP_PROXY_LISTEN = "0.0.0.0:8885"
        TS_ROUTES = "${NOMAD_META_TS_ROUTES}"
        TS_SOCKET = "/tmp/tailscaled.sock"
        TS_SOCKS5_SERVER = ":1055"
        TS_STATE_DIR = "/var/lib/tailscale"
        TS_EXTRA_ARGS = "--accept-routes --advertise-exit-node"
        TS_USERSPACE = "true"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "tailscale-warp"
        
        check {
          type     = "http"
          path     = "/healthz"
          port     = 41641
          interval = "30s"
          timeout  = "10s"
        }
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
    
    # Paths
    CONFIG_PATH = "./configs"
    
    # Domain configuration
    DOMAIN = "example.com"
    DUCKDNS_SUBDOMAIN = "example"
    TS_HOSTNAME = "example"
    
    # WARP configuration
    WARP_LICENSE_KEY = "eyJhIjoiZTRlYjNkYmViMTJiZWFhY2MxNzcwNDEyMzE3OTA0NTQiLCJ0IjoiM2ExODhhOTMtYzQwNC00Zjg5LTg4NzItOThlMDkxNjNiYzAzIiwicyI6Ill6SmpNVFl5WmpNdE9EYzROUzAwWlRrMUxUazFORFl0TWpnd1lXWXhZVEpsT1dNMiJ9"
    TUNNEL_TOKEN = "eyJhIjoiZTRlYjNkYmViMTJiZWFhY2MxNzcwNDEyMzE3OTA0NTQiLCJ0IjoiM2ExODhhOTMtYzQwNC00Zjg5LTg4NzItOThlMDkxNjNiYzAzIiwicyI6Ill6SmpNVFl5WmpNdE9EYzROUzAwWlRrMUxUazFORFl0TWpnd1lXWXhZVEpsT1dNMiJ9"
    
    # Tailscale configuration
    TS_AUTHKEY = ""
    TS_STATE_DIR = "/var/lib/tailscale"
    TS_ROUTES = "10.76.0.0/16,172.17.0.0/16,100.64.0.0/10"
    WARP_TUN_DEVICE = "/dev/net/tun"
  }
} 