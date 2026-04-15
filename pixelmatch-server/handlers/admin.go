package handlers

import (
	"database/sql"
	"log"
	"net/http"
	"strconv"
	"strings"

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

type adminBattle struct {
	ID              string `json:"id"`
	Player1UID      string `json:"player1Uid"`
	Player2UID      string `json:"player2Uid"`
	Player1Display  string `json:"p1DisplayName"`
	Player2Display  string `json:"p2DisplayName"`
	WinnerUID       string `json:"winnerUid"`
	Duration        int    `json:"duration"`
	XPAwarded       int    `json:"xpAwarded"`
	CreatedAt       string `json:"createdAt"`
}

func maskEmail(email string) string {
	at := strings.IndexByte(email, '@')
	if at <= 0 {
		return "***"
	}
	return string(email[0]) + "***@" + email[at+1:]
}

func parseLimit(c *gin.Context) int {
	limit := 50
	if s := c.Query("limit"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n > 0 {
			limit = n
		}
	}
	if limit > 100 {
		limit = 100
	}
	return limit
}

// ListUsers returns paginated users (keyset by created_at) with optional search.
func (h *AdminHandler) ListUsers(c *gin.Context) {
	limit := parseLimit(c)
	cursor := c.Query("cursor")
	q := strings.TrimSpace(c.Query("q"))

	args := []interface{}{}
	where := []string{}
	if cursor != "" {
		args = append(args, cursor)
		where = append(where, "created_at < $"+strconv.Itoa(len(args)))
	}
	if q != "" {
		args = append(args, "%"+q+"%")
		idx := strconv.Itoa(len(args))
		where = append(where, "(email ILIKE $"+idx+" OR display_name ILIKE $"+idx+")")
	}
	whereSQL := ""
	if len(where) > 0 {
		whereSQL = "WHERE " + strings.Join(where, " AND ")
	}
	args = append(args, limit)
	limitIdx := strconv.Itoa(len(args))

	query := `
		SELECT uid, email, display_name, character_class, level, league,
		       wins, losses, is_premium, created_at
		FROM users
		` + whereSQL + `
		ORDER BY created_at DESC
		LIMIT $` + limitIdx

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		log.Printf("admin ListUsers query failed: %v", err)
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	users := []adminUser{}
	for rows.Next() {
		var u adminUser
		if err := rows.Scan(&u.UID, &u.Email, &u.DisplayName, &u.CharacterClass,
			&u.Level, &u.League, &u.Wins, &u.Losses, &u.IsPremium, &u.CreatedAt); err != nil {
			log.Printf("admin ListUsers scan failed: %v", err)
			continue
		}
		u.Email = maskEmail(u.Email)
		users = append(users, u)
	}

	nextCursor := ""
	if len(users) == limit {
		nextCursor = users[len(users)-1].CreatedAt
	}

	c.JSON(http.StatusOK, gin.H{
		"users":      users,
		"count":      len(users),
		"nextCursor": nextCursor,
	})
}

// GetStats returns aggregate game statistics in a single CTE query.
func (h *AdminHandler) GetStats(c *gin.Context) {
	var totalUsers, totalBattles, totalMatches int
	var battlesToday, matchesToday, usersToday int
	var avgDuration sql.NullFloat64

	err := database.DB.QueryRow(`
		SELECT
			(SELECT COUNT(*) FROM users),
			(SELECT COUNT(*) FROM battles),
			(SELECT COUNT(*) FROM matches),
			(SELECT COUNT(*) FROM users WHERE created_at >= NOW() - INTERVAL '24 hours'),
			(SELECT COUNT(*) FROM matches WHERE created_at >= NOW() - INTERVAL '24 hours'),
			(SELECT COUNT(*) FROM battles WHERE created_at >= NOW() - INTERVAL '24 hours'),
			(SELECT AVG(duration) FROM battles WHERE created_at >= NOW() - INTERVAL '7 days')
	`).Scan(&totalUsers, &totalBattles, &totalMatches, &usersToday, &matchesToday, &battlesToday, &avgDuration)
	if err != nil {
		log.Printf("admin GetStats aggregate query failed: %v", err)
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}

	leagueCounts := map[string]int{}
	rows, err := database.DB.Query(`SELECT league, COUNT(*) FROM users GROUP BY league`)
	if err != nil {
		log.Printf("admin GetStats league query failed: %v", err)
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()
	for rows.Next() {
		var league string
		var count int
		if err := rows.Scan(&league, &count); err != nil {
			log.Printf("admin GetStats league scan failed: %v", err)
			helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
			return
		}
		leagueCounts[league] = count
	}

	avg := 0.0
	if avgDuration.Valid {
		avg = avgDuration.Float64
	}

	c.JSON(http.StatusOK, gin.H{
		"totalUsers":      totalUsers,
		"totalBattles":    totalBattles,
		"totalMatches":    totalMatches,
		"usersToday":      usersToday,
		"matchesToday":    matchesToday,
		"battlesToday":    battlesToday,
		"avgBattleLength": avg,
		"leagueBreakdown": leagueCounts,
	})
}

// ListBattles returns paginated battles joined with player display names.
func (h *AdminHandler) ListBattles(c *gin.Context) {
	limit := parseLimit(c)
	cursor := c.Query("cursor")

	args := []interface{}{}
	whereSQL := ""
	if cursor != "" {
		args = append(args, cursor)
		whereSQL = "WHERE b.created_at < $1"
	}
	args = append(args, limit)
	limitIdx := strconv.Itoa(len(args))

	query := `
		SELECT b.id, b.player1_uid, b.player2_uid,
		       COALESCE(u1.display_name, ''), COALESCE(u2.display_name, ''),
		       COALESCE(b.winner_uid, ''), b.duration, b.xp_awarded, b.created_at
		FROM battles b
		LEFT JOIN users u1 ON u1.uid = b.player1_uid
		LEFT JOIN users u2 ON u2.uid = b.player2_uid
		` + whereSQL + `
		ORDER BY b.created_at DESC
		LIMIT $` + limitIdx

	rows, err := database.DB.Query(query, args...)
	if err != nil {
		log.Printf("admin ListBattles query failed: %v", err)
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	battles := []adminBattle{}
	for rows.Next() {
		var b adminBattle
		if err := rows.Scan(&b.ID, &b.Player1UID, &b.Player2UID,
			&b.Player1Display, &b.Player2Display,
			&b.WinnerUID, &b.Duration, &b.XPAwarded, &b.CreatedAt); err != nil {
			log.Printf("admin ListBattles scan failed: %v", err)
			continue
		}
		battles = append(battles, b)
	}

	nextCursor := ""
	if len(battles) == limit {
		nextCursor = battles[len(battles)-1].CreatedAt
	}

	c.JSON(http.StatusOK, gin.H{
		"battles":    battles,
		"count":      len(battles),
		"nextCursor": nextCursor,
	})
}

// GetUser returns full user detail (unmasked email) plus recent battles with display names.
func (h *AdminHandler) GetUser(c *gin.Context) {
	uid := c.Param("uid")

	var u adminUser
	err := database.DB.QueryRow(`
		SELECT uid, email, display_name, character_class, level, league,
		       wins, losses, is_premium, created_at
		FROM users WHERE uid = $1
	`, uid).Scan(&u.UID, &u.Email, &u.DisplayName, &u.CharacterClass,
		&u.Level, &u.League, &u.Wins, &u.Losses, &u.IsPremium, &u.CreatedAt)
	if err == sql.ErrNoRows {
		helpers.RespondError(c, http.StatusNotFound, helpers.ErrNotFound)
		return
	}
	if err != nil {
		log.Printf("admin GetUser query failed: %v", err)
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}

	rows, err := database.DB.Query(`
		SELECT b.id, b.player1_uid, b.player2_uid,
		       COALESCE(u1.display_name, ''), COALESCE(u2.display_name, ''),
		       COALESCE(b.winner_uid, ''), b.duration, b.xp_awarded, b.created_at
		FROM battles b
		LEFT JOIN users u1 ON u1.uid = b.player1_uid
		LEFT JOIN users u2 ON u2.uid = b.player2_uid
		WHERE b.player1_uid = $1 OR b.player2_uid = $1
		ORDER BY b.created_at DESC
		LIMIT 20
	`, uid)
	battles := []adminBattle{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var b adminBattle
			if err := rows.Scan(&b.ID, &b.Player1UID, &b.Player2UID,
				&b.Player1Display, &b.Player2Display,
				&b.WinnerUID, &b.Duration, &b.XPAwarded, &b.CreatedAt); err == nil {
				battles = append(battles, b)
			}
		}
	} else {
		log.Printf("admin GetUser battles query failed: %v", err)
	}

	c.JSON(http.StatusOK, gin.H{"user": u, "battles": battles})
}

// Me confirms the current bearer token belongs to an admin account.
// The AdminJWTRequired middleware has already verified is_admin = true,
// so reaching this handler is itself the confirmation.
func (h *AdminHandler) Me(c *gin.Context) {
	uid := c.GetString("uid")

	var email, displayName string
	err := database.DB.QueryRow(`SELECT email, display_name FROM users WHERE uid = $1`, uid).
		Scan(&email, &displayName)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"uid":         uid,
		"email":       email,
		"displayName": displayName,
		"isAdmin":     true,
	})
}
