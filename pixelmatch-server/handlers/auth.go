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

	token, err := middleware.GenerateToken(user.UID, h.Cfg.JWTSecret, false)
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

	token, err := middleware.GenerateToken(user.UID, h.Cfg.JWTSecret, false)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInternal)
		return
	}

	c.JSON(http.StatusOK, models.AuthResponse{Token: token, User: user})
}

func (h *AuthHandler) AdminLogin(c *gin.Context) {
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

	var isAdmin bool
	if err := database.DB.QueryRow(`SELECT is_admin FROM users WHERE uid = $1`, user.UID).Scan(&isAdmin); err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrInternal)
		return
	}
	if !isAdmin {
		helpers.RespondError(c, http.StatusForbidden, "admin access required")
		return
	}

	token, err := middleware.GenerateToken(user.UID, h.Cfg.JWTSecret, true)
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
