package failover

import (
	"encoding/json"
	"fmt"
	"os"
	"time"
)

// MigrationConfig represents migration rules loaded from configuration
type MigrationConfig struct {
	Rules []MigrationRule `json:"rules"`
}

// LoadMigrationRules loads migration rules from a configuration file or environment
func LoadMigrationRules(configPath string) ([]MigrationRule, error) {
	// Try to load from file first
	if configPath != "" {
		if _, err := os.Stat(configPath); err == nil {
			data, err := os.ReadFile(configPath)
			if err != nil {
				return nil, fmt.Errorf("failed to read migration config: %w", err)
			}

			var config MigrationConfig
			if err := json.Unmarshal(data, &config); err != nil {
				return nil, fmt.Errorf("failed to parse migration config: %w", err)
			}

			// Validate and set defaults for rules
			for i := range config.Rules {
				rule := &config.Rules[i]
				if rule.MaxRetries == 0 {
					rule.MaxRetries = 3
				}
				if rule.RetryDelay == 0 {
					rule.RetryDelay = 30 * time.Second
				}
			}

			return config.Rules, nil
		}
	}

	// Try environment variable as fallback
	envConfig := os.Getenv("MIGRATION_RULES")
	if envConfig != "" {
		var config MigrationConfig
		if err := json.Unmarshal([]byte(envConfig), &config); err != nil {
			return nil, fmt.Errorf("failed to parse migration rules from environment: %w", err)
		}

		// Validate and set defaults
		for i := range config.Rules {
			rule := &config.Rules[i]
			if rule.MaxRetries == 0 {
				rule.MaxRetries = 3
			}
			if rule.RetryDelay == 0 {
				rule.RetryDelay = 30 * time.Second
			}
		}

		return config.Rules, nil
	}

	// Return empty rules if no configuration found
	return []MigrationRule{}, nil
}

