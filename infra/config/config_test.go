package config

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadConfig(t *testing.T) {
	// Test loading with defaults
	cfg, err := LoadConfig("")
	if err != nil {
		t.Fatalf("Failed to load default config: %v", err)
	}

	if cfg.Domain != "example.com" {
		t.Errorf("Expected default domain 'example.com', got '%s'", cfg.Domain)
	}
	if cfg.StackName != "infra" {
		t.Errorf("Expected default stack_name 'infra', got '%s'", cfg.StackName)
	}
}

func TestLoadConfigFromYAML(t *testing.T) {
	// Create a temporary YAML file
	tmpDir := t.TempDir()
	yamlFile := filepath.Join(tmpDir, "test-config.yaml")
	yamlContent := `
domain: test.example.com
stack_name: test-stack
node_name: test-node

traefik:
  web_port: 8080
  websecure_port: 8443
  error_pages_middleware: "custom-error-pages@file"

cluster:
  bind_port: 9000
  raft_port: 9001
  api_port: 9002
  priority: 50

registry:
  image_prefix: "docker.io/testorg"
`
	if err := os.WriteFile(yamlFile, []byte(yamlContent), 0644); err != nil {
		t.Fatalf("Failed to write test YAML file: %v", err)
	}

	cfg, err := LoadConfig(yamlFile)
	if err != nil {
		t.Fatalf("Failed to load config from YAML: %v", err)
	}

	if cfg.Domain != "test.example.com" {
		t.Errorf("Expected domain 'test.example.com', got '%s'", cfg.Domain)
	}
	if cfg.StackName != "test-stack" {
		t.Errorf("Expected stack_name 'test-stack', got '%s'", cfg.StackName)
	}
	if cfg.NodeName != "test-node" {
		t.Errorf("Expected node_name 'test-node', got '%s'", cfg.NodeName)
	}
	if cfg.Traefik.WebPort != 8080 {
		t.Errorf("Expected traefik.web_port 8080, got %d", cfg.Traefik.WebPort)
	}
	if cfg.Traefik.WebSecurePort != 8443 {
		t.Errorf("Expected traefik.websecure_port 8443, got %d", cfg.Traefik.WebSecurePort)
	}
	if cfg.Traefik.ErrorPagesMiddleware != "custom-error-pages@file" {
		t.Errorf("Expected custom error pages middleware, got '%s'", cfg.Traefik.ErrorPagesMiddleware)
	}
	if cfg.Cluster.BindPort != 9000 {
		t.Errorf("Expected cluster.bind_port 9000, got %d", cfg.Cluster.BindPort)
	}
	if cfg.Registry.ImagePrefix != "docker.io/testorg" {
		t.Errorf("Expected image prefix 'docker.io/testorg', got '%s'", cfg.Registry.ImagePrefix)
	}
}

func TestValidateConfig(t *testing.T) {
	tests := []struct {
		name    string
		config  *Config
		wantErr bool
	}{
		{
			name: "valid config",
			config: &Config{
				Domain:     "example.com",
				StackName:  "test-stack",
				ConfigPath: "./volumes",
				SecretsPath: "./secrets",
				DataDir:    "/opt/data",
				Traefik: TraefikConfig{
					WebPort:        80,
					WebSecurePort:  443,
					HTTPProviderPort: 8081,
				},
				Cluster: ClusterConfig{
					BindPort: 7946,
					RaftPort: 8300,
					APIPort:  8080,
				},
			},
			wantErr: false,
		},
		{
			name: "missing domain",
			config: &Config{
				StackName:  "test-stack",
				ConfigPath: "./volumes",
				SecretsPath: "./secrets",
				DataDir:    "/opt/data",
			},
			wantErr: true,
		},
		{
			name: "missing stack_name",
			config: &Config{
				Domain:     "example.com",
				ConfigPath: "./volumes",
				SecretsPath: "./secrets",
				DataDir:    "/opt/data",
			},
			wantErr: true,
		},
		{
			name: "invalid port",
			config: &Config{
				Domain:     "example.com",
				StackName:  "test-stack",
				ConfigPath: "./volumes",
				SecretsPath: "./secrets",
				DataDir:    "/opt/data",
				Traefik: TraefikConfig{
					WebPort: 70000, // Invalid port
				},
			},
			wantErr: true,
		},
		{
			name: "duplicate ports",
			config: &Config{
				Domain:     "example.com",
				StackName:  "test-stack",
				ConfigPath: "./volumes",
				SecretsPath: "./secrets",
				DataDir:    "/opt/data",
				Traefik: TraefikConfig{
					WebPort:        8080,
					HTTPProviderPort: 8080, // Duplicate
				},
				Cluster: ClusterConfig{
					APIPort: 8080, // Also duplicate
				},
			},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := tt.config.Validate()
			if (err != nil) != tt.wantErr {
				t.Errorf("Validate() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}

func TestGetImageName(t *testing.T) {
	tests := []struct {
		name       string
		imagePrefix string
		image      string
		want       string
	}{
		{
			name:       "no prefix",
			imagePrefix: "",
			image:      "my-app:latest",
			want:       "my-app:latest",
		},
		{
			name:       "with prefix",
			imagePrefix: "docker.io/myorg",
			image:      "my-app:latest",
			want:       "docker.io/myorg/my-app:latest",
		},
		{
			name:       "image already has registry",
			imagePrefix: "docker.io/myorg",
			image:      "docker.io/otherorg/app:latest",
			want:       "docker.io/otherorg/app:latest",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cfg := &Config{
				Registry: RegistryConfig{
					ImagePrefix: tt.imagePrefix,
				},
			}
			got := cfg.GetImageName(tt.image)
			if got != tt.want {
				t.Errorf("GetImageName() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestGetTraefikMiddlewares(t *testing.T) {
	tests := []struct {
		name       string
		config     *Config
		want       string
	}{
		{
			name: "all enabled",
			config: &Config{
				Middlewares: MiddlewareConfig{
					ErrorPagesEnabled: true,
					CrowdsecEnabled:   true,
					StripWWWEnabled:   true,
				},
				Traefik: TraefikConfig{
					ErrorPagesMiddleware: "error-pages@file",
					CrowdsecMiddleware:   "crowdsec@file",
					StripWWWMiddleware:  "strip-www@file",
				},
			},
			want: "error-pages@file,crowdsec@file,strip-www@file",
		},
		{
			name: "some disabled",
			config: &Config{
				Middlewares: MiddlewareConfig{
					ErrorPagesEnabled: true,
					CrowdsecEnabled:   false,
					StripWWWEnabled:   true,
				},
				Traefik: TraefikConfig{
					ErrorPagesMiddleware: "error-pages@file",
					CrowdsecMiddleware:   "crowdsec@file",
					StripWWWMiddleware:  "strip-www@file",
				},
			},
			want: "error-pages@file,strip-www@file",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tt.config.GetTraefikMiddlewares()
			if got != tt.want {
				t.Errorf("GetTraefikMiddlewares() = %v, want %v", got, tt.want)
			}
		})
	}
}
