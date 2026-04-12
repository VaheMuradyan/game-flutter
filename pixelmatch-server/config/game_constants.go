package config

// Game balance — keep in sync with Flutter constants.dart
const (
	XPPerWin  = 50
	XPPerLoss = -20
	MinXP     = 0

	StartingTowerHealth   = 1000
	BattleDurationSeconds = 180

	DailyFreeSwipes   = 20
	PremiumSwipeLimit = 999999
)

// LeagueForLevel maps a player level to their league name.
func LeagueForLevel(level int) string {
	switch {
	case level >= 100:
		return "Legend"
	case level >= 61:
		return "Diamond"
	case level >= 31:
		return "Gold"
	case level >= 11:
		return "Silver"
	default:
		return "Bronze"
	}
}
