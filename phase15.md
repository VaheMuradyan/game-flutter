# Phase 15 — Premium System, Testing & Deployment

## Goal
Implement the premium upgrade system, add unit and widget tests for both Go and Flutter, set up environment-based configuration for Go, add push notification stubs, and create admin API endpoints. When this phase is complete, the app is production-ready with a monetization path, test coverage, and operational tools.

## Prerequisites
Phases 11–14 complete: clean codebase, polished UI, sprites and audio working.

---

## 1. Premium Endpoints — Go Backend

The `is_premium` field already exists in the database and is checked in `matchmaking.go`. Add endpoints to manage premium status.

### `handlers/premium.go`

```go
package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
)

type PremiumHandler struct{}

// GetPremiumStatus returns the user's premium status and feature list.
func (h *PremiumHandler) GetPremiumStatus(c *gin.Context) {
	uid := c.GetString("uid")

	var isPremium bool
	if err := database.DB.QueryRow(
		"SELECT is_premium FROM users WHERE uid = $1", uid,
	).Scan(&isPremium); err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}

	features := map[string]interface{}{
		"unlimitedSwipes":  isPremium,
		"priorityQueue":    isPremium,
		"premiumBadge":     isPremium,
	}

	c.JSON(http.StatusOK, gin.H{
		"isPremium": isPremium,
		"features":  features,
	})
}

// ActivatePremium activates premium for the user.
// In production, this should verify a purchase receipt from the app store.
// For now, it accepts a simple activation code for testing.
func (h *PremiumHandler) ActivatePremium(c *gin.Context) {
	uid := c.GetString("uid")

	var req struct {
		// In production: replace with receipt/transaction verification
		ActivationCode string `json:"activationCode" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	// Stub: accept any non-empty code for testing
	// TODO: Replace with RevenueCat/App Store receipt verification
	if req.ActivationCode == "" {
		helpers.RespondError(c, http.StatusBadRequest, "invalid activation code")
		return
	}

	_, err := database.DB.Exec(
		"UPDATE users SET is_premium = TRUE WHERE uid = $1", uid,
	)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrUpdateFailed)
		return
	}

	c.JSON(http.StatusOK, gin.H{"isPremium": true})
}
```

### Register routes in `main.go`

```go
premiumHandler := &handlers.PremiumHandler{}
protected.GET("/premium/status", premiumHandler.GetPremiumStatus)
protected.POST("/premium/activate", premiumHandler.ActivatePremium)
```

---

## 2. Flutter Premium Screen — `lib/screens/premium/premium_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/api_client.dart';
import '../../providers/auth_provider.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isPremium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final resp = await ApiClient.get('/api/premium/status');
      setState(() {
        _isPremium = resp['isPremium'] as bool;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    try {
      await ApiClient.post('/api/premium/activate', {'activationCode': 'PREMIUM2024'});
      setState(() => _isPremium = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Activation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('PREMIUM')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _isPremium ? Icons.star : Icons.star_border,
              size: 64,
              color: AppTheme.accentGold,
            ),
            const SizedBox(height: 16),
            Text(
              _isPremium ? 'You are Premium!' : 'Go Premium',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _featureRow(Icons.all_inclusive, 'Unlimited daily swipes'),
            _featureRow(Icons.speed, 'Priority battle queue'),
            _featureRow(Icons.verified, 'Premium profile badge'),
            const SizedBox(height: 32),
            if (!_isPremium)
              ElevatedButton(
                onPressed: _activate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentGold,
                  minimumSize: const Size(double.infinity, 56),
                ),
                child: const Text('ACTIVATE PREMIUM'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, color: AppTheme.accentGold, size: 24),
      const SizedBox(width: 16),
      Text(text, style: Theme.of(context).textTheme.bodyLarge),
    ]),
  );
}
```

Add a route in `routes.dart`:
```dart
GoRoute(path: '/premium', pageBuilder: (_, s) => _pixelPage(const PremiumScreen(), s)),
```

Add a link to premium from the profile screen.

---

## 3. Go Environment Configuration

Add `.env` file support with `godotenv` for different environments.

### Install godotenv

```bash
cd pixelmatch-server
go get github.com/joho/godotenv
```

### Update `config/config.go`

```go
package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
	JWTSecret  string
	ServerPort string
	UploadDir  string
	Env        string // "development", "staging", "production"
}

func Load() *Config {
	// Load .env file if it exists (not an error if missing)
	env := getEnv("APP_ENV", "development")
	godotenv.Load(".env." + env)
	godotenv.Load(".env") // fallback

	return &Config{
		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnv("DB_PORT", "5432"),
		DBUser:     getEnv("DB_USER", "pixelmatch"),
		DBPassword: getEnv("DB_PASSWORD", "pixelmatch_secret_2024"),
		DBName:     getEnv("DB_NAME", "pixelmatch"),
		JWTSecret:  getEnv("JWT_SECRET", "pixelmatch_jwt_secret_change_me"),
		ServerPort: getEnv("SERVER_PORT", "8080"),
		UploadDir:  getEnv("UPLOAD_DIR", "./uploads"),
		Env:        env,
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
```

### Create `.env.development`

```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=pixelmatch
DB_PASSWORD=pixelmatch_secret_2024
DB_NAME=pixelmatch
JWT_SECRET=dev_jwt_secret_not_for_production
SERVER_PORT=8080
UPLOAD_DIR=./uploads
```

### Create `.env.production` (template)

```env
DB_HOST=your-rds-endpoint.amazonaws.com
DB_PORT=5432
DB_USER=pixelmatch_prod
DB_PASSWORD=CHANGE_ME_STRONG_PASSWORD
DB_NAME=pixelmatch_prod
JWT_SECRET=CHANGE_ME_RANDOM_64_CHAR_SECRET
SERVER_PORT=8080
UPLOAD_DIR=/var/data/pixelmatch/uploads
```

### Add `.env*` to `.gitignore`

```
# Environment files
.env
.env.*
!.env.development
```

---

## 4. Push Notification Stubs

### Database Migration

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT NOT NULL DEFAULT '';
```

### Go: Update user model — `models/user.go`

Add `FcmToken` field (json tag: `"-"` to never send to client):

```go
type User struct {
	// ... existing fields ...
	FcmToken string `json:"-"` // never expose to client
}
```

### Go: Register FCM token endpoint — `handlers/notification.go`

```go
package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
)

type NotificationHandler struct{}

func (h *NotificationHandler) RegisterToken(c *gin.Context) {
	uid := c.GetString("uid")

	var req struct {
		FcmToken string `json:"fcmToken" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		helpers.RespondError(c, http.StatusBadRequest, err.Error())
		return
	}

	_, err := database.DB.Exec(
		"UPDATE users SET fcm_token = $1 WHERE uid = $2",
		req.FcmToken, uid,
	)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrUpdateFailed)
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "registered"})
}
```

### Register route

```go
notifHandler := &handlers.NotificationHandler{}
protected.POST("/notifications/register", notifHandler.RegisterToken)
```

### Flutter: Add `firebase_messaging` (when ready)

```yaml
# pubspec.yaml — add when Firebase project is set up:
# firebase_core: ^2.27.0
# firebase_messaging: ^14.7.0
```

This is a stub — full Firebase integration requires creating a Firebase project and adding `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).

---

## 5. Admin Endpoints — `handlers/admin.go`

Simple admin API for moderation. Protected by a separate admin middleware.

### `middleware/admin.go`

```go
package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/config"
)

// AdminRequired checks for a static admin API key.
// In production, use role-based auth instead.
func AdminRequired(cfg *config.Config) gin.HandlerFunc {
	adminKey := cfg.AdminKey() // add AdminKey to config
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
```

### Update `config/config.go` — add admin key

```go
type Config struct {
	// ... existing fields ...
	adminKey string
}

func (c *Config) AdminKey() string { return c.adminKey }

// In Load():
//   adminKey: getEnv("ADMIN_KEY", "dev_admin_key_change_me"),
```

### `handlers/admin.go`

```go
package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
	"pixelmatch-server/helpers"
)

type AdminHandler struct{}

// ListUsers returns all users (paginated).
func (h *AdminHandler) ListUsers(c *gin.Context) {
	rows, err := database.DB.Query(`
		SELECT uid, email, display_name, character_class, level, league,
		       wins, losses, is_premium, created_at
		FROM users
		ORDER BY created_at DESC
		LIMIT 100
	`)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrQueryFailed)
		return
	}
	defer rows.Close()

	type AdminUser struct {
		UID            string `json:"uid"`
		Email          string `json:"email"`
		DisplayName    string `json:"displayName"`
		CharacterClass string `json:"characterClass"`
		Level          int    `json:"level"`
		League         string `json:"league"`
		Wins           int    `json:"wins"`
		Losses         int    `json:"losses"`
		IsPremium      bool   `json:"isPremium"`
		CreatedAt      string `json:"createdAt"`
	}

	users := []AdminUser{}
	for rows.Next() {
		var u AdminUser
		if err := rows.Scan(&u.UID, &u.Email, &u.DisplayName, &u.CharacterClass,
			&u.Level, &u.League, &u.Wins, &u.Losses, &u.IsPremium, &u.CreatedAt); err != nil {
			continue
		}
		users = append(users, u)
	}

	c.JSON(http.StatusOK, gin.H{"users": users, "count": len(users)})
}

// GetStats returns aggregate game statistics.
func (h *AdminHandler) GetStats(c *gin.Context) {
	var totalUsers, totalBattles, totalMatches int

	database.DB.QueryRow("SELECT COUNT(*) FROM users").Scan(&totalUsers)
	database.DB.QueryRow("SELECT COUNT(*) FROM battles").Scan(&totalBattles)
	database.DB.QueryRow("SELECT COUNT(*) FROM matches").Scan(&totalMatches)

	c.JSON(http.StatusOK, gin.H{
		"totalUsers":   totalUsers,
		"totalBattles": totalBattles,
		"totalMatches": totalMatches,
	})
}

// BanUser sets a user's display name to "[banned]" and clears their profile.
// A proper ban system would use a separate `banned` column.
func (h *AdminHandler) BanUser(c *gin.Context) {
	uid := c.Param("uid")

	_, err := database.DB.Exec(`
		UPDATE users SET display_name = '[banned]', photo_url = ''
		WHERE uid = $1
	`, uid)
	if err != nil {
		helpers.RespondError(c, http.StatusInternalServerError, helpers.ErrUpdateFailed)
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "banned", "uid": uid})
}
```

### Register admin routes in `main.go`

```go
admin := r.Group("/admin")
admin.Use(middleware.AdminRequired(cfg))
{
    adminHandler := &handlers.AdminHandler{}
    admin.GET("/users", adminHandler.ListUsers)
    admin.GET("/stats", adminHandler.GetStats)
    admin.POST("/users/:uid/ban", adminHandler.BanUser)
}
```

---

## 6. Flutter Unit Tests — `test/`

### `test/utils/xp_calculator_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_match/utils/xp_calculator.dart';

void main() {
  group('XpCalculator', () {
    test('xpForLevel returns 0 for level 1', () {
      expect(XpCalculator.xpForLevel(1), 0);
    });

    test('xpForLevel returns 100 for level 2', () {
      expect(XpCalculator.xpForLevel(2), 100);
    });

    test('levelForXp returns 1 for 0 XP', () {
      expect(XpCalculator.levelForXp(0), 1);
    });

    test('levelForXp returns 2 for 100 XP', () {
      expect(XpCalculator.levelForXp(100), 2);
    });

    test('levelForXp returns 1 for negative XP', () {
      expect(XpCalculator.levelForXp(-50), 1);
    });

    test('progressToNextLevel at level start is 0', () {
      expect(XpCalculator.progressToNextLevel(0), 0.0);
    });

    test('progressToNextLevel at 50 XP is 0.5', () {
      expect(XpCalculator.progressToNextLevel(50), 0.5);
    });
  });
}
```

### `test/utils/league_helper_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_match/utils/league_helper.dart';

void main() {
  group('LeagueHelper.leagueForLevel', () {
    test('level 1 is Bronze', () {
      expect(LeagueHelper.leagueForLevel(1), 'Bronze');
    });

    test('level 10 is Bronze', () {
      expect(LeagueHelper.leagueForLevel(10), 'Bronze');
    });

    test('level 11 is Silver', () {
      expect(LeagueHelper.leagueForLevel(11), 'Silver');
    });

    test('level 31 is Gold', () {
      expect(LeagueHelper.leagueForLevel(31), 'Gold');
    });

    test('level 61 is Diamond', () {
      expect(LeagueHelper.leagueForLevel(61), 'Diamond');
    });

    test('level 100 is Legend', () {
      expect(LeagueHelper.leagueForLevel(100), 'Legend');
    });
  });
}
```

### `test/models/user_model_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_match/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('fromJson parses correctly', () {
      final json = {
        'uid': 'abc-123',
        'email': 'test@test.com',
        'displayName': 'TestUser',
        'characterClass': 'Mage',
        'photoUrl': '/uploads/photo.jpg',
        'level': 5,
        'xp': 450,
        'league': 'Bronze',
        'wins': 10,
        'losses': 3,
        'isPremium': false,
        'createdAt': '2024-01-01T00:00:00Z',
      };

      final user = UserModel.fromJson(json);
      expect(user.uid, 'abc-123');
      expect(user.displayName, 'TestUser');
      expect(user.characterClass, 'Mage');
      expect(user.level, 5);
      expect(user.isPremium, false);
    });

    test('isOnboarded returns true when displayName is set', () {
      final user = UserModel.fromJson({
        'uid': 'x', 'email': 'x@x.com', 'displayName': 'Name',
        'characterClass': 'Warrior', 'photoUrl': '', 'level': 1,
        'xp': 0, 'league': 'Bronze', 'wins': 0, 'losses': 0,
        'isPremium': false, 'createdAt': '2024-01-01T00:00:00Z',
      });
      expect(user.isOnboarded, true);
    });

    test('isOnboarded returns false when displayName is empty', () {
      final user = UserModel.fromJson({
        'uid': 'x', 'email': 'x@x.com', 'displayName': '',
        'characterClass': 'Warrior', 'photoUrl': '', 'level': 1,
        'xp': 0, 'league': 'Bronze', 'wins': 0, 'losses': 0,
        'isPremium': false, 'createdAt': '2024-01-01T00:00:00Z',
      });
      expect(user.isOnboarded, false);
    });

    test('copyWith creates modified copy', () {
      final user = UserModel.fromJson({
        'uid': 'x', 'email': 'x@x.com', 'displayName': 'Old',
        'characterClass': 'Warrior', 'photoUrl': '', 'level': 1,
        'xp': 0, 'league': 'Bronze', 'wins': 0, 'losses': 0,
        'isPremium': false, 'createdAt': '2024-01-01T00:00:00Z',
      });

      final updated = user.copyWith(displayName: 'New', level: 10);
      expect(updated.displayName, 'New');
      expect(updated.level, 10);
      expect(updated.uid, 'x'); // unchanged
    });
  });
}
```

---

## 7. Go Unit Tests

### `config/game_constants_test.go`

```go
package config

import "testing"

func TestLeagueForLevel(t *testing.T) {
	tests := []struct {
		level    int
		expected string
	}{
		{1, "Bronze"},
		{10, "Bronze"},
		{11, "Silver"},
		{30, "Silver"},
		{31, "Gold"},
		{60, "Gold"},
		{61, "Diamond"},
		{99, "Diamond"},
		{100, "Legend"},
		{500, "Legend"},
	}

	for _, tt := range tests {
		got := LeagueForLevel(tt.level)
		if got != tt.expected {
			t.Errorf("LeagueForLevel(%d) = %q, want %q", tt.level, got, tt.expected)
		}
	}
}
```

### `handlers/auth_test.go` (integration test with test DB)

```go
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

func setupTestRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	cfg := config.Load() // uses test env
	database.Connect(cfg)

	r := gin.New()
	authHandler := &handlers.AuthHandler{Cfg: cfg}
	r.POST("/api/auth/register", authHandler.Register)
	r.POST("/api/auth/login", authHandler.Login)
	return r
}

func TestRegisterAndLogin(t *testing.T) {
	r := setupTestRouter()

	// Register
	body, _ := json.Marshal(map[string]string{
		"email":    "test_integration@test.com",
		"password": "testpass123",
	})
	req := httptest.NewRequest("POST", "/api/auth/register", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusCreated && w.Code != http.StatusConflict {
		t.Fatalf("Register: expected 201 or 409, got %d", w.Code)
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
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp["token"] == nil {
		t.Fatal("Login response missing token")
	}
}
```

---

## 8. Running Tests

### Flutter

```bash
cd pixel_match
flutter test
```

### Go

```bash
cd pixelmatch-server

# Unit tests (no DB needed)
go test ./config/...

# Integration tests (need running PostgreSQL)
APP_ENV=test go test ./handlers/... -v
```

---

## 9. Verification Checklist

### Premium System
- [ ] `GET /api/premium/status` returns premium status and feature list
- [ ] `POST /api/premium/activate` sets `is_premium = true`
- [ ] Premium users get unlimited swipes (verified in matchmaking)
- [ ] Flutter premium screen shows features and activation button
- [ ] Route `/premium` accessible from profile screen

### Admin Endpoints
- [ ] `GET /admin/users` returns user list (requires `X-Admin-Key` header)
- [ ] `GET /admin/stats` returns aggregate stats
- [ ] `POST /admin/users/:uid/ban` sets display name to `[banned]`
- [ ] All admin routes reject requests without valid admin key

### Environment Config
- [ ] Go server loads `.env.development` in dev mode
- [ ] Go server loads `.env.production` when `APP_ENV=production`
- [ ] `.env*` files are in `.gitignore` (except `.env.development`)

### Push Notifications (Stubs)
- [ ] `ALTER TABLE users ADD COLUMN fcm_token` applied
- [ ] `POST /api/notifications/register` stores FCM token
- [ ] User model has `FcmToken` field (not serialized to client)

### Flutter Tests
- [ ] `flutter test` passes
- [ ] XpCalculator tests pass (7 test cases)
- [ ] LeagueHelper tests pass (6 test cases)
- [ ] UserModel tests pass (4 test cases)

### Go Tests
- [ ] `go test ./config/...` passes (LeagueForLevel)
- [ ] `go test ./handlers/...` passes (register + login integration)

### End-to-End
- [ ] Full flow: register → onboard → battle → match → chat → leaderboard
- [ ] Premium activation works
- [ ] Admin stats reflect real data

---

## What Comes After Phase 15

These are deferred to post-launch:
- **App Store submission:** Build signing, store listings, app icon (1024×1024)
- **RevenueCat integration:** Replace stub activation with real in-app purchases
- **Firebase project:** Full push notification setup with `google-services.json`
- **Nginx + HTTPS:** Production reverse proxy with Let's Encrypt
- **Connection pooling:** PostgreSQL connection pool tuning for production load
- **CI/CD pipeline:** GitHub Actions for automated testing and deployment
- **Admin web panel:** React/Vue dashboard consuming the admin API

## New Files Created in This Phase
```
pixelmatch-server/
├── handlers/premium.go           (premium status & activation)
├── handlers/notification.go      (FCM token registration)
├── handlers/admin.go             (user list, stats, ban)
├── middleware/admin.go            (admin key auth)
├── config/game_constants_test.go  (league tests)
├── handlers/auth_test.go         (integration tests)
├── .env.development              (dev config)
├── .env.production               (production template)

pixel_match/
├── lib/screens/premium/premium_screen.dart
├── test/utils/xp_calculator_test.dart
├── test/utils/league_helper_test.dart
└── test/models/user_model_test.dart
```

## Files Modified
```
pixelmatch-server/
├── config/config.go              (godotenv, AdminKey, Env field)
├── main.go                       (premium, notification, admin routes)
├── models/user.go                (fcm_token field)
├── .gitignore                    (.env* exclusion)

pixel_match/
├── lib/config/routes.dart        (/premium route)
├── lib/screens/profile/profile_screen.dart (premium link)
```
