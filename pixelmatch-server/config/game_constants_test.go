package config

import "testing"

func TestLeagueForLevel(t *testing.T) {
	tests := []struct {
		level    int
		expected string
	}{
		{1, "Bronze"},
		{5, "Bronze"},
		{6, "Silver"},
		{12, "Silver"},
		{13, "Gold"},
		{22, "Gold"},
		{23, "Diamond"},
		{40, "Diamond"},
		{41, "Legend"},
		{500, "Legend"},
	}

	for _, tt := range tests {
		got := LeagueForLevel(tt.level)
		if got != tt.expected {
			t.Errorf("LeagueForLevel(%d) = %q, want %q", tt.level, got, tt.expected)
		}
	}
}
