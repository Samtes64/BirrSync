package handlers

import (
	"testing"
)

func TestCleanPhoneNumber(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{input: "0911223344", expected: "0911223344"},
		{input: "+251911223344", expected: "251911223344"},
		{input: "251 911-22-33-44", expected: "251911223344"},
		{input: "(+251) 911 22 3344", expected: "251911223344"},
		{input: "Abebe (2519****3344)", expected: "25193344"},
	}

	for _, tc := range tests {
		result := cleanPhoneNumber(tc.input)
		if result != tc.expected {
			t.Errorf("cleanPhoneNumber(%q) = %q; expected %q", tc.input, result, tc.expected)
		}
	}
}

func TestNullIfEmpty(t *testing.T) {
	if nullIfEmpty("") != nil {
		t.Errorf("expected empty string to yield nil")
	}
	if nullIfEmpty("   ") != nil {
		t.Errorf("expected whitespace to yield nil")
	}
	if nullIfEmpty("app_123") != "app_123" {
		t.Errorf("expected app_123, got %v", nullIfEmpty("app_123"))
	}
}
