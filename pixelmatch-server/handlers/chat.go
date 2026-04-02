package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/models"
)

type ChatHandler struct{}

func (h *ChatHandler) GetMessages(c *gin.Context) {
	uid := c.GetString("uid")
	chatID := c.Param("chatId")

	// Verify user is a participant
	var matchID string
	err := database.DB.QueryRow("SELECT match_id FROM chats WHERE id = $1", chatID).Scan(&matchID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "chat not found"})
		return
	}

	var isParticipant bool
	database.DB.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM matches WHERE id = $1 AND (user1_uid = $2 OR user2_uid = $2)
		)
	`, matchID, uid).Scan(&isParticipant)

	if !isParticipant {
		c.JSON(http.StatusForbidden, gin.H{"error": "not a participant"})
		return
	}

	// Get messages, optionally after a timestamp for polling
	afterParam := c.Query("after") // ISO timestamp string

	var rows interface{ Close() error }
	var queryErr error

	if afterParam != "" {
		rows2, err := database.DB.Query(`
			SELECT id, chat_id, sender_uid, text, message_type, created_at
			FROM messages WHERE chat_id = $1 AND created_at > $2
			ORDER BY created_at ASC
		`, chatID, afterParam)
		rows = rows2
		queryErr = err
	} else {
		rows2, err := database.DB.Query(`
			SELECT id, chat_id, sender_uid, text, message_type, created_at
			FROM messages WHERE chat_id = $1
			ORDER BY created_at ASC LIMIT 100
		`, chatID)
		rows = rows2
		queryErr = err
	}

	if queryErr != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	messages := []models.Message{}
	// Type assert to iterate
	if r, ok := rows.(interface {
		Next() bool
		Scan(dest ...interface{}) error
	}); ok {
		for r.Next() {
			var m models.Message
			r.Scan(&m.ID, &m.ChatID, &m.SenderUID, &m.Text, &m.MessageType, &m.CreatedAt)
			messages = append(messages, m)
		}
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
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.MessageType == "" {
		req.MessageType = "text"
	}

	// Verify participation
	var matchID string
	err := database.DB.QueryRow("SELECT match_id FROM chats WHERE id = $1", chatID).Scan(&matchID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "chat not found"})
		return
	}

	var isParticipant bool
	database.DB.QueryRow(`
		SELECT EXISTS(
			SELECT 1 FROM matches WHERE id = $1 AND (user1_uid = $2 OR user2_uid = $2)
		)
	`, matchID, uid).Scan(&isParticipant)

	if !isParticipant {
		c.JSON(http.StatusForbidden, gin.H{"error": "not a participant"})
		return
	}

	// Insert message
	var msg models.Message
	err = database.DB.QueryRow(`
		INSERT INTO messages (chat_id, sender_uid, text, message_type)
		VALUES ($1, $2, $3, $4)
		RETURNING id, chat_id, sender_uid, text, message_type, created_at
	`, chatID, uid, req.Text, req.MessageType).Scan(
		&msg.ID, &msg.ChatID, &msg.SenderUID, &msg.Text, &msg.MessageType, &msg.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "insert failed"})
		return
	}

	// Update chat's last message
	preview := req.Text
	if req.MessageType == "emote" {
		preview = "[emote]"
	}
	database.DB.Exec(`
		UPDATE chats SET last_message = $1, last_message_at = NOW() WHERE id = $2
	`, preview, chatID)

	c.JSON(http.StatusCreated, gin.H{"message": msg})
}
