package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/config"
)

// AdminRequired checks for a static admin API key in the X-Admin-Key header.
// Production deployments should replace this with role-based auth.
func AdminRequired(cfg *config.Config) gin.HandlerFunc {
	adminKey := cfg.AdminKey()
	return func(c *gin.Context) {
		key := c.GetHeader("X-Admin-Key")
		if key == "" || key != adminKey {
			c.JSON(http.StatusForbidden, gin.H{"error": "admin access required"})
			c.Abort()
			return
		}
		c.Next()
	}
}
