package helpers

import "github.com/gin-gonic/gin"

// RespondError sends a JSON error response with the given HTTP status.
func RespondError(c *gin.Context, status int, msg string) {
	c.JSON(status, gin.H{"error": msg})
}

// Common error messages
const (
	ErrNotFound     = "not found"
	ErrForbidden    = "forbidden"
	ErrBadRequest   = "bad request"
	ErrInternal     = "internal server error"
	ErrUnauthorized = "unauthorized"
	ErrQueryFailed  = "query failed"
	ErrUpdateFailed = "update failed"
	ErrInsertFailed = "insert failed"
	ErrLimitReached = "daily limit reached"
)
