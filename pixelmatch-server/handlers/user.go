package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/models"
)

type UserHandler struct {
	Cfg *config.Config
}

func (h *UserHandler) GetUser(c *gin.Context) {
	uid := c.Param("uid")

	var user models.User
	err := database.DB.QueryRow(`
		SELECT uid, email, display_name, character_class, photo_url,
		       level, xp, league, wins, losses, is_premium, created_at
		FROM users WHERE uid = $1
	`, uid).Scan(
		&user.UID, &user.Email, &user.DisplayName, &user.CharacterClass,
		&user.PhotoUrl, &user.Level, &user.XP, &user.League,
		&user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
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
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	err := database.DB.QueryRow(`
		UPDATE users SET display_name = $1 WHERE uid = $2
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, req.DisplayName, uid).Scan(
		&user.UID, &user.Email, &user.DisplayName, &user.CharacterClass,
		&user.PhotoUrl, &user.Level, &user.XP, &user.League,
		&user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "update failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": user})
}

func (h *UserHandler) UploadPhoto(c *gin.Context) {
	uid := c.GetString("uid")

	file, err := c.FormFile("photo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no file uploaded"})
		return
	}

	// Create uploads dir if not exists
	os.MkdirAll(h.Cfg.UploadDir, 0755)

	// Save with unique name
	ext := filepath.Ext(file.Filename)
	filename := fmt.Sprintf("%s_%s%s", uid, uuid.New().String()[:8], ext)
	savePath := filepath.Join(h.Cfg.UploadDir, filename)

	if err := c.SaveUploadedFile(file, savePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save file"})
		return
	}

	photoUrl := fmt.Sprintf("/uploads/%s", filename)

	// Update database
	var user models.User
	err = database.DB.QueryRow(`
		UPDATE users SET photo_url = $1 WHERE uid = $2
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, photoUrl, uid).Scan(
		&user.UID, &user.Email, &user.DisplayName, &user.CharacterClass,
		&user.PhotoUrl, &user.Level, &user.XP, &user.League,
		&user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "db update failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": user})
}

// Fetch users at the caller's level or below, excluding the caller.
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	users := []models.User{}
	for rows.Next() {
		var u models.User
		rows.Scan(&u.UID, &u.Email, &u.DisplayName, &u.CharacterClass,
			&u.PhotoUrl, &u.Level, &u.XP, &u.League,
			&u.Wins, &u.Losses, &u.IsPremium, &u.CreatedAt)
		users = append(users, u)
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}
