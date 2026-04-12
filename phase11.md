# Phase 11 — Backend Hardening & Code Quality

## Goal
Eliminate duplicated code, fix missing error handling, standardize error responses, sync game constants between Go and Flutter, add rate limiting and input validation, and introduce structured logging. When this phase is complete, the Go backend is robust, maintainable, and safe against common misuse.

> **NO NEW FEATURES.** This phase is purely about code quality and correctness.

## Prerequisites
Phases 1–10 complete: all screens, services, providers, game engine, chat, leaderboard work.

---

## 1. User Scan Helper — `helpers/scan.go`

The 12-field user scan pattern appears 7+ times across `handlers/auth.go`, `handlers/user.go`, and `handlers/leaderboard.go`. Extract it once.

```go
package helpers

import (
	"database/sql"
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
```

---

## 2. Standardized Error Responses — `helpers/errors.go`

Replace ad-hoc `gin.H{"error": "..."}` strings with consistent helpers.

```go
package helpers

import "github.com/gin-gonic/gin"

// RespondError sends a JSON error response with the given HTTP status.
func RespondError(c *gin.Context, status int, msg string) {
	c.JSON(status, gin.H{"error": msg})
}

// Common error messages
const (
	ErrNotFound      = "not found"
	ErrForbidden     = "forbidden"
	ErrBadRequest    = "bad request"
	ErrInternal      = "internal server error"
	ErrUnauthorized  = "unauthorized"
	ErrQueryFailed   = "query failed"
	ErrUpdateFailed  = "update failed"
	ErrInsertFailed  = "insert failed"
	ErrLimitReached  = "daily limit reached"
)
```

---

## 3. Game Constants — `config/game_constants.go`

Extract hardcoded XP, level, and league values from `websocket/battle_ws.go` so they mirror `lib/config/constants.dart`.

```go
package config

// Game balance — keep in sync with Flutter constants.dart
const (
	XPPerWin  = 50
	XPPerLoss = -20
	MinXP     = 0

	StartingTowerHealth  = 1000
	BattleDurationSeconds = 180

	DailyFreeSwipes = 20
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
```

---

## 4. Refactor `handlers/auth.go`

Replace duplicated scan patterns with `helpers.ScanUser` and fix error responses.

```go
package handlers

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
	"pixelmatch-server/middleware"
	"pixelmatch-server/models"
)

type AuthHandler struct {
	Cfg *config.Config
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInternal)
		return
	}

	row := database.DB.QueryRow(`
		INSERT INTO users (email, password_hash)
		VALUES ($1, $2)
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, req.Email, string(hash))

	user, err := helpers.ScanUser(row)
	if err != nil {
		helpers.RespondError(c, http.StatusConflict, "email already registered")
		return
	}

	token, err := middleware.GenerateToken(user.UID, h.Cfg.JWTSecret)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInternal)
		return
	}

	c.JSON(http.StatusCreated, models.AuthResponse{Token: token, User: user})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	row := database.DB.QueryRow(`
		SELECT uid, email, password_hash, display_name, character_class, photo_url,
		       level, xp, league, wins, losses, is_premium, created_at
		FROM users WHERE email = $1
	`, req.Email)

	user, passwordHash, err := helpers.ScanUserWithPassword(row)
	if err == sql.ErrNoRows {
		helpers.RespondError(c, http.StatusUnauthorized, helpers.ErrUnauthorized)
		return
	}
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInternal)
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		helpers.RespondError(c, http.StatusUnauthorized, helpers.ErrUnauthorized)
		return
	}

	token, err := middleware.GenerateToken(user.UID, h.Cfg.JWTSecret)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInternal)
		return
	}

	c.JSON(http.StatusOK, models.AuthResponse{Token: token, User: user})
}

func (h *AuthHandler) CompleteOnboarding(c *gin.Context) {
	uid := c.GetString("uid")

	var req models.OnboardingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	validClasses := map[string]bool{
		"Warrior": true, "Mage": true, "Archer": true,
		"Rogue": true, "Healer": true,
	}
	if !validClasses[req.CharacterClass] {
		helpers.RespondError(c, http.StatusBadRequest, "invalid character class")
		return
	}

	row := database.DB.QueryRow(`
		UPDATE users SET display_name = $1, character_class = $2
		WHERE uid = $3
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, req.DisplayName, req.CharacterClass, uid)

	user, err := helpers.ScanUser(row)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrUpdateFailed)
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": user})
}

func (h *AuthHandler) GetMe(c *gin.Context) {
	uid := c.GetString("uid")

	row := database.DB.QueryRow(`
		SELECT uid, email, display_name, character_class, photo_url,
		       level, xp, league, wins, losses, is_premium, created_at
		FROM users WHERE uid = $1
	`, uid)

	user, err := helpers.ScanUser(row)
	if err != nil {
		helpers.RespondError(c, http.StatusNotFound, helpers.ErrNotFound)
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": user})
}
```

---

## 5. Refactor `handlers/user.go`

Same pattern — use `helpers.ScanUser` and add file validation on upload.

```go
package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
	"pixelmatch-server/models"
)

type UserHandler struct {
	Cfg *config.Config
}

// Max upload size: 5 MB
const maxUploadSize = 5 << 20

// Allowed MIME types for photo upload
var allowedMIME = map[string]bool{
	"image/jpeg": true,
	"image/png":  true,
	"image/webp": true,
}

func (h *UserHandler) GetUser(c *gin.Context) {
	uid := c.Param("uid")

	row := database.DB.QueryRow(`
		SELECT uid, email, display_name, character_class, photo_url,
		       level, xp, league, wins, losses, is_premium, created_at
		FROM users WHERE uid = $1
	`, uid)

	user, err := helpers.ScanUser(row)
	if err != nil {
		helpers.RespondError(c, http.StatusNotFound, helpers.ErrNotFound)
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": user})
}

func (h *UserHandler) UpdateProfile(c *gin.Context) {
	uid := c.GetString("uid")

	var req struct {
		DisplayName string `json:"displayName"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	row := database.DB.QueryRow(`
		UPDATE users SET display_name = $1 WHERE uid = $2
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, req.DisplayName, uid)

	user, err := helpers.ScanUser(row)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrUpdateFailed)
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": user})
}

func (h *UserHandler) UploadPhoto(c *gin.Context) {
	uid := c.GetString("uid")

	file, err := c.FormFile("photo")
	if err != nil {
		helpers.RespondError(c, http.StatusBadRequest, "no file uploaded")
		return
	}

	// Validate file size
	if file.Size > maxUploadSize {
		helpers.RespondError(c, http.StatusBadRequest, "file too large (max 5 MB)")
		return
	}

	// Validate MIME type
	mime := file.Header.Get("Content-Type")
	if !allowedMIME[strings.ToLower(mime)] {
		helpers.RespondError(c, http.StatusBadRequest, "unsupported file type (jpeg, png, webp only)")
		return
	}

	os.MkdirAll(h.Cfg.UploadDir, 0755)

	ext := filepath.Ext(file.Filename)
	filename := fmt.Sprintf("%s_%s%s", uid, uuid.New().String()[:8], ext)
	savePath := filepath.Join(h.Cfg.UploadDir, filename)

	if err := c.SaveUploadedFile(file, savePath); err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, "failed to save file")
		return
	}

	photoUrl := fmt.Sprintf("/uploads/%s", filename)

	row := database.DB.QueryRow(`
		UPDATE users SET photo_url = $1 WHERE uid = $2
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, photoUrl, uid)

	user, err := helpers.ScanUser(row)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrUpdateFailed)
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": user})
}

func (h *UserHandler) GetEligibleProfiles(c *gin.Context) {
	uid := c.GetString("uid")

	rows, err := database.DB.Query(`
		SELECT uid, email, display_name, character_class, photo_url,
		       level, xp, league, wins, losses, is_premium, created_at
		FROM users
		WHERE uid != $1
		  AND level <= (SELECT level FROM users WHERE uid = $1)
		  AND display_name != ''
		ORDER BY RANDOM()
		LIMIT 50
	`, uid)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	users := []models.User{}
	for rows.Next() {
		user, err := helpers.ScanUser(rows)
		if err != nil {
			continue
		}
		users = append(users, user)
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}
```

---

## 6. Refactor `handlers/chat.go`

Fix the fragile type assertion and add error checking on `.Scan()` calls. Add message length validation.

```go
package handlers

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
	"pixelmatch-server/models"
)

type ChatHandler struct{}

// maxMessageLength is the maximum allowed length for a chat message.
const maxMessageLength = 2000

// verifyParticipant checks the caller is part of the chat's match.
func verifyParticipant(chatID, uid string) (bool, error) {
	var matchID string
	err := database.DB.QueryRow("SELECT match_id FROM chats WHERE id = $1", chatID).Scan(&matchID)
	if err != nil {
		return false, err
	}

	var ok bool
	err = database.DB.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM matches WHERE id = $1 AND (user1_uid = $2 OR user2_uid = $2)
		)
	`, matchID, uid).Scan(&ok)
	return ok, err
}

func (h *ChatHandler) GetMessages(c *gin.Context) {
	uid := c.GetString("uid")
	chatID := c.Param("chatId")

	ok, err := verifyParticipant(chatID, uid)
	if err != nil {
		helpers.RespondError(c, http.StatusNotFound, "chat not found")
		return
	}
	if !ok {
		helpers.RespondError(c, http.StatusForbidden, helpers.ErrForbidden)
		return
	}

	afterParam := c.Query("after")

	var rows *sql.Rows
	if afterParam != "" {
		rows, err = database.DB.Query(`
			SELECT id, chat_id, sender_uid, text, message_type, created_at
			FROM messages WHERE chat_id = $1 AND created_at > $2
			ORDER BY created_at ASC
		`, chatID, afterParam)
	} else {
		rows, err = database.DB.Query(`
			SELECT id, chat_id, sender_uid, text, message_type, created_at
			FROM messages WHERE chat_id = $1
			ORDER BY created_at ASC LIMIT 100
		`, chatID)
	}

	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	messages := []models.Message{}
	for rows.Next() {
		var m models.Message
		if err := rows.Scan(&m.ID, &m.ChatID, &m.SenderUID, &m.Text, &m.MessageType, &m.CreatedAt); err != nil {
			continue
		}
		messages = append(messages, m)
	}

	c.JSON(http.StatusOK, gin.H{"messages": messages})
}

func (h *ChatHandler) SendMessage(c *gin.Context) {
	uid := c.GetString("uid")
	chatID := c.Param("chatId")

	var req struct {
		Text        string `json:"text" binding:"required"`
		MessageType string `json:"messageType"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	if len(req.Text) > maxMessageLength {
		helpers.RespondError(c, http.StatusBadRequest, "message too long")
		return
	}

	if req.MessageType == "" {
		req.MessageType = "text"
	}

	ok, err := verifyParticipant(chatID, uid)
	if err != nil {
		helpers.RespondError(c, http.StatusNotFound, "chat not found")
		return
	}
	if !ok {
		helpers.RespondError(c, http.StatusForbidden, helpers.ErrForbidden)
		return
	}

	var msg models.Message
	err = database.DB.QueryRow(`
		INSERT INTO messages (chat_id, sender_uid, text, message_type)
		VALUES ($1, $2, $3, $4)
		RETURNING id, chat_id, sender_uid, text, message_type, created_at
	`, chatID, uid, req.Text, req.MessageType).Scan(
		&msg.ID, &msg.ChatID, &msg.SenderUID, &msg.Text, &msg.MessageType, &msg.CreatedAt,
	)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInsertFailed)
		return
	}

	preview := req.Text
	if req.MessageType == "emote" {
		preview = "[emote]"
	}
	if _, err := database.DB.Exec(`
		UPDATE chats SET last_message = $1, last_message_at = NOW() WHERE id = $2
	`, preview, chatID); err != nil {
		// Non-critical: log but don't fail the request
		// slog.Error("failed to update chat preview", "err", err)
	}

	c.JSON(http.StatusCreated, gin.H{"message": msg})
}
```

---

## 7. Refactor `handlers/matchmaking.go`

Add error checking on all `.Scan()` calls and use game constants.

```go
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
```

---

## 8. Refactor `handlers/leaderboard.go`

Use proper structs instead of `map[string]interface{}` and check scan errors.

```go
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
	ID            string      `json:"id"`
	Player1UID    string      `json:"player1Uid"`
	Player2UID    string      `json:"player2Uid"`
	WinnerUID     string      `json:"winnerUid"`
	Player1Health int         `json:"player1Health"`
	Player2Health int         `json:"player2Health"`
	Duration      int         `json:"duration"`
	XPAwarded     int         `json:"xpAwarded"`
	CreatedAt     time.Time   `json:"createdAt"`
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
```

---

## 9. Refactor `websocket/battle_ws.go` — Use Game Constants & Fix Error Handling

Key changes:
- Use `config.XPPerWin`, `config.XPPerLoss`, `config.LeagueForLevel()`
- Check `.Scan()` and `.Exec()` errors in `awardXP()`
- Use `log/slog` instead of `log.Printf`

Replace the `awardXP` and `leagueForLevel` functions and `saveBattleResult`:

```go
func saveBattleResult(room *BattleRoom, winnerUID string) {
	_, err := database.DB.Exec(`
		INSERT INTO battles (player1_uid, player2_uid, winner_uid, player1_health, player2_health, duration, xp_awarded)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, room.Players[0].UID, room.Players[1].UID, winnerUID,
		room.TowerHealth[0], room.TowerHealth[1], room.Duration, config.XPPerWin)
	if err != nil {
		slog.Error("failed to save battle", "err", err)
	}

	awardXP(room.Players[0].UID, room.Players[0].UID == winnerUID)
	awardXP(room.Players[1].UID, room.Players[1].UID == winnerUID)
}

func awardXP(uid string, won bool) {
	delta := config.XPPerLoss
	winIncr := 0
	lossIncr := 1
	if won {
		delta = config.XPPerWin
		winIncr = 1
		lossIncr = 0
	}

	var currentXP int
	if err := database.DB.QueryRow("SELECT xp FROM users WHERE uid = $1", uid).Scan(&currentXP); err != nil {
		slog.Error("failed to get user XP", "uid", uid, "err", err)
		return
	}

	newXP := currentXP + delta
	if newXP < config.MinXP {
		newXP = config.MinXP
	}

	newLevel := (newXP / 100) + 1
	newLeague := config.LeagueForLevel(newLevel)

	if _, err := database.DB.Exec(`
		UPDATE users SET xp = $1, level = $2, league = $3,
		       wins = wins + $4, losses = losses + $5
		WHERE uid = $6
	`, newXP, newLevel, newLeague, winIncr, lossIncr, uid); err != nil {
		slog.Error("failed to update user XP", "uid", uid, "err", err)
	}
}
```

Delete the local `leagueForLevel()` function — it's now in `config/game_constants.go`.

Also update `BattleRoom` creation to use constants:

```go
room := &BattleRoom{
    ID:          uuid.New().String(),
    Players:     [2]*Player{p1, p2},
    TowerHealth: [2]int{config.StartingTowerHealth, config.StartingTowerHealth},
    StartTime:   time.Now(),
    Duration:    config.BattleDurationSeconds,
}
```

---

## 10. Rate Limiting Middleware — `middleware/rate_limit.go`

Simple in-memory per-IP rate limiter for auth endpoints.

```go
package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type rateLimiter struct {
	mu       sync.Mutex
	attempts map[string][]time.Time
	limit    int
	window   time.Duration
}

func newRateLimiter(limit int, window time.Duration) *rateLimiter {
	rl := &rateLimiter{
		attempts: make(map[string][]time.Time),
		limit:    limit,
		window:   window,
	}
	// Cleanup old entries every minute
	go func() {
		for range time.NewTicker(1 * time.Minute).C {
			rl.cleanup()
		}
	}()
	return rl
}

func (rl *rateLimiter) allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	cutoff := now.Add(-rl.window)

	// Remove old attempts
	valid := make([]time.Time, 0)
	for _, t := range rl.attempts[ip] {
		if t.After(cutoff) {
			valid = append(valid, t)
		}
	}
	rl.attempts[ip] = valid

	if len(valid) >= rl.limit {
		return false
	}

	rl.attempts[ip] = append(rl.attempts[ip], now)
	return true
}

func (rl *rateLimiter) cleanup() {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	cutoff := time.Now().Add(-rl.window)
	for ip, attempts := range rl.attempts {
		valid := make([]time.Time, 0)
		for _, t := range attempts {
			if t.After(cutoff) {
				valid = append(valid, t)
			}
		}
		if len(valid) == 0 {
			delete(rl.attempts, ip)
		} else {
			rl.attempts[ip] = valid
		}
	}
}

// RateLimit returns middleware that limits requests per IP.
// limit: max requests, window: time window (e.g. 1 minute).
func RateLimit(limit int, window time.Duration) gin.HandlerFunc {
	rl := newRateLimiter(limit, window)
	return func(c *gin.Context) {
		ip := c.ClientIP()
		if !rl.allow(ip) {
			c.JSON(http.StatusTooManyRequests, gin.H{"error": "too many requests, try again later"})
			c.Abort()
			return
		}
		c.Next()
	}
}
```

---

## 11. Apply Rate Limiting in `main.go`

```go
import "time"

// Inside main(), before route registration:
authRateLimit := middleware.RateLimit(10, 1*time.Minute)

auth := api.Group("/auth")
{
    auth.POST("/register", authRateLimit, authHandler.Register)
    auth.POST("/login", authRateLimit, authHandler.Login)
}
```

---

## 12. Verification Checklist

### Compilation
- [ ] `go build ./...` passes with zero errors
- [ ] New `helpers/` package compiles (no circular imports)
- [ ] New `config/game_constants.go` compiles

### Error Handling
- [ ] Every `QueryRow().Scan()` return value is checked
- [ ] Every `database.DB.Exec()` return value is checked (or logged if non-critical)
- [ ] `awardXP()` returns early on read error instead of writing incorrect XP

### Deduplication
- [ ] No inline user scan patterns remain in handlers — all use `helpers.ScanUser()`
- [ ] `leagueForLevel()` exists only in `config/game_constants.go`, not in `websocket/battle_ws.go`
- [ ] `verifyParticipant()` extracted in `chat.go` — no duplicate participation checks

### Constants
- [ ] `battle_ws.go` uses `config.XPPerWin` (50) and `config.XPPerLoss` (-20) — not hardcoded numbers
- [ ] `battle_ws.go` uses `config.StartingTowerHealth` (1000) and `config.BattleDurationSeconds` (180)
- [ ] `matchmaking.go` uses `config.DailyFreeSwipes` (20) — not hardcoded

### Validation
- [ ] `UploadPhoto` rejects files > 5 MB
- [ ] `UploadPhoto` rejects non-image MIME types
- [ ] `SendMessage` rejects messages > 2000 characters
- [ ] Rate limiter blocks > 10 auth requests per IP per minute

### Leaderboard
- [ ] `LeaderboardEntry` and `BattleHistoryEntry` are proper structs (not `map[string]interface{}`)
- [ ] All `rows.Scan()` errors are checked

### End-to-End
- [ ] Register → Login → Battle → XP update still works
- [ ] Chat send/receive still works
- [ ] Leaderboard returns same data as before
- [ ] Photo upload with valid JPEG works
- [ ] Photo upload with .exe file is rejected

---

## What Phase 12 Expects
A clean, well-structured Go backend with all errors handled, constants centralized, and code deduplicated. The Flutter client's API contract is unchanged — no endpoint URLs or response shapes changed, so no Flutter updates are needed for this phase.

## New Files Created in This Phase
```
pixelmatch-server/
├── helpers/
│   ├── scan.go           (ScanUser, ScanUserWithPassword)
│   └── errors.go         (RespondError, error constants)
├── config/
│   └── game_constants.go (XP, league, battle constants)
└── middleware/
    └── rate_limit.go     (per-IP rate limiter)
```
