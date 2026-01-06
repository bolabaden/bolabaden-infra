package tailscale

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNormalizeHeadscaleURL(t *testing.T) {
	tests := []struct {
		name        string
		input       string
		expected    string
		expectError bool
		errorMsg    string
	}{
		{
			name:     "URL with https scheme",
			input:    "https://headscale.example.com",
			expected: "https://headscale.example.com",
		},
		{
			name:     "URL with http scheme",
			input:    "http://headscale.example.com",
			expected: "http://headscale.example.com",
		},
		{
			name:     "Schemeless URL (should prepend https://)",
			input:    "headscale.example.com",
			expected: "https://headscale.example.com",
		},
		{
			name:     "URL with path (should remove path)",
			input:    "https://headscale.example.com/api/v1",
			expected: "https://headscale.example.com",
		},
		{
			name:     "URL with port",
			input:    "https://headscale.example.com:8080",
			expected: "https://headscale.example.com:8080",
		},
		{
			name:     "Schemeless URL with port",
			input:    "headscale.example.com:8080",
			expected: "https://headscale.example.com:8080",
		},
		{
			name:        "Invalid scheme",
			input:       "ftp://headscale.example.com",
			expectError: true,
			errorMsg:    "unsupported scheme",
		},
		{
			name:        "Empty string",
			input:       "",
			expectError: true,
		},
		{
			name:     "URL with query and fragment (should remove them)",
			input:    "https://headscale.example.com/path?query=1#fragment",
			expected: "https://headscale.example.com",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := normalizeHeadscaleURL(tt.input)

			if tt.expectError {
				require.Error(t, err, "Expected error for input: %s", tt.input)
				if tt.errorMsg != "" {
					assert.Contains(t, err.Error(), tt.errorMsg, "Error message should contain: %s", tt.errorMsg)
				}
			} else {
				require.NoError(t, err, "Unexpected error for input: %s", tt.input)
				assert.Equal(t, tt.expected, result, "Normalized URL should match expected")
			}
		})
	}
}

func TestNormalizeHeadscaleURL_SchemelessBug(t *testing.T) {
	// This test specifically verifies the bug fix:
	// Schemeless URLs like "headscale.example.com" should work correctly
	// The bug was that url.Parse puts schemeless URLs in Path, not Host
	// The fix is to prepend "https://" BEFORE parsing

	testCases := []string{
		"headscale.example.com",
		"headscale.local",
		"192.168.1.1",
		"headscale.example.com:8080",
	}

	for _, input := range testCases {
		t.Run(input, func(t *testing.T) {
			result, err := normalizeHeadscaleURL(input)
			require.NoError(t, err, "Schemeless URL should be normalized: %s", input)
			assert.Contains(t, result, "://", "Result should contain scheme: %s", result)
			assert.NotEmpty(t, result, "Result should not be empty")
		})
	}
}
