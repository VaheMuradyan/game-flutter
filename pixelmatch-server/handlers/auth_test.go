package handlers_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/handlers"
)

func setupTestRouter(t *testing.T) *gin.Engine {
	t.Helper()
	gin.SetMode(gin.TestMode)
	cfg := config.Load()
	if err := safeConnect(cfg); err != nil {
		t.Skipf("skipping integration test: %v", err)
	}

	r := gin.New()
	authHandler := &handlers.AuthHandler{Cfg: cfg}
	r.POST("/api/auth/register", authHandler.Register)
	r.POST("/api/auth/login", authHandler.Login)
	return r
}

// safeConnect attempts to open the DB; returns an error instead of panicking
// so the test can skip cleanly when no DB is available.
func safeConnect(cfg *config.Config) (err error) {
	defer func() {
		if r := recover(); r != nil {
			err = errFromPanic(r)
		}
	}()
	database.Connect(cfg)
	if database.DB != nil {
		return database.DB.Ping()
	}
	return nil
}

type panicErr struct{ msg string }

func (e *panicErr) Error() string { return e.msg }

func errFromPanic(r interface{}) error {
	switch v := r.(type) {
	case string:
		return &panicErr{msg: v}
	case error:
		return v
	default:
		return &panicErr{msg: "panic during db connect"}
	}
}

func TestRegisterAndLogin(t *testing.T) {
	r := setupTestRouter(t)

	body, _ := json.Marshal(map[string]string{
		"email":    "test_integration@test.com",
		"password": "testpass123",
	})

	// Register — accept either 201 (new) or 409 (already exists from prior run).
	req := httptest.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated && w.Code != http.StatusConflict {
		t.Fatalf("Register: expected 201 or 409, got %d: %s", w.Code, w.Body.String())
	}

	// Login
	req = httptest.NewRequest("POST", "/api/auth/login", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("Login: expected 200, got %d: %s", w.Code, w.Body.String())
	}

	var resp map[string]interface{}
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if resp["token"] == nil {
		t.Fatal("Login response missing token")
	}
}
