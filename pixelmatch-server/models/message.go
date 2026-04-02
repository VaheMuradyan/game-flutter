package models

import "time"

type Message struct {
	ID          string    `json:"id"`
	ChatID      string    `json:"chatId"`
	SenderUID   string    `json:"senderUid"`
	Text        string    `json:"text"`
	MessageType string    `json:"messageType"` // "text", "emote"
	CreatedAt   time.Time `json:"createdAt"`
}
