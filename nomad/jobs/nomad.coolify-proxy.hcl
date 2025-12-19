# Nomad job equivalent to compose/docker-compose.coolify-proxy.yml
# Extracted from nomad.hcl
# Variables are loaded from ../variables.nomad.hcl via -var-file
# This matches the include structure in docker-compose.yml

job "docker-compose.coolify-proxy" {
  datacenters = ["dc1"]
  type        = "service"

  # Note: Constraint removed - nodes may not expose consul.version attribute
  # Consul integration is verified via service discovery, not version constraint

  group "nginx-traefik-extensions-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "nginx_extensions" { to = 80 }
    }

    # Nginx Traefik Extensions (Auth Middleware)
    task "nginx-traefik-extensions" {
      driver = "docker"

      config {
        image = "docker.io/nginx:alpine"
        ports = ["nginx_extensions"]
        volumes = [
          "${var.config_path}/traefik/nginx-middlewares/auth:/etc/nginx/auth:ro"
        ]
        args = ["nginx", "-c", "/local/nginx.conf", "-g", "daemon off;"]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "nginx-traefik-extensions"
        }
      }

      # Nginx configuration template
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
user nginx;
worker_processes auto;

error_log /dev/stderr warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    log_format main '\n\r$time_iso8601 | $status | $remote_addr | $http_host | $request | ${request_time}ms | '
                    'auth_method="$auth_method" | $http_user_agent | '
                    'request_method=$request_method | '
                    'request_uri=$request_uri | '
                    'query_string=$query_string | '
                    'content_type=$content_type | '
                    'server_protocol=$server_protocol | '
                    'request_scheme=$scheme | '
                    '\n\rheaders: {'
                      '"accept":"$http_accept",'
                      '"accept_encoding":"$http_accept_encoding",'
                      '"cookie":"$http_cookie",'
                      '"x_forwarded_for":"$http_x_forwarded_for",'
                      '"x_forwarded_port":"$http_x_forwarded_port",'
                      '"x_forwarded_proto":"$http_x_forwarded_proto",'
                      '"x_forwarded_host":"$http_x_forwarded_host",'
                      '"x_real_ip":"$http_x_real_ip",'
                      '"x_api_key":"$http_x_api_key",'
                    '}';

    # Output all access logs to stdout for Docker console visibility
    access_log /dev/stdout main;
    error_log /dev/stderr warn;

    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Fix for long API keys in map module
    map_hash_bucket_size 128;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=auth:10m rate=10r/s;

    set_real_ip_from <<<< env "CROWDSEC_GF_SUBNET" | or "10.0.6.0/24" >>>>;
    set_real_ip_from <<<< env "BACKEND_SUBNET" | or "10.0.7.0/24" >>>>;
    real_ip_header X-Forwarded-For;
    real_ip_recursive on;

    geo $ip_whitelisted {
        default 0;
        <<<< env "CROWDSEC_GF_SUBNET" | or "10.0.6.0/24" >>>> 1;
        <<<< env "BACKEND_SUBNET" | or "10.0.7.0/24" >>>>     1;
    }

    map $http_x_api_key $api_key_valid {
        default 0;
        "${ var.nginx_auth_api_key }" 1;
        # Add more API keys here as needed
    }

    upstream tinyauth {
        server auth:3000;
    }

    server {
        listen 80 default_server;
        server_name _;

        set $auth_passed 0;
        set $auth_method "none";

        if ($api_key_valid = 1) {
            set $auth_passed 1;
            set $auth_method "api_key";
        }

        if ($ip_whitelisted = 1) {
            set $auth_passed 1;
            set $auth_method "ip_whitelist";
        }

        location /auth {
            limit_req zone=auth burst=20 nodelay;
            if ($auth_passed = 1) {
                add_header X-Auth-Method "$auth_method" always;
                add_header X-Auth-Passed "true" always;
                return 200 "OK";
            }

            proxy_pass http://tinyauth/api/auth/traefik;
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
            proxy_set_header X-Original-URI $http_x_original_uri;
            proxy_set_header X-Original-Method $http_x_original_method;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $http_x_forwarded_host;
            add_header X-Auth-Method "tinyauth" always;
            access_log /dev/stdout main;
        }

        location /health {
            access_log /dev/stdout main;
            return 200 "nginx service healthy\n";
            add_header Content-Type text/plain;
        }

        location / {
            access_log /dev/stdout main;
            return 200 "nginx service healthy\n";
            add_header Content-Type text/plain;
        }
    }
}
EOF
        destination = "local/nginx.conf"
      }

      env {
        TZ                 = var.tz
        NGINX_ACCESS_LOG   = "/dev/stdout"
        NGINX_ERROR_LOG    = "/dev/stderr"
        NGINX_LOG_LEVEL    = "debug"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "nginx-traefik-extensions"
        port = "nginx_extensions"
        tags = [
          "nginx-traefik-extensions",
          "${var.domain}"
        ]

        check {
          type     = "http"
          path     = "/health"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
  group "tinyauth-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "tinyauth" { to = 3000 }
    }

    # TinyAuth
    task "tinyauth" {
      driver = "docker"

      config {
        image = "ghcr.io/steveiliop56/tinyauth:v3"
        ports = ["tinyauth"]
        volumes = [
          "${var.config_path}/traefik/tinyauth:/data"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "tinyauth"
        }
      }

      env {
        TZ                     = var.tz
        SECRET                 = var.tinyauth_secret
        APP_URL                = "https://auth.${var.domain}"
        USERS                  = var.tinyauth_users
        GOOGLE_CLIENT_ID       = var.tinyauth_google_client_id
        GOOGLE_CLIENT_SECRET   = var.tinyauth_google_client_secret
        GITHUB_CLIENT_ID       = var.tinyauth_github_client_id
        GITHUB_CLIENT_SECRET   = var.tinyauth_github_client_secret
        SESSION_EXPIRY         = "604800"
        COOKIE_SECURE          = "true"
        APP_TITLE              = var.domain
        LOGIN_MAX_RETRIES      = "15"
        LOGIN_TIMEOUT          = "300"
        OAUTH_AUTO_REDIRECT    = "none"
        OAUTH_WHITELIST        = var.tinyauth_oauth_whitelist
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "tinyauth"
        port = "tinyauth"
        tags = [
          "tinyauth",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.tinyauth.rule=Host(`auth.${var.domain}`) || Host(`auth.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.tinyauth.loadbalancer.server.port=3000"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
  group "crowdsec-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "crowdsec_lapi" {
        static = 9876
        to = 8080
      }
      port "crowdsec_appsec" { to = 7422 }
      port "crowdsec_metrics" { to = 6060 }
    }

    # 🔹🔹 CrowdSec 🔹🔹
    # Highly recommend this guide: https://blog.lrvt.de/configuring-crowdsec-with-traefik/
    task "crowdsec" {
      driver = "docker"

      config {
        image = "docker.io/crowdsecurity/crowdsec:v1.7.0"
        ports = ["crowdsec_lapi", "crowdsec_appsec", "crowdsec_metrics"]
        volumes = [
          "${var.config_path}/traefik/crowdsec/data:/var/lib/crowdsec/data:rw",
          "${var.config_path}/traefik/crowdsec/etc/crowdsec:/etc/crowdsec:rw",
          "${var.config_path}/traefik/crowdsec/plugins:/usr/local/lib/crowdsec/plugins:rw",
          # Log bind mounts into crowdsec
          "${var.config_path}/traefik/logs:/var/log/traefik:ro"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "crowdsec"
        }
      }

      env {
        TZ          = var.tz
        UID         = var.puid
        GID         = var.pgid
        COLLECTIONS = "crowdsecurity/appsec-crs crowdsecurity/appsec-generic-rules crowdsecurity/appsec-virtual-patching crowdsecurity/whitelist-good-actors crowdsecurity/base-http-scenarios crowdsecurity/http-cve crowdsecurity/linux crowdsecurity/sshd"
      }

      # CrowdSec Config Templates
      # CrowdSec files are typically access restricted (644) by the root user.
      # If your log files are stored onto an NFS share, you may want to use poll_without_inotify: true for each log source
      
      # docker exec crowdsec cscli notifications list
      
      # crowdsec-config.yaml
      template {
        data = <<EOF
common:
  log_media: stdout
  log_level: info
  log_dir: /var/log/
config_paths:
  config_dir: /etc/crowdsec/
  data_dir: /var/lib/crowdsec/data/
  simulation_path: /etc/crowdsec/simulation.yaml
  hub_dir: /etc/crowdsec/hub/
  index_path: /etc/crowdsec/hub/.index.json
  notification_dir: /etc/crowdsec/notifications/
  plugin_dir: /usr/local/lib/crowdsec/plugins/
crowdsec_service:
  acquisition_path: /etc/crowdsec/acquis.yaml
  acquisition_dir: /etc/crowdsec/acquis.d
  parser_routines: 1
plugin_config:
  user: nobody
  group: nobody
cscli:
  output: human
db_config:
  log_level: info
  type: sqlite
  db_path: /var/lib/crowdsec/data/crowdsec.db
  flush:
    max_items: 5000
    max_age: 7d
  use_wal: false
api:
  client:
    insecure_skip_verify: false
    credentials_path: /etc/crowdsec/local_api_credentials.yaml
  server:
    log_level: info
    listen_uri: 0.0.0.0:8080
    profiles_path: /etc/crowdsec/profiles.yaml
    trusted_ips:
      - 127.0.0.1
      - ::1
      - 172.16.0.0/12
      - 10.0.0.0/8
    online_client:
      credentials_path: /etc/crowdsec//online_api_credentials.yaml
    enable: true
prometheus:
  enabled: true
  level: full
  listen_addr: 0.0.0.0
  listen_port: 6060
EOF
        destination = "local/config.yaml"
        perms       = "0644"
      }
      
      # crowdsec-acquis.yaml
      template {
        data = <<EOF
filenames:
  - /var/log/auth.log
  - /var/log/syslog
labels:
  type: syslog
---
poll_without_inotify: false
filenames:
  - {{ env "TRAEFIK_INTERNAL_LOG_DIR" | or "/var/log/traefik" }}/*.log
#  - {{ env "TRAEFIK_INTERNAL_LOG_DIR" | or "/var/log/traefik" }}/access.log
labels:
  type: traefik
EOF
        destination = "local/acquis.yaml"
        perms       = "0644"
      }

      # crowdsec-profiles.yaml
      # If you are already using other custom notification channels, make sure to only add `http_victoriametrics` to the mix.
      # Your already existing notification channels should remain unchanged.
      template {
        data = <<EOF
name: default_ip_remediation
#debug: true
filters:
- Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
- type: ban
  duration: 4h
#duration_expr: Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 4)
#notifications:
#   - email_default         # Set the required email parameters in /etc/crowdsec/notifications/email.yaml before enabling this.
#   - http_victoriametrics  # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
#   - slack_default         # Set the webhook in /etc/crowdsec/notifications/slack.yaml before enabling this.
#   - splunk_default        # Set the splunk url and token in /etc/crowdsec/notifications/splunk.yaml before enabling this.
#   - http_default          # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
on_success: break
---
name: default_range_remediation
#debug: true
filters:
- Alert.Remediation == true && Alert.GetScope() == "Range"
decisions:
- type: ban
  duration: 4h
#duration_expr: Sprintf('%dh', (GetDecisionsCount(Alert.GetValue()) + 1) * 4)
#notifications:
#   - email_default         # Set the required email parameters in /etc/crowdsec/notifications/email.yaml before enabling this.
#   - http_victoriametrics  # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
#   - slack_default         # Set the webhook in /etc/crowdsec/notifications/slack.yaml before enabling this.
#   - splunk_default        # Set the splunk url and token in /etc/crowdsec/notifications/splunk.yaml before enabling this.
#   - http_default          # Set the required http parameters in /etc/crowdsec/notifications/http.yaml before enabling this.
on_success: break
EOF
        destination = "local/profiles.yaml"
        perms       = "0644"
      }

      # crowdsec-victoriametrics.yaml  
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: http
name: http_victoriametrics
log_level: debug
format: >
  {{- range $$Alert := . -}}
  {{- $$traefikRouters := GetMeta . "traefik_router_name" -}}
  {{- range .Decisions -}}
  {"metric":{"__name__":"cs_lapi_decision","instance":"my-instance","country":"{{$$Alert.Source.Cn}}","asname":"{{$$Alert.Source.AsName}}","asnumber":"{{$$Alert.Source.AsNumber}}","latitude":"{{$$Alert.Source.Latitude}}","longitude":"{{$$Alert.Source.Longitude}}","iprange":"{{$$Alert.Source.Range}}","scenario":"{{.Scenario}}","type":"{{.Type}}","duration":"{{.Duration}}","scope":"{{.Scope}}","ip":"{{.Value}}","traefik_routers":{{ printf "%q" ($$traefikRouters | uniq | join ",")}}},"values": [1],"timestamps":[{{now|unixEpoch}}000]}
  {{- end }}
  {{- end -}}
url: http://victoriametrics:<<<< env "VICTORIAMETRICS_PORT" | or "8428" >>>>/api/v1/import
method: POST
headers:
  Content-Type: application/json
  # if you use vmauth as proxy, please uncomment next line and add your token
  # If you would like to add authentication, please read about vmauth.
  # https://docs.victoriametrics.com/victoriametrics/vmauth/?ref=blog.lrvt.de#bearer-token-auth-proxy
  # It's basically another Docker container service, which acts as proxy in front of VictoriaMetrics and enforces Bearer HTTP Authentication.
  # Authorization: "<<<< env "VICTORIAMETRICS_AUTH_TOKEN" | or "" >>>>"
EOF
        destination = "local/notifications/victoriametrics.yaml"
        perms       = "0644"
      }

      # crowdsec-email.yaml - docker exec crowdsec cscli notifications test email_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: email           # Don't change
name: email_default   # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: info

# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
timeout: 20s          # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the email message body
format: |
  <html><body>
  {{range . -}}
    {{$$alert := . -}}
    {{range .Decisions -}}
      <p><a href="https://www.whois.com/whois/{{.Value}}">{{.Value}}</a> will get <b>{{.Type}}</b> for next <b>{{.Duration}}</b> for triggering <b>{{.Scenario}}</b> on machine <b>{{$$alert.MachineID}}</b>.</p> <p><a href="https://app.crowdsec.net/cti/{{.Value}}">CrowdSec CTI</a></p>
    {{end -}}
  {{end -}}
  </body></html>

smtp_host: <<<< env "CROWDSEC_SMTP_HOST" | or "smtp.gmail.com" >>>>  # example: smtp.gmail.com
smtp_username: <<<< with (env "CROWDSEC_SMTP_USERNAME") >>>><<<< . >>>><<<< else >>>>${ var.acme_resolver_email }<<<< end >>>>
smtp_password: <<<< with (env "CROWDSEC_SMTP_PASSWORD") >>>><<<< . >>>><<<< else >>>>${ var.gmail_app_password }<<<< end >>>>
smtp_port: <<<< env "CROWDSEC_SMTP_PORT" | or "587" >>>>   # Common values are any of [25, 465, 587, 2525]
auth_type: <<<< env "CROWDSEC_SMTP_AUTH_TYPE" | or "login" >>>>   # Valid choices are "none", "crammd5", "login", "plain"
sender_name: "CrowdSec"
sender_email: <<<< with (env "CROWDSEC_SENDER_EMAIL") >>>><<<< . >>>><<<< else >>>>${ var.acme_resolver_email }<<<< end >>>>
email_subject: "CrowdSec Security Alert"
receiver_emails:
  - <<<< env "CROWDSEC_RECEIVER_EMAIL" | or "admin@localhost" >>>>
  - <<<< env "ACME_RESOLVER_EMAIL" >>>>
# - email1@gmail.com
# - email2@gmail.com

# One of "ssltls", "starttls", "none"
encryption_type: "ssltls"

# If you need to set the HELO hostname:
# helo_host: "localhost"

# If the email server is hitting the default timeouts (10 seconds), you can increase them here
#
# connect_timeout: 10s
# send_timeout: 10s

---

# type: email
# name: email_second_notification
# ...
EOF
        destination = "local/email.yaml"
        perms       = "0644"
      }

      # crowdsec-file.yaml - docker exec crowdsec cscli notifications test file_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
# Don't change this
type: file

name: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_NAME" | or "file_default" >>>>  # this must match with the registered plugin in the profile
log_level: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_LOG_LEVEL" | or "info" >>>>  # Options include: trace, debug, info, warn, error, off

# This template render all events as ndjson
format: |
  {{range . -}}
  { "time": "{{.StopAt}}", "program": "crowdsec", "alert": {{. | toJSON >>>> }
  {{ end -}}

group_wait: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_GROUP_WAIT" | or "30s" >>>>  # duration to wait collecting alerts before sending to this plugin
group_threshold: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_GROUP_THRESHOLD" | or "10" >>>>  # if alerts exceed this, then the plugin will be sent the message

# Use full path EG /tmp/crowdsec_alerts.json or %TEMP%\crowdsec_alerts.json
log_path: "<<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_LOG_PATH" | or "/tmp/crowdsec_alerts.json" >>>>"
rotate:
  enabled: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_ROTATE_ENABLED" | or "true" >>>>  # Change to false if you want to handle log rotate on system basis
  max_size: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_MAX_SIZE" | or "500" >>>>  # in MB
  max_files: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_MAX_FILES" | or "5" >>>>
  max_age: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_MAX_AGE" | or "5" >>>>
  compress: <<<< env "CROWDSEC_FILE_FIRST_NOTIFICATION_COMPRESS" | or "true" >>>>
EOF
        destination = "local/file.yaml"
        perms       = "0644"
      }

      # crowdsec-http.yaml - docker exec crowdsec cscli notifications test http_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: http          # Don't change
name: http_default  # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: <<<< env "CROWDSEC_HTTP_LOG_LEVEL" | or "info" >>>>

# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
# timeout:            # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the http request body
format: |
  {{.|toJSON}}

# The plugin will make requests to this url, eg:  https://www.cloudflare.com/
url: <<<< env "CROWDSEC_HTTP_URL" | or "https://grafana.${var.domain}/api/annotations" >>>>

# Any of the http verbs: "POST", "GET", "PUT"...
method: <<<< env "CROWDSEC_HTTP_METHOD" | or "POST" >>>>

# headers:
#   Authorization: token 0x64312313
#   Content-Type: application/json

skip_tls_verification: <<<< env "CROWDSEC_HTTP_SKIP_TLS_VERIFICATION" | or "false" >>>>  # true or false. Default is false

---

# type: http
# name: http_second_notification
# ...
EOF
        destination = "local/http.yaml"
        perms       = "0644"
      }

      # crowdsec-slack.yaml - docker exec crowdsec cscli notifications test slack_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: slack           # Don't change
name: slack_default   # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: info

# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
# timeout:            # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the slack message
format: |
  {{range . -}}
  {{$$alert := . -}}
  {{range .Decisions -}}
  {{if $$alert.Source.Cn -}}
  :flag-{{$$alert.Source.Cn}}: <https://www.whois.com/whois/{{.Value}}|{{.Value}}> will get {{.Type}} for next {{.Duration}} for triggering {{.Scenario}} on machine '{{$$alert.MachineID}}'. <https://app.crowdsec.net/cti/{{.Value}}|CrowdSec CTI>{{end}}
  {{if not $$alert.Source.Cn -}}
  :pirate_flag: <https://www.whois.com/whois/{{.Value}}|{{.Value}}> will get {{.Type}} for next {{.Duration}} for triggering {{.Scenario}} on machine '{{$$alert.MachineID}}'.  <https://app.crowdsec.net/cti/{{.Value}}|CrowdSec CTI>{{end}}
  {{end -}}
  {{end -}}


webhook: <<<< env "CROWDSEC_SLACK_WEBHOOK_URL" | or "<SLACK_WEBHOOK_URL>" >>>>

# API request data as defined by the Slack webhook API.
#channel: <CHANNEL_NAME>
#username: <USERNAME>
#icon_emoji: <ICON_EMOJI>
#icon_url: <ICON_URL>

---

# type: slack
# name: slack_second_notification
# ...
EOF
        destination = "local/slack.yaml"
        perms       = "0644"
      }

      # crowdsec-splunk.yaml - docker exec crowdsec cscli notifications test splunk_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: splunk          # Don't change
name: <<<< env "CROWDSEC_SPLUNK_FIRST_NOTIFICATION_NAME" | or "splunk_default" >>>>  # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: <<<< env "CROWDSEC_SPLUNK_FIRST_NOTIFICATION_LOG_LEVEL" | or "info" >>>>

# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
# timeout:            # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the splunk notification
format: |
  {{.|toJSON}}

url: <<<< env "CROWDSEC_SPLUNK_FIRST_NOTIFICATION_HTTP_URL" | or "<SPLUNK_HTTP_URL>" >>>>
token: <<<< env "CROWDSEC_SPLUNK_FIRST_NOTIFICATION_TOKEN" | or "<SPLUNK_TOKEN>" >>>>

---

# type: splunk
# name: splunk_second_notification
# ...
EOF
        destination = "local/splunk.yaml"
        perms       = "0644"
      }

      # crowdsec-sentinel.yaml - docker exec crowdsec cscli notifications test sentinel_default
      template {
        left_delimiter  = "<<<<"
        right_delimiter = ">>>>"
        data = <<EOF
type: sentinel          # Don't change
name: <<<< env "CROWDSEC_SENTINEL_FIRST_NOTIFICATION_NAME" | or "sentinel_default" >>>>  # Must match the registered plugin in the profile

# One of "trace", "debug", "info", "warn", "error", "off"
log_level: <<<< env "CROWDSEC_SENTINEL_FIRST_NOTIFICATION_LOG_LEVEL" | or "info" >>>>
# group_wait:         # Time to wait collecting alerts before relaying a message to this plugin, eg "30s"
# group_threshold:    # Amount of alerts that triggers a message before <group_wait> has expired, eg "10"
# max_retry:          # Number of attempts to relay messages to plugins in case of error
# timeout:            # Time to wait for response from the plugin before considering the attempt a failure, eg "10s"

#-------------------------
# plugin-specific options

# The following template receives a list of models.Alert objects
# The output goes in the http request body
format: |
  {{.|toJSON}}

customer_id: <<<< env "CROWDSEC_SENTINEL_FIRST_NOTIFICATION_CUSTOMER_ID" | or "XXX-XXX" >>>>
shared_key: <<<< env "CROWDSEC_SENTINEL_FIRST_NOTIFICATION_SHARED_KEY" | or "XXXXXXX" >>>>
EOF
        destination = "local/sentinel.yaml"
        perms       = "0644"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "crowdsec"
        port = "crowdsec_lapi"
        tags = [
          "crowdsec",
          "${var.domain}"
        ]

        check {
          type     = "script"
          command  = "/usr/local/bin/cscli"
          args     = ["version"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }

  group "traefik-group" {
    count = 3  # HA: Run on multiple nodes for failover


    spread {
      attribute = "${node.unique.name}"
    }

    update {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "3m"
      auto_revert      = true
      canary           = 0
    }

    migrate {
      max_parallel     = 1
      health_check     = "checks"
      min_healthy_time = "10s"
      healthy_deadline = "5m"
    }

    network {
      mode = "bridge"
      
      port "traefik_api" { to = 8080 }
      port "traefik_http" {
        static = 80
        to = 80
      }
      port "traefik_https" {
        static = 443
        to = 443
      }
    }

    # https://doc.traefik.io
    task "traefik" {
      driver = "docker"

      kill_timeout = "30s"
      kill_signal  = "SIGTERM"

      config {
        image = "docker.io/traefik:latest"
        ports = ["traefik_api", "traefik_http", "traefik_https"]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
        cap_add = ["NET_ADMIN"]
        volumes = [
          # Dynamic config is now generated via template in /local/dynamic/
          "${var.config_path}/traefik/certs:/certs",
          "${var.config_path}/traefik/plugins-local:/plugins-local",
          "${var.config_path}/traefik/logs:/var/log/traefik:rw"
        ]
        command = "--accessLog=true"
        args = [
          "--accessLog.bufferingSize=0",
          "--accessLog.fields.headers.defaultMode=drop",
          "--accessLog.fields.headers.names.User-Agent=keep",
          "--accessLog.fields.names.StartUTC=drop",
          "--accessLog.filePath=/var/log/traefik/traefik.log",
          "--accessLog.filters.statusCodes=100-999",
          "--accessLog.format=json",
          "--metrics.prometheus.buckets=0.1,0.3,1.2,5.0",
          "--api.dashboard=true",
          "--api.debug=true",
          "--api.disableDashboardAd=true",
          "--api.insecure=true",
          "--api=true",
          "--certificatesResolvers.letsencrypt.acme.caServer=${var.traefik_ca_server}",
          "--certificatesResolvers.letsencrypt.acme.dnsChallenge=${var.traefik_dns_challenge}",
          "--certificatesResolvers.letsencrypt.acme.dnsChallenge.provider=cloudflare",
          "--certificatesResolvers.letsencrypt.acme.dnsChallenge.resolvers=${var.traefik_dns_resolvers}",
          "--certificatesResolvers.letsencrypt.acme.email=${var.acme_resolver_email}",
          "--certificatesResolvers.letsencrypt.acme.httpChallenge=${var.traefik_http_challenge}",
          "--certificatesResolvers.letsencrypt.acme.httpChallenge.entryPoint=web",
          "--certificatesResolvers.letsencrypt.acme.tlsChallenge=${var.traefik_tls_challenge}",
          "--certificatesResolvers.letsencrypt.acme.storage=/certs/acme.json",
          "--entryPoints.web.address=:80",
          "--entryPoints.web.http.redirections.entryPoint.scheme=https",
          "--entryPoints.web.http.redirections.entryPoint.to=websecure",
          "--entryPoints.web.forwardedHeaders.trustedIPs=103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,104.16.0.0/13,104.24.0.0/14,108.162.192.0/18,131.0.72.0/22,141.101.64.0/18,162.158.0.0/15,172.64.0.0/13,173.245.48.0/20,188.114.96.0/20,190.93.240.0/20,197.234.240.0/22,198.41.128.0/17,2400:cb00::/32,2405:8100::/32,2405:b500::/32,2606:4700::/32,2803:f800::/32,2a06:98c0::/29,2c0f:f248::/32",
          "--entryPoints.websecure.forwardedHeaders.trustedIPs=103.21.244.0/22,103.22.200.0/22,103.31.4.0/22,104.16.0.0/13,104.24.0.0/14,108.162.192.0/18,131.0.72.0/22,141.101.64.0/18,162.158.0.0/15,172.64.0.0/13,173.245.48.0/20,188.114.96.0/20,190.93.240.0/20,197.234.240.0/22,198.41.128.0/17,2400:cb00::/32,2405:8100::/32,2405:b500::/32,2606:4700::/32,2803:f800::/32,2a06:98c0::/29,2c0f:f248::/32",
          "--entryPoints.websecure.address=:443",
          "--entryPoints.websecure.http.encodeQuerySemiColons=true",
          "--entryPoints.websecure.http.middlewares=bolabaden-error-pages@file,crowdsec@file,strip-www@file",
          "--entryPoints.websecure.http.tls=true",
          "--entryPoints.websecure.http.tls.certResolver=letsencrypt",
          "--entryPoints.websecure.http.tls.domains[0].main=${var.domain}",
          "--entryPoints.websecure.http.tls.domains[0].sans=www.${var.domain},*.${var.domain},*.${node.unique.name}.${var.domain}",
          "--entryPoints.websecure.http2.maxConcurrentStreams=100",
          "--entryPoints.websecure.http3",
          "--global.checkNewVersion=true",
          "--global.sendAnonymousUsage=false",
          "--log.level=INFO",
          "--ping=true",
          "--providers.consulCatalog=true",
          "--providers.consulCatalog.endpoint.address=172.26.64.1:8500",
          "--providers.consulCatalog.exposedByDefault=false",
          "--providers.consulCatalog.defaultRule=Host(`{{ normalize .Name }}.${var.domain}`) || Host(`{{ normalize .Name }}.${node.unique.name}.${var.domain}`)",
          "--providers.consulCatalog.watch=true",
          "--providers.consulCatalog.prefix=traefik",
          "--providers.file.directory=/local/dynamic/",
          "--providers.file.watch=true",
          "--experimental.plugins.bouncer.modulename=github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin",
          "--experimental.plugins.bouncer.version=v1.4.5",
          "--experimental.plugins.traefikerrorreplace.modulename=github.com/PseudoResonance/traefikerrorreplace",
          "--experimental.plugins.traefikerrorreplace.version=v1.0.1",
          "--serversTransport.insecureSkipVerify=true"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "traefik"
          "traefik.enable" = "true"
          "traefik.http.routers.traefik.service" = "api@internal"
          "traefik.http.routers.traefik.rule" = "Host(`traefik.${var.domain}`) || Host(`traefik.${node.unique.name}.${var.domain}`)"
          "traefik.http.services.traefik.loadbalancer.server.port" = "8080"
          "homepage.group" = "Infrastructure"
          "homepage.name" = "Traefik"
          "homepage.icon" = "traefik.png"
          "homepage.href" = "https://traefik.${var.domain}/dashboard"
          "homepage.widget.type" = "traefik"
          "homepage.widget.url" = "http://traefik:8080"
          "homepage.description" = "Reverse proxy entrypoint for all services with TLS, Cloudflare integration, and auth middleware"
          "kuma.traefik.http.name" = "traefik.${node.unique.name}.${var.domain}"
          "kuma.traefik.http.url" = "https://traefik.${var.domain}/dashboard"
          "kuma.traefik.http.interval" = "20"
        }
      }

      env {
        TZ                  = var.tz
        LETS_ENCRYPT_EMAIL  = var.acme_resolver_email
        CLOUDFLARE_EMAIL    = var.cloudflare_email
        CLOUDFLARE_API_KEY  = var.cloudflare_api_key
        CLOUDFLARE_ZONE_ID  = var.cloudflare_zone_id
        CROWDSEC_LAPI_KEY   = var.crowdsec_lapi_key
        CROWDSEC_BOUNCER_ENABLED = var.crowdsec_bouncer_enabled
      }

      template {
        data = <<EOF
{{ range service "crowdsec" -}}
CROWDSEC_LAPI_HOST="{{ .Address }}:{{ .Port }}"
{{ end -}}
{{ range service "crowdsec" }}{{ range .Tags }}{{ if . | contains "crowdsec_appsec" -}}
CROWDSEC_APPSEC_HOST="{{ .Address }}:{{ .Port }}"
{{ end }}{{ end }}{{ end -}}
EOF
        destination = "secrets/crowdsec-endpoints.env"
        env         = true
      }

      # traefik-dynamic.yaml - Core dynamic configuration
      template {
        data = <<EOF
# yaml-language-server: $schema=https://www.schemastore.org/traefik-v3-file-provider.json
http:
  routers:
    nomad-ui:
      entryPoints:
        - web
        - websecure
      service: nomad-ui@file
      rule: Host(`nomad.${var.domain}`) || Host(`nomad.${node.unique.name}.${var.domain}`)
      middlewares:
        - nginx-auth@file
      priority: 100
    consul-ui:
      entryPoints:
        - web
        - websecure
      service: consul-ui@file
      rule: Host(`consul.${var.domain}`) || Host(`consul.${node.unique.name}.${var.domain}`)
      middlewares:
        - nginx-auth@file
      priority: 100
    bolabaden-nextjs:
      entryPoints:
        - web
        - websecure
      service: bolabaden-nextjs@file
      rule: Host(`${var.domain}`) || Host(`${node.unique.name}.${var.domain}`)
      priority: 100
      # Note: In docker-compose.yml, the router doesn't have middlewares in the label
      # The error middleware is defined but not attached to the router
    catchall:
      entryPoints:
        - web
        - websecure
      service: noop@internal
      rule: Host(`${var.domain}`) || Host(`${node.unique.name}.${var.domain}`) || HostRegexp(`^(.+)$`)
      priority: 1
      middlewares:
        - traefikerrorreplace@file
  services:
    nomad-ui:
      loadBalancer:
        servers:
          - url: http://172.26.64.1:4646
    consul-ui:
      loadBalancer:
        servers:
          - url: http://172.26.64.1:8500
    nginx-traefik-extensions:
      loadBalancer:
        servers:
          - url: http://nginx-traefik-extensions:80
    bolabaden-nextjs:
      loadBalancer:
        servers:
          # Use Consul DNS name for service resolution (matches docker-compose.coolify-proxy.yml)
          - url: http://bolabaden-nextjs.service.consul:3000
  serversTransports:
    default:
      insecureSkipVerify: true
  middlewares:
    traefikerrorreplace:
      plugin:
        traefikerrorreplace:
          matchStatus:
            - 418
          replaceStatus: 404
    bolabaden-error-pages:
      errors:
        status:
          - 400-599
        service: bolabaden-nextjs@file
        query: /api/error/{status}
    nginx-auth:
      forwardAuth:
        address: http://nginx-traefik-extensions:80/auth
        trustForwardHeader: true
        authResponseHeaders: ["X-Auth-Method", "X-Auth-Passed", "X-Middleware-Name"]
    strip-www:
      redirectRegex:
        regex: '^(http|https)?://www\.(.+)$'
        replacement: '$1://$2'
        permanent: false
    crowdsec:
      plugin:
        bouncer:
          # Enable the plugin (default: false)
          enabled: {{ env "CROWDSEC_BOUNCER_ENABLED" | or "false" }}

          # Log level (default: INFO, expected: INFO, DEBUG, ERROR)
          logLevel: {{ env "CROWDSEC_BOUNCER_LOG_LEVEL" | or "INFO" }}

          # File path to write logs (default: "")
          logFilePath: "{{ env "CROWDSEC_BOUNCER_LOG_FILE_PATH" | or "" }}"

          # Interval in seconds between metrics updates to Crowdsec (default: 600, <=0 disables metrics)
          metricsUpdateIntervalSeconds: {{ env "CROWDSEC_BOUNCER_METRICS_UPDATE_INTERVAL_SECONDS" | or "600" }}

          # Mode for Crowdsec integration (default: live, expected: none, live, stream, alone, appsec)
          crowdsecMode: {{ env "CROWDSEC_BOUNCER_MODE" | or "live" }}

          # Enable Crowdsec Appsec Server (WAF) (default: false)
          crowdsecAppsecEnabled: {{ env "CROWDSEC_APPSEC_ENABLED" | or "false" }}

          # Crowdsec Appsec Server host and port (default: "crowdsec:7422")
          crowdsecAppsecHost: {{ env "CROWDSEC_APPSEC_HOST" | or "10.16.1.78:23733" }}

          # Crowdsec Appsec Server path (default: "/")
          crowdsecAppsecPath: {{ env "CROWDSEC_APPSEC_PATH" | or "/" }}

          # Block request when Crowdsec Appsec Server returns 500 (default: true)
          crowdsecAppsecFailureBlock: {{ env "CROWDSEC_APPSEC_FAILURE_BLOCK" | or "true" }}

          # Block request when Crowdsec Appsec Server is unreachable (default: true)
          crowdsecAppsecUnreachableBlock: {{ env "CROWDSEC_APPSEC_UNREACHABLE_BLOCK" | or "true" }}

          # Transmit only the first number of bytes to Crowdsec Appsec Server (default: 10485760 = 10MB)
          crowdsecAppsecBodyLimit: {{ env "CROWDSEC_APPSEC_BODY_LIMIT" | or "10485760" }}

          # Scheme for Crowdsec LAPI (default: http, expected: http, https)
          crowdsecLapiScheme: {{ env "CROWDSEC_LAPI_SCHEME" | or "http" }}

          # Crowdsec LAPI host and port (default: "crowdsec:8080")
          crowdsecLapiHost: {{ env "CROWDSEC_LAPI_HOST" | or "10.16.1.78:9876" }}

          # Crowdsec LAPI path (default: "/")
          crowdsecLapiPath: {{ env "CROWDSEC_LAPI_PATH" | or "/" }}

          # Crowdsec LAPI key for the bouncer (default: "")
          crowdsecLapiKey: {{ env "CROWDSEC_LAPI_KEY" | or "" }}

          # Disable TLS verification for Crowdsec LAPI (default: false)
          crowdsecLapiTlsInsecureVerify: {{ env "CROWDSEC_LAPI_TLS_INSECURE_VERIFY" | or "false" }}

          # PEM-encoded CA for Crowdsec LAPI (default: "")
          crowdsecLapiTlsCertificateAuthority: "{{ env "CROWDSEC_LAPI_TLS_CA" | or "" }}"

          # PEM-encoded client certificate for the Bouncer (default: "")
          crowdsecLapiTlsCertificateBouncer: "{{ env "CROWDSEC_LAPI_TLS_CERT" | or "" }}"

          # PEM-encoded client key for the Bouncer (default: "")
          crowdsecLapiTlsCertificateBouncerKey: "{{ env "CROWDSEC_LAPI_TLS_KEY" | or "" }}"

          # Name of the header in response when requests are cancelled (default: "")
          remediationHeadersCustomName: "{{ env "CROWDSEC_BOUNCER_REMEDIATION_HEADER_NAME" | or "" }}"

          # Name of the header where real client IP is retrieved (default: "X-Forwarded-For")
          forwardedHeadersCustomName: "{{ env "CROWDSEC_BOUNCER_FORWARDED_HEADER_NAME" | or "X-Forwarded-For" }}"      

          # Enable Redis cache (default: false)
          redisCacheEnabled: {{ env "CROWDSEC_BOUNCER_REDIS_ENABLED" | or "false" }}

          # Redis hostname and port (default: "redis:6379")
          redisCacheHost: {{ env "CROWDSEC_BOUNCER_REDIS_HOST" | or "redis:6379" }}

          # Redis password (default: "")
          redisCachePassword: "{{ env "CROWDSEC_BOUNCER_REDIS_PASSWORD" | or "" }}"

          # Redis database selection (default: "")
          redisCacheDatabase: "{{ env "CROWDSEC_BOUNCER_REDIS_DB" | or "" }}"

          # Block request when Redis is unreachable (default: true, adds 1s delay)
          redisCacheUnreachableBlock: {{ env "CROWDSEC_BOUNCER_REDIS_UNREACHABLE_BLOCK" | or "true" }}

          # Default timeout in seconds for contacting Crowdsec LAPI (default: 10)
          httpTimeoutSeconds: {{ env "CROWDSEC_BOUNCER_HTTP_TIMEOUT_SECONDS" | or "10" }}

          # Interval between LAPI fetches in stream mode (default: 60)
          updateIntervalSeconds: {{ env "CROWDSEC_BOUNCER_UPDATE_INTERVAL_SECONDS" | or "60" }}

          # Max failures before blocking traffic in stream/alone mode (default: 0, -1 = never block)
          updateMaxFailure: {{ env "CROWDSEC_BOUNCER_UPDATE_MAX_FAILURE" | or "0" }}

          # Maximum decision duration in live mode (default: 60)
          defaultDecisionSeconds: {{ env "CROWDSEC_BOUNCER_DEFAULT_DECISION_SECONDS" | or "60" }}

          # HTTP status code for banned user (default: 403)
          remediationStatusCode: {{ env "CROWDSEC_BOUNCER_REMEDIATION_STATUS_CODE" | or "403" }}

          # CAPI Machine ID (used only in alone mode)
          crowdsecCapiMachineId: {{ env "CROWDSEC_CAPI_MACHINE_ID" | or "" }}

          # CAPI Password (used only in alone mode)
          crowdsecCapiPassword: "{{ env "CROWDSEC_CAPI_PASSWORD" | or "" }}"

          # CAPI Scenarios (used only in alone mode)
          crowdsecCapiScenarios: {{ env "CROWDSEC_CAPI_SCENARIOS" | or "[]" }}

          # Captcha provider (expected: hcaptcha, recaptcha, turnstile)
          captchaProvider: "{{ env "CROWDSEC_BOUNCER_CAPTCHA_PROVIDER" | or "" }}"

          # Captcha site key
          captchaSiteKey: "{{ env "CROWDSEC_BOUNCER_CAPTCHA_SITE_KEY" | or "" }}"

          # Captcha secret key
          captchaSecretKey: "{{ env "CROWDSEC_BOUNCER_CAPTCHA_SECRET_KEY" | or "" }}"

          # Grace period after captcha validation before revalidation required (default: 1800s = 30m)
          captchaGracePeriodSeconds: {{ env "CROWDSEC_BOUNCER_CAPTCHA_GRACE_PERIOD_SECONDS" | or "1800" }}

          # Path to captcha template (default: /captcha.html)
          captchaHTMLFilePath: {{ env "CROWDSEC_BOUNCER_CAPTCHA_HTML_FILE_PATH" | or "/captcha.html" }}

          # Path to ban HTML file (default: "", disabled if empty)
          banHTMLFilePath: "{{ env "CROWDSEC_BOUNCER_BAN_HTML_FILE_PATH" | or "" }}"

          # List of trusted proxies in front of Traefik (default: [])
          # As can be seen in the middleware declaration, we are actively defining all private class IPv4/IPv6 subnets as trusted IPs.
          # This is necessary, as we want to trust our Traefik reverse proxy's HTTP headers like X-Forwarded-For and X-Real-IP.
          # Those headers typically define the real IP address of our website visitors and threat actors, used by CrowdSec for decision making and banning.
          forwardedHeadersTrustedIPs:
            - "127.0.0.1/32"    # Loopback addresses
            - "10.0.0.0/8"      # RFC1918 private network
            - "100.64.0.0/10"   # Carrier-grade NAT (RFC6598)
            - "127.0.0.0/8"     # Loopback addresses
            - "169.254.0.0/16"  # Link-local addresses (RFC3927)
            - "172.16.0.0/12"   # RFC1918 private network
            - "192.168.0.0/16"  # RFC1918 private network
            - "::1/128"         # IPv6 loopback address
            - "2002::/16"       # 6to4 IPv6 addresses
            - "fc00::/7"        # Unique local IPv6 unicast (RFC4193)
            - "fe80::/10"       # IPv6 link-local addresses

          # List of client IPs to trust (default: [])
          clientTrustedIPs:
            - "127.0.0.1/32"    # Loopback addresses
            - "10.0.0.0/8"      # RFC1918 private network
            - "100.64.0.0/10"   # Carrier-grade NAT (RFC6598)
            - "127.0.0.0/8"     # Loopback addresses
            - "169.254.0.0/16"  # Link-local addresses (RFC3927)
            - "172.16.0.0/12"   # RFC1918 private network
            - "192.168.0.0/16"  # RFC1918 private network
            - "::1/128"         # IPv6 loopback address
            - "2002::/16"       # 6to4 IPv6 addresses
            - "fc00::/7"        # Unique local IPv6 unicast (RFC4193)
            - "fe80::/10"       # IPv6 link-local addresses
EOF
        destination = "local/dynamic/core.yaml"
        perms       = "0644"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "traefik"
        port = "traefik_api"
        tags = [
          "traefik",
          "${var.domain}",
          "traefik.enable=true",
          "traefik.http.routers.traefik.service=api@internal",
          "traefik.http.routers.traefik.rule=Host(`traefik.${var.domain}`) || Host(`traefik.${node.unique.name}.${var.domain}`)",
          "traefik.http.services.traefik.loadbalancer.server.port=8080",
          "homepage.group=Infrastructure",
          "homepage.name=Traefik",
          "homepage.icon=traefik.png",
          "homepage.href=https://traefik.${var.domain}/dashboard",
          "homepage.widget.type=traefik",
          "homepage.description=Reverse proxy entrypoint for all services with TLS, Cloudflare integration, and auth middleware",
          "kuma.traefik.http.name=traefik.${node.unique.name}.${var.domain}",
          "kuma.traefik.http.url=https://traefik.${var.domain}/dashboard",
          "kuma.traefik.http.interval=20"
        ]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "traefik healthcheck --ping > /dev/null 2>&1 || exit 1"]
          interval = "10s"
          timeout  = "3s"
        }
      }
    }
  }
  group "whoami-group" {
    count = 1

    network {
      mode = "bridge"
      
      port "whoami" { to = 80 }
    }

    # Whoami
    task "whoami" {
      driver = "docker"

      config {
        image = "docker.io/traefik/whoami:v1.11"
        ports = ["whoami"]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "whoami"
        }
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {

        name = "whoami"
        port = "whoami"
        tags = [
          "traefik.enable=true",
          "traefik.http.routers.whoami.service=whoami@consulcatalog",
          "traefik.http.services.whoami.loadbalancer.server.port=80",
          "homepage.group=Web Services",
          "homepage.name=whoami",
          "homepage.icon=whoami.png",
          "homepage.href=https://whoami.${var.domain}",
          "homepage.description=Request echo service used to verify reverse-proxy, headers, and auth middleware",
          "kuma.whoami.http.name=whoami.${node.unique.name}.${var.domain}",
          "kuma.whoami.http.url=https://whoami.${var.domain}",
          "kuma.whoami.http.interval=60"
        ]

        check {
          type     = "http"
          path     = "/"
          interval = "30s"
          timeout  = "10s"
        }
      }
    }
  }
  group "autokuma-group" {
    count = 1

    network {
      mode = "bridge"
      
    }

    # Autokuma
    task "autokuma" {
      driver = "docker"

      config {
        image = "ghcr.io/bigboot/autokuma:latest"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "autokuma"
        }
      }

      template {
        data = <<EOF
AUTOKUMA__KUMA__URL={{ env "AUTOKUMA__KUMA__URL" | or "https://uptimekuma.${var.domain}" }}
AUTOKUMA__KUMA__USERNAME={{ env "AUTOKUMA__KUMA__USERNAME" | or "admin" }}
AUTOKUMA__KUMA__PASSWORD={{ with (env "AUTOKUMA__KUMA__PASSWORD") }}{{ . }}{{ else }}${ var.sudo_password }{{ end }}
AUTOKUMA__KUMA__CALL_TIMEOUT={{ env "AUTOKUMA__KUMA__CALL_TIMEOUT" | or "5" }}
AUTOKUMA__KUMA__CONNECT_TIMEOUT={{ env "AUTOKUMA__KUMA__CONNECT_TIMEOUT" | or "5" }}
EOF
        destination = "local/autokuma.env"
        env         = true
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }
  group "docker-gen-failover-group" {
    count = 1

    network {
      mode = "bridge"
      
    }

    # Docker Gen for Traefik Failover Configuration
    task "docker-gen-failover" {
      driver = "docker"

      config {
        image = "docker.io/nginxproxy/docker-gen:latest"
        volumes = [
          "${var.config_path}/traefik/dynamic:/traefik/dynamic"
        ]
        args = [
          "-endpoint", "tcp://dockerproxy-rw:2375",
          "-only-exposed",
          "-include-stopped",
          "-event-filter", "event=start",
          "-event-filter", "event=create",
          "-event-filter", "event=expose",
          "-event-filter", "event=update",
          "-event-filter", "event=connect",
          "-event-filter", "label=traefik.enable=true",
          "-container-filter", "label=traefik.enable=true",
          "-watch", "/templates/traefik-failover-dynamic.conf.tmpl", "/traefik/dynamic/failover-fallbacks.yaml"
        ]
        extra_hosts = ["host.docker.internal:${attr.unique.network.ip-address}"]
      }

      # Traefik failover template
      template {
        data = <<EOF
# NOTE: This template is a placeholder - the actual template content 
# should be copied from compose/docker-compose.coolify-proxy.yml config section
# for traefik-failover-dynamic.conf.tmpl
# 
# This generates dynamic Traefik configuration for container failover
EOF
        destination = "local/templates/traefik-failover-dynamic.conf.tmpl"
      }

      resources {
        cpu        = 500
        memory     = 256
        memory_max = 512
      }

      service {
        name = "docker-gen-failover"
        tags = [
          "docker-gen-failover",
          "${var.domain}"
        ]
      }

      restart {
        attempts = 0
        mode     = "fail"
      }
    }
  }

  group "logrotate-traefik-group" {
    count = 1

    # Task uses network_mode = "none", so we don't need a network block

    # Logrotate for Traefik
    task "logrotate-traefik" {
      driver = "docker"

      config {
        image = "docker.io/bolabaden/logrotate-traefik:latest"
        network_mode = "none"
        volumes = [
          "${var.config_path}/traefik/logs:/var/log/traefik"
        ]
        labels = {
          "com.docker.compose.project" = "coolify-proxy-group"
          "com.docker.compose.service" = "logrotate-traefik"
        }
      }

      env {
        TZ = var.tz
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }

  group "infrastructure-services" {
    count = 1

    network {
      mode = "bridge"
      
      port "dockerproxy_ro" { to = 2375 }
      
      # dockerproxy-rw has ports: 127.0.0.1:2375:2375 in docker-compose.yml
      port "dockerproxy_rw" { to = 2375 }
    }

    # 🔹🔹 Docker Socket Proxy (Read-Only) 🔹🔹
    task "dockerproxy-ro" {
      driver = "docker"

      config {
        image = "docker.io/tecnativa/docker-socket-proxy"
        ports = ["dockerproxy_ro"]
        privileged = true
        userns_mode = "host"  # needed if userns-remap is enabled on the host
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "dockerproxy-ro"
          "deunhealth.restart.on.unhealthy" = "true"
        }
      }

      env {
        TZ           = var.tz
        PUID         = var.puid
        PGID         = var.pgid
        UMASK        = var.umask
        CONTAINERS   = "1"
        EVENTS       = "1"
        INFO         = "1"
        DISABLE_IPV6 = "0"
      }

      resources {
        cpu        = 200
        memory     = 256
        memory_max = 512
      }

      service {
        name = "dockerproxy-ro"
        port = "dockerproxy_ro"
        tags = ["dockerproxy-ro"]

        check {
          type     = "script"
          command  = "/bin/sh"
          args     = ["-c", "wget --no-verbose --tries=1 --spider http://127.0.0.1:2375/_ping || exit 1"]
          interval = "30s"
          timeout  = "10s"
        }
      }
    }

    # 🔹🔹 Docker Socket Proxy (Read-Write) 🔹🔹
    task "dockerproxy-rw" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/socket-proxy"
        ports = ["dockerproxy_rw"]  # Has ports: 127.0.0.1:2375:2375 in docker-compose.yml
        privileged = true
        userns_mode = "host"  # this is needed if https://docs.docker.com/engine/security/userns-remap/#enable-userns-remap-on-the-daemon is setup
        volumes = [
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "dockerproxy-rw"
        }
      }

      env {
        TZ           = var.tz
        PUID         = var.puid
        PGID         = var.pgid
        UMASK        = var.umask
        # Controls /containers/{id}/start (POST).
        # Set 1 to allow starting containers even if POST=0.
        # Useful for selective starts in read-only mode.
        ALLOW_START  = "1"
        # Controls /containers/{id}/stop (POST).
        # Set 1 to allow stopping containers even if POST=0. Enables remote shutdown without broad write access.
        ALLOW_STOP   = "1"
        # Enables /containers/{id}/stop, /restart, /kill (POST).
        # Set 1 to allow restarts/kills even if POST=0. Useful for health checks and auto-scaling.
        ALLOW_RESTARTS = "1"
        # Controls /auth (POST) for registry authentication.
        # Set 1 to allow credential handling for private image pulls.
        AUTH         = "1"
        # Controls /build (POST) for building images.
        # Set 1 to allow image builds, e.g. for CI tools.
        BUILD        = "1"
        # Controls /commit (POST) to save container changes as new image.
        # Set 1 to allow ad-hoc image creation.
        COMMIT       = "1"
        # Controls /configs endpoints (Swarm).
        # Set 1 to allow config management (create/list/delete).
        CONFIGS      = "1"
        # Controls /containers endpoints.
        # Set 1 to allow list, inspect, create, and manage containers.
        CONTAINERS   = "1"
        # Set 1 to prevent proxy from binding to IPv6 interfaces. Useful for legacy systems.
        DISABLE_IPV6 = "0"
        # Controls /distribution endpoints for image metadata.
        # Set 1 to allow inspection of image distribution info.
        DISTRIBUTION = "1"
        # Enables /events (GET) for real-time Docker event streaming.
        # Set 1 to allow monitoring.
        EVENTS       = "1"
        # Controls /exec and /containers/{id}/exec.
        # Set 1 to allow running commands in containers (shell access).
        EXEC         = "1"
        # Controls /images endpoints.
        # Set 1 to allow image list, pull, remove, etc.
        IMAGES       = "1"
        # Enables /info (GET) for daemon diagnostics.
        # Set 1 to allow health/status queries.
        INFO         = "1"
        # Sets NGINX error_log level (debug, info, warning, etc). Affects proxy logging verbosity.
        LOG_LEVEL    = "info"
        # Controls /networks endpoints.
        # Set 1 to allow network management (create/list/delete).
        NETWORKS     = "1"
        # Controls /nodes endpoints (Swarm).
        # Set 1 to allow node management.
        NODES        = "1"
        # Enables /_ping (GET) for daemon health checks.
        # Set 1 to allow.
        PING         = "1"
        # Controls /plugins endpoints.
        # Set 1 to allow plugin management (enable/disable/list).
        PLUGINS      = "1"
        # Toggles all write methods (POST/PUT/DELETE) globally.
        # Set 0 for read-only except for specific overrides.
        POST         = "1"
        # Controls /secrets endpoints (Swarm).
        # Set 1 to allow secret management.
        SECRETS      = "1"
        # Controls /services endpoints (Swarm).
        # Set 1 to allow service management.
        SERVICES     = "1"
        # Enables /session for interactive protocols (attach/exec).
        # Set 1 to allow.
        SESSION      = "1"
        # Controls /swarm endpoints.
        # Set 1 to allow Swarm cluster management.
        SWARM        = "1"
        # Controls /system subpaths (info, version, df).
        # Set 1 to allow system queries.
        SYSTEM       = "1"
        # Controls /tasks endpoints (Swarm).
        # Set 1 to allow task inspection.
        TASKS        = "1"
        # Enables /version (GET) for daemon/client version info.
        # Set 1 to allow.
        VERSION      = "1"
        # Controls /volumes endpoints.
        # Set 1 to allow volume management (create/list/delete).
        VOLUMES      = "1"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }

      service {
        name = "dockerproxy-rw"
        port = "dockerproxy_rw"
        tags = ["dockerproxy-rw"]
      }
    }

    # 🔹🔹 Watchtower 🔹🔹
    task "watchtower" {
      driver = "docker"

      config {
        image = "docker.io/containrrr/watchtower"
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:rw"
        ]
        labels = {
          "com.docker.compose.project" = "core-group"
          "com.docker.compose.service" = "watchtower"
        }
      }

      # Watchtower needs Docker credentials config
      # docker credentials acquired through `docker login` on host!
      template {
        data = <<EOF
{
  "auths": {}
}
EOF
        destination = "local/config.json"
        perms       = "0444"
      }

      env {
        # --------------------------------------------------------------------------
        # Docker Host Configuration
        # --------------------------------------------------------------------------
        # Docker daemon socket to connect to. Can be pointed at a remote Docker host
        # by specifying a TCP endpoint as "tcp://hostname:port".
        # Default: "unix:///var/run/docker.sock"
        DOCKER_HOST                        = "unix:///var/run/docker.sock"
        # Docker API version to use by the Docker client for connecting to the Docker daemon.
        # Default: "1.24"
        DOCKER_API_VERSION                 = "1.52"
        # Use TLS when connecting to the Docker socket and verify the server's certificate.
        # Default: false
        DOCKER_TLS_VERIFY                  = "false"
        # --------------------------------------------------------------------------
        # Timezone
        # --------------------------------------------------------------------------
        # Sets the time zone to be used by WatchTower's logs and scheduling.
        # Default: "UTC"
        TZ                                 = var.tz
        # --------------------------------------------------------------------------
        # Registry Authentication (for private image pulls)
        # --------------------------------------------------------------------------
        # Docker registry username for private image pulls (if required).
        # Default: "username"
        REPO_USER                          = "bolabaden"
        # Docker registry password for private image pulls (if required).
        # Default: "password"
        REPO_PASS                          = var.sudo_password
        # --------------------------------------------------------------------------
        # Watchtower Container Filtering and Behavior
        # --------------------------------------------------------------------------
        # Will also include restarting containers.
        # Default: false
        WATCHTOWER_INCLUDE_RESTARTING      = "true"
        # Will also include created and exited containers.
        # Default: false
        WATCHTOWER_INCLUDE_STOPPED         = "true"
        # Start any stopped containers that have had their image updated. Only usable with --include-stopped.
        # Default: false
        WATCHTOWER_REVIVE_STOPPED          = "false"
        # Monitor and update containers that have a com.centurylinklabs.watchtower.enable label set to true.
        # Default: false
        WATCHTOWER_LABEL_ENABLE            = "false"
        # Monitor and update containers whose names are not in a given set of names (comma- or space-separated).
        # Default: ""
        WATCHTOWER_DISABLE_CONTAINERS      = ""
        # By default, arguments will take precedence over labels. If set to true, labels take precedence.
        # Default: false
        WATCHTOWER_LABEL_TAKE_PRECEDENCE   = "true"
        # Update containers that have a com.centurylinklabs.watchtower.scope label set with the same value as the given argument.
        # Default: unset
        WATCHTOWER_SCOPE                   = ""
        # --------------------------------------------------------------------------
        # Update and Polling Behavior
        # --------------------------------------------------------------------------
        # Poll interval (in seconds). Controls how frequently watchtower will poll for new images.
        # Default: 86400 (24 hours)
        WATCHTOWER_POLL_INTERVAL           = "86400"
        # Cron expression in 6 fields which defines when and how often to check for new images.
        # Default: unset
        WATCHTOWER_SCHEDULE                = "0 0 6 * * *"  # Run at 6am daily
        # Will only monitor for new images, send notifications and invoke the pre-check/post-check hooks, but will not update the containers.
        # Default: false
        WATCHTOWER_MONITOR_ONLY            = "false"
        # Do not restart containers after updating.
        # Default: false
        WATCHTOWER_NO_RESTART              = "false"
        # Do not pull new images. Only monitor the local image cache for changes.
        # Default: false
        WATCHTOWER_NO_PULL                 = "false"
        # Removes old images after updating to prevent accumulation of orphaned images.
        # Default: false
        WATCHTOWER_CLEANUP                 = "true"
        # Removes anonymous volumes after updating.
        # Default: false
        WATCHTOWER_REMOVE_VOLUMES          = "false"
        # Restart one image at time instead of stopping and starting all at once.
        # Default: false
        WATCHTOWER_ROLLING_RESTART         = "false"
        # Timeout before the container is forcefully stopped. Example: 30s
        # Default: 10s
        WATCHTOWER_TIMEOUT                 = "10s"
        # Run an update attempt against a container name list one time immediately and exit.
        # Default: false
        WATCHTOWER_RUN_ONCE                = "false"
        # Do not send a message after watchtower started.
        # Default: false
        WATCHTOWER_NO_STARTUP_MESSAGE      = "false"
        # When to warn about HEAD pull requests failing. Possible values: always, auto, never
        # Default: auto
        WATCHTOWER_WARN_ON_HEAD_FAILURE    = "auto"
        # --------------------------------------------------------------------------
        # HTTP API Mode
        # --------------------------------------------------------------------------
        # Runs Watchtower in HTTP API mode, only allowing image updates to be triggered by an HTTP request.
        # Default: false
        WATCHTOWER_HTTP_API_UPDATE         = "false"
        # Sets an authentication token to HTTP API requests. Can also reference a file.
        # Default: unset
        WATCHTOWER_HTTP_API_TOKEN          = ""
        # Keep running periodic updates if the HTTP API mode is enabled.
        # Default: false
        WATCHTOWER_HTTP_API_PERIODIC_POLLS = "false"
        # Enables a metrics endpoint, exposing prometheus metrics via HTTP.
        # NOTE: Requires an API token to be set for WATCHTOWER_HTTP_API_TOKEN (above).
        # Default: false
        WATCHTOWER_HTTP_API_METRICS        = "false"
        # --------------------------------------------------------------------------
        # Logging and Output
        # --------------------------------------------------------------------------
        # Enable debug mode with verbose logging.
        # Default: false
        WATCHTOWER_DEBUG                   = "true"
        # Enable trace mode with very verbose logging. Caution: exposes credentials!
        # Default: false
        WATCHTOWER_TRACE                   = "false"
        # The maximum log level that will be written to STDERR. Possible values: panic, fatal, error, warn, info, debug, trace.
        # Default: info
        WATCHTOWER_LOG_LEVEL               = "debug"
        # Sets what logging format to use for console output. Possible values: Auto, LogFmt, Pretty, JSON.
        # Default: Auto
        WATCHTOWER_LOG_FORMAT              = "Auto"
        # Disable ANSI color escape codes in log output.
        # Default: false
        NO_COLOR                           = "false"
        # Enable programmatic output (porcelain). Possible values: v1
        # Default: unset
        WATCHTOWER_PORCELAIN               = ""
        # --------------------------------------------------------------------------
        # Notification and Reporting
        # --------------------------------------------------------------------------
        # Notification URL(s) for sending update reports (e.g. shoutrrr URLs, email, Slack, etc).
        # Default: unset
        WATCHTOWER_NOTIFICATION_URL        = ""
        # Send a notification report after each update cycle.
        # Default: false
        WATCHTOWER_NOTIFICATION_REPORT     = "true"
      }

      resources {
        cpu        = 1
        memory     = 256
        memory_max = 0
      
      }
    }
  }
}
