package config

// Game balance — canonical source is design_reference/balance_sheet.md.
// Flutter mirrors live in pixel_match/lib/config/constants.dart.
// Any drift between these three is a bug.
const (
	// XP — balance_sheet.md §1
	XPPerWin  = 75
	XPPerLoss = -10
	MinXP     = 0

	// Battle — balance_sheet.md §3
	StartingTowerHealth   = 1200
	BattleDurationSeconds = 150

	// Combat economy — balance_sheet.md §4
	TroopBaseDamage = 50
	SpellDamage     = 80

	// Swipes — balance_sheet.md §6
	DailyFreeSwipes   = 25
	PremiumSwipeLimit = 999999
)

// LeagueForLevel maps a player level to their league name.
// Thresholds from balance_sheet.md §2.
func LeagueForLevel(level int) string {
	switch {
	case level >= 41:
		return "Legend"
	case level >= 23:
		return "Diamond"
	case level >= 13:
		return "Gold"
	case level >= 6:
		return "Silver"
	default:
		return "Bronze"
	}
}
