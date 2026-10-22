package models

import (
	"testing"
)

func TestCleanTransactionID(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{
			input:    "DJD1R7KTJJ",
			expected: "DJD1R7KTJJ",
		},
		{
			input:    "v2-hfHCxHC6unkKSXCtrNI1",
			expected: "V2-HFHCXHC6UNKKSXCTRNI1",
		},
		{
			input:    "https://mbreciept.cbe.com.et/v2-hfHCxHC6unkKSXCtrNI1",
			expected: "V2-HFHCXHC6UNKKSXCTRNI1",
		},
		{
			input:    "https://mbreciept.cbe.com.et/v2-hfHCxHC6unkKSXCtrNI1?ref=cbe#sec",
			expected: "V2-HFHCXHC6UNKKSXCTRNI1",
		},
		{
			input:    "   https://mbreciept.cbe.com.et/v2-hfHCxHC6unkKSXCtrNI1/   ",
			expected: "V2-HFHCXHC6UNKKSXCTRNI1",
		},
	}

	for _, tc := range tests {
		result := CleanTransactionID(tc.input)
		if result != tc.expected {
			t.Errorf("CleanTransactionID(%q) = %q, expected %q", tc.input, result, tc.expected)
		}
	}
}
