package middleware

import (
	"database/sql"
	"log"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
)

// AdminJWTRequired validates the JWT Authorization header and then verifies
// that the corresponding user row has is_admin = true. The is_admin column
// must exist (see database/schema/admin_panel.sql).
func AdminJWTRequired(cfg *config.Config) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
			c.Abort()
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		token, err := jwt.Parse(tokenStr, func(t *jwt.Token) (interface{}, error) {
			return []byte(cfg.JWTSecret), nil
		}, jwt.WithValidMethods([]string{"HS256"}))
		if err != nil || !token.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			c.Abort()
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid claims"})
			c.Abort()
			return
		}

		uid, _ := claims["uid"].(string)
		if uid == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid claims"})
			c.Abort()
			return
		}

		var isAdmin bool
		err = database.DB.QueryRow(`SELECT is_admin FROM users WHERE uid = $1`, uid).Scan(&isAdmin)
		if err == sql.ErrNoRows || (err == nil && !isAdmin) {
			c.JSON(http.StatusForbidden, gin.H{"error": "admin access required"})
			c.Abort()
			return
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "admin lookup failed"})
			c.Abort()
			return
		}

		c.Set("uid", uid)
		c.Next()
	}
}

// AdminCORS allows the Vite dev panel (http://localhost:5173) to call
// /api/admin/* with credentials. Scoped to the admin group only.
func AdminCORS() gin.HandlerFunc {
	const allowedOrigin = "http://localhost:5173"
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin == allowedOrigin {
			c.Header("Access-Control-Allow-Origin", allowedOrigin)
			c.Header("Vary", "Origin")
			c.Header("Access-Control-Allow-Credentials", "true")
			c.Header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type")
		}
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

// AdminAuditLog inserts one row into admin_audit_log for each admin request
// after the handler completes. Must be wired in AFTER AdminJWTRequired so the
// uid context value is populated.
func AdminAuditLog() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Next()
		actorUID := c.GetString("uid")
		if actorUID == "" {
			return
		}
		targetUID := c.Param("uid")
		var target interface{}
		if targetUID != "" {
			target = targetUID
		}
		_, err := database.DB.Exec(
			`INSERT INTO admin_audit_log (actor_uid, action, target_uid, path, ip)
			 VALUES ($1, $2, $3, $4, $5)`,
			actorUID, c.Request.Method, target, c.FullPath(), c.ClientIP(),
		)
		if err != nil {
			log.Printf("admin audit log insert failed: %v", err)
		}
	}
}
