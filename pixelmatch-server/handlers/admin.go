package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
)

type AdminHandler struct{}

type adminUser struct {
	UID            string `json:"uid"`
	Email          string `json:"email"`
	DisplayName    string `json:"displayName"`
	CharacterClass string `json:"characterClass"`
	Level          int    `json:"level"`
	League         string `json:"league"`
	Wins           int    `json:"wins"`
	Losses         int    `json:"losses"`
	IsPremium      bool   `json:"isPremium"`
	CreatedAt      string `json:"createdAt"`
}

// ListUsers returns the most recent 100 users.
func (h *AdminHandler) ListUsers(c *gin.Context) {
	rows, err := database.DB.Query(`
		SELECT uid, email, display_name, character_class, level, league,
		       wins, losses, is_premium, created_at
		FROM users
		ORDER BY created_at DESC
		LIMIT 100
	`)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	users := []adminUser{}
	for rows.Next() {
		var u adminUser
		if err := rows.Scan(&u.UID, &u.Email, &u.DisplayName, &u.CharacterClass,
			&u.Level, &u.League, &u.Wins, &u.Losses, &u.IsPremium, &u.CreatedAt); err != nil {
			continue
		}
		users = append(users, u)
	}

	c.JSON(http.StatusOK, gin.H{"users": users, "count": len(users)})
}

// GetStats returns aggregate game statistics.
func (h *AdminHandler) GetStats(c *gin.Context) {
	var totalUsers, totalBattles, totalMatches int

	_ = database.DB.QueryRow("SELECT COUNT(*) FROM users").Scan(&totalUsers)
	_ = database.DB.QueryRow("SELECT COUNT(*) FROM battles").Scan(&totalBattles)
	_ = database.DB.QueryRow("SELECT COUNT(*) FROM matches").Scan(&totalMatches)

	c.JSON(http.StatusOK, gin.H{
		"totalUsers":   totalUsers,
		"totalBattles": totalBattles,
		"totalMatches": totalMatches,
	})
}

// BanUser clears a user's profile and marks display name as [banned].
func (h *AdminHandler) BanUser(c *gin.Context) {
	uid := c.Param("uid")

	_, err := database.DB.Exec(`
		UPDATE users SET display_name = '[banned]', photo_url = ''
		WHERE uid = $1
	`, uid)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrUpdateFailed)
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "banned", "uid": uid})
}
