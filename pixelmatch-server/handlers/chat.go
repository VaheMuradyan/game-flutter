package handlers

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
	"pixelmatch-server/models"
	"pixelmatch-server/websocket"
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

	websocket.BroadcastToChat(chatID, msg)

	preview := req.Text
	if req.MessageType == "emote" {
		preview = "[emote]"
	}
	if _, err := database.DB.Exec(`
		UPDATE chats SET last_message = $1, last_message_at = NOW() WHERE id = $2
	`, preview, chatID); err != nil {
		// Non-critical: log but don't fail the request
	}

	c.JSON(http.StatusCreated, gin.H{"message": msg})
}
