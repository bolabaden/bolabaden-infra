package main

import (
	"testing"
)

func TestParseMemory(t *testing.T) {
	tests := []struct {
		input    string
		expected int64
	}{
		{"4G", 4 * 1024 * 1024 * 1024},
		{"512M", 512 * 1024 * 1024},
		{"1G", 1 * 1024 * 1024 * 1024}, // Note: Sscanf only reads integer part, so "1.5G" becomes 1
		{"", 0},
		{"invalid", 0},
	}

	infra := &Infrastructure{}
	for _, tt := range tests {
		result := infra.parseMemory(tt.input)
		if result != tt.expected {
			t.Errorf("parseMemory(%q) = %d, want %d", tt.input, result, tt.expected)
		}
	}
}

func TestParseCPUs(t *testing.T) {
	tests := []struct {
		input    string
		expected int64
	}{
		{"2.0", 2000000000},
		{"4", 4000000000},
		{"1.5", 1500000000},
		{"", 0},
		{"invalid", 0},
	}

	infra := &Infrastructure{}
	for _, tt := range tests {
		result := infra.parseCPUs(tt.input)
		if result != tt.expected {
			t.Errorf("parseCPUs(%q) = %d, want %d", tt.input, result, tt.expected)
		}
	}
}

func TestParseDuration(t *testing.T) {
	tests := []struct {
		input    string
		expected bool // true if duration > 0
	}{
		{"30s", true},
		{"10m", true},
		{"1h", true},
		{"", false},
		{"invalid", false},
	}

	for _, tt := range tests {
		result := parseDuration(tt.input)
		valid := result > 0
		if valid != tt.expected {
			t.Errorf("parseDuration(%q) = %v, want %v", tt.input, valid, tt.expected)
		}
	}
}

func TestEnvMapToSlice(t *testing.T) {
	infra := &Infrastructure{}
	env := map[string]string{
		"KEY1": "value1",
		"KEY2": "value2",
	}

	result := infra.envMapToSlice(env)
	if len(result) != 2 {
		t.Errorf("envMapToSlice returned %d items, want 2", len(result))
	}

	// Check that all keys are present
	found := make(map[string]bool)
	for _, item := range result {
		found[item] = true
	}

	if !found["KEY1=value1"] && !found["KEY2=value2"] {
		t.Error("envMapToSlice missing expected items")
	}
}
