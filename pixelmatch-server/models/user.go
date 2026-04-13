package models

import "time"

type User struct {
	UID            string    `json:"uid"`
	Email          string    `json:"email"`
	PasswordHash   string    `json:"-"` // never sent to client
	DisplayName    string    `json:"displayName"`
	CharacterClass string    `json:"characterClass"`
	PhotoUrl       string    `json:"photoUrl"`
	Level          int       `json:"level"`
	XP             int       `json:"xp"`
	League         string    `json:"league"`
	Wins           int       `json:"wins"`
	Losses         int       `json:"losses"`
	IsPremium      bool      `json:"isPremium"`
	CreatedAt      time.Time `json:"createdAt"`
	FcmToken       string    `json:"-"` // never expose to client
}

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required"`
	Password string `json:"password" binding:"required"`
}

type OnboardingRequest struct {
	DisplayName    string `json:"displayName" binding:"required,max=20"`
	CharacterClass string `json:"characterClass" binding:"required"`
}

type AuthResponse struct {
	Token string `json:"token"`
	User  User   `json:"user"`
}
