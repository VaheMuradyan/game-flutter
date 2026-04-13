package config

import "testing"

func TestLeagueForLevel(t *testing.T) {
	tests := []struct {
		level    int
		expected string
	}{
		{1, "Bronze"},
		{10, "Bronze"},
		{11, "Silver"},
		{30, "Silver"},
		{31, "Gold"},
		{60, "Gold"},
		{61, "Diamond"},
		{99, "Diamond"},
		{100, "Legend"},
		{500, "Legend"},
	}

	for _, tt := range tests {
		got := LeagueForLevel(tt.level)
		if got != tt.expected {
			t.Errorf("LeagueForLevel(%d) = %q, want %q", tt.level, got, tt.expected)
		}
	}
}
