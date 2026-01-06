package config

import (
	"testing"
)

func TestSecretManager(t *testing.T) {
	password := "test-password-123"
	salt := []byte("test-salt")

	sm := NewSecretManager(password, salt)

	plaintext := "sensitive-secret-value"
	encrypted, err := sm.Encrypt(plaintext)
	if err != nil {
		t.Fatalf("Failed to encrypt: %v", err)
	}

	if encrypted == plaintext {
		t.Error("Encrypted value should be different from plaintext")
	}

	decrypted, err := sm.Decrypt(encrypted)
	if err != nil {
		t.Fatalf("Failed to decrypt: %v", err)
	}

	if decrypted != plaintext {
		t.Errorf("Decrypted value doesn't match. Got: %s, Want: %s", decrypted, plaintext)
	}
}

func TestEncryptConfigValue(t *testing.T) {
	sm := NewSecretManager("test-password", []byte("test-salt"))

	value := "my-secret-api-key"
	encrypted, err := sm.EncryptConfigValue(value)
	if err != nil {
		t.Fatalf("Failed to encrypt config value: %v", err)
	}

	if !IsEncryptedValue(encrypted) {
		t.Error("Encrypted value should have 'encrypted:' prefix")
	}

	decrypted, err := sm.DecryptConfigValue(encrypted)
	if err != nil {
		t.Fatalf("Failed to decrypt config value: %v", err)
	}

	if decrypted != value {
		t.Errorf("Decrypted value doesn't match. Got: %s, Want: %s", decrypted, value)
	}
}

func TestIsEncryptedValue(t *testing.T) {
	tests := []struct {
		name  string
		value string
		want  bool
	}{
		{
			name:  "encrypted value",
			value: "encrypted:base64encodeddata",
			want:  true,
		},
		{
			name:  "plain value",
			value: "plain-secret",
			want:  false,
		},
		{
			name:  "empty string",
			value: "",
			want:  false,
		},
		{
			name:  "short string",
			value: "encrypt",
			want:  false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := IsEncryptedValue(tt.value)
			if got != tt.want {
				t.Errorf("IsEncryptedValue() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestDecryptConfigValue_PlainText(t *testing.T) {
	sm := NewSecretManager("test-password", []byte("test-salt"))

	// Plain text should be returned as-is
	plaintext := "not-encrypted-value"
	decrypted, err := sm.DecryptConfigValue(plaintext)
	if err != nil {
		t.Fatalf("Failed to decrypt plain text: %v", err)
	}

	if decrypted != plaintext {
		t.Errorf("Plain text should be returned as-is. Got: %s, Want: %s", decrypted, plaintext)
	}
}
