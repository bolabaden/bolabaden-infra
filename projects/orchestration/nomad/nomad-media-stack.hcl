job "media-stack-core" {
  datacenters = ["dc1"]
  type        = "service"
  priority    = 80

  # Network configuration
  network {
    mode = "bridge"
    port "traefik_http" {
      static = 80
    }
    port "traefik_https" {
      static = 443
    }
    port "mongodb" {
      static = 27017
    }
    port "redis" {
      static = 6379
    }
    port "qdrant" {
      static = 6333
    }
  }

  group "databases" {
    count = 1

    network {
      mode = "bridge"
      port "mongodb" {
        to = 27017
      }
      port "redis" {
        to = 6379
      }
      port "qdrant" {
        to = 6333
      }
    }

    task "mongodb" {
      driver = "docker"

      config {
        image = "mongo:latest"
        hostname = "${NOMAD_META_MONGODB_HOSTNAME}"
        ports = ["mongodb"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/mongodb/data:/data/db"
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
        memory = 512
      }

      service {
        name = "mongodb"
        port = "mongodb"
        
        check {
          type     = "script"
          name     = "mongodb-health"
          command  = "/bin/sh"
          args     = ["-c", "mongosh 127.0.0.1:27017/test --quiet --eval 'db.runCommand(\"ping\").ok' > /dev/null 2>&1"]
          interval = "10s"
          timeout  = "10s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.mongodb.middlewares=nginx-auth@file",
          "traefik.http.routers.mongodb.rule=Host(`mongodb.${NOMAD_META_DOMAIN}`) || Host(`mongodb.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`mongodb.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.mongodb.loadbalancer.server.port=27017"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "redis" {
      driver = "docker"

      config {
        image = "redis:latest"
        hostname = "redis"
        ports = ["redis"]
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/redis:/data"
        ]
        command = "redis-server"
        args = ["--appendonly", "yes", "--save", "60", "1"]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        PUID = "${NOMAD_META_PUID}"
        PGID = "${NOMAD_META_PGID}"
        UMASK = "${NOMAD_META_UMASK}"
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name = "redis"
        port = "redis"
        
        check {
          type     = "script"
          name     = "redis-health"
          command  = "/bin/sh"
          args     = ["-c", "redis-cli ping > /dev/null 2>&1"]
          interval = "10s"
          timeout  = "5s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.redis.middlewares=nginx-auth@file",
          "traefik.http.routers.redis.rule=Host(`redis.${NOMAD_META_DOMAIN}`) || Host(`redis.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`redis.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.redis.loadbalancer.server.port=6379"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "qdrant" {
      driver = "docker"

      config {
        image = "qdrant/qdrant:latest"
        ports = ["qdrant"]
        volumes = [
          "qdrant_storage:/qdrant/storage"
        ]
      }

      resources {
        cpu    = 300
        memory = 512
      }

      service {
        name = "qdrant"
        port = "qdrant"
        
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.qdrant.middlewares=nginx-auth@file",
          "traefik.http.routers.qdrant.rule=Host(`qdrant.${NOMAD_META_DOMAIN}`) || Host(`qdrant.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`qdrant.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.qdrant.loadbalancer.server.port=6333"
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

  group "traefik" {
    count = 1

    network {
      mode = "bridge"
      port "http" {
        static = 80
        to = 80
      }
      port "https" {
        static = 443
        to = 443
      }
      port "api" {
        to = 8080
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image = "traefik:latest"
        hostname = "traefik"
        ports = ["http", "https", "api"]
        volumes = [
          "/var/run/tailscale/tailscaled.sock:/var/run/tailscale/tailscaled.sock",
          "${NOMAD_META_CERTS_PATH}:/certs",
          "${NOMAD_META_CONFIG_PATH}/traefik/config:/config",
          "${NOMAD_META_CONFIG_PATH}/traefik/plugins-local:/plugins-local",
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
        cap_add = ["NET_ADMIN"]
        sysctl = {
          "net.ipv6.conf.all.disable_ipv6" = "1"
        }
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        CLOUDFLARE_EMAIL = "${NOMAD_META_CLOUDFLARE_EMAIL}"
        CLOUDFLARE_DNS_API_TOKEN = "${NOMAD_META_CLOUDFLARE_DNS_API_TOKEN}"
        CLOUDFLARE_ZONE_API_TOKEN = "${NOMAD_META_CLOUDFLARE_ZONE_API_TOKEN}"
        LETS_ENCRYPT_EMAIL = "${NOMAD_META_LETS_ENCRYPT_EMAIL}"
        DUCKDNS_TOKEN = "${NOMAD_META_DUCKDNS_TOKEN}"
      }

      template {
        data = <<EOF
--accesslog=true
--api.dashboard=true
--api.debug=false
--api.disableDashboardAd=true
--api.insecure=true
--certificatesresolvers.letsencrypt.acme.caServer=https://acme-v02.api.letsencrypt.org/directory
--certificatesresolvers.letsencrypt.acme.dnsChallenge.provider=duckdns
--certificatesresolvers.letsencrypt.acme.dnsChallenge.resolvers=8.8.8.8,8.8.4.4
--certificatesresolvers.letsencrypt.acme.dnsChallenge=true
--certificatesresolvers.letsencrypt.acme.email=${NOMAD_META_LETS_ENCRYPT_EMAIL}
--certificatesresolvers.letsencrypt.acme.httpChallenge.entryPoint=web
--certificatesresolvers.letsencrypt.acme.httpChallenge=true
--certificatesresolvers.letsencrypt.acme.storage=/certs/acme.json
--certificatesresolvers.letsencrypt.acme.tlsChallenge=true
--entrypoints.web.address=:80
--entrypoints.web.forwardedHeaders.trustedIPs=127.0.0.1/32,::1/128,172.17.0.0/12,${NOMAD_META_PUBLICNET_SUBNET},${NOMAD_META_TAILSCALE_CIDR}
--entrypoints.web.http.redirections.entryPoint.scheme=https
--entrypoints.web.http.redirections.entryPoint.to=websecure
--entrypoints.websecure.address=:443
--entrypoints.websecure.forwardedHeaders.trustedIPs=127.0.0.1/32,::1/128,172.17.0.0/12,${NOMAD_META_PUBLICNET_SUBNET},${NOMAD_META_TAILSCALE_CIDR}
--entrypoints.websecure.http.tls.certResolver=letsencrypt
--entrypoints.websecure.http.tls.domains[0].main=${NOMAD_META_DOMAIN}
--entrypoints.websecure.http.tls.domains[0].sans=*.${NOMAD_META_DOMAIN}
--entrypoints.websecure.http.tls=true
--global.checkNewVersion=true
--global.sendAnonymousUsage=false
--log.level=DEBUG
--ping.terminatingStatusCode=503
--ping=true
--providers.docker.defaultRule=Host(`{{ .ContainerName }}.${NOMAD_META_DOMAIN}`) || Host(`{{ .ContainerName }}.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`{{ .ContainerName }}.${NOMAD_META_TS_HOSTNAME}.duckdns.org`) || Host(`{{ .ContainerName }}.${NOMAD_META_TS_HOSTNAME}.${NOMAD_META_DOMAIN}`) || Host(`{{ .ContainerName }}.${NOMAD_META_TS_HOSTNAME}.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`)
--providers.docker.exposedByDefault=false
--providers.docker.network=publicnet
--providers.docker=true
--providers.file.directory=/config
--providers.file.watch=true
--serversTransport.insecureSkipVerify=true
EOF
        destination = "local/traefik.yml"
      }

      resources {
        cpu    = 300
        memory = 256
      }

      service {
        name = "traefik"
        port = "api"
        
        check {
          type     = "http"
          path     = "/ping"
          interval = "10s"
          timeout  = "3s"
        }

        tags = [
          "traefik.enable=true",
          "traefik.http.routers.traefik.middlewares=nginx-auth@file",
          "traefik.http.routers.traefik.rule=Host(`traefik.${NOMAD_META_DOMAIN}`) || Host(`traefik.${NOMAD_META_DUCKDNS_SUBDOMAIN}.duckdns.org`) || Host(`traefik.${NOMAD_META_TS_HOSTNAME}.duckdns.org`)",
          "traefik.http.services.traefik.loadbalancer.server.port=8080"
        ]
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "error-pages" {
      driver = "docker"

      config {
        image = "httpd:alpine"
        hostname = "error-pages"
        volumes = [
          "${NOMAD_META_CONFIG_PATH}/traefik/error-pages:/usr/local/apache2/htdocs/:ro"
        ]
      }

      resources {
        cpu    = 50
        memory = 64
      }

      service {
        name = "error-pages"
        port = "80"
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }
  }

  group "system-services" {
    count = 1

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
        WATCHTOWER_CLEANUP = "${NOMAD_META_WATCHTOWER_CLEANUP}"
        WATCHTOWER_SCHEDULE = "${NOMAD_META_WATCHTOWER_SCHEDULE}"
        WATCHTOWER_NOTIFICATION_URL = "${NOMAD_META_WATCHTOWER_NOTIFICATION_URL}"
        WATCHTOWER_NOTIFICATION_REPORT = "${NOMAD_META_WATCHTOWER_NOTIFICATION_REPORT}"
        WATCHTOWER_NOTIFICATION_TEMPLATE = <<EOF
{{- if .Report -}}
  {{- with .Report -}}
    {{- if ( or .Updated .Failed ) -}}
{{len .Scanned}} Scanned, {{len .Updated}} Updated, {{len .Failed}} Failed
      {{- range .Updated}}
- {{.Name}} ({{.ImageName}}): {{.CurrentImageID.ShortID}} updated to {{.LatestImageID.ShortID}}
      {{- end -}}
      {{- range .Skipped}}
- {{.Name}} ({{.ImageName}}): {{.State}}: {{.Error}}
      {{- end -}}
      {{- range .Failed}}
- {{.Name}} ({{.ImageName}}): {{.State}}: {{.Error}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- else -}}
  {{range .Entries -}}{{.Message}}{{"\n"}}{{- end -}}
{{- end -}}
EOF
      }

      resources {
        cpu    = 100
        memory = 128
      }

      restart {
        attempts = 3
        delay    = "30s"
        interval = "5m"
        mode     = "fail"
      }
    }

    task "deunhealth" {
      driver = "docker"

      config {
        image = "qmcgaw/deunhealth"
        network_mode = "none"
        security_opt = ["no-new-privileges:true"]
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:z"
        ]
      }

      env {
        TZ = "${NOMAD_META_TZ}"
        LOG_LEVEL = "${NOMAD_META_DEUNHEALTH_LOG_LEVEL}"
        HEALTH_SERVER_ADDRESS = "${NOMAD_META_DEUNHEALTH_HEALTH_SERVER_ADDRESS}"
      }

      resources {
        cpu    = 50
        memory = 64
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
    CERTS_PATH = "./certs"
    
    # Domain configuration
    DOMAIN = "example.com"
    DUCKDNS_SUBDOMAIN = "example"
    TS_HOSTNAME = "example"
    
    # Network configuration
    PUBLICNET_SUBNET = "10.76.0.0/16"
    TAILSCALE_CIDR = "100.64.0.0/10"
    
    # Service hostnames
    MONGODB_HOSTNAME = "mongodb"
    
    # Traefik configuration
    CLOUDFLARE_EMAIL = ""
    CLOUDFLARE_DNS_API_TOKEN = ""
    CLOUDFLARE_ZONE_API_TOKEN = ""
    LETS_ENCRYPT_EMAIL = ""
    DUCKDNS_TOKEN = ""
    
    # Watchtower configuration
    WATCHTOWER_CLEANUP = "true"
    WATCHTOWER_SCHEDULE = "0 0 6 * * *"
    WATCHTOWER_NOTIFICATION_URL = ""
    WATCHTOWER_NOTIFICATION_REPORT = "true"
    
    # DeUnhealth configuration
    DEUNHEALTH_LOG_LEVEL = "debug"
    DEUNHEALTH_HEALTH_SERVER_ADDRESS = "127.0.0.1:9999"
  }
} 