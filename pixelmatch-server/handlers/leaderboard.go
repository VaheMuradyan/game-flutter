package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
)

type LeaderboardHandler struct{}

func (h *LeaderboardHandler) GetGlobalLeaderboard(c *gin.Context) {
	rows, err := database.DB.Query(`
		SELECT uid, display_name, character_class, level, xp, league, wins
		FROM users
		WHERE display_name != ''
		ORDER BY xp DESC
		LIMIT 50
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	entries := []map[string]interface{}{}
	for rows.Next() {
		var uid, name, class_, league string
		var level, xp, wins int
		rows.Scan(&uid, &name, &class_, &level, &xp, &league, &wins)
		entries = append(entries, map[string]interface{}{
			"uid": uid, "displayName": name, "characterClass": class_,
			"level": level, "xp": xp, "league": league, "wins": wins,
		})
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	entries := []map[string]interface{}{}
	for rows.Next() {
		var uid, name, class_, lg string
		var level, xp, wins int
		rows.Scan(&uid, &name, &class_, &level, &xp, &lg, &wins)
		entries = append(entries, map[string]interface{}{
			"uid": uid, "displayName": name, "characterClass": class_,
			"level": level, "xp": xp, "league": lg, "wins": wins,
		})
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	battles := []map[string]interface{}{}
	for rows.Next() {
		var id, p1, p2, winner string
		var p1h, p2h, dur, xp int
		var createdAt interface{}
		rows.Scan(&id, &p1, &p2, &winner, &p1h, &p2h, &dur, &xp, &createdAt)
		battles = append(battles, map[string]interface{}{
			"id": id, "player1Uid": p1, "player2Uid": p2, "winnerUid": winner,
			"player1Health": p1h, "player2Health": p2h, "duration": dur,
			"xpAwarded": xp, "createdAt": createdAt,
		})
	}
	c.JSON(http.StatusOK, gin.H{"battles": battles})
}
