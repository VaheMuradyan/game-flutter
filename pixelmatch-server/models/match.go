package models

import "time"

type Match struct {
	ID        string    `json:"id"`
	User1UID  string    `json:"user1Uid"`
	User2UID  string    `json:"user2Uid"`
	ChatID    string    `json:"chatId"`
	MatchedAt time.Time `json:"matchedAt"`
}
