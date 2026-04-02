package models

import "time"

type Battle struct {
	ID            string    `json:"id"`
	Player1UID    string    `json:"player1Uid"`
	Player2UID    string    `json:"player2Uid"`
	WinnerUID     string    `json:"winnerUid"`
	Player1Health int       `json:"player1Health"`
	Player2Health int       `json:"player2Health"`
	Duration      int       `json:"duration"`
	XPAwarded     int       `json:"xpAwarded"`
	CreatedAt     time.Time `json:"createdAt"`
}
