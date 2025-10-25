# Nomad Variables File (Non-Sensitive Configuration)
# This file contains non-sensitive configuration variables
# Auto-loaded when using: nomad job run docker-compose.nomad.hcl
# For secrets (API keys, passwords), see secrets.auto.tfvars.hcl

# Core Configuration
domain             = "bolabaden.org"
duckdns_subdomain  = "bolabaden"
duckdns_domain     = "bolabaden.duckdns.org"
ts_hostname        = "micklethefickle"
ts_domain          = "micklethefickle.noodlefish-pound.ts.net"
ts_base_domain     = "noodlefish-pound.ts.net"
external_ip        = "170.9.225.137"
stack_name         = "my-media-stack"
main_username      = "brunner56"

# Paths
root_dir           = "/home/ubuntu/my-media-stack"
root_path          = "/home/ubuntu/my-media-stack"
repo_root          = "/home/ubuntu/my-media-stack"
config_path        = "/home/ubuntu/my-media-stack/volumes"
certs_dir          = "/home/ubuntu/my-media-stack/certs"
certs_path         = "/home/ubuntu/my-media-stack/certs"
data_dir           = "/home/ubuntu/my-media-stack/data"
data_path          = "/home/ubuntu/my-media-stack/data"
secrets_dir        = "/home/ubuntu/my-media-stack/secrets"
secrets_path       = "/home/ubuntu/my-media-stack/secrets"
credentials_directory = "/home/ubuntu/my-media-stack/secrets"
src_dir            = "/home/ubuntu/my-media-stack/projects"
src_path           = "/home/ubuntu/my-media-stack/projects"
backup_dir         = "/home/ubuntu/my-media-stack/backup"

# Docker Configuration
docker_socket      = "/var/run/docker.sock"
docker_network     = "my-media-stack_publicnet"

# System Configuration
tz                 = "America/Chicago"
puid               = 1001
pgid               = 121
umask              = "002"
arch_name          = "arm64"
arch_platform      = "linux/arm64"
arch_isa           = "armv8"
arch_variant       = "arm64v8"
cpu_count          = 4
cpu_cores          = 4

# Email Configuration
acme_resolver_email = "boden.crouch@gmail.com"

# Redis Configuration
redis_hostname     = "redis"
redis_port         = "6379"
redis_username     = "brunner56"
redis_database     = "0"

# MongoDB Configuration
mongodb_hostname   = "mongodb"

# Compose Configuration
compose_bake       = "true"
compose_project_name = "my-media-stack"
compose_buildkit   = "1"

# Network Subnets
nginx_traefik_subnet  = "10.0.8.0/24"
nginx_traefik_gateway = "10.0.8.1"
backend_subnet        = "10.0.7.0/24"
backend_gateway       = "10.0.7.1"
publicnet_subnet      = "10.76.0.0/16"
publicnet_gateway     = "10.76.0.1"
warp_nat_net_subnet   = "10.0.2.0/24"
warp_nat_net_gateway  = "10.0.2.1"
crowdsec_gf_subnet    = "10.0.6.0/24"

# Service Hostnames and Ports
codeserver_hostname        = "code-server"
codeserver_port            = 8080
codeserver_default_workspace = "/workspace"

deluge_hostname            = "deluge"
deluge_port                = 8112
deluge_username            = "ubuntu"

duplicati_hostname         = "duplicati"
duplicati_port             = 8200

grafana_hostname           = "grafana"
grafana_port               = 3000
grafana_username           = "brunner56"
grafana_log_level          = "debug"
grafana_serve_from_sub_path = "false"

dashy_hostname             = "dashy"
dashy_port                 = 4002

# *Arr Services
autobrr_port               = 7474
bazarr_port                = 6767
bazarr_hostname            = "bazarr"
lidarr_port                = 8686
lidarr_hostname            = "lidarr"
notifiarr_hostname         = "notifiarr"
notifiarr_port             = 5000
prowlarr_hostname          = "prowlarr"
prowlarr_port              = 9696
radarr_port                = 7878
readarr_port               = 8787
sonarr_port                = 8989
sonarr_hostname            = "sonarr"
sonarr_root_folder         = "/storage/realdebrid-zurg/shows"

# Jackett
jackett_hostname           = "jackett"
jackett_port               = 9117

# Jellyfin/Emby
jellyfin_hostname          = "jellyfin"
jellyfin_port              = 8096
emby_hostname              = "emby"
emby_port                  = 8096

# FlareSolverr
flaresolverr_hostname      = "flaresolverr"
flaresolverr_port          = 8191

# Jellyseerr/Overseerr
jellyseerr_hostname        = "jellyseerr"
jellyseerr_port            = 5055
overseerr_hostname         = "overseerr"
overseerr_port             = 5055

# Jellystat
jellystat_hostname         = "jellystat"
jellystat_port             = 3000

# Kavita
kavita_hostname            = "kavita"
kavita_port                = 5000

# Khoj
khoj_postgres_host         = "khoj-postgres"
khoj_admin_email           = "boden.crouch@gmail.com"
khoj_hostname              = "khoj"
khoj_port                  = 42110

# LiteLLM
litellm_hostname           = "litellm"

# LM Studio
lmstudio_hostname          = "lmstudio"
lmstudio_port              = 1234

# MeiliSearch
meili_hostname             = "meili"
meili_port                 = 7700

# Playwright
playwright_port            = 3000
playwright_hostname        = "playwright"
playwright_proxy_username  = "ubuntu"

# Plex
plex_hostname              = "plex"
plex_port                  = 32400
plex_ipv4_address          = "10.76.128.95"
plex_email                 = "boden.crouch@gmail.com"
plex_username              = "brunner56"
plex_dlna_port             = "1902"
plex_metadata_host         = "https://metadata.provider.plex.tv/"

# Postgres
postgres_hostname          = "postgres"
postgres_port              = 5432

# QBitTorrent
qbittorrent_hostname       = "qbittorrent"
qbittorrent_port           = 8080
qbittorrent_username       = "brunner56"

# QDirStat
qdirstat_hostname          = "qdirstat"
qdirstat_port              = 8080

# Speedtest Tracker
speedtest_tracker_admin_email = "boden.crouch@gmail.com"
speedtest_tracker_admin_name  = "ubuntu"
speedtest_tracker_hostname    = "speedtest-tracker"
speedtest_tracker_port        = 80

# Stremio Addons
comet_hostname             = "comet"
comet_port                 = 2020
comet_username             = "ubuntu"

mediafusion_hostname       = "mediafusion"
mediafusion_addon_name     = "MediaFusion | bolabaden.org"
mediafusion_contact_email  = "boden.crouch@gmail.com"
mediafusion_branding_description = "Hosted on bolabaden.org"
mediafusion_port           = 8000
mediafusion_username       = "ubuntu"

mediaflow_proxy_hostname   = "mediaflow-proxy"
mediaflow_proxy_port       = 8888
mediaflow_proxy_username   = "ubuntu"

stremthru_hostname         = "stremthru"
stremthru_port             = 8080
stremthru_username         = "ubuntu"

# Rclone
rclone_base_folder         = "/mnt/remote"
rclone_user                = "brunner56"

# Zurg
zurg_hostname              = "zurg"
zurg_port                  = 9999
zurg_username              = "ubuntu"
zurg_mount                 = "/mnt/remote/zurg"
zurg_cache_dir             = "/mnt/remote/cache/zurg"
blackhole_base_watch_path  = "/mnt/remote/zurg/blackhole"
blackhole_radarr_path      = "radarr"
blackhole_sonarr_path      = "sonarr"
blackhole_fail_if_not_cached = true
blackhole_rd_mount_refresh_seconds = "200"
blackhole_wait_for_torrent_timeout = "300"
blackhole_history_page_size = "500"

# Tailscale
ts_client_id               = "ktiyDxLa7E11CNTRL"

# VectorDB
vectordb_port              = 6333
vectordb_postgres_user     = "ubuntu"

# Discord
discord_enabled            = "false"
discord_update_enabled     = "false"
discord_webhook_url        = ""

# WordPress
wordpress_db_user          = "wordpress"
wordpress_db_password      = "wordpress"
wordpress_db_name          = "wordpress"
wordpress_db_host          = "mariadb"
wordpress_db_port          = "3306"
wordpress_db_prefix        = "wp_"
wordpress_db_charset       = "utf8"

# Watchlist Plex
watchlist_plex_product     = "Plex Request Authentication"
watchlist_plex_version     = "1.0.0"

# Python
pythonunbuffered           = "TRUE"

# Repair Settings
repair_repair_interval     = "10m"
repair_run_interval        = "1d"

# Gluetun VPN
gluetun_block_ads          = true
gluetun_block_malicious    = true
gluetun_block_surveillance = true
gluetun_private_internet_access_user = "p6969448"

# Cloudflare Settings
cloudflare_http_timeout    = 100
cloudflare_polling_interval = 2
cloudflare_propagation_timeout = 120
cloudflare_ttl             = 120

# Alertmanager
alertmanager_smtp_smarthost = "smtp.gmail.com:587"
alertmanager_smtp_require_tls = "true"
alertmanager_smtp_from     = "contact@bolabaden.org"
alertmanager_smtp_to       = "boden.crouch@gmail.com"
alertmanager_resolve_timeout = "5m"

# CrowdSec
crowdsec_bouncer_enabled   = "true"
crowdsec_machine_id        = "localhost"

# Real-Debrid Users
realdebrid_enabled         = true
realdebrid_user            = "brunner56"
realdebrid_2_user          = "th3w1zard1"
realdebrid_mount_torrents_path = "/mnt/remote/zurg"

# Premiumize
premiumize_customer_id     = "117274388"
premiumize_oauth_client_id = "495910292"

# AWS
aws_account_name           = "brunner56"
aws_account_email_address  = "boden.crouch@gmail.com"
aws_account_id             = "891612555571"
aws_canonical_user_id      = "cefc3747bc5d60495b1de85eb170a7e7b0fcbe44ee1591b2447cfb2aa7655068"

# Google
providers_google_cookie_secret = "cRC0MywXNz6HVIA4qpe3FY2OONY5t2upgKeARwL2CRPLIVAviXVwk4oKwAXBLyz"

# Imgur
imgur_client_id            = "f127f082324e962"

# TinyAuth OAuth Whitelist
tinyauth_oauth_whitelist   = "boden.crouch@gmail.com,halomastar@gmail.com,athenajaguiar@gmail.com,dgorsch2@gmail.com,dgorsch4@gmail.com"

# Trakt OAuth
trakt_oauth_redirect_uri   = "urn:ietf:wg:oauth:2.0:oob"
trakt_refresh_token        = ""

# Autokuma
autokuma_kuma_username     = "brunner56"

# WARP Configuration
warp_license_key           = ""
gost_args                  = "-L :1080"
gost_socks5_port           = 1080
warp_enable_nat            = "false"
warp_sleep                 = 2

# Stremio
stremio_port               = 11470
stremio_https_port         = 12470

# AIOStreams
aiostreams_port            = 3000

# Rclone
rclone_port                = 5572

# Firecrawl
firecrawl_use_db_authentication = ""
firecrawl_env              = "local"
firecrawl_playwright_service_port = 3000
firecrawl_internal_port    = 3002
firecrawl_worker_port      = 3005
firecrawl_extract_worker_port = 3004
firecrawl_proxy_server     = ""
firecrawl_proxy_username   = ""
firecrawl_proxy_password   = ""
firecrawl_block_media      = "false"
firecrawl_model_name       = ""
firecrawl_model_embedding_name = ""
firecrawl_ollama_base_url  = ""

# Dozzle
dozzle_no_analytics        = "true"
dozzle_filter              = ""
dozzle_enable_actions      = "false"
dozzle_auth_provider       = "none"
dozzle_level               = "info"
dozzle_hostname            = ""
dozzle_base                = "/"
dozzle_addr                = ":8080"

# Homepage
homepage_allowed_hosts     = "*"
homepage_var_title         = "Bolabaden"
homepage_var_search_provider = "duckduckgo"
homepage_var_header_style  = "glass"
homepage_var_theme         = "dark"
homepage_var_weather_city  = "Iowa City"
homepage_var_weather_lat   = "41.661129"
homepage_var_weather_long  = "-91.5302"
homepage_var_weather_unit  = "fahrenheit"

# Watchtower
watchtower_repo_user       = "bolabaden"
watchtower_include_restarting = "true"
watchtower_include_stopped = "true"
watchtower_revive_stopped  = "false"
watchtower_label_enable    = "false"
watchtower_disable_containers = ""
watchtower_label_take_precedence = "true"
watchtower_scope           = ""
watchtower_poll_interval   = "86400"
watchtower_schedule        = "0 0 6 * * *"
watchtower_monitor_only    = "false"
watchtower_no_restart      = "false"
watchtower_no_pull         = "false"
watchtower_cleanup         = "true"
watchtower_remove_volumes  = "false"
watchtower_rolling_restart = "false"
watchtower_timeout         = "10s"
watchtower_run_once        = "false"
watchtower_no_startup_message = "false"
watchtower_warn_on_head_failure = "auto"
watchtower_http_api_update = "false"
watchtower_http_api_token  = ""
watchtower_http_api_periodic_polls = "false"
watchtower_http_api_metrics = "false"
watchtower_debug           = "true"
watchtower_trace           = "false"
watchtower_log_level       = "debug"
watchtower_log_format      = "Auto"
no_color                   = "false"
watchtower_porcelain       = ""
watchtower_notification_url = ""
watchtower_notification_report = "true"
docker_api_version         = "1.24"
docker_tls_verify          = "false"

# Traefik Configuration
traefik_ca_server          = "https://acme-v02.api.letsencrypt.org/directory"
traefik_dns_challenge      = "true"
traefik_http_challenge     = "false"
traefik_tls_challenge      = "false"
traefik_dns_resolvers      = "1.1.1.1,1.0.0.1"

# CrowdSec Configuration
crowdsec_lapi_port         = "8080"
crowdsec_appsec_port       = "7422"
crowdsec_smtp_host         = "smtp.gmail.com"
crowdsec_smtp_port         = "587"
crowdsec_smtp_auth_type    = "login"
crowdsec_receiver_email    = "admin@localhost"
crowdsec_http_log_level    = "info"
crowdsec_http_method       = "POST"
crowdsec_http_skip_tls_verification = "false"
crowdsec_bouncer_log_level = "INFO"
crowdsec_bouncer_mode      = "live"
crowdsec_appsec_enabled    = "false"
crowdsec_appsec_host       = "crowdsec:7422"
crowdsec_appsec_path       = "/"
crowdsec_appsec_failure_block = "true"
crowdsec_appsec_unreachable_block = "true"
crowdsec_appsec_body_limit = "10485760"
crowdsec_lapi_scheme       = "http"
crowdsec_lapi_host         = "crowdsec:8080"
crowdsec_lapi_path         = "/"
crowdsec_lapi_tls_insecure_verify = "false"
crowdsec_bouncer_metrics_update_interval_seconds = "600"
crowdsec_bouncer_http_timeout_seconds = "10"
crowdsec_bouncer_update_interval_seconds = "60"
crowdsec_bouncer_update_max_failure = "0"
crowdsec_bouncer_default_decision_seconds = "60"
crowdsec_bouncer_remediation_status_code = "403"
crowdsec_bouncer_captcha_grace_period_seconds = "1800"
crowdsec_bouncer_captcha_html_file_path = "/captcha.html"
crowdsec_bouncer_redis_enabled = "false"
crowdsec_bouncer_redis_host = "redis:6379"
crowdsec_bouncer_redis_unreachable_block = "true"
crowdsec_bouncer_forwarded_header_name = "X-Forwarded-For"

# Open WebUI
open_webui_port            = 8080
open_webui_enable_realtime_chat_save = "True"
open_webui_webui_build_hash = "dev-build"
open_webui_aiohttp_client_timeout = "300"
open_webui_aiohttp_client_timeout_model_list = "10"
open_webui_aiohttp_client_timeout_openai_model_list = "10"
open_webui_data_dir        = "./data"
open_webui_frontend_build_dir = "../build"
open_webui_static_dir      = "./static"
open_webui_ollama_base_url = "/ollama"
open_webui_use_ollama_docker = "false"
open_webui_k8s_flag        = "False"
open_webui_enable_forward_user_info_headers = "False"
open_webui_session_cookie_same_site = "lax"
open_webui_session_cookie_secure = "False"

# SearXNG
searxng_port               = 8080
searxng_internal_url       = "http://searxng:8080"

# TinyAuth
tinyauth_session_expiry    = "604800"
tinyauth_cookie_secure     = "true"
tinyauth_login_max_retries = "15"
tinyauth_login_timeout     = "300"
tinyauth_oauth_auto_redirect = "none"

# Session Manager
session_manager_port       = 8080
inactivity_timeout         = 3600
default_workspace          = "/workspace"
ext_path                   = "/home/ubuntu/my-media-stack/volumes/extensions/holo-lsp-1.0.0.vsix"

# VictoriaMetrics
victoriametrics_port       = "8428"
prometheus_port            = "9090"
victoriametrics_retention_period = "1y"
victoriametrics_memory_allowed_percent = "60"
victoriametrics_search_max_concurrent_requests = "8"
victoriametrics_insert_max_concurrent_requests = "32"
