package config

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
	"os"

	"path/filepath"
	"golang.org/x/crypto/pbkdf2"
)

// SecretManager handles encryption and decryption of sensitive configuration values
type SecretManager struct {
	key []byte
}

// NewSecretManager creates a new secret manager with a key derived from a password
func NewSecretManager(password string, salt []byte) *SecretManager {
	// Derive key using PBKDF2
	key := pbkdf2.Key([]byte(password), salt, 4096, 32, sha256.New)
	return &SecretManager{key: key}
}

// NewSecretManagerFromEnv creates a secret manager from environment variable
// Uses CONFIG_ENCRYPTION_KEY environment variable
func NewSecretManagerFromEnv() (*SecretManager, error) {
	key := os.Getenv("CONFIG_ENCRYPTION_KEY")
	if key == "" {
		return nil, fmt.Errorf("CONFIG_ENCRYPTION_KEY environment variable not set")
	}
	
	// Use a fixed salt for environment-based encryption
	// In production, consider using a configurable salt
	salt := []byte("config-encryption-salt")
	secretManager := NewSecretManager(key, salt)
	return secretManager, nil
}

// Encrypt encrypts a plaintext string
func (sm *SecretManager) Encrypt(plaintext string) (string, error) {
	block, err := aes.NewCipher(sm.key)
	if err != nil {
		return "", fmt.Errorf("failed to create cipher: %w", err)
	}

	// Create GCM
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("failed to create GCM: %w", err)
	}

	// Create nonce
	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", fmt.Errorf("failed to generate nonce: %w", err)
	}

	// Encrypt
	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

// Decrypt decrypts an encrypted string
func (sm *SecretManager) Decrypt(encrypted string) (string, error) {
	// Decode base64
	ciphertext, err := base64.StdEncoding.DecodeString(encrypted)
	if err != nil {
		return "", fmt.Errorf("failed to decode base64: %w", err)
	}

	block, err := aes.NewCipher(sm.key)
	if err != nil {
		return "", fmt.Errorf("failed to create cipher: %w", err)
	}

	// Create GCM
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("failed to create GCM: %w", err)
	}

	// Extract nonce
	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return "", fmt.Errorf("ciphertext too short")
	}

	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]

	// Decrypt
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", fmt.Errorf("failed to decrypt: %w", err)
	}

	return string(plaintext), nil
}

// EncryptConfigValue encrypts a configuration value and returns it in a format suitable for YAML
func (sm *SecretManager) EncryptConfigValue(value string) (string, error) {
	encrypted, err := sm.Encrypt(value)
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("encrypted:%s", encrypted), nil
}

// DecryptConfigValue decrypts a configuration value from the encrypted format
func (sm *SecretManager) DecryptConfigValue(encryptedValue string) (string, error) {
	if !IsEncryptedValue(encryptedValue) {
		return encryptedValue, nil // Not encrypted, return as-is
	}
	
	// Remove "encrypted:" prefix
	encrypted := encryptedValue[len("encrypted:"):]
	return sm.Decrypt(encrypted)
}

// IsEncryptedValue checks if a value is in encrypted format
func IsEncryptedValue(value string) bool {
	return len(value) > 10 && value[:10] == "encrypted:"
}

// DecryptConfigSecrets decrypts all encrypted values in a configuration
func DecryptConfigSecrets(cfg *Config, secretManager *SecretManager) error {
	if secretManager == nil {
		// Try to create from environment
		sm, err := NewSecretManagerFromEnv()
		if err != nil {
			return fmt.Errorf("no secret manager available and CONFIG_ENCRYPTION_KEY not set")
		}
		secretManager = sm
	}

	// Decrypt DNS secrets
	if IsEncryptedValue(cfg.DNS.APIKey) {
		decrypted, err := secretManager.DecryptConfigValue(cfg.DNS.APIKey)
		if err != nil {
			return fmt.Errorf("failed to decrypt DNS API key: %w", err)
		}
		cfg.DNS.APIKey = decrypted
	}

	if IsEncryptedValue(cfg.DNS.ZoneID) {
		decrypted, err := secretManager.DecryptConfigValue(cfg.DNS.ZoneID)
		if err != nil {
			return fmt.Errorf("failed to decrypt DNS Zone ID: %w", err)
		}
		cfg.DNS.ZoneID = decrypted
	}

	// Future: Add more secret fields as needed
	return nil
}

// ReadSecretFromFile reads a secret from a file
func ReadSecretFromFile(filePath string) (string, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to read secret file: %w", err)
	}
	return string(data), nil
}

// WriteSecretToFile writes a secret to a file with restricted permissions
func WriteSecretToFile(filePath string, secret string) error {
	// Ensure directory exists
	dir := filepath.Dir(filePath)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("failed to create directory: %w", err)
	}

	// Write file with restricted permissions (0600 = owner read/write only)
	if err := os.WriteFile(filePath, []byte(secret), 0600); err != nil {
		return fmt.Errorf("failed to write secret file: %w", err)
	}

	return nil
}
