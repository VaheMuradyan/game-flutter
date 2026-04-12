package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
)

type LeaderboardHandler struct{}

type LeaderboardEntry struct {
	UID            string `json:"uid"`
	DisplayName    string `json:"displayName"`
	CharacterClass string `json:"characterClass"`
	Level          int    `json:"level"`
	XP             int    `json:"xp"`
	League         string `json:"league"`
	Wins           int    `json:"wins"`
}

type BattleHistoryEntry struct {
	ID            string    `json:"id"`
	Player1UID    string    `json:"player1Uid"`
	Player2UID    string    `json:"player2Uid"`
	WinnerUID     string    `json:"winnerUid"`
	Player1Health int       `json:"player1Health"`
	Player2Health int       `json:"player2Health"`
	Duration      int       `json:"duration"`
	XPAwarded     int       `json:"xpAwarded"`
	CreatedAt     time.Time `json:"createdAt"`
}

func (h *LeaderboardHandler) GetGlobalLeaderboard(c *gin.Context) {
	rows, err := database.DB.Query(`
		SELECT uid, display_name, character_class, level, xp, league, wins
		FROM users
		WHERE display_name != ''
		ORDER BY xp DESC
		LIMIT 50
	`)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	entries := []LeaderboardEntry{}
	for rows.Next() {
		var e LeaderboardEntry
		if err := rows.Scan(&e.UID, &e.DisplayName, &e.CharacterClass,
			&e.Level, &e.XP, &e.League, &e.Wins); err != nil {
			continue
		}
		entries = append(entries, e)
	}
	c.JSON(http.StatusOK, gin.H{"entries": entries})
}

func (h *LeaderboardHandler) GetLeagueLeaderboard(c *gin.Context) {
	league := c.Param("league")

	rows, err := database.DB.Query(`
		SELECT uid, display_name, character_class, level, xp, league, wins
		FROM users
		WHERE league = $1 AND display_name != ''
		ORDER BY xp DESC
		LIMIT 50
	`, league)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	entries := []LeaderboardEntry{}
	for rows.Next() {
		var e LeaderboardEntry
		if err := rows.Scan(&e.UID, &e.DisplayName, &e.CharacterClass,
			&e.Level, &e.XP, &e.League, &e.Wins); err != nil {
			continue
		}
		entries = append(entries, e)
	}
	c.JSON(http.StatusOK, gin.H{"entries": entries})
}

func (h *LeaderboardHandler) GetBattleHistory(c *gin.Context) {
	uid := c.GetString("uid")

	rows, err := database.DB.Query(`
		SELECT id, player1_uid, player2_uid, winner_uid,
		       player1_health, player2_health, duration, xp_awarded, created_at
		FROM battles
		WHERE player1_uid = $1 OR player2_uid = $1
		ORDER BY created_at DESC
		LIMIT 30
	`, uid)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	battles := []BattleHistoryEntry{}
	for rows.Next() {
		var b BattleHistoryEntry
		if err := rows.Scan(&b.ID, &b.Player1UID, &b.Player2UID, &b.WinnerUID,
			&b.Player1Health, &b.Player2Health, &b.Duration, &b.XPAwarded, &b.CreatedAt); err != nil {
			continue
		}
		battles = append(battles, b)
	}
	c.JSON(http.StatusOK, gin.H{"battles": battles})
}
