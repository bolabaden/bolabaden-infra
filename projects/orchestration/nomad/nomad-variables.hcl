# Nomad Variables for Media Stack
# This file defines all variables used across the Nomad job files
# Based on the environment variables from the original Docker Compose configuration

# Common Environment Variables
variable "tz" {
  description = "Timezone"
  type        = string
  default     = "America/Chicago"
}

variable "puid" {
  description = "Process User ID"
  type        = string
  default     = "1002"
}

variable "pgid" {
  description = "Process Group ID"
  type        = string
  default     = "988"
}

variable "umask" {
  description = "File creation mask"
  type        = string
  default     = "002"
}

# Path Configuration
variable "config_path" {
  description = "Configuration path"
  type        = string
  default     = "./configs"
}

variable "certs_path" {
  description = "Certificates path"
  type        = string
  default     = "./certs"
}

variable "root_dir" {
  description = "Root directory"
  type        = string
  default     = "."
}

# Domain Configuration
variable "domain" {
  description = "Primary domain"
  type        = string
  default     = "example.com"
}

variable "duckdns_subdomain" {
  description = "DuckDNS subdomain"
  type        = string
  default     = "example"
}

variable "ts_hostname" {
  description = "Tailscale hostname"
  type        = string
  default     = "example"
}

# Network Configuration
variable "publicnet_subnet" {
  description = "Public network subnet"
  type        = string
  default     = "10.76.0.0/16"
}

variable "publicnet_gateway" {
  description = "Public network gateway"
  type        = string
  default     = "10.76.0.1"
}

variable "publicnet_ip_range" {
  description = "Public network IP range"
  type        = string
  default     = "10.76.0.0/16"
}

variable "tailscale_cidr" {
  description = "Tailscale CIDR"
  type        = string
  default     = "100.64.0.0/10"
}

# Service IP Addresses
variable "mongodb_ipv4_address" {
  description = "MongoDB IPv4 address"
  type        = string
  default     = "10.76.0.50"
}

variable "redis_ipv4_address" {
  description = "Redis IPv4 address"
  type        = string
  default     = "10.76.128.87"
}

variable "qdrant_ipv4_address" {
  description = "Qdrant IPv4 address"
  type        = string
  default     = "10.76.128.44"
}

variable "traefik_ipv4_address" {
  description = "Traefik IPv4 address"
  type        = string
  default     = "10.76.128.85"
}

variable "traefik_error_pages_ipv4_address" {
  description = "Traefik Error Pages IPv4 address"
  type        = string
  default     = "10.76.128.84"
}

variable "watchtower_ipv4_address" {
  description = "Watchtower IPv4 address"
  type        = string
  default     = "10.76.128.83"
}

variable "tinyauth_ipv4_address" {
  description = "TinyAuth IPv4 address"
  type        = string
  default     = "10.76.128.82"
}

variable "whoami_ipv4_address" {
  description = "Whoami IPv4 address"
  type        = string
  default     = "10.76.128.81"
}

variable "code_demo_ipv4_address" {
  description = "Code Demo IPv4 address"
  type        = string
  default     = "10.76.128.80"
}

variable "searxng_ipv4_address" {
  description = "SearxNG IPv4 address"
  type        = string
  default     = "10.76.128.90"
}

variable "dozzle_ipv4_address" {
  description = "Dozzle IPv4 address"
  type        = string
  default     = "10.76.128.89"
}

variable "homepage_ipv4_address" {
  description = "Homepage IPv4 address"
  type        = string
  default     = "10.76.128.88"
}

variable "speedtest_ipv4_address" {
  description = "Speedtest IPv4 address"
  type        = string
  default     = "10.76.128.86"
}

variable "code_dev_ipv4_address" {
  description = "Code Dev IPv4 address"
  type        = string
  default     = "10.76.128.92"
}

variable "flaresolverr_ipv4_address" {
  description = "FlareSolverr IPv4 address"
  type        = string
  default     = "10.76.128.93"
}

variable "nginx_auth_ipv4_address" {
  description = "Nginx Auth IPv4 address"
  type        = string
  default     = "10.76.128.94"
}

variable "warp_ipv4_address" {
  description = "WARP IPv4 address"
  type        = string
  default     = "10.76.128.97"
}

variable "gpt_researcher_ipv4_address" {
  description = "GPT Researcher IPv4 address"
  type        = string
  default     = "10.76.128.43"
}

variable "lobechat_ipv4_address" {
  description = "LobeChat IPv4 address"
  type        = string
  default     = "10.76.128.46"
}

variable "dash_ipv4_address" {
  description = "Dash IPv4 address"
  type        = string
  default     = "10.76.128.23"
}

# Service Hostnames
variable "mongodb_hostname" {
  description = "MongoDB hostname"
  type        = string
  default     = "mongodb"
}

variable "searxng_hostname" {
  description = "SearxNG hostname"
  type        = string
  default     = "searxng"
}

variable "gpt_researcher_hostname" {
  description = "GPT Researcher hostname"
  type        = string
  default     = "gptr"
}

variable "lobechat_hostname" {
  description = "LobeChat hostname"
  type        = string
  default     = "lobechat"
}

# SSL/TLS Configuration
variable "lets_encrypt_email" {
  description = "Let's Encrypt email"
  type        = string
  default     = "admin@example.com"
}

variable "cloudflare_email" {
  description = "Cloudflare email"
  type        = string
  default     = ""
}

variable "cloudflare_dns_api_token" {
  description = "Cloudflare DNS API token"
  type        = string
  default     = ""
}

variable "cloudflare_zone_api_token" {
  description = "Cloudflare Zone API token"
  type        = string
  default     = ""
}

variable "duckdns_token" {
  description = "DuckDNS token"
  type        = string
  default     = ""
}

# Watchtower Configuration
variable "watchtower_cleanup" {
  description = "Watchtower cleanup"
  type        = string
  default     = "true"
}

variable "watchtower_schedule" {
  description = "Watchtower schedule"
  type        = string
  default     = "0 0 6 * * *"
}

variable "watchtower_notification_url" {
  description = "Watchtower notification URL"
  type        = string
  default     = ""
}

variable "watchtower_notification_report" {
  description = "Watchtower notification report"
  type        = string
  default     = "true"
}

# DeUnhealth Configuration
variable "deunhealth_log_level" {
  description = "DeUnhealth log level"
  type        = string
  default     = "debug"
}

variable "deunhealth_health_server_address" {
  description = "DeUnhealth health server address"
  type        = string
  default     = "127.0.0.1:9999"
}

# SearxNG Configuration
variable "searxng_url" {
  description = "SearxNG base URL"
  type        = string
  default     = "http://searxng:8080"
}

# Homepage Configuration
variable "homepage_allowed_hosts" {
  description = "Homepage allowed hosts"
  type        = string
  default     = "*"
}

variable "homepage_var_title" {
  description = "Homepage title"
  type        = string
  default     = "Bolabaden"
}

variable "homepage_var_search_provider" {
  description = "Homepage search provider"
  type        = string
  default     = "google"
}

variable "homepage_var_header_style" {
  description = "Homepage header style"
  type        = string
  default     = ""
}

variable "homepage_var_weather_city" {
  description = "Homepage weather city"
  type        = string
  default     = "Chicago"
}

variable "homepage_var_weather_lat" {
  description = "Homepage weather latitude"
  type        = string
  default     = "41.8781"
}

variable "homepage_var_weather_long" {
  description = "Homepage weather longitude"
  type        = string
  default     = "-87.6298"
}

variable "homepage_var_weather_unit" {
  description = "Homepage weather unit"
  type        = string
  default     = "fahrenheit"
}

# Speedtest Tracker Configuration
variable "speedtest_tracker_admin_email" {
  description = "Speedtest Tracker admin email"
  type        = string
  default     = ""
}

variable "speedtest_tracker_admin_name" {
  description = "Speedtest Tracker admin name"
  type        = string
  default     = ""
}

variable "speedtest_tracker_admin_password" {
  description = "Speedtest Tracker admin password"
  type        = string
  default     = "b00tstr4p"
}

variable "speedtest_tracker_api_rate_limit" {
  description = "Speedtest Tracker API rate limit"
  type        = string
  default     = "60"
}

variable "speedtest_tracker_app_key" {
  description = "Speedtest Tracker app key"
  type        = string
  default     = ""
}

variable "speedtest_tracker_app_name" {
  description = "Speedtest Tracker app name"
  type        = string
  default     = "Speedtest Tracker"
}

variable "speedtest_tracker_app_timezone" {
  description = "Speedtest Tracker app timezone"
  type        = string
  default     = "America/Chicago"
}

variable "speedtest_tracker_app_url" {
  description = "Speedtest Tracker app URL"
  type        = string
  default     = ""
}

variable "speedtest_tracker_asset_url" {
  description = "Speedtest Tracker asset URL"
  type        = string
  default     = ""
}

variable "speedtest_tracker_chart_begin_at_zero" {
  description = "Speedtest Tracker chart begin at zero"
  type        = string
  default     = "true"
}

variable "speedtest_tracker_chart_datetime_format" {
  description = "Speedtest Tracker chart datetime format"
  type        = string
  default     = "j/m G:i"
}

variable "speedtest_tracker_content_width" {
  description = "Speedtest Tracker content width"
  type        = string
  default     = "7xl"
}

variable "speedtest_tracker_datetime_format" {
  description = "Speedtest Tracker datetime format"
  type        = string
  default     = "j M Y, G:i:s"
}

variable "speedtest_tracker_db_connection" {
  description = "Speedtest Tracker DB connection"
  type        = string
  default     = "sqlite"
}

variable "speedtest_tracker_display_timezone" {
  description = "Speedtest Tracker display timezone"
  type        = string
  default     = "America/Chicago"
}

variable "speedtest_tracker_prune_results_older_than" {
  description = "Speedtest Tracker prune results older than"
  type        = string
  default     = "0"
}

variable "speedtest_tracker_public_dashboard" {
  description = "Speedtest Tracker public dashboard"
  type        = string
  default     = "true"
}

variable "speedtest_tracker_blocked_servers" {
  description = "Speedtest Tracker blocked servers"
  type        = string
  default     = ""
}

variable "speedtest_tracker_interface" {
  description = "Speedtest Tracker interface"
  type        = string
  default     = ""
}

variable "speedtest_tracker_schedule" {
  description = "Speedtest Tracker schedule"
  type        = string
  default     = "0 * * * *"
}

variable "speedtest_tracker_servers" {
  description = "Speedtest Tracker servers"
  type        = string
  default     = ""
}

variable "speedtest_tracker_skip_ips" {
  description = "Speedtest Tracker skip IPs"
  type        = string
  default     = ""
}

variable "speedtest_tracker_threshold_download" {
  description = "Speedtest Tracker threshold download"
  type        = string
  default     = "900"
}

variable "speedtest_tracker_threshold_enabled" {
  description = "Speedtest Tracker threshold enabled"
  type        = string
  default     = "true"
}

variable "speedtest_tracker_threshold_ping" {
  description = "Speedtest Tracker threshold ping"
  type        = string
  default     = "25"
}

variable "speedtest_tracker_threshold_upload" {
  description = "Speedtest Tracker threshold upload"
  type        = string
  default     = "900"
}

# TinyAuth Configuration
variable "tinyauth_secret" {
  description = "TinyAuth secret"
  type        = string
  default     = ""
}

variable "tinyauth_app_url" {
  description = "TinyAuth app URL"
  type        = string
  default     = "https://auth.example.com"
}

variable "tinyauth_users" {
  description = "TinyAuth users"
  type        = string
  default     = ""
}

variable "tinyauth_google_client_id" {
  description = "TinyAuth Google client ID"
  type        = string
  default     = ""
}

variable "tinyauth_google_client_secret" {
  description = "TinyAuth Google client secret"
  type        = string
  default     = ""
}

variable "tinyauth_github_client_id" {
  description = "TinyAuth GitHub client ID"
  type        = string
  default     = ""
}

variable "tinyauth_github_client_secret" {
  description = "TinyAuth GitHub client secret"
  type        = string
  default     = ""
}

variable "tinyauth_session_expiry" {
  description = "TinyAuth session expiry"
  type        = string
  default     = "604800"
}

variable "tinyauth_cookie_secure" {
  description = "TinyAuth cookie secure"
  type        = string
  default     = "true"
}

variable "tinyauth_app_title" {
  description = "TinyAuth app title"
  type        = string
  default     = "Bolabaden"
}

variable "tinyauth_login_max_retries" {
  description = "TinyAuth login max retries"
  type        = string
  default     = "15"
}

variable "tinyauth_login_timeout" {
  description = "TinyAuth login timeout"
  type        = string
  default     = "300"
}

variable "tinyauth_oauth_auto_redirect" {
  description = "TinyAuth OAuth auto redirect"
  type        = string
  default     = "none"
}

variable "tinyauth_oauth_whitelist" {
  description = "TinyAuth OAuth whitelist"
  type        = string
  default     = "boden.crouch@gmail.com,halomastar@gmail.com,athenajaguiar@gmail.com,bolabaden.duckdns@gmail.com"
}

# Code Server Configuration
variable "codeserver_password" {
  description = "Code Server password"
  type        = string
  default     = ""
}

variable "codeserver_sudo_password" {
  description = "Code Server sudo password"
  type        = string
  default     = ""
}

variable "codeserver_default_workspace" {
  description = "Code Server default workspace"
  type        = string
  default     = "/workspace"
}

# FlareSolverr Configuration
variable "flaresolverr_port" {
  description = "FlareSolverr port"
  type        = string
  default     = "8191"
}

variable "flaresolverr_log_level" {
  description = "FlareSolverr log level"
  type        = string
  default     = "info"
}

variable "flaresolverr_log_html" {
  description = "FlareSolverr log HTML"
  type        = string
  default     = "false"
}

variable "flaresolverr_captcha_solver" {
  description = "FlareSolverr captcha solver"
  type        = string
  default     = "none"
}

variable "flaresolverr_host" {
  description = "FlareSolverr host"
  type        = string
  default     = "0.0.0.0"
}

variable "flaresolverr_headless" {
  description = "FlareSolverr headless"
  type        = string
  default     = "true"
}

variable "flaresolverr_browser_timeout" {
  description = "FlareSolverr browser timeout"
  type        = string
  default     = "120000"
}

variable "flaresolverr_test_url" {
  description = "FlareSolverr test URL"
  type        = string
  default     = "https://www.google.com"
}

variable "flaresolverr_prometheus_enabled" {
  description = "FlareSolverr Prometheus enabled"
  type        = string
  default     = "false"
}

variable "prometheus_port" {
  description = "Prometheus port"
  type        = string
  default     = "9090"
}

# VPN Configuration
variable "warp_tun_device" {
  description = "WARP TUN device"
  type        = string
  default     = "/dev/net/tun"
}

variable "ts_authkey" {
  description = "Tailscale auth key"
  type        = string
  default     = ""
}

variable "ts_state_dir" {
  description = "Tailscale state directory"
  type        = string
  default     = "/var/lib/tailscale"
}

variable "ts_routes" {
  description = "Tailscale routes"
  type        = string
  default     = "10.76.0.0/16,172.17.0.0/16,100.64.0.0/10"
}

variable "aiostreams_port" {
  description = "AIOStreams port"
  type        = string
  default     = "3005"
}

variable "comet_port" {
  description = "Comet port"
  type        = string
  default     = "2020"
}

# AI Service Configuration
variable "lobechat_access_code" {
  description = "LobeChat access code"
  type        = string
  default     = "brunner56"
}

# AI API Keys
variable "anthropic_api_key" {
  description = "Anthropic API key"
  type        = string
  default     = ""
}

variable "brave_api_key" {
  description = "Brave API key"
  type        = string
  default     = ""
}

variable "deepseek_api_key" {
  description = "DeepSeek API key"
  type        = string
  default     = ""
}

variable "exa_api_key" {
  description = "Exa API key"
  type        = string
  default     = ""
}

variable "firecrawl_api_key" {
  description = "Firecrawl API key"
  type        = string
  default     = ""
}

variable "fire_crawl_api_key" {
  description = "Fire Crawl API key"
  type        = string
  default     = ""
}

variable "gemini_api_key" {
  description = "Gemini API key"
  type        = string
  default     = ""
}

variable "glama_api_key" {
  description = "Glama API key"
  type        = string
  default     = ""
}

variable "groq_api_key" {
  description = "Groq API key"
  type        = string
  default     = ""
}

variable "hf_token" {
  description = "Hugging Face token"
  type        = string
  default     = ""
}

variable "huggingface_access_token" {
  description = "Hugging Face access token"
  type        = string
  default     = ""
}

variable "huggingface_api_token" {
  description = "Hugging Face API token"
  type        = string
  default     = ""
}

variable "langchain_api_key" {
  description = "LangChain API key"
  type        = string
  default     = ""
}

variable "mistral_api_key" {
  description = "Mistral API key"
  type        = string
  default     = ""
}

variable "mistralai_api_key" {
  description = "MistralAI API key"
  type        = string
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  default     = ""
}

variable "openrouter_api_key" {
  description = "OpenRouter API key"
  type        = string
  default     = ""
}

variable "perplexity_api_key" {
  description = "Perplexity API key"
  type        = string
  default     = ""
}

variable "perplexityai_api_key" {
  description = "PerplexityAI API key"
  type        = string
  default     = ""
}

variable "replicate_api_key" {
  description = "Replicate API key"
  type        = string
  default     = ""
}

variable "revid_api_key" {
  description = "Revid API key"
  type        = string
  default     = ""
}

variable "sambanova_api_key" {
  description = "SambaNova API key"
  type        = string
  default     = ""
}

variable "search1api_key" {
  description = "Search1API key"
  type        = string
  default     = ""
}

variable "serpapi_api_key" {
  description = "SerpAPI key"
  type        = string
  default     = ""
}

variable "tavily_api_key" {
  description = "Tavily API key"
  type        = string
  default     = ""
}

variable "togetherai_api_key" {
  description = "TogetherAI API key"
  type        = string
  default     = ""
}

variable "unify_api_key" {
  description = "Unify API key"
  type        = string
  default     = ""
}

variable "upstage_api_key" {
  description = "Upstage API key"
  type        = string
  default     = ""
}

variable "upstageai_api_key" {
  description = "UpstageAI API key"
  type        = string
  default     = ""
}

variable "you_api_key" {
  description = "You API key"
  type        = string
  default     = ""
}

variable "next_public_ga_measurement_id" {
  description = "Next.js Google Analytics measurement ID"
  type        = string
  default     = ""
} 

variable "gluetun_premiumize_nl_ipv4_address" {
  description = "Gluetun Premiumize NL IPv4 address"
  type        = string
  default     = "10.76.128.119"
}

variable "bocloud_nextjs_ipv4_address" {
  description = "Bocloud Next.js IPv4 address"
  type        = string
  default     = "10.76.128.45"
}

variable "maintainerr_ipv4_address" {
  description = "Maintainerr IPv4 address"
  type        = string
  default     = "10.76.128.84"
}

variable "plex_ipv4_address" {
  description = "Plex IPv4 address"
  type        = string
  default     = "10.76.128.95"
}

variable "stremthru_ipv4_address" {
  description = "Stremthru IPv4 address"
  type        = string
  default     = "10.76.128.99"
}

variable "riven_ipv4_address" {
  description = "Riven Frontend IPv4 address"
  type        = string
  default     = "10.76.128.100"
}

variable "riven_core_ipv4_address" {
  description = "Riven Core IPv4 address"
  type        = string
  default     = "10.76.128.101"
}

variable "riven_db_ipv4_address" {
  description = "Riven DB IPv4 address"
  type        = string
  default     = "10.76.128.102"
}

variable "tautulli_ipv4_address" {
  description = "Tautulli IPv4 address"
  type        = string
  default     = "10.76.128.103"
}

variable "crowdsec_ipv4_address" {
  description = "Crowdsec IPv4 address"
  type        = string
  default     = "10.76.128.104"
}

variable "gatus_ipv4_address" {
  description = "Gatus IPv4 address"
  type        = string
  default     = "10.76.128.105"
}

variable "homer_ipv4_address" {
  description = "Homer IPv4 address"
  type        = string
  default     = "10.76.0.106"
}

variable "wizarr_ipv4_address" {
  description = "Wizarr IPv4 address"
  type        = string
  default     = "10.76.128.107"
}

variable "plex_watchlist_ipv4_address" {
  description = "Plex Watchlist IPv4 address"
  type        = string
  default     = "10.76.52.97"
}

variable "realdebrid_account_monitor_ipv4_address" {
  description = "RealDebrid Account Monitor IPv4 address"
  type        = string
  default     = "10.76.128.109"
}

variable "rclone_ipv4_address" {
  description = "Rclone IPv4 address"
  type        = string
  default     = "10.76.128.111"
}

variable "plex_authentication_ipv4_address" {
  description = "Plex Authentication IPv4 address"
  type        = string
  default     = "10.76.128.112"
}

variable "plex_request_ipv4_address" {
  description = "Plex Request IPv4 address"
  type        = string
  default     = "10.76.128.113"
}

variable "jellyseerr_ipv4_address" {
  description = "Jellyseerr IPv4 address"
  type        = string
  default     = "10.76.128.115"
}

variable "overseerr_ipv4_address" {
  description = "Overseerr IPv4 address"
  type        = string
  default     = "10.76.128.116"
}

variable "jellyfin_ipv4_address" {
  description = "Jellyfin IPv4 address"
  type        = string
  default     = "10.76.128.120"
}

variable "radarr_ipv4_address" {
  description = "Radarr IPv4 address"
  type        = string
  default     = "10.76.128.121"
}

variable "sonarr_ipv4_address" {
  description = "Sonarr IPv4 address"
  type        = string
  default     = "10.76.128.122"
}

variable "sonarr_anime_ipv4_address" {
  description = "Sonarr Anime IPv4 address"
  type        = string
  default     = "10.76.128.123"
}

variable "firecrawl_api_ipv4_address" {
  description = "Firecrawl API IPv4 address"
  type        = string
  default     = "10.76.128.127"
}

variable "firecrawl_worker_ipv4_address" {
  description = "Firecrawl Worker IPv4 address"
  type        = string
  default     = "10.76.128.128"
}

variable "firecrawl_playwright_ipv4_address" {
  description = "Firecrawl Playwright IPv4 address"
  type        = string
  default     = "10.76.128.130"
}

variable "decluttarr_ipv4_address" {
  description = "Decluttarr IPv4 address"
  type        = string
  default     = "10.76.128.21"
}

variable "whisparr_ipv4_address" {
  description = "Whisparr IPv4 address"
  type        = string
  default     = "10.76.0.120"
}

variable "aiostreams_ipv4_address" {
  description = "AIOStreams IPv4 address"
  type        = string
  default     = "10.76.128.200"
}

variable "plex_repair_ipv4_address" {
  description = "Plex Repair IPv4 address"
  type        = string
  default     = "10.76.0.115"
}

variable "script_runner_ipv4_address" {
  description = "Script Runner IPv4 address"
  type        = string
  default     = "10.76.0.116"
}

variable "open_webui_ipv4_address" {
  description = "Open WebUI IPv4 address"
  type        = string
  default     = "10.76.128.118"
}

variable "autoscan_ipv4_address" {
  description = "Autoscan IPv4 address"
  type        = string
  default     = "10.76.0.119"
}

variable "dashboard_ipv4_address" {
  description = "Dashboard IPv4 address"
  type        = string
  default     = "10.76.128.150"
}

variable "headscale_ipv4_address" {
  description = "Headscale IPv4 address"
  type        = string
  default     = "10.76.0.106"
}

variable "meilisearch_ipv4_address" {
  description = "Meilisearch IPv4 address"
  type        = string
  default     = "10.76.128.124"
}

# Service Hostnames
variable "radarr_hostname" {
  description = "Radarr hostname"
  type        = string
  default     = "radarr"
}

variable "tautulli_hostname" {
  description = "Tautulli hostname"
  type        = string
  default     = "tautulli"
}

variable "aiostreams_hostname" {
  description = "AIOStreams hostname"
  type        = string
  default     = "aiostreams"
}

# Rclone Configuration
variable "rclone_user" {
  description = "Rclone username"
  type        = string
  default     = "admin"
}

variable "rclone_pass" {
  description = "Rclone password"
  type        = string
  default     = ""
}

# Main password for services
variable "sudo_password" {
  description = "Sudo password"
  type        = string
  default     = ""
}

# Plex configuration
variable "plex_claim" {
  description = "Plex claim token"
  type        = string
  default     = ""
}

variable "plex_token" {
  description = "Plex authentication token"
  type        = string
  default     = ""
}

variable "advertise_ip" {
  description = "Plex advertise IP"
  type        = string
  default     = ""
}

variable "email_to" {
  description = "Email to send notifications to"
  type        = string
  default     = ""
}

variable "smtp_from" {
  description = "SMTP from address"
  type        = string
  default     = ""
}

variable "smtp_port" {
  description = "SMTP port"
  type        = string
  default     = "587"
}

variable "wait_for_mount_paths" {
  description = "Paths to wait for before starting service"
  type        = string
  default     = ""
}

variable "wait_for_urls" {
  description = "URLs to wait for before starting service"
  type        = string
  default     = ""
}

# Recyclarr Configuration
variable "recyclarr_api_key" {
  description = "Recyclarr API key"
  type        = string
  default     = ""
}

# Jellyfin Configuration
variable "jellyfin_api_key" {
  description = "Jellyfin API key"
  type        = string
  default     = ""
}

variable "jellyfin_published_server_url" {
  description = "Jellyfin published server URL"
  type        = string
  default     = ""
}

# Open WebUI Configuration
variable "webui_auth" {
  description = "Open WebUI authentication enabled"
  type        = string
  default     = "False"
}

variable "webui_name" {
  description = "Open WebUI name"
  type        = string
  default     = "BadenAI"
}

variable "webui_url" {
  description = "Open WebUI URL"
  type        = string
  default     = ""
}

variable "webui_secret_key" {
  description = "Open WebUI secret key"
  type        = string
  default     = ""
}

# Stremio Configuration
variable "stremio_server_url" {
  description = "Stremio server URL"
  type        = string
  default     = ""
}

variable "stremio_webui_location" {
  description = "Stremio web UI location"
  type        = string
  default     = ""
}

variable "no_cors" {
  description = "Stremio no CORS"
  type        = string
  default     = "0"
}

variable "casting_disabled" {
  description = "Stremio casting disabled"
  type        = string
  default     = "1"
}

variable "stremio_default_username" {
  description = "Stremio default username"
  type        = string
  default     = ""
}

variable "stremio_default_password" {
  description = "Stremio default password"
  type        = string
  default     = ""
}

# AIOStreams Configuration
variable "aiostreams_addon_name" {
  description = "AIOStreams addon name"
  type        = string
  default     = "BadenAIO"
}

variable "aiostreams_addon_id" {
  description = "AIOStreams addon ID"
  type        = string
  default     = ""
}

variable "aiostreams_base_url" {
  description = "AIOStreams base URL"
  type        = string
  default     = ""
}

variable "aiostreams_secret_key" {
  description = "AIOStreams secret key"
  type        = string
  default     = ""
}

variable "aiostreams_addon_password" {
  description = "AIOStreams addon password"
  type        = string
  default     = ""
}

variable "aiostreams_database_uri" {
  description = "AIOStreams database URI"
  type        = string
  default     = ""
}

variable "tmdb_access_token" {
  description = "TMDB access token"
  type        = string
  default     = ""
}

variable "alldebrid_api_key" {
  description = "AllDebrid API key"
  type        = string
  default     = ""
}

variable "debridlink_api_key" {
  description = "DebridLink API key"
  type        = string
  default     = ""
}

variable "offcloud_api_key" {
  description = "OffCloud API key"
  type        = string
  default     = ""
}

variable "offcloud_email" {
  description = "OffCloud email"
  type        = string
  default     = ""
}

variable "offcloud_password" {
  description = "OffCloud password"
  type        = string
  default     = ""
}

variable "putio_client_id" {
  description = "Put.io client ID"
  type        = string
  default     = ""
}

variable "putio_client_secret" {
  description = "Put.io client secret"
  type        = string
  default     = ""
}

variable "easynews_username" {
  description = "EasyNews username"
  type        = string
  default     = ""
}

variable "easynews_password" {
  description = "EasyNews password"
  type        = string
  default     = ""
}

variable "easydebrid_api_key" {
  description = "EasyDebrid API key"
  type        = string
  default     = ""
}

variable "pikpak_email" {
  description = "PikPak email"
  type        = string
  default     = ""
}

variable "pikpak_password" {
  description = "PikPak password"
  type        = string
  default     = ""
}

variable "seedr_encoded_token" {
  description = "Seedr encoded token"
  type        = string
  default     = ""
}

variable "aiostreams_custom_html" {
  description = "AIOStreams custom HTML"
  type        = string
  default     = ""
}

variable "aiostreams_trusted_uuids" {
  description = "AIOStreams trusted UUIDs"
  type        = string
  default     = ""
}

variable "regex_filter_access" {
  description = "AIOStreams regex filter access"
  type        = string
  default     = "trusted"
}

variable "aliased_configurations" {
  description = "AIOStreams aliased configurations"
  type        = string
  default     = ""
}

variable "aiostreams_default_max_cache_size" {
  description = "AIOStreams default max cache size"
  type        = string
  default     = "100000"
}

variable "aiostreams_proxy_ip_cache_ttl" {
  description = "AIOStreams proxy IP cache TTL"
  type        = string
  default     = "900"
}

variable "aiostreams_manifest_cache_ttl" {
  description = "AIOStreams manifest cache TTL"
  type        = string
  default     = "300"
}

variable "aiostreams_subtitle_cache_ttl" {
  description = "AIOStreams subtitle cache TTL"
  type        = string
  default     = "300"
}

variable "aiostreams_stream_cache_ttl" {
  description = "AIOStreams stream cache TTL"
  type        = string
  default     = "1"
}

variable "aiostreams_catalog_cache_ttl" {
  description = "AIOStreams catalog cache TTL"
  type        = string
  default     = "300"
}

variable "aiostreams_meta_cache_ttl" {
  description = "AIOStreams meta cache TTL"
  type        = string
  default     = "300"
}

variable "aiostreams_addon_catalog_cache_ttl" {
  description = "AIOStreams addon catalog cache TTL"
  type        = string
  default     = "300"
}

variable "aiostreams_rpdb_api_key_validity_cache_ttl" {
  description = "AIOStreams RPDB API key validity cache TTL"
  type        = string
  default     = "604800"
}

variable "aiostreams_disable_self_scraping" {
  description = "AIOStreams disable self scraping"
  type        = string
  default     = "false"
}

variable "disabled_hosts" {
  description = "AIOStreams disabled hosts"
  type        = string
  default     = ""
}

variable "disabled_addons" {
  description = "AIOStreams disabled addons"
  type        = string
  default     = ""
}

variable "disabled_services" {
  description = "AIOStreams disabled services"
  type        = string
  default     = ""
}

variable "aiostreams_log_level" {
  description = "AIOStreams log level"
  type        = string
  default     = "verbose"
}

variable "aiostreams_log_format" {
  description = "AIOStreams log format"
  type        = string
  default     = "text"
}

variable "aiostreams_log_sensitive_info" {
  description = "AIOStreams log sensitive info"
  type        = string
  default     = "true"
}

variable "aiostreams_addon_proxy" {
  description = "AIOStreams addon proxy"
  type        = string
  default     = ""
}

variable "aiostreams_addon_proxy_config" {
  description = "AIOStreams addon proxy config"
  type        = string
  default     = ""
}

variable "aiostreams_default_proxy_enabled" {
  description = "AIOStreams default proxy enabled"
  type        = string
  default     = "true"
}

variable "aiostreams_force_proxy_id" {
  description = "AIOStreams force proxy ID"
  type        = string
  default     = "stremthru"
}

variable "aiostreams_default_proxy_url" {
  description = "AIOStreams default proxy URL"
  type        = string
  default     = ""
}

variable "aiostreams_force_proxy_url" {
  description = "AIOStreams force proxy URL"
  type        = string
  default     = ""
}

variable "stremthru_credentials" {
  description = "Stremthru proxy credentials"
  type        = string
  default     = ""
}

variable "aiostreams_default_proxy_credentials" {
  description = "AIOStreams default proxy credentials"
  type        = string
  default     = ""
}

variable "aiostreams_force_proxy_credentials" {
  description = "AIOStreams force proxy credentials"
  type        = string
  default     = ""
}

variable "aiostreams_default_proxy_public_ip" {
  description = "AIOStreams default proxy public IP"
  type        = string
  default     = ""
}

variable "aiostreams_force_proxy_public_ip" {
  description = "AIOStreams force proxy public IP"
  type        = string
  default     = ""
}

variable "aiostreams_default_proxy_proxied_services" {
  description = "AIOStreams default proxy proxied services"
  type        = string
  default     = ""
}

variable "aiostreams_force_proxy_proxied_services" {
  description = "AIOStreams force proxy proxied services"
  type        = string
  default     = ""
}

variable "aiostreams_force_proxy_disable_proxied_addons" {
  description = "AIOStreams force proxy disable proxied addons"
  type        = string
  default     = "false"
}

variable "aiostreams_encrypt_mediaflow_urls" {
  description = "AIOStreams encrypt MediaFlow URLs"
  type        = string
  default     = "true"
}

variable "aiostreams_encrypt_stremthru_urls" {
  description = "AIOStreams encrypt StremThru URLs"
  type        = string
  default     = "true"
}

variable "aiostreams_force_public_proxy_host" {
  description = "AIOStreams force public proxy host"
  type        = string
  default     = ""
}

variable "aiostreams_force_public_proxy_port" {
  description = "AIOStreams force public proxy port"
  type        = string
  default     = ""
}

variable "aiostreams_force_public_proxy_protocol" {
  description = "AIOStreams force public proxy protocol"
  type        = string
  default     = ""
}

variable "aiostreams_default_timeout" {
  description = "AIOStreams default timeout"
  type        = string
  default     = "15000"
}

variable "aiostreams_max_addons" {
  description = "AIOStreams max addons"
  type        = string
  default     = "100"
}

variable "aiostreams_max_groups" {
  description = "AIOStreams max groups"
  type        = string
  default     = "50"
}

variable "aiostreams_max_keyword_filters" {
  description = "AIOStreams max keyword filters"
  type        = string
  default     = "50"
}

variable "aiostreams_max_condition_filters" {
  description = "AIOStreams max condition filters"
  type        = string
  default     = "200"
}

variable "aiostreams_max_timeout" {
  description = "AIOStreams max timeout"
  type        = string
  default     = "50000"
}

variable "aiostreams_min_timeout" {
  description = "AIOStreams min timeout"
  type        = string
  default     = "1000"
}

variable "aiostreams_disable_rate_limits" {
  description = "AIOStreams disable rate limits"
  type        = string
  default     = "false"
}

variable "aiostreams_static_rate_limit_window" {
  description = "AIOStreams static rate limit window"
  type        = string
  default     = "5"
}

variable "aiostreams_static_rate_limit_max_requests" {
  description = "AIOStreams static rate limit max requests"
  type        = string
  default     = "75"
}

variable "aiostreams_user_api_rate_limit_window" {
  description = "AIOStreams user API rate limit window"
  type        = string
  default     = "5"
}

variable "aiostreams_user_api_rate_limit_max_requests" {
  description = "AIOStreams user API rate limit max requests"
  type        = string
  default     = "5"
}

variable "aiostreams_stream_api_rate_limit_window" {
  description = "AIOStreams stream API rate limit window"
  type        = string
  default     = "5"
}

variable "aiostreams_stream_api_rate_limit_max_requests" {
  description = "AIOStreams stream API rate limit max requests"
  type        = string
  default     = "10"
}

variable "aiostreams_format_api_rate_limit_window" {
  description = "AIOStreams format API rate limit window"
  type        = string
  default     = "5"
}

variable "aiostreams_format_api_rate_limit_max_requests" {
  description = "AIOStreams format API rate limit max requests"
  type        = string
  default     = "30"
}

variable "aiostreams_catalog_api_rate_limit_window" {
  description = "AIOStreams catalog API rate limit window"
  type        = string
  default     = "5"
}

variable "aiostreams_catalog_api_rate_limit_max_requests" {
  description = "AIOStreams catalog API rate limit max requests"
  type        = string
  default     = "5"
}

variable "aiostreams_stremio_stream_rate_limit_window" {
  description = "AIOStreams Stremio stream rate limit window"
  type        = string
  default     = "15"
}

variable "aiostreams_stremio_stream_rate_limit_max_requests" {
  description = "AIOStreams Stremio stream rate limit max requests"
  type        = string
  default     = "10"
}

variable "aiostreams_stremio_catalog_rate_limit_window" {
  description = "AIOStreams Stremio catalog rate limit window"
  type        = string
  default     = "5"
}

variable "aiostreams_stremio_catalog_rate_limit_max_requests" {
  description = "AIOStreams Stremio catalog rate limit max requests"
  type        = string
  default     = "30"
}

variable "aiostreams_stremio_manifest_rate_limit_window" {
  description = "AIOStreams Stremio manifest rate limit window"
  type        = string
  default     = "5"
}

variable "aiostreams_stremio_manifest_rate_limit_max_requests" {
  description = "AIOStreams Stremio manifest rate limit max requests"
  type        = string
  default     = "5"
}

variable "aiostreams_stremio_subtitle_rate_limit_window" {
  description = "AIOStreams Stremio subtitle rate limit window"
  type        = string
  default     = "5"
}

variable "aiostreams_stremio_subtitle_rate_limit_max_requests" {
  description = "AIOStreams Stremio subtitle rate limit max requests"
  type        = string
  default     = "10"
}

variable "aiostreams_stremio_meta_rate_limit_window" {
  description = "AIOStreams Stremio meta rate limit window"
  type        = string
  default     = "5"
}

variable "aiostreams_stremio_meta_rate_limit_max_requests" {
  description = "AIOStreams Stremio meta rate limit max requests"
  type        = string
  default     = "15"
}

variable "aiostreams_prune_interval" {
  description = "AIOStreams prune interval"
  type        = string
  default     = "86400"
}

variable "aiostreams_prune_max_days" {
  description = "AIOStreams prune max days"
  type        = string
  default     = "-1"
}

variable "comet_internal_url" {
  description = "Comet internal URL"
  type        = string
  default     = ""
}

variable "mediafusion_internal_url" {
  description = "MediaFusion internal URL"
  type        = string
  default     = ""
}

variable "jackettio_url" {
  description = "Jackettio URL"
  type        = string
  default     = "https://jackettio.elfhosted.com/"
}

variable "jackettio_stremthru_url" {
  description = "Jackettio StremThru URL"
  type        = string
  default     = "https://stremthru.13377001.xyz"
}

variable "stremthru_store_internal_url" {
  description = "StremThru Store internal URL"
  type        = string
  default     = ""
}

variable "stremthru_torz_url" {
  description = "StremThru Torz URL"
  type        = string
  default     = "https://stremthru.elfhosted.com/stremio/torz"
}

variable "stremthru_torz_internal_url" {
  description = "StremThru Torz internal URL"
  type        = string
  default     = ""
}

variable "easynews_plus_url" {
  description = "EasyNews Plus URL"
  type        = string
  default     = "https://b89262c192b0-stremio-easynews-addon.baby-beamup.club/"
}

variable "easynews_plus_plus_url" {
  description = "EasyNews Plus Plus URL"
  type        = string
  default     = "https://easynews-cloudflare-worker.jqrw92fchz.workers.dev/"
}

variable "streamfusion_url" {
  description = "StreamFusion URL"
  type        = string
  default     = "https://stream-fusion.stremiofr.com/"
}

variable "marvel_universe_url" {
  description = "Marvel Universe URL"
  type        = string
  default     = "https://addon-marvel.onrender.com/"
}

variable "dc_universe_url" {
  description = "DC Universe URL"
  type        = string
  default     = "https://addon-dc-cq85.onrender.com/"
}

variable "star_wars_universe_url" {
  description = "Star Wars Universe URL"
  type        = string
  default     = "https://addon-star-wars-u9e3.onrender.com/"
}

variable "anime_kitsu_url" {
  description = "Anime Kitsu URL"
  type        = string
  default     = "https://anime-kitsu.strem.fun/"
}

variable "nuviostreams_url" {
  description = "Nuviostreams URL"
  type        = string
  default     = "https://nuviostreams.hayd.uk/"
}

variable "tmdb_collections_url" {
  description = "TMDB Collections URL"
  type        = string
  default     = "https://61ab9c85a149-tmdb-collections.baby-beamup.club/"
}

variable "orion_stremio_addon_url" {
  description = "Orion Stremio Addon URL"
  type        = string
  default     = "https://5a0d1888fa64-orion.baby-beamup.club/"
}

variable "peerflix_url" {
  description = "Peerflix URL"
  type        = string
  default     = "https://peerflix-addon.onrender.com/"
}

variable "torbox_stremio_url" {
  description = "Torbox Stremio URL"
  type        = string
  default     = "https://stremio.torbox.app/"
}

variable "easynews_url" {
  description = "EasyNews URL"
  type        = string
  default     = "https://ea627ddf0ee7-easynews.baby-beamup.club/"
}

variable "debridio_url" {
  description = "Debridio URL"
  type        = string
  default     = "https://addon.debridio.com/"
}

variable "debridio_tvdb_url" {
  description = "Debridio TVDB URL"
  type        = string
  default     = "https://tvdb-addon.debridio.com/"
}

variable "debridio_tmdb_url" {
  description = "Debridio TMDB URL"
  type        = string
  default     = "https://tmdb-addon.debridio.com/"
}

variable "debridio_tv_url" {
  description = "Debridio TV URL"
  type        = string
  default     = "https://tv-addon.debridio.com/"
}

variable "debridio_watchtower_url" {
  description = "Debridio Watchtower URL"
  type        = string
  default     = "https://wt-addon.debridio.com/"
}

variable "opensubtitles_url" {
  description = "OpenSubtitles URL"
  type        = string
  default     = "https://opensubtitles-v3.strem.io/"
}

variable "torrent_catalogs_url" {
  description = "Torrent Catalogs URL"
  type        = string
  default     = "https://torrent-catalogs.strem.fun/"
}

variable "rpdb_catalogs_url" {
  description = "RPDB Catalogs URL"
  type        = string
  default     = "https://1fe84bc728af-rpdb.baby-beamup.club/"
}

variable "streaming_catalogs_url" {
  description = "Streaming Catalogs URL"
  type        = string
  default     = "https://7a82163c306e-stremio-netflix-catalog-addon.baby-beamup.club/"
}

variable "anime_catalogs_url" {
  description = "Anime Catalogs URL"
  type        = string
  default     = "https://1fe84bc728af-stremio-anime-catalogs.baby-beamup.club/"
}

variable "doctor_who_universe_url" {
  description = "Doctor Who Universe URL"
  type        = string
  default     = "https://new-who.onrender.com"
}

variable "webstreamr_url" {
  description = "Webstreamr URL"
  type        = string
  default     = "https://webstreamr.hayd.uk"
}

# Meilisearch Configuration
variable "meili_master_key" {
  description = "Meilisearch master key"
  type        = string
  default     = ""
}

# Jackett Configuration
variable "jackett_internal_url" {
  description = "Jackett internal URL"
  type        = string
  default     = "http://jackett:9117"
}

variable "jackett_port" {
  description = "Jackett port"
  type        = string
  default     = "9117"
}

variable "jackett_ratelimit" {
  description = "Jackett rate limit"
  type        = string
  default     = "false"
}

# Prowlarr Configuration
variable "prowlarr_internal_url" {
  description = "Prowlarr internal URL"
  type        = string
  default     = "http://prowlarr:9696"
}

variable "prowlarr_ratelimit" {
  description = "Prowlarr rate limit"
  type        = string
  default     = "false"
}

# Comet Configuration
variable "comet_indexer_manager_type" {
  description = "Comet indexer manager type"
  type        = string
  default     = "prowlarr"
}

variable "comet_indexer_manager_url" {
  description = "Comet indexer manager URL"
  type        = string
  default     = "http://prowlarr:9696"
}

variable "comet_indexer_manager_api_key" {
  description = "Comet indexer manager API key"
  type        = string
  default     = ""
}

variable "comet_indexer_manager_indexers" {
  description = "Comet indexer manager indexers"
  type        = string
  default     = "["animetosho", "anirena", "bitsearch", "eztv", "nyaasi", "thepiratebay", "therarbg", "yts"]"
}

variable "comet_ratelimit" {
  description = "Comet rate limit"
  type        = string
  default     = "false"
}

# MediaFusion Configuration
variable "is_scrap_from_prowlarr" {
  description = "MediaFusion enable Prowlarr scraping"
  type        = string
  default     = "False"
}

variable "is_scrap_from_jackett" {
  description = "MediaFusion enable Jackett scraping"
  type        = string
  default     = "False"
}

variable "is_scrap_from_bt4g" {
  description = "MediaFusion enable BT4G scraping"
  type        = string
  default     = "True"
}

variable "bt4g_url" {
  description = "BT4G service URL"
  type        = string
  default     = "https://bt4gprx.com"
}

# Torrenting Services
variable "deluge_loglevel" {
  description = "Deluge log level"
  type        = string
  default     = "info"
}

variable "qb_torrenting_port" {
  description = "qBittorrent torrenting port"
  type        = string
  default     = "6881"
}

variable "qb_webui_port" {
  description = "qBittorrent web UI port"
  type        = string
  default     = "8084"
}

variable "qbittorrent_username" {
  description = "qBittorrent username"
  type        = string
  default     = "admin"
}

variable "qbittorrent_password" {
  description = "qBittorrent password"
  type        = string
  default     = "adminadmin"
}

variable "transmission_user" {
  description = "Transmission username"
  type        = string
  default     = "admin"
}

variable "transmission_pass" {
  description = "Transmission password"
  type        = string
  default     = "admin"
}

variable "transmission_peerport" {
  description = "Transmission peer port"
  type        = string
  default     = "51413"
}

# Zurg Configuration
variable "zurg_log_level" {
  description = "Zurg log level"
  type        = string
  default     = "debug"
}

# General Domain Configuration
variable "second_domain" {
  description = "Second domain"
  type        = string
  default     = "bocloud.org"
}

# K8s App Name
variable "k8s_app_name" {
  description = "Kubernetes app name"
  type        = string
  default     = ""
}

# Elf App Name
variable "elf_app_name" {
  description = "Elfhosted app name"
  type        = string
  default     = ""
}

# RealDebrid API Keys
variable "real_debrid_api_key" {
  description = "RealDebrid API key (alternative)"
  type        = string
  default     = ""
}

variable "realdebrid_token" {
  description = "RealDebrid token (alternative)"
  type        = string
  default     = ""
}

variable "jellystat_db_password" {
  description = "Jellystat database password"
  type        = string
  default     = ""
}

variable "jellystat_jwt_secret" {
  description = "Jellystat JWT secret"
  type        = string
  default     = ""
}

variable "zilean_api_url" {
  description = "Zilean API URL"
  type        = string
  default     = "https://zilean.elfhosted.com"
} 