package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"pixelmatch-server/database"
	"pixelmatch-server/models"
)

type MatchmakingHandler struct{}

func (h *MatchmakingHandler) RecordLike(c *gin.Context) {
	uid := c.GetString("uid")

	var req struct {
		LikedUID string `json:"likedUid" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if uid == req.LikedUID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "cannot like yourself"})
		return
	}

	// Check daily limit (20 free swipes)
	var todayCount int
	database.DB.QueryRow(`
		SELECT COUNT(*) FROM likes
		WHERE liker_uid = $1 AND created_at >= CURRENT_DATE
	`, uid).Scan(&todayCount)

	// Check if premium
	var isPremium bool
	database.DB.QueryRow("SELECT is_premium FROM users WHERE uid = $1", uid).Scan(&isPremium)

	if !isPremium && todayCount >= 20 {
		c.JSON(http.StatusForbidden, gin.H{"error": "daily swipe limit reached"})
		return
	}

	// Insert the like
	_, err := database.DB.Exec(`
		INSERT INTO likes (liker_uid, liked_uid) VALUES ($1, $2)
		ON CONFLICT (liker_uid, liked_uid) DO NOTHING
	`, uid, req.LikedUID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to record like"})
		return
	}

	// Check for mutual like
	var reverseExists bool
	database.DB.QueryRow(`
		SELECT EXISTS(SELECT 1 FROM likes WHERE liker_uid = $1 AND liked_uid = $2)
	`, req.LikedUID, uid).Scan(&reverseExists)

	if reverseExists {
		// Check if already matched
		var alreadyMatched bool
		database.DB.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM matches
				WHERE (user1_uid = $1 AND user2_uid = $2)
				   OR (user1_uid = $2 AND user2_uid = $1)
			)
		`, uid, req.LikedUID).Scan(&alreadyMatched)

		if !alreadyMatched {
			chatID := uuid.New().String()
			matchID := uuid.New().String()

			database.DB.Exec(`
				INSERT INTO matches (id, user1_uid, user2_uid, chat_id)
				VALUES ($1, $2, $3, $4)
			`, matchID, uid, req.LikedUID, chatID)

			database.DB.Exec(`
				INSERT INTO chats (id, match_id) VALUES ($1, $2)
			`, chatID, matchID)

			c.JSON(http.StatusOK, gin.H{
				"match":  true,
				"chatId": chatID,
			})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"match": false})
}

func (h *MatchmakingHandler) GetSwipesToday(c *gin.Context) {
	uid := c.GetString("uid")
	var count int
	database.DB.QueryRow(`
		SELECT COUNT(*) FROM likes WHERE liker_uid = $1 AND created_at >= CURRENT_DATE
	`, uid).Scan(&count)

	var isPremium bool
	database.DB.QueryRow("SELECT is_premium FROM users WHERE uid = $1", uid).Scan(&isPremium)

	limit := 20
	if isPremium {
		limit = 9999
	}

	c.JSON(http.StatusOK, gin.H{
		"count":     count,
		"limit":     limit,
		"remaining": max(0, limit-count),
	})
}

func (h *MatchmakingHandler) GetMatches(c *gin.Context) {
	uid := c.GetString("uid")

	rows, err := database.DB.Query(`
		SELECT m.id, m.user1_uid, m.user2_uid, m.chat_id, m.matched_at,
		       u.uid, u.display_name, u.character_class, u.photo_url,
		       u.level, u.league, u.wins, u.losses
		FROM matches m
		JOIN users u ON u.uid = CASE WHEN m.user1_uid = $1 THEN m.user2_uid ELSE m.user1_uid END
		WHERE m.user1_uid = $1 OR m.user2_uid = $1
		ORDER BY m.matched_at DESC
	`, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	type MatchWithUser struct {
		models.Match
		OtherUser models.User `json:"otherUser"`
	}

	matches := []MatchWithUser{}
	for rows.Next() {
		var m models.Match
		var u models.User
		rows.Scan(&m.ID, &m.User1UID, &m.User2UID, &m.ChatID, &m.MatchedAt,
			&u.UID, &u.DisplayName, &u.CharacterClass, &u.PhotoUrl,
			&u.Level, &u.League, &u.Wins, &u.Losses)
		matches = append(matches, MatchWithUser{Match: m, OtherUser: u})
	}

	c.JSON(http.StatusOK, gin.H{"matches": matches})
}

func (h *MatchmakingHandler) GetLikedUIDs(c *gin.Context) {
	uid := c.GetString("uid")

	rows, err := database.DB.Query("SELECT liked_uid FROM likes WHERE liker_uid = $1", uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	uids := []string{}
	for rows.Next() {
		var likedUID string
		rows.Scan(&likedUID)
		uids = append(uids, likedUID)
	}
	c.JSON(http.StatusOK, gin.H{"likedUids": uids})
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
