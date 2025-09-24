# Global variables for media stack
variable "domain" {
  type        = string
  description = "Primary domain for the stack"
}

variable "ts_hostname" {
  type        = string
  description = "Tailscale hostname"
}

variable "config_path" {
  type        = string
  default     = "./volumes"
  description = "Configuration path for persistent data"
}

variable "tz" {
  type        = string
  default     = "America/Chicago"
  description = "Timezone for containers"
}

variable "puid" {
  type        = string
  default     = "1001"
  description = "Process user ID"
}

variable "pgid" {
  type        = string
  default     = "999"
  description = "Process group ID"
}

variable "umask" {
  type        = string
  default     = "002"
  description = "File creation mask"
}

variable "root_path" {
  type        = string
  default     = "."
  description = "Root path for the project"
}

variable "src_path" {
  type        = string
  default     = "./src"
  description = "Source code path"
}

variable "docker_host" {
  type        = string
  default     = "unix:///var/run/docker.sock"
  description = "Docker daemon socket"
}

# Network configurations
variable "warp_nat_net_subnet" {
  type        = string
  default     = "10.0.2.0/24"
  description = "Warp NAT network subnet"
}

variable "warp_nat_net_gateway" {
  type        = string
  default     = "10.0.2.1"
  description = "Warp NAT network gateway"
}

variable "publicnet_subnet" {
  type        = string
  default     = "10.0.5.0/24"
  description = "Public network subnet"
}

variable "publicnet_gateway" {
  type        = string
  default     = "10.0.5.1"
  description = "Public network gateway"
}

variable "backend_subnet" {
  type        = string
  default     = "10.0.7.0/24"
  description = "Backend network subnet"
}

variable "backend_gateway" {
  type        = string
  default     = "10.0.7.1"
  description = "Backend network gateway"
}

# Port configurations
variable "open_webui_port" {
  type        = string
  default     = "8080"
  description = "Open WebUI port"
}

variable "session_manager_port" {
  type        = string
  default     = "8080"
  description = "Session manager port"
}

variable "kotorscript_session_manager_port" {
  type        = string
  default     = "8080"
  description = "KotorScript session manager port"
}

# Database configurations
variable "litellm_postgres_hostname" {
  type        = string
  default     = "litellm-postgres"
  description = "LiteLLM PostgreSQL hostname"
}

variable "litellm_postgres_user" {
  type        = string
  default     = "litellm"
  description = "LiteLLM PostgreSQL user"
}

variable "litellm_postgres_password" {
  type        = string
  default     = "litellm"
  description = "LiteLLM PostgreSQL password"
}

variable "litellm_postgres_db" {
  type        = string
  default     = "litellm"
  description = "LiteLLM PostgreSQL database name"
}

variable "mongodb_hostname" {
  type        = string
  default     = "mongodb"
  description = "MongoDB hostname"
}

variable "authentik_tag" {
  type        = string
  default     = "2025.6.4"
  description = "Authentik Docker image tag"
}

# Service configurations
variable "litellm_log" {
  type        = string
  default     = "INFO"
  description = "LiteLLM log level"
}

variable "litellm_mode" {
  type        = string
  default     = "PRODUCTION"
  description = "LiteLLM mode"
}

variable "litellm_ui_username" {
  type        = string
  default     = "admin"
  description = "LiteLLM UI username"
}

variable "redis_hostname" {
  type        = string
  default     = "redis"
  description = "Redis hostname"
}

variable "redis_port" {
  type        = string
  default     = "6379"
  description = "Redis port"
}

variable "searxng_internal_url" {
  type        = string
  default     = "http://searxng:8080"
  description = "SearxNG internal URL"
}

variable "webui_auth" {
  type        = string
  default     = "True"
  description = "Open WebUI authentication enabled"
}

variable "chokidar_usepolling" {
  type        = string
  default     = "true"
  description = "Chokidar use polling for file watching"
}

variable "gptr_logging_level" {
  type        = string
  default     = "DEBUG"
  description = "GPTR logging level"
}

variable "langsmith_tracing" {
  type        = string
  default     = "true"
  description = "LangSmith tracing enabled"
}

variable "langsmith_endpoint" {
  type        = string
  default     = "https://api.smith.langchain.com"
  description = "LangSmith endpoint"
}

# Firecrawl configurations
variable "firecrawl_use_db_authentication" {
  type        = string
  default     = "false"
  description = "Firecrawl use database authentication"
}

variable "firecrawl_logging_level" {
  type        = string
  default     = "info"
  description = "Firecrawl logging level"
}

variable "firecrawl_searxng_endpoint" {
  type        = string
  default     = "https://searxng.bolabaden.org"
  description = "Firecrawl SearxNG endpoint"
}

variable "playwright_host" {
  type        = string
  default     = "http://playwright-service:3000/scrape"
  description = "Playwright service host"
}

# WordPress configurations
variable "wordpress_db_user" {
  type        = string
  description = "WordPress database user"
}

variable "wordpress_db_password" {
  type        = string
  description = "WordPress database password"
}

variable "wordpress_db_name" {
  type        = string
  default     = "wordpress"
  description = "WordPress database name"
}

variable "wordpress_db_root_password" {
  type        = string
  description = "WordPress database root password"
}

# Authentik configurations
variable "authentik_secret_key" {
  type        = string
  default     = "fd14e752f651b2a0b31daf49247766e9856aa93b57a479b3f6f12ae477d78b3d"
  description = "Authentik secret key"
}

variable "authentik_fqdn" {
  type        = string
  description = "Authentik fully qualified domain name"
}

variable "authentik_url" {
  type        = string
  description = "Authentik URL"
}

variable "wordpress_fqdn" {
  type        = string
  description = "WordPress fully qualified domain name"
}

variable "wordpress_url" {
  type        = string
  description = "WordPress URL"
}

# Code Server configurations
variable "codeserver_hashed_password" {
  type        = string
  description = "Code Server hashed password"
}

variable "codeserver_sudo_password_hash" {
  type        = string
  description = "Code Server sudo password hash"
}

variable "codeserver_pwa_appname" {
  type        = string
  description = "Code Server PWA app name"
}

variable "codeserver_default_workspace" {
  type        = string
  default     = "/workspace"
  description = "Code Server default workspace"
}

# Watchtower configurations
variable "watchtower_repo_user" {
  type        = string
  default     = "bolabaden"
  description = "Watchtower repository user"
}

variable "watchtower_include_restarting" {
  type        = string
  default     = "true"
  description = "Watchtower include restarting containers"
}

variable "watchtower_include_stopped" {
  type        = string
  default     = "true"
  description = "Watchtower include stopped containers"
}

variable "watchtower_revive_stopped" {
  type        = string
  default     = "false"
  description = "Watchtower revive stopped containers"
}

variable "watchtower_label_enable" {
  type        = string
  default     = "false"
  description = "Watchtower label enable"
}

variable "watchtower_disable_containers" {
  type        = string
  default     = ""
  description = "Watchtower disable containers"
}

variable "watchtower_label_take_precedence" {
  type        = string
  default     = "true"
  description = "Watchtower label take precedence"
}

variable "watchtower_scope" {
  type        = string
  default     = ""
  description = "Watchtower scope"
}

variable "watchtower_poll_interval" {
  type        = string
  default     = "86400"
  description = "Watchtower poll interval"
}

variable "watchtower_schedule" {
  type        = string
  default     = "0 0 6 * * *"
  description = "Watchtower schedule (6am daily)"
}

variable "watchtower_monitor_only" {
  type        = string
  default     = "false"
  description = "Watchtower monitor only"
}

variable "watchtower_no_restart" {
  type        = string
  default     = "false"
  description = "Watchtower no restart"
}

variable "watchtower_no_pull" {
  type        = string
  default     = "false"
  description = "Watchtower no pull"
}

variable "watchtower_cleanup" {
  type        = string
  default     = "true"
  description = "Watchtower cleanup"
}

variable "watchtower_remove_volumes" {
  type        = string
  default     = "false"
  description = "Watchtower remove volumes"
}

variable "watchtower_rolling_restart" {
  type        = string
  default     = "false"
  description = "Watchtower rolling restart"
}

variable "watchtower_timeout" {
  type        = string
  default     = "10s"
  description = "Watchtower timeout"
}

variable "watchtower_run_once" {
  type        = string
  default     = "false"
  description = "Watchtower run once"
}

variable "watchtower_no_startup_message" {
  type        = string
  default     = "false"
  description = "Watchtower no startup message"
}

variable "watchtower_warn_on_head_failure" {
  type        = string
  default     = "auto"
  description = "Watchtower warn on head failure"
}

variable "watchtower_http_api_update" {
  type        = string
  default     = "false"
  description = "Watchtower HTTP API update"
}

variable "watchtower_http_api_token" {
  type        = string
  default     = ""
  description = "Watchtower HTTP API token"
}

variable "watchtower_http_api_periodic_polls" {
  type        = string
  default     = "false"
  description = "Watchtower HTTP API periodic polls"
}

variable "watchtower_http_api_metrics" {
  type        = string
  default     = "false"
  description = "Watchtower HTTP API metrics"
}

variable "watchtower_debug" {
  type        = string
  default     = "true"
  description = "Watchtower debug"
}

variable "watchtower_trace" {
  type        = string
  default     = "false"
  description = "Watchtower trace"
}

variable "watchtower_log_level" {
  type        = string
  default     = "debug"
  description = "Watchtower log level"
}

variable "watchtower_log_format" {
  type        = string
  default     = "Auto"
  description = "Watchtower log format"
}

variable "no_color" {
  type        = string
  default     = "false"
  description = "No color output"
}

variable "watchtower_porcelain" {
  type        = string
  default     = ""
  description = "Watchtower porcelain"
}

variable "watchtower_notification_url" {
  type        = string
  default     = ""
  description = "Watchtower notification URL"
}
