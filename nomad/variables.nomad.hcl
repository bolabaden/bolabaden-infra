# Shared variables for all Nomad jobs
# This file is included in all job files using Nomad's variable system

# Core Variables
variable "domain" {
  type    = string
  default = "bolabaden.org"
}
variable "config_path" {
  type    = string
  default = "/home/ubuntu/my-media-stack/volumes"
}

variable "root_path" {
  type    = string
  default = "/home/ubuntu/my-media-stack"
}

variable "docker_socket" {
  type    = string
  default = "/var/run/docker.sock"
}

variable "tz" {
  type    = string
  default = "America/Chicago"
}

variable "puid" {
  type    = number
  default = 1001
}

variable "pgid" {
  type    = number
  default = 121
}

variable "umask" {
  type    = string
  default = "002"
}

variable "sudo_password" {
  type        = string
  description = "Admin/sudo password (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "main_username" {
  type    = string
  default = "brunner56"
}

variable "require_auth" {
  type    = string
  default = "true"
}

variable "max_timestamp_drift" {
  type    = number
  default = 300
}

variable "log_level" {
  type    = string
  default = "info"
}

# Service-specific variables
variable "redis_hostname" {
  type    = string
  default = "redis"
}

variable "redis_port" {
  type    = number
  default = 6379
}

variable "redis_password" {
  type        = string
  description = "Redis password (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "redis_database" {
  type    = number
  default = 0
}

variable "redis_username" {
  type    = string
  default = "brunner56"
}

variable "searxng_secret" {
  type        = string
  description = "SearXNG secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "searxng_port" {
  type    = number
  default = 8080
}

variable "authentik_secret_key" {
  type        = string
  description = "Authentik secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "gmail_app_password" {
  type        = string
  description = "Gmail app password for SMTP (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
  default = "nbru aavt hmcx veqs"
}

variable "acme_resolver_email" {
  type    = string
  default = "boden.crouch@gmail.com"
}

variable "tinyauth_secret" {
  type        = string
  description = "TinyAuth secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_google_client_id" {
  type        = string
  description = "TinyAuth Google OAuth client ID (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_google_client_secret" {
  type        = string
  description = "TinyAuth Google OAuth client secret (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_github_client_id" {
  type        = string
  description = "TinyAuth GitHub OAuth client ID (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_github_client_secret" {
  type        = string
  description = "TinyAuth GitHub OAuth client secret (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_users" {
  type        = string
  description = "TinyAuth user credentials with bcrypt hashes (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tinyauth_oauth_whitelist" {
  type    = string
  default = "boden.crouch@gmail.com,halomastar@gmail.com,athenajaguiar@gmail.com,dgorsch2@gmail.com,dgorsch4@gmail.com"
}

variable "cloudflare_email" {
  type    = string
  default = "boden.crouch@gmail.com"
}

variable "cloudflare_api_key" {
  type        = string
  description = "Cloudflare Global API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare Zone ID for DNS management (defined in secrets.auto.tfvars.hcl)"
}

variable "nginx_auth_api_key" {
  type        = string
  description = "Nginx auth middleware API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# API Keys
variable "openai_api_key" {
  type        = string
  description = "OpenAI API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "firecrawl_api_key" {
  type        = string
  description = "Firecrawl API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "anthropic_api_key" {
  type        = string
  description = "Anthropic/Claude API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "mcpo_api_key" {
  type        = string
  description = "MCPO API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "litellm_master_key" {
  type        = string
  description = "LiteLLM master key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "open_webui_secret_key" {
  type        = string
  description = "Open WebUI secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# WARP Variables
variable "warp_license_key" {
  type    = string
  default = ""
}

variable "gost_args" {
  type    = string
  default = "-L :1080"
}

variable "warp_enable_nat" {
  type    = string
  default = "false"
}

variable "warp_sleep" {
  type    = number
  default = 2
}

variable "docker_network_name" {
  type    = string
  default = "warp-nat-net"
}

variable "warp_nat_net_subnet" {
  type    = string
  default = "10.0.2.0/24"
}

variable "warp_nat_net_gateway" {
  type    = string
  default = "10.0.2.1"
}

# Stremio/Media Variables
variable "aiostreams_secret_key" {
  type        = string
  description = "AIOStreams secret key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "aiostreams_addon_password" {
  type        = string
  description = "AIOStreams addon password (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "stremthru_proxy_auth" {
  type        = string
  description = "StremThru proxy authentication credentials (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "stremthru_store_auth" {
  type        = string
  description = "StremThru store authentication with debrid API keys (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "rclone_port" {
  type    = number
  default = 5572
}

# Debrid Service Variables
variable "realdebrid_api_key" {
  type        = string
  description = "Real-Debrid API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "alldebrid_api_key" {
  type        = string
  description = "AllDebrid API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "premiumize_api_key" {
  type        = string
  description = "Premiumize API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "torbox_api_key" {
  type        = string
  description = "TorBox API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "debridlink_api_key" {
  type        = string
  description = "DebridLink API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "offcloud_api_key" {
  type        = string
  description = "Offcloud API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# *Arr Application Variables  
variable "prowlarr_api_key" {
  type        = string
  description = "Prowlarr API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "jackett_api_key" {
  type        = string
  description = "Jackett API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# TMDB Variables
variable "tmdb_api_key" {
  type        = string
  description = "TMDB API key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "tmdb_access_token" {
  type        = string
  description = "TMDB access token (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# Trakt Variables
variable "trakt_client_id" {
  type        = string
  description = "Trakt OAuth client ID (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "trakt_client_secret" {
  type        = string
  description = "Trakt OAuth client secret (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

# CrowdSec Variables
variable "crowdsec_lapi_key" {
  type        = string
  description = "CrowdSec LAPI key (SENSITIVE - defined in secrets.auto.tfvars.hcl)"
}

variable "crowdsec_bouncer_enabled" {
  type    = string
  default = "true"
}

# Traefik ACME Variables
variable "traefik_ca_server" {
  type    = string
  default = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "traefik_dns_challenge" {
  type    = string
  default = "true"
}

variable "traefik_dns_resolvers" {
  type    = string
  default = "1.1.1.1,1.0.0.1"
}

variable "traefik_http_challenge" {
  type    = string
  default = "false"
}

variable "traefik_tls_challenge" {
  type    = string
  default = "false"
}

