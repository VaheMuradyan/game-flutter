package helpers

import (
	"pixelmatch-server/models"
)

// ScanUser scans a single user row into a User struct.
// Works with both *sql.Row and *sql.Rows.
func ScanUser(scanner interface{ Scan(dest ...interface{}) error }) (models.User, error) {
	var u models.User
	err := scanner.Scan(
		&u.UID, &u.Email, &u.DisplayName, &u.CharacterClass,
		&u.PhotoUrl, &u.Level, &u.XP, &u.League,
		&u.Wins, &u.Losses, &u.IsPremium, &u.CreatedAt,
	)
	return u, err
}

// ScanUserWithPassword scans a user row that includes password_hash (for login).
func ScanUserWithPassword(scanner interface{ Scan(dest ...interface{}) error }) (models.User, string, error) {
	var u models.User
	var passwordHash string
	err := scanner.Scan(
		&u.UID, &u.Email, &passwordHash, &u.DisplayName,
		&u.CharacterClass, &u.PhotoUrl, &u.Level, &u.XP,
		&u.League, &u.Wins, &u.Losses, &u.IsPremium, &u.CreatedAt,
	)
	return u, passwordHash, err
}
