package main

import (
	"log"
	"time"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/handlers"
	"pixelmatch-server/middleware"
	"pixelmatch-server/websocket"
)

func main() {
	cfg := config.Load()
	database.Connect(cfg)

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "pixelmatch"})
	})

	r.Static("/uploads", cfg.UploadDir)

	authHandler := &handlers.AuthHandler{Cfg: cfg}
	authRateLimit := middleware.RateLimit(10, 1*time.Minute)

	api := r.Group("/api")
	{
		auth := api.Group("/auth")
		{
			auth.POST("/register", authRateLimit, authHandler.Register)
			auth.POST("/login", authRateLimit, authHandler.Login)
		}

		protected := api.Group("")
		protected.Use(middleware.AuthRequired(cfg))
		{
			protected.GET("/me", authHandler.GetMe)
			protected.PUT("/onboarding", authHandler.CompleteOnboarding)

			userHandler := &handlers.UserHandler{Cfg: cfg}
			protected.GET("/users/:uid", userHandler.GetUser)
			protected.PUT("/users/profile", userHandler.UpdateProfile)
			protected.POST("/users/photo", userHandler.UploadPhoto)
			protected.GET("/users/eligible", userHandler.GetEligibleProfiles)

			matchHandler := &handlers.MatchmakingHandler{}
			protected.POST("/likes", matchHandler.RecordLike)
			protected.GET("/likes/today", matchHandler.GetSwipesToday)
			protected.GET("/likes/uids", matchHandler.GetLikedUIDs)
			protected.GET("/matches", matchHandler.GetMatches)

			chatHandler := &handlers.ChatHandler{}
			protected.GET("/chats/:chatId/messages", chatHandler.GetMessages)
			protected.POST("/chats/:chatId/messages", chatHandler.SendMessage)

			lbHandler := &handlers.LeaderboardHandler{}
			protected.GET("/leaderboard", lbHandler.GetGlobalLeaderboard)
			protected.GET("/leaderboard/:league", lbHandler.GetLeagueLeaderboard)
			protected.GET("/battles/history", lbHandler.GetBattleHistory)

			premiumHandler := &handlers.PremiumHandler{}
			protected.GET("/premium/status", premiumHandler.GetPremiumStatus)
			protected.POST("/premium/activate", premiumHandler.ActivatePremium)

			notifHandler := &handlers.NotificationHandler{}
			protected.POST("/notifications/register", notifHandler.RegisterToken)
		}
	}

	// Admin routes — separate static-key auth, NOT user JWT.
	admin := r.Group("/admin")
	admin.Use(middleware.AdminRequired(cfg))
	{
		adminHandler := &handlers.AdminHandler{}
		admin.GET("/users", adminHandler.ListUsers)
		admin.GET("/stats", adminHandler.GetStats)
		admin.POST("/users/:uid/ban", adminHandler.BanUser)
	}

	// WebSocket routes — no auth middleware (auth via message)
	r.GET("/ws/battle", websocket.HandleBattleWS)
	r.GET("/ws/chat/:chatId", websocket.HandleChatWS)

	log.Printf("PixelMatch server starting on :%s", cfg.ServerPort)
	r.Run(":" + cfg.ServerPort)
}
