package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
)

type PremiumHandler struct{}

// GetPremiumStatus returns the user's premium status and feature list.
func (h *PremiumHandler) GetPremiumStatus(c *gin.Context) {
	uid := c.GetString("uid")

	var isPremium bool
	if err := database.DB.QueryRow(
		"SELECT is_premium FROM users WHERE uid = $1", uid,
	).Scan(&isPremium); err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}

	features := map[string]interface{}{
		"unlimitedSwipes": isPremium,
		"priorityQueue":   isPremium,
		"premiumBadge":    isPremium,
	}

	c.JSON(http.StatusOK, gin.H{
		"isPremium": isPremium,
		"features":  features,
	})
}

// ActivatePremium activates premium for the user.
// In production, replace the activation-code check with a real
// receipt verification (RevenueCat / App Store / Play Billing).
func (h *PremiumHandler) ActivatePremium(c *gin.Context) {
	uid := c.GetString("uid")

	var req struct {
		ActivationCode string `json:"activationCode" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	if req.ActivationCode == "" {
		helpers.RespondError(c, http.StatusBadRequest, "invalid activation code")
		return
	}

	_, err := database.DB.Exec(
		"UPDATE users SET is_premium = TRUE WHERE uid = $1", uid,
	)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrUpdateFailed)
		return
	}

	c.JSON(http.StatusOK, gin.H{"isPremium": true})
}
