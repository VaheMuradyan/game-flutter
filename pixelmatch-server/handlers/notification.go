package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
)

type NotificationHandler struct{}

// RegisterToken stores the client's FCM token against the authenticated user.
func (h *NotificationHandler) RegisterToken(c *gin.Context) {
	uid := c.GetString("uid")

	var req struct {
		FcmToken string `json:"fcmToken" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	_, err := database.DB.Exec(
		"UPDATE users SET fcm_token = $1 WHERE uid = $2",
		req.FcmToken, uid,
	)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrUpdateFailed)
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "registered"})
}
