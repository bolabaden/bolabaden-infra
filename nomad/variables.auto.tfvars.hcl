# Nomad Variables File (Non-Sensitive Configuration)
# Auto-loaded when using: nomad job run nomad.hcl
# For secrets (API keys, passwords), see secrets.auto.tfvars.hcl

# Core Configuration
domain                     = "bolabaden.org"
main_username              = "brunner56"

# Paths
root_path                  = "/home/ubuntu/my-media-stack"
config_path                = "/home/ubuntu/my-media-stack/volumes"

# System Configuration
tz                         = "America/Chicago"
puid                       = 1001
pgid                       = 121
umask                      = "002"

# Email Configuration
acme_resolver_email        = "boden.crouch@gmail.com"
cloudflare_email           = "boden.crouch@gmail.com"

# Redis Configuration
redis_hostname             = "redis"
redis_port                 = 6379
redis_username             = "brunner56"
redis_database             = 0

# Service Ports
searxng_port               = 8080
rclone_port                = 5572

# TinyAuth OAuth Whitelist
tinyauth_oauth_whitelist   = "boden.crouch@gmail.com,halomastar@gmail.com"

# Traefik Configuration
traefik_ca_server          = "https://acme-v02.api.letsencrypt.org/directory"
traefik_dns_challenge      = "true"
traefik_http_challenge     = "false"
traefik_tls_challenge      = "false"
traefik_dns_resolvers      = "1.1.1.1,1.0.0.1"

# CrowdSec
crowdsec_bouncer_enabled   = "true"

# WARP Configuration
warp_license_key           = ""
gost_args                  = "-L :1080"
warp_enable_nat            = "false"
warp_sleep                 = 2
