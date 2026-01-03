package main

import (
	"fmt"
)

// defineServicesMetrics returns all services from compose/docker-compose.metrics.yml
// Note: Large configs (grafana.ini, prometheus.yml, loki.yaml, promtail.yaml, blackbox.yml)
// are expected to exist in ${CONFIG_PATH}/metrics/ directory
func defineServicesMetrics(config *Config) []Service {
	domain := config.Domain
	configPath := config.ConfigPath
	secretsPath := config.SecretsPath
	tsHostname := getEnv("TS_HOSTNAME", "localhost")

	services := []Service{}

	// init_victoriametrics
	services = append(services, Service{
		Name:          "init_victoriametrics",
		Image:         "docker.io/victoriametrics/victoria-metrics:latest",
		ContainerName: "init_victoriametrics",
		Hostname:      "init_victoriametrics",
		User:          "root",
		Entrypoint:    []string{"/bin/sh", "-c", "chown -R 65534:65534 /storage && chmod -R 755 /storage"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/victoriametrics", configPath), Target: "/storage", Type: "bind"},
		},
		Restart:    "no",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// victoriametrics
	victoriametricsPort := getEnv("VICTORIAMETRICS_PORT", "8428")
	services = append(services, Service{
		Name:          "victoriametrics",
		Image:         "docker.io/victoriametrics/victoria-metrics:latest",
		ContainerName: "victoriametrics",
		Hostname:      "victoriametrics",
		Networks:      []string{"backend"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/victoriametrics", configPath), Target: "/storage", Type: "bind"},
		},
		Environment: map[string]string{
			"VM_RETENTION_PERIOD":                              getEnv("VICTORIAMETRICS_RETENTION_PERIOD", "1y"),
			"VM_MEMORY_ALLOWED_PERCENT":                        getEnv("VICTORIAMETRICS_MEMORY_ALLOWED_PERCENT", "60"),
			"VM_SEARCH_MAX_CONCURRENT_REQUESTS":                getEnv("VICTORIAMETRICS_SEARCH_MAX_CONCURRENT_REQUESTS", "8"),
			"VM_INSERT_MAX_CONCURRENT_REQUESTS":                getEnv("VICTORIAMETRICS_INSERT_MAX_CONCURRENT_REQUESTS", "32"),
			"VICTORIAMETRICS_BIG_MERGE_CONCURRENCY":            getEnv("VICTORIAMETRICS_BIG_MERGE_CONCURRENCY", "0"),
			"VICTORIAMETRICS_DEDUP_MIN_SCRAPE_INTERVAL":        getEnv("VICTORIAMETRICS_DEDUP_MIN_SCRAPE_INTERVAL", "0s"),
			"VICTORIAMETRICS_ENABLE_TCP6":                      getEnv("VICTORIAMETRICS_ENABLE_TCP6", "false"),
			"VICTORIAMETRICS_FINAL_MERGE_DELAY":                getEnv("VICTORIAMETRICS_FINAL_MERGE_DELAY", "0s"),
			"VICTORIAMETRICS_MAX_GRACEFUL_SHUTDOWN_DURATION":   getEnv("VICTORIAMETRICS_MAX_GRACEFUL_SHUTDOWN_DURATION", "7s"),
			"VICTORIAMETRICS_SHUTDOWN_DELAY":                   getEnv("VICTORIAMETRICS_SHUTDOWN_DELAY", "0s"),
			"VICTORIAMETRICS_PORT":                             victoriametricsPort,
			"VICTORIAMETRICS_INFLUX_MAX_LINE_SIZE":             getEnv("VICTORIAMETRICS_INFLUX_MAX_LINE_SIZE", "262144"),
			"VICTORIAMETRICS_LOG_FORMAT":                       getEnv("VICTORIAMETRICS_LOG_FORMAT", "default"),
			"VICTORIAMETRICS_LOG_LEVEL":                        getEnv("VICTORIAMETRICS_LOG_LEVEL", "INFO"),
			"VICTORIAMETRICS_PROMSCRAPE_MAX_SCRAPE_SIZE":       getEnv("VICTORIAMETRICS_PROMSCRAPE_MAX_SCRAPE_SIZE", "16777216"),
			"VICTORIAMETRICS_SEARCH_MAX_MEMORY_PER_QUERY":      getEnv("VICTORIAMETRICS_SEARCH_MAX_MEMORY_PER_QUERY", "1GB"),
			"VICTORIAMETRICS_SEARCH_MAX_POINTS_PER_TIMESERIES": getEnv("VICTORIAMETRICS_SEARCH_MAX_POINTS_PER_TIMESERIES", "30000"),
			"VICTORIAMETRICS_SEARCH_MAX_QUERY_DURATION":        getEnv("VICTORIAMETRICS_SEARCH_MAX_QUERY_DURATION", "30s"),
			"VICTORIAMETRICS_SEARCH_MAX_SERIES":                getEnv("VICTORIAMETRICS_SEARCH_MAX_SERIES", "30000"),
			"VICTORIAMETRICS_SEARCH_MAX_TAG_KEYS":              getEnv("VICTORIAMETRICS_SEARCH_MAX_TAG_KEYS", "100000"),
			"VICTORIAMETRICS_SEARCH_MAX_TAG_VALUES":            getEnv("VICTORIAMETRICS_SEARCH_MAX_TAG_VALUES", "100000"),
			"VICTORIAMETRICS_SEARCH_MAX_UNIQUE_TIMESERIES":     getEnv("VICTORIAMETRICS_SEARCH_MAX_UNIQUE_TIMESERIES", "300000"),
			"VICTORIAMETRICS_SMALL_MERGE_CONCURRENCY":          getEnv("VICTORIAMETRICS_SMALL_MERGE_CONCURRENCY", "0"),
		},
		Command: []string{
			fmt.Sprintf("--bigMergeConcurrency=%s", getEnv("VICTORIAMETRICS_BIG_MERGE_CONCURRENCY", "0")),
			fmt.Sprintf("--dedup.minScrapeInterval=%s", getEnv("VICTORIAMETRICS_DEDUP_MIN_SCRAPE_INTERVAL", "0s")),
			fmt.Sprintf("--enableTCP6=%s", getEnv("VICTORIAMETRICS_ENABLE_TCP6", "false")),
			fmt.Sprintf("--finalMergeDelay=%s", getEnv("VICTORIAMETRICS_FINAL_MERGE_DELAY", "0s")),
			fmt.Sprintf("--http.maxGracefulShutdownDuration=%s", getEnv("VICTORIAMETRICS_MAX_GRACEFUL_SHUTDOWN_DURATION", "7s")),
			fmt.Sprintf("--http.shutdownDelay=%s", getEnv("VICTORIAMETRICS_SHUTDOWN_DELAY", "0s")),
			fmt.Sprintf("--httpListenAddr=:%s", victoriametricsPort),
			fmt.Sprintf("--influx.maxLineSize=%s", getEnv("VICTORIAMETRICS_INFLUX_MAX_LINE_SIZE", "262144")),
			fmt.Sprintf("--loggerFormat=%s", getEnv("VICTORIAMETRICS_LOG_FORMAT", "default")),
			fmt.Sprintf("--loggerLevel=%s", getEnv("VICTORIAMETRICS_LOG_LEVEL", "INFO")),
			fmt.Sprintf("--memory.allowedPercent=%s", getEnv("VICTORIAMETRICS_MEMORY_ALLOWED_PERCENT", "60")),
			fmt.Sprintf("--promscrape.maxScrapeSize=%s", getEnv("VICTORIAMETRICS_PROMSCRAPE_MAX_SCRAPE_SIZE", "16777216")),
			fmt.Sprintf("--retentionPeriod=%s", getEnv("VICTORIAMETRICS_RETENTION_PERIOD", "1y")),
			fmt.Sprintf("--search.maxConcurrentRequests=%s", getEnv("VICTORIAMETRICS_SEARCH_MAX_CONCURRENT_REQUESTS", "8")),
			fmt.Sprintf("--search.maxMemoryPerQuery=%s", getEnv("VICTORIAMETRICS_SEARCH_MAX_MEMORY_PER_QUERY", "1GB")),
			fmt.Sprintf("--search.maxPointsPerTimeseries=%s", getEnv("VICTORIAMETRICS_SEARCH_MAX_POINTS_PER_TIMESERIES", "30000")),
			fmt.Sprintf("--search.maxQueryDuration=%s", getEnv("VICTORIAMETRICS_SEARCH_MAX_QUERY_DURATION", "30s")),
			fmt.Sprintf("--search.maxSeries=%s", getEnv("VICTORIAMETRICS_SEARCH_MAX_SERIES", "30000")),
			fmt.Sprintf("--search.maxTagKeys=%s", getEnv("VICTORIAMETRICS_SEARCH_MAX_TAG_KEYS", "100000")),
			fmt.Sprintf("--search.maxTagValues=%s", getEnv("VICTORIAMETRICS_SEARCH_MAX_TAG_VALUES", "100000")),
			fmt.Sprintf("--search.maxUniqueTimeseries=%s", getEnv("VICTORIAMETRICS_SEARCH_MAX_UNIQUE_TIMESERIES", "300000")),
			fmt.Sprintf("--smallMergeConcurrency=%s", getEnv("VICTORIAMETRICS_SMALL_MERGE_CONCURRENCY", "0")),
			"--storageDataPath=/storage",
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
			"prometheus.io/scrape":            "true",
			"prometheus.io/port":              victoriametricsPort,
			"prometheus.io/path":              "/metrics",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", fmt.Sprintf("wget --no-verbose --tries=1 --spider http://127.0.0.1:%s/health || exit 1", victoriametricsPort)},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "40s",
		},
		DependsOn:  []string{"init_victoriametrics"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// init_prometheus
	services = append(services, Service{
		Name:          "init_prometheus",
		Image:         "docker.io/prom/prometheus",
		ContainerName: "init_prometheus",
		Hostname:      "init_prometheus",
		User:          "root",
		Entrypoint:    []string{"/bin/sh", "-c", "chown -R 65534:65534 /prometheus"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/prometheus/data", configPath), Target: "/prometheus", Type: "bind"},
		},
		Restart:    "no",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// prometheus
	services = append(services, Service{
		Name:          "prometheus",
		Image:         "docker.io/prom/prometheus",
		ContainerName: "prometheus",
		Hostname:      "prometheus",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/prometheus/data", configPath), Target: "/prometheus", Type: "bind"},
		},
		Configs: []ConfigMount{
			{Source: fmt.Sprintf("%s/metrics/prometheus.yml", configPath), Target: "/etc/prometheus/prometheus.yml", Mode: "0444"},
			{Source: fmt.Sprintf("%s/metrics/alert.rules", configPath), Target: "/etc/prometheus/alert.rules", Mode: "0444"},
		},
		Environment: map[string]string{
			"PROMETHEUS_RETENTION_TIME":        getEnv("PROMETHEUS_RETENTION_TIME", "15d"),
			"PROMETHEUS_RETENTION_SIZE":        getEnv("PROMETHEUS_RETENTION_SIZE", "0"),
			"PROMETHEUS_QUERY_MAX_CONCURRENCY": getEnv("PROMETHEUS_QUERY_MAX_CONCURRENCY", "20"),
			"PROMETHEUS_QUERY_TIMEOUT":         getEnv("PROMETHEUS_QUERY_TIMEOUT", "2m"),
			"PROMETHEUS_QUERY_MAX_SAMPLES":     getEnv("PROMETHEUS_QUERY_MAX_SAMPLES", "50000000"),
			"PROMETHEUS_WEB_MAX_CONNECTIONS":   getEnv("PROMETHEUS_WEB_MAX_CONNECTIONS", "512"),
			"PROMETHEUS_LOG_FORMAT":            getEnv("PROMETHEUS_LOG_FORMAT", "logfmt"),
			"PROMETHEUS_LOG_LEVEL":             getEnv("PROMETHEUS_LOG_LEVEL", "info"),
		},
		Command: []string{
			"--config.file=/etc/prometheus/prometheus.yml",
			fmt.Sprintf("--log.format=%s", getEnv("PROMETHEUS_LOG_FORMAT", "logfmt")),
			fmt.Sprintf("--log.level=%s", getEnv("PROMETHEUS_LOG_LEVEL", "info")),
			fmt.Sprintf("--query.max-concurrency=%s", getEnv("PROMETHEUS_QUERY_MAX_CONCURRENCY", "20")),
			fmt.Sprintf("--query.max-samples=%s", getEnv("PROMETHEUS_QUERY_MAX_SAMPLES", "50000000")),
			fmt.Sprintf("--query.timeout=%s", getEnv("PROMETHEUS_QUERY_TIMEOUT", "2m")),
			"--storage.tsdb.path=/prometheus",
			fmt.Sprintf("--storage.tsdb.retention.size=%s", getEnv("PROMETHEUS_RETENTION_SIZE", "0")),
			fmt.Sprintf("--storage.tsdb.retention.time=%s", getEnv("PROMETHEUS_RETENTION_TIME", "15d")),
			"--web.console.libraries=/usr/share/prometheus/console_libraries",
			"--web.console.templates=/usr/share/prometheus/consoles",
			"--web.enable-admin-api",
			"--web.enable-lifecycle",
			fmt.Sprintf("--web.max-connections=%s", getEnv("PROMETHEUS_WEB_MAX_CONNECTIONS", "512")),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                           "true",
			"traefik.enable":                                            "true",
			"traefik.http.routers.prometheus.middlewares":               "nginx-auth@file",
			"traefik.http.routers.prometheus.rule":                      fmt.Sprintf("Host(`prometheus.%s`) || Host(`prometheus.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.prometheus.loadbalancer.server.port": "9090",
			"homepage.group":                                            "Infrastructure",
			"homepage.name":                                             "Prometheus",
			"homepage.icon":                                             "prometheus.png",
			"homepage.href":                                             fmt.Sprintf("https://prometheus.%s", domain),
			"homepage.description":                                      "Prometheus is an open-source monitoring system with a dimensional data model, flexible query language, efficient time series database, and modern alerting approach.",
			"homepage.widget.type":                                      "prometheus",
			"homepage.widget.url":                                       "http://prometheus:9090",
			"kuma.prometheus.http.name":                                 fmt.Sprintf("prometheus.%s.%s", tsHostname, domain),
			"kuma.prometheus.http.url":                                  fmt.Sprintf("https://prometheus.%s", domain),
			"kuma.prometheus.http.interval":                             "60",
			"prometheus.io/scrape":                                      "true",
			"prometheus.io/port":                                        "9090",
			"prometheus.io/path":                                        "/metrics",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:9090/-/healthy || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "40s",
		},
		DependsOn:  []string{"init_prometheus", "victoriametrics"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// grafana
	grafanaFQDN := getEnv("GF_FQDN", fmt.Sprintf("grafana.%s", domain))
	grafanaURL := getEnv("GF_URL", fmt.Sprintf("https://%s", grafanaFQDN))
	services = append(services, Service{
		Name:          "grafana",
		Image:         "docker.io/grafana/grafana",
		ContainerName: "grafana",
		Hostname:      "grafana",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/grafana/data", configPath), Target: "/var/lib/grafana", Type: "bind"},
			{Source: fmt.Sprintf("%s/grafana/provisioning", configPath), Target: "/etc/grafana/provisioning", Type: "bind"},
		},
		Configs: []ConfigMount{
			{Source: fmt.Sprintf("%s/metrics/grafana.ini", configPath), Target: "/etc/grafana/grafana.ini", Mode: "0444"},
		},
		Secrets: []SecretMount{
			{Source: fmt.Sprintf("%s/grafana-password.txt", secretsPath), Target: "/run/secrets/grafana-admin-password", Mode: "0400"},
			{Source: fmt.Sprintf("%s/grafana-secret-key.txt", secretsPath), Target: "/run/secrets/grafana-secret-key", Mode: "0400"},
		},
		Environment: map[string]string{
			"GF_LOG_LEVEL":                               getEnv("GF_LOG_LEVEL", "info"),
			"GF_FEATURE_TOGGLES_ENABLE":                  getEnv("GF_FEATURE_TOGGLES_ENABLE", ""),
			"GF_SECURITY_ENCRYPTION_PROVIDER":            "",
			"GF_SECURITY_AVAILABLE_ENCRYPTION_PROVIDERS": "",
			"GF_SERVER_DOMAIN":                           grafanaFQDN,
			"GF_SERVER_ROOT_URL":                         grafanaURL,
			"GF_SECURITY_ADMIN_USER":                     getEnv("GF_SECURITY_ADMIN_USER", "admin"),
			"GF_SECURITY_ADMIN_PASSWORD__FILE":           "/run/secrets/grafana-admin-password",
			"GF_SECURITY_SECRET_KEY__FILE":               "/run/secrets/grafana-secret-key",
			"GF_SECRETS_MANAGER_SECRET_KEY__FILE":        "/run/secrets/grafana-secret-key",
			"GF_PATHS_PROVISIONING":                      getEnv("GF_PATHS_PROVISIONING", "/etc/grafana/provisioning"),
			"GF_SERVER_SERVE_FROM_SUB_PATH":              getEnv("GF_SERVE_FROM_SUB_PATH", "false"),
			"GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS":  getEnv("GF_PLUGINS_ALLOW_LOADING_UNSIGNED_PLUGINS", "victoriametrics-datasource"),
			"GF_PLUGINS_PREINSTALL":                      getEnv("GF_PLUGINS_PREINSTALL", "grafana-piechart-panel,grafana-worldmap-panel,natel-discrete-panel,flant-statusmap-panel,vonage-status-panel,michaeldmoore-multistat-panel,grafana-polystat-panel,marcusolsson-dynamictext-panel,yesoreyeram-boomtable-panel,grafana-clock-panel,grafana-simple-json-datasource,btplc-status-dot-panel,camptocamp-prometheus-alertmanager-datasource"),
			"GF_SECURITY_COOKIE_SECURE":                  getEnv("GF_SECURITY_COOKIE_SECURE", "true"),
			"GF_SECURITY_COOKIE_SAMESITE":                getEnv("GF_SECURITY_COOKIE_SAMESITE", "lax"),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                        "true",
			"traefik.enable":                                         "true",
			"traefik.http.routers.grafana.rule":                      fmt.Sprintf("Host(`%s`)", grafanaFQDN),
			"traefik.http.services.grafana.loadbalancer.server.port": "3000",
			"homepage.group":                                         "Infrastructure",
			"homepage.name":                                          "Grafana",
			"homepage.icon":                                          "grafana.png",
			"homepage.href":                                          grafanaURL,
			"homepage.description":                                   "Grafana is an open-source platform for monitoring and observability.",
			"kuma.grafana.http.name":                                 fmt.Sprintf("grafana.%s.%s", tsHostname, domain),
			"kuma.grafana.http.url":                                  grafanaURL,
			"kuma.grafana.http.interval":                             "60",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/api/health || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "60s",
		},
		DependsOn:  []string{"prometheus"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// node_exporter
	services = append(services, Service{
		Name:          "node_exporter",
		Image:         "docker.io/prom/node-exporter",
		ContainerName: "node_exporter",
		Hostname:      "node_exporter",
		Networks:      []string{"backend"},
		Volumes: []VolumeMount{
			{Source: "/proc", Target: "/host/proc", Type: "bind", ReadOnly: true},
			{Source: "/sys", Target: "/host/sys", Type: "bind", ReadOnly: true},
			{Source: "/", Target: "/rootfs", Type: "bind", ReadOnly: true},
			{Source: "/run/dbus/system_bus_socket", Target: "/var/run/dbus/system_bus_socket", Type: "bind", ReadOnly: true},
			{Source: "/etc/machine-id", Target: "/etc/machine-id", Type: "bind", ReadOnly: true},
			{Source: "/run/udev/data", Target: "/run/udev/data", Type: "bind", ReadOnly: true},
		},
		Environment: map[string]string{
			"DBUS_SESSION_BUS_ADDRESS": "unix:path=/var/run/dbus/system_bus_socket",
		},
		Command: []string{
			"--path.procfs=/host/proc",
			"--path.rootfs=/rootfs",
			"--path.sysfs=/host/sys",
			"--collector.cpu.info",
			"--collector.diskstats.device-exclude=^(ram|loop|fd|(h|s|v)d[a-z]|nvme\\d+n\\d+p)\\d+$",
			"--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($|/)",
			"--collector.interrupts",
			"--collector.processes",
			"--collector.systemd",
			"--collector.systemd.unit-include=.*",
			"--collector.systemd.unit-exclude=.+\\.(automount|device|mount|scope|slice)",
			"--collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$",
		},
		Labels: map[string]string{
			"prometheus.io/scrape": "true",
			"prometheus.io/port":   "9100",
			"prometheus.io/path":   "metrics",
		},
		Restart: "always",
	})

	// cadvisor
	services = append(services, Service{
		Name:          "cadvisor",
		Image:         "gcr.io/cadvisor/cadvisor",
		ContainerName: "cadvisor",
		Hostname:      "cadvisor",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: "/", Target: "/rootfs", Type: "bind", ReadOnly: true},
			{Source: "/var/run", Target: "/var/run", Type: "bind", ReadOnly: true},
			{Source: "/sys", Target: "/sys", Type: "bind", ReadOnly: true},
			{Source: "/var/lib/docker/", Target: "/var/lib/docker", Type: "bind", ReadOnly: true},
			{Source: "/dev/disk/", Target: "/dev/disk", Type: "bind", ReadOnly: true},
		},
		Devices:    []string{"/dev/kmsg"},
		Privileged: true,
		Command: []string{
			fmt.Sprintf("--housekeeping_interval=%s", getEnv("CADVISOR_HOUSEKEEPING_INTERVAL", "30s")),
			fmt.Sprintf("--docker_only=%s", getEnv("CADVISOR_DOCKER_ONLY", "true")),
			fmt.Sprintf("--disable_metrics=%s", getEnv("CADVISOR_DISABLE_METRICS", "cpu_topology,disk,memory_numa,tcp,udp,percpu,sched,process,hugetlb,referenced_memory,resctrl,cpuset,advtcp")),
			fmt.Sprintf("--store_container_labels=%s", getEnv("CADVISOR_STORE_CONTAINER_LABELS", "false")),
		},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy":                         "true",
			"traefik.enable":                                          "true",
			"traefik.http.routers.cadvisor.middlewares":               "nginx-auth@file",
			"traefik.http.routers.cadvisor.rule":                      fmt.Sprintf("Host(`cadvisor.%s`) || Host(`cadvisor.%s.%s`)", domain, tsHostname, domain),
			"traefik.http.services.cadvisor.loadbalancer.server.port": "8080",
			"homepage.group":                                          "Monitoring",
			"homepage.name":                                           "cAdvisor",
			"homepage.icon":                                           "https://raw.githubusercontent.com/google/cadvisor/master/logo.png",
			"homepage.href":                                           fmt.Sprintf("https://cadvisor.%s/", domain),
			"homepage.description":                                    "Container resource usage and performance characteristics",
			"kuma.cadvisor.http.name":                                 fmt.Sprintf("cadvisor.%s.%s", tsHostname, domain),
			"kuma.cadvisor.http.url":                                  fmt.Sprintf("https://cadvisor.%s", domain),
			"kuma.cadvisor.http.interval":                             "60",
			"prometheus.io/scrape":                                    "true",
			"prometheus.io/port":                                      "8080",
			"prometheus.io/path":                                      "metrics",
		},
		Healthcheck: &Healthcheck{
			Test:        []string{"CMD-SHELL", "command -v wget >/dev/null || (apt-get update >/dev/null 2>&1 && apt-get install -y wget >/dev/null 2>&1); wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/metrics || exit 1"},
			Interval:    "30s",
			Timeout:     "10s",
			Retries:     3,
			StartPeriod: "30s",
		},
		Restart: "always",
	})

	// loki
	services = append(services, Service{
		Name:          "loki",
		Image:         "docker.io/grafana/loki",
		ContainerName: "loki",
		Hostname:      "loki",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: fmt.Sprintf("%s/loki/data", configPath), Target: "/loki", Type: "bind"},
		},
		Configs: []ConfigMount{
			{Source: fmt.Sprintf("%s/metrics/loki.yaml", configPath), Target: "/etc/loki/config.yaml", Mode: "0777"},
		},
		Command: []string{"-config.file=/etc/loki/config.yaml"},
		Labels: map[string]string{
			"deunhealth.restart.on.unhealthy": "true",
		},
		Restart: "always",
	})

	// promtail
	services = append(services, Service{
		Name:          "promtail",
		Image:         "docker.io/grafana/promtail",
		ContainerName: "promtail",
		Hostname:      "promtail",
		Networks:      []string{"backend", "publicnet"},
		Volumes: []VolumeMount{
			{Source: "/var/lib/docker/containers", Target: "/var/lib/docker/containers", Type: "bind", ReadOnly: true},
			{Source: "/var/log", Target: "/var/log", Type: "bind", ReadOnly: true},
		},
		Configs: []ConfigMount{
			{Source: fmt.Sprintf("%s/metrics/promtail.yaml", configPath), Target: "/etc/promtail/config.yaml", Mode: "0777"},
		},
		Environment: map[string]string{
			"DOCKER_HOST": "tcp://dockerproxy-ro:9323",
		},
		Command:    []string{"-config.file=/etc/promtail/config.yaml"},
		DependsOn:  []string{"loki"},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	// blackbox-exporter
	services = append(services, Service{
		Name:          "blackbox-exporter",
		Image:         "docker.io/prom/blackbox-exporter",
		ContainerName: "blackbox-exporter",
		Hostname:      "blackbox-exporter",
		Networks:      []string{"backend", "publicnet"},
		Configs: []ConfigMount{
			{Source: fmt.Sprintf("%s/metrics/blackbox.yml", configPath), Target: getEnv("BLACKBOX_INTERNAL_CONFIG_PATH", "/etc/blackbox_exporter/config.yml"), Mode: "0777"},
		},
		Command: []string{
			fmt.Sprintf("--config.file=%s", getEnv("BLACKBOX_INTERNAL_CONFIG_PATH", "/etc/blackbox_exporter/config.yml")),
		},
		Labels: map[string]string{
			"prometheus.io/scrape": "true",
			"prometheus.io/port":   "9115",
			"prometheus.io/path":   "/metrics",
		},
		Restart:    "always",
		ExtraHosts: []string{"host.docker.internal:host-gateway"},
	})

	return services
}
