package config

import (
	"testing"
)

func TestBuildServiceURL(t *testing.T) {
	cfg := &Config{
		Domain:   "example.com",
		NodeName: "node1",
	}

	tests := []struct {
		name      string
		service   string
		useHTTPS  bool
		path      string
		want      string
	}{
		{
			name:     "HTTP without path",
			service:  "api",
			useHTTPS: false,
			path:     "",
			want:     "http://api.node1.example.com",
		},
		{
			name:     "HTTPS without path",
			service:  "api",
			useHTTPS: true,
			path:     "",
			want:     "https://api.node1.example.com",
		},
		{
			name:     "HTTPS with path",
			service:  "api",
			useHTTPS: true,
			path:     "/v1/health",
			want:     "https://api.node1.example.com/v1/health",
		},
		{
			name:     "HTTP with path without leading slash",
			service:  "api",
			useHTTPS: false,
			path:     "v1/health",
			want:     "http://api.node1.example.com/v1/health",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := BuildServiceURL(cfg, tt.service, tt.useHTTPS, tt.path)
			if got != tt.want {
				t.Errorf("BuildServiceURL() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestBuildInternalServiceURL(t *testing.T) {
	tests := []struct {
		name     string
		service  string
		port     int
		path     string
		want     string
	}{
		{
			name:    "default port",
			service: "api",
			port:    80,
			path:    "",
			want:    "http://api",
		},
		{
			name:    "custom port",
			service: "api",
			port:    8080,
			path:    "",
			want:    "http://api:8080",
		},
		{
			name:    "with path",
			service: "api",
			port:    8080,
			path:    "/health",
			want:    "http://api:8080/health",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := BuildInternalServiceURL(tt.service, tt.port, tt.path)
			if got != tt.want {
				t.Errorf("BuildInternalServiceURL() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestIsProduction(t *testing.T) {
	tests := []struct {
		name string
		cfg  *Config
		want bool
	}{
		{
			name: "production config",
			cfg: &Config{
				Domain:      "example.com",
				ConfigPath:  "/opt/infra/volumes",
				Registry:    RegistryConfig{ImagePrefix: "docker.io/myorg"},
			},
			want: true,
		},
		{
			name: "development config",
			cfg: &Config{
				Domain:     "localhost",
				ConfigPath: "./volumes",
				Registry:   RegistryConfig{ImagePrefix: ""},
			},
			want: false,
		},
		{
			name: "local domain",
			cfg: &Config{
				Domain:     "local.example.com",
				ConfigPath: "/opt/infra/volumes",
				Registry:   RegistryConfig{ImagePrefix: "docker.io/myorg"},
			},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := IsProduction(tt.cfg)
			if got != tt.want {
				t.Errorf("IsProduction() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestIsDevelopment(t *testing.T) {
	tests := []struct {
		name string
		cfg  *Config
		want bool
	}{
		{
			name: "localhost domain",
			cfg: &Config{
				Domain: "localhost",
			},
			want: true,
		},
		{
			name: "local domain",
			cfg: &Config{
				Domain: "local.example.com",
			},
			want: true,
		},
		{
			name: "dev stack name",
			cfg: &Config{
				Domain:    "example.com",
				StackName: "dev",
			},
			want: true,
		},
		{
			name: "relative path",
			cfg: &Config{
				Domain:     "example.com",
				ConfigPath: "./volumes",
			},
			want: true,
		},
		{
			name: "production config",
			cfg: &Config{
				Domain:     "example.com",
				StackName:  "production",
				ConfigPath: "/opt/infra/volumes",
			},
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := IsDevelopment(tt.cfg)
			if got != tt.want {
				t.Errorf("IsDevelopment() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestSanitizeStackName(t *testing.T) {
	tests := []struct {
		name string
		input string
		want string
	}{
		{
			name:  "valid name",
			input: "my-stack",
			want:  "my-stack",
		},
		{
			name:  "with invalid characters",
			input: "my-stack@123!",
			want:  "my-stack123",
		},
		{
			name:  "empty after sanitization",
			input: "@#$%",
			want:  "infra",
		},
		{
			name:  "with underscores",
			input: "my_stack_123",
			want:  "my_stack_123",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := SanitizeStackName(tt.input)
			if got != tt.want {
				t.Errorf("SanitizeStackName() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestBuildEnvironmentMap(t *testing.T) {
	cfg := &Config{
		Domain:    "example.com",
		StackName: "test-stack",
		NodeName:  "node1",
	}

	defaults := map[string]string{
		"LOG_LEVEL": "info",
		"SERVICE_NAME": "my-service",
	}

	overrides := map[string]string{
		"LOG_LEVEL": "debug",
		"CUSTOM_VAR": "custom-value",
	}

	env := BuildEnvironmentMap(cfg, defaults, overrides)

	if env["DOMAIN"] != "example.com" {
		t.Errorf("Expected DOMAIN=example.com, got %s", env["DOMAIN"])
	}
	if env["STACK_NAME"] != "test-stack" {
		t.Errorf("Expected STACK_NAME=test-stack, got %s", env["STACK_NAME"])
	}
	if env["NODE_NAME"] != "node1" {
		t.Errorf("Expected NODE_NAME=node1, got %s", env["NODE_NAME"])
	}
	if env["LOG_LEVEL"] != "debug" { // Override should win
		t.Errorf("Expected LOG_LEVEL=debug, got %s", env["LOG_LEVEL"])
	}
	if env["SERVICE_NAME"] != "my-service" {
		t.Errorf("Expected SERVICE_NAME=my-service, got %s", env["SERVICE_NAME"])
	}
	if env["CUSTOM_VAR"] != "custom-value" {
		t.Errorf("Expected CUSTOM_VAR=custom-value, got %s", env["CUSTOM_VAR"])
	}
}
