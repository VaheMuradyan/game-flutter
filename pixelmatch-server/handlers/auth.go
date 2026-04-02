package handlers

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/middleware"
	"pixelmatch-server/models"
)

type AuthHandler struct {
	Cfg *config.Config
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to hash password"})
		return
	}

	var user models.User
	err = database.DB.QueryRow(`
		INSERT INTO users (email, password_hash)
		VALUES ($1, $2)
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, req.Email, string(hash)).Scan(
		&user.UID, &user.Email, &user.DisplayName, &user.CharacterClass,
		&user.PhotoUrl, &user.Level, &user.XP, &user.League,
		&user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "email already registered"})
		return
	}

	token, err := middleware.GenerateToken(user.UID, h.Cfg.JWTSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create token"})
		return
	}

	c.JSON(http.StatusCreated, models.AuthResponse{Token: token, User: user})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	var passwordHash string
	err := database.DB.QueryRow(`
		SELECT uid, email, password_hash, display_name, character_class, photo_url,
		       level, xp, league, wins, losses, is_premium, created_at
		FROM users WHERE email = $1
	`, req.Email).Scan(
		&user.UID, &user.Email, &passwordHash, &user.DisplayName,
		&user.CharacterClass, &user.PhotoUrl, &user.Level, &user.XP,
		&user.League, &user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database error"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	token, err := middleware.GenerateToken(user.UID, h.Cfg.JWTSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create token"})
		return
	}

	c.JSON(http.StatusOK, models.AuthResponse{Token: token, User: user})
}

func (h *AuthHandler) CompleteOnboarding(c *gin.Context) {
	uid := c.GetString("uid")

	var req models.OnboardingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	validClasses := map[string]bool{
		"Warrior": true, "Mage": true, "Archer": true,
		"Rogue": true, "Healer": true,
	}
	if !validClasses[req.CharacterClass] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid character class"})
		return
	}

	var user models.User
	err := database.DB.QueryRow(`
		UPDATE users SET display_name = $1, character_class = $2
		WHERE uid = $3
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, req.DisplayName, req.CharacterClass, uid).Scan(
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

func (h *AuthHandler) GetMe(c *gin.Context) {
	uid := c.GetString("uid")

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
