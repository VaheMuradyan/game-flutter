package handlers

import (
	"log/slog"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
	"pixelmatch-server/models"
)

type MatchmakingHandler struct{}

func (h *MatchmakingHandler) RecordLike(c *gin.Context) {
	uid := c.GetString("uid")

	var req struct {
		LikedUID string `json:"likedUid" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	if uid == req.LikedUID {
		helpers.RespondError(c, http.StatusBadRequest, "cannot like yourself")
		return
	}

	// Check daily limit
	var todayCount int
	if err := database.DB.QueryRow(`
		SELECT COUNT(*) FROM likes
		WHERE liker_uid = $1 AND created_at >= CURRENT_DATE
	`, uid).Scan(&todayCount); err != nil {
		slog.Error("failed to count today's likes", "err", err)
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInternal)
		return
	}

	var isPremium bool
	if err := database.DB.QueryRow("SELECT is_premium FROM users WHERE uid = $1", uid).Scan(&isPremium); err != nil {
		slog.Error("failed to check premium status", "err", err)
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInternal)
		return
	}

	if !isPremium && todayCount >= config.DailyFreeSwipes {
		helpers.RespondError(c, http.StatusForbidden, helpers.ErrLimitReached)
		return
	}

	// Insert the like
	_, err := database.DB.Exec(`
		INSERT INTO likes (liker_uid, liked_uid) VALUES ($1, $2)
		ON CONFLICT (liker_uid, liked_uid) DO NOTHING
	`, uid, req.LikedUID)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInsertFailed)
		return
	}

	// Check for mutual like
	var reverseExists bool
	if err := database.DB.QueryRow(`
		SELECT EXISTS(SELECT 1 FROM likes WHERE liker_uid = $1 AND liked_uid = $2)
	`, req.LikedUID, uid).Scan(&reverseExists); err != nil {
		slog.Error("failed to check reverse like", "err", err)
	}

	if reverseExists {
		var alreadyMatched bool
		if err := database.DB.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM matches
				WHERE (user1_uid = $1 AND user2_uid = $2)
				   OR (user1_uid = $2 AND user2_uid = $1)
			)
		`, uid, req.LikedUID).Scan(&alreadyMatched); err != nil {
			slog.Error("failed to check existing match", "err", err)
		}

		if !alreadyMatched {
			chatID := uuid.New().String()
			matchID := uuid.New().String()

			if _, err := database.DB.Exec(`
				INSERT INTO matches (id, user1_uid, user2_uid, chat_id)
				VALUES ($1, $2, $3, $4)
			`, matchID, uid, req.LikedUID, chatID); err != nil {
				slog.Error("failed to create match", "err", err)
				helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInternal)
				return
			}

			if _, err := database.DB.Exec(`
				INSERT INTO chats (id, match_id) VALUES ($1, $2)
			`, chatID, matchID); err != nil {
				slog.Error("failed to create chat", "err", err)
			}

			c.JSON(http.StatusOK, gin.H{"match": true, "chatId": chatID})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"match": false})
}

func (h *MatchmakingHandler) GetSwipesToday(c *gin.Context) {
	uid := c.GetString("uid")

	var count int
	if err := database.DB.QueryRow(`
		SELECT COUNT(*) FROM likes WHERE liker_uid = $1 AND created_at >= CURRENT_DATE
	`, uid).Scan(&count); err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}

	var isPremium bool
	if err := database.DB.QueryRow("SELECT is_premium FROM users WHERE uid = $1", uid).Scan(&isPremium); err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}

	limit := config.DailyFreeSwipes
	if isPremium {
		limit = config.PremiumSwipeLimit
	}

	remaining := limit - count
	if remaining < 0 {
		remaining = 0
	}

	c.JSON(http.StatusOK, gin.H{
		"count":     count,
		"limit":     limit,
		"remaining": remaining,
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
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
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
		if err := rows.Scan(&m.ID, &m.User1UID, &m.User2UID, &m.ChatID, &m.MatchedAt,
			&u.UID, &u.DisplayName, &u.CharacterClass, &u.PhotoUrl,
			&u.Level, &u.League, &u.Wins, &u.Losses); err != nil {
			continue
		}
		matches = append(matches, MatchWithUser{Match: m, OtherUser: u})
	}

	c.JSON(http.StatusOK, gin.H{"matches": matches})
}

func (h *MatchmakingHandler) GetLikedUIDs(c *gin.Context) {
	uid := c.GetString("uid")

	rows, err := database.DB.Query("SELECT liked_uid FROM likes WHERE liker_uid = $1", uid)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	uids := []string{}
	for rows.Next() {
		var likedUID string
		if err := rows.Scan(&likedUID); err != nil {
			continue
		}
		uids = append(uids, likedUID)
	}
	c.JSON(http.StatusOK, gin.H{"likedUids": uids})
}
