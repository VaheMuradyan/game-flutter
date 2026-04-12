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
