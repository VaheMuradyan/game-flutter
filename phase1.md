# Phase 1 — Project Setup

## Goal
Initialize the Flutter project, establish folder structure, install all dependencies, set up the Go backend project with PostgreSQL, and create the database schema. When this phase is complete, the Flutter app compiles and runs showing a welcome screen, the Go API server starts and connects to PostgreSQL, and all tables exist.

> **NOTE:** This project does NOT use Firebase. The backend is a self-hosted Go (Golang) REST API + WebSocket server with PostgreSQL. There is NO Google Play or App Store setup in any phase — publishing is deferred to after the app is fully built and tested. All 10 phases focus only on building a working app.

---

## 1. Server Prerequisites (Ubuntu)


---

## 2. PostgreSQL Database Setup

```bash
# Create database and user
sudo -u postgres psql <<EOF
CREATE USER pixelmatch WITH PASSWORD 'pixelmatch_secret_2024';
CREATE DATABASE pixelmatch OWNER pixelmatch;
GRANT ALL PRIVILEGES ON DATABASE pixelmatch TO pixelmatch;
EOF
```

---

## 3. Database Schema

Connect and create all tables:

```bash
sudo -u postgres psql -d pixelmatch
```

```sql
-- Users table
CREATE TABLE users (
    uid UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    display_name VARCHAR(20) NOT NULL DEFAULT '',
    character_class VARCHAR(20) NOT NULL DEFAULT 'Warrior',
    photo_url TEXT NOT NULL DEFAULT '',
    level INT NOT NULL DEFAULT 1,
    xp INT NOT NULL DEFAULT 0,
    league VARCHAR(20) NOT NULL DEFAULT 'Bronze',
    wins INT NOT NULL DEFAULT 0,
    losses INT NOT NULL DEFAULT 0,
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Battles table
CREATE TABLE battles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player1_uid UUID NOT NULL REFERENCES users(uid),
    player2_uid UUID NOT NULL REFERENCES users(uid),
    winner_uid UUID NOT NULL REFERENCES users(uid),
    player1_health INT NOT NULL DEFAULT 0,
    player2_health INT NOT NULL DEFAULT 0,
    duration INT NOT NULL DEFAULT 180,
    xp_awarded INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Likes table
CREATE TABLE likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    liker_uid UUID NOT NULL REFERENCES users(uid),
    liked_uid UUID NOT NULL REFERENCES users(uid),
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE(liker_uid, liked_uid)
);

-- Matches table (when two people mutually like)
CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_uid UUID NOT NULL REFERENCES users(uid),
    user2_uid UUID NOT NULL REFERENCES users(uid),
    chat_id UUID NOT NULL,
    matched_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Chats table
CREATE TABLE chats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id),
    last_message TEXT NOT NULL DEFAULT '',
    last_message_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Messages table
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID NOT NULL REFERENCES chats(id),
    sender_uid UUID NOT NULL REFERENCES users(uid),
    text TEXT NOT NULL,
    message_type VARCHAR(20) NOT NULL DEFAULT 'text',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_battles_player1 ON battles(player1_uid);
CREATE INDEX idx_battles_player2 ON battles(player2_uid);
CREATE INDEX idx_likes_liker ON likes(liker_uid);
CREATE INDEX idx_likes_liked ON likes(liked_uid);
CREATE INDEX idx_matches_user1 ON matches(user1_uid);
CREATE INDEX idx_matches_user2 ON matches(user2_uid);
CREATE INDEX idx_messages_chat ON messages(chat_id);
CREATE INDEX idx_users_level ON users(level);
CREATE INDEX idx_users_league ON users(league);
CREATE INDEX idx_users_xp ON users(xp DESC);
```

---

## 4. Go Backend Project Structure

Create the backend project:

```bash
mkdir -p ~/pixelmatch-server
cd ~/pixelmatch-server
go mod init pixelmatch-server
```

Folder structure:

```
pixelmatch-server/
├── go.mod
├── go.sum
├── main.go
├── config/
│   └── config.go
├── models/
│   ├── user.go
│   ├── battle.go
│   ├── match.go
│   └── message.go
├── handlers/
│   ├── auth.go
│   ├── user.go
│   ├── battle.go
│   ├── matchmaking.go
│   ├── chat.go
│   └── leaderboard.go
├── middleware/
│   └── auth.go
├── database/
│   └── db.go
├── websocket/
│   └── battle_ws.go
└── uploads/
    └── (profile photos stored here)
```

```bash
mkdir -p config models handlers middleware database websocket uploads
```

---

## 5. Go Dependencies

```bash
cd ~/pixelmatch-server

# Web framework
go get github.com/gin-gonic/gin

# PostgreSQL driver
go get github.com/lib/pq

# JWT for auth tokens
go get github.com/golang-jwt/jwt/v5

# UUID
go get github.com/google/uuid

# WebSocket
go get github.com/gorilla/websocket

# Password hashing
go get golang.org/x/crypto/bcrypt

# Environment variables
go get github.com/joho/godotenv
```

---

## 6. `config/config.go`

```go
package config

import (
	"os"
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
}

func Load() *Config {
	return &Config{
		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnv("DB_PORT", "5432"),
		DBUser:     getEnv("DB_USER", "pixelmatch"),
		DBPassword: getEnv("DB_PASSWORD", "pixelmatch_secret_2024"),
		DBName:     getEnv("DB_NAME", "pixelmatch"),
		JWTSecret:  getEnv("JWT_SECRET", "pixelmatch_jwt_secret_change_me"),
		ServerPort: getEnv("SERVER_PORT", "8080"),
		UploadDir:  getEnv("UPLOAD_DIR", "./uploads"),
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
```

---

## 7. `database/db.go`

```go
package database

import (
	"database/sql"
	"fmt"
	"log"

	_ "github.com/lib/pq"
	"pixelmatch-server/config"
)

var DB *sql.DB

func Connect(cfg *config.Config) {
	connStr := fmt.Sprintf(
		"host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		cfg.DBHost, cfg.DBPort, cfg.DBUser, cfg.DBPassword, cfg.DBName,
	)

	var err error
	DB, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	if err = DB.Ping(); err != nil {
		log.Fatalf("Failed to ping database: %v", err)
	}

	DB.SetMaxOpenConns(25)
	DB.SetMaxIdleConns(5)

	log.Println("Connected to PostgreSQL")
}
```

---

## 8. `main.go` (starter)

```go
package main

import (
	"log"
	"pixelmatch-server/config"
	"pixelmatch-server/database"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()
	database.Connect(cfg)

	r := gin.Default()

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok", "service": "pixelmatch"})
	})

	// Static file serving for profile photos
	r.Static("/uploads", cfg.UploadDir)

	// Routes will be added in later phases
	// Phase 2: POST /api/auth/register, POST /api/auth/login
	// Phase 3: GET/PUT /api/users/:uid
	// Phase 5: WebSocket /ws/battle
	// Phase 7: POST /api/likes, GET /api/matches
	// Phase 8: GET/POST /api/chats/:chatId/messages
	// Phase 9: GET /api/leaderboard

	log.Printf("PixelMatch server starting on :%s", cfg.ServerPort)
	r.Run(":" + cfg.ServerPort)
}
```

---

## 9. Flutter Project

```bash
cd ~
flutter create --org com.pixelmatch pixel_match
cd pixel_match
```

### Folder structure inside `lib/`:

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── theme.dart
│   ├── routes.dart
│   ├── constants.dart
│   └── api_client.dart
├── models/
│   ├── user_model.dart
│   ├── battle_model.dart
│   ├── match_model.dart
│   └── message_model.dart
├── services/
│   ├── auth_service.dart
│   ├── user_service.dart
│   ├── battle_service.dart
│   ├── matchmaking_service.dart
│   ├── chat_service.dart
│   └── websocket_service.dart
├── providers/
│   ├── auth_provider.dart
│   ├── user_provider.dart
│   ├── battle_provider.dart
│   ├── match_provider.dart
│   └── chat_provider.dart
├── screens/
│   ├── onboarding/
│   │   ├── welcome_screen.dart
│   │   ├── class_selection_screen.dart
│   │   └── profile_setup_screen.dart
│   ├── home/
│   │   ├── home_shell.dart
│   │   └── home_screen.dart
│   ├── battle/
│   │   ├── battle_queue_screen.dart
│   │   └── battle_screen.dart
│   ├── browse/
│   │   └── match_browser_screen.dart
│   ├── match/
│   │   └── match_celebration_screen.dart
│   ├── chat/
│   │   ├── chat_list_screen.dart
│   │   └── chat_screen.dart
│   ├── profile/
│   │   ├── profile_screen.dart
│   │   └── battle_history_screen.dart
│   └── leaderboard/
│       └── leaderboard_screen.dart
├── widgets/
│   ├── pixel_button.dart
│   ├── pixel_card.dart
│   ├── level_badge.dart
│   ├── health_bar.dart
│   ├── level_up_overlay.dart
│   └── swipe_card.dart
├── game/
│   ├── pixel_match_game.dart
│   ├── class_colors.dart
│   └── components/
│       ├── tower.dart
│       ├── troop.dart
│       ├── spell.dart
│       └── arena.dart
└── utils/
    ├── xp_calculator.dart
    ├── league_helper.dart
    └── validators.dart
```

Create all directories:

```bash
cd ~/pixel_match
mkdir -p lib/config lib/models lib/services lib/providers
mkdir -p lib/screens/onboarding lib/screens/home lib/screens/battle
mkdir -p lib/screens/browse lib/screens/match lib/screens/chat
mkdir -p lib/screens/profile lib/screens/leaderboard
mkdir -p lib/widgets lib/game/components lib/utils
mkdir -p assets/images assets/sprites assets/audio assets/fonts
```

---

## 10. `pubspec.yaml`

Replace entirely:

```yaml
name: pixel_match
description: Level up your love life. Only the worthy match.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # State management
  provider: ^6.1.2

  # Game engine
  flame: ^1.14.0

  # Routing
  go_router: ^13.2.0

  # Networking
  http: ^1.2.1
  web_socket_channel: ^2.4.0

  # Image handling
  image_picker: ^1.0.7
  cached_network_image: ^3.3.1

  # UI helpers
  flutter_card_swiper: ^7.0.0
  shimmer: ^3.0.0
  google_fonts: ^6.1.0
  flutter_animate: ^4.5.0

  # Local storage (for JWT token)
  shared_preferences: ^2.2.2

  # Utilities
  uuid: ^4.3.3
  intl: ^0.19.0
  url_launcher: ^6.2.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true

  assets:
    - assets/images/
    - assets/sprites/
    - assets/audio/
    - assets/fonts/
```

Run:

```bash
flutter pub get
```

---

## 11. `lib/config/constants.dart`

```dart
class AppConstants {
  // Server — change this to your server's IP
  static const String apiBaseUrl = 'http://YOUR_SERVER_IP:8080';
  static const String wsBaseUrl = 'ws://YOUR_SERVER_IP:8080';

  // XP
  static const int xpPerWin = 50;
  static const int xpPerLoss = -20;
  static const int startingXp = 0;
  static const int startingLevel = 1;

  // Battle
  static const int battleDurationSeconds = 180;
  static const int startingTowerHealth = 1000;
  static const double manaRegenPerSecond = 1.0;
  static const int maxMana = 10;

  // Leagues
  static const Map<String, List<int>> leagueRanges = {
    'Bronze': [1, 10],
    'Silver': [11, 30],
    'Gold': [31, 60],
    'Diamond': [61, 99],
    'Legend': [100, 9999],
  };

  // Character classes
  static const List<String> characterClasses = [
    'Warrior',
    'Mage',
    'Archer',
    'Rogue',
    'Healer',
  ];

  // Swipe limits (free tier)
  static const int dailyFreeSwipes = 20;
}
```

---

## 12. `lib/config/api_client.dart`

Centralized HTTP client that attaches the JWT token to every request.

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiClient {
  static const _tokenKey = 'jwt_token';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final resp = await http.get(url, headers: await _headers());
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final resp = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> put(
      String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final resp = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Upload a file via multipart POST. Returns the response body.
  static Future<Map<String, dynamic>> uploadFile(
      String path, String filePath, String fieldName) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final request = http.MultipartRequest('POST', url);
    final token = await getToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    final streamResp = await request.send();
    final resp = await http.Response.fromStream(streamResp);
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
}
```

---

## 13. `lib/config/theme.dart`

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFFF6B6B);
  static const Color secondaryColor = Color(0xFF4ECDC4);
  static const Color backgroundColor = Color(0xFF1A1A2E);
  static const Color surfaceColor = Color(0xFF16213E);
  static const Color accentGold = Color(0xFFFFD93D);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0B0);

  static const Color bronzeColor = Color(0xFFCD7F32);
  static const Color silverColor = Color(0xFFC0C0C0);
  static const Color goldColor = Color(0xFFFFD700);
  static const Color diamondColor = Color(0xFFB9F2FF);
  static const Color legendColor = Color(0xFFFF4500);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: surfaceColor,
        ),
        textTheme: GoogleFonts.pressStart2pTextTheme(
          const TextTheme(
            headlineLarge: TextStyle(fontSize: 24, color: textPrimary),
            headlineMedium: TextStyle(fontSize: 18, color: textPrimary),
            bodyLarge: TextStyle(fontSize: 14, color: textPrimary),
            bodyMedium: TextStyle(fontSize: 12, color: textSecondary),
            labelLarge: TextStyle(fontSize: 10, color: textPrimary),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        cardTheme: CardTheme(
          color: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}
```

---

## 14. `lib/config/routes.dart`

```dart
import 'package:go_router/go_router.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/home/home_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
```

---

## 15. `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PixelMatchApp());
}
```

---

## 16. `lib/app.dart`

```dart
import 'package:flutter/material.dart';
import 'config/theme.dart';
import 'config/routes.dart';

class PixelMatchApp extends StatelessWidget {
  const PixelMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PixelMatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
```

---

## 17. Stub Screens

### `lib/screens/onboarding/welcome_screen.dart`

```dart
import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('PixelMatch — Welcome')),
    );
  }
}
```

### `lib/screens/home/home_screen.dart`

```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('PixelMatch — Home')),
    );
  }
}
```

---

## 18. Start Everything

### Terminal 1 — Go server:

```bash
cd ~/pixelmatch-server
go run main.go
```

Verify: `curl http://localhost:8080/health` should return `{"status":"ok","service":"pixelmatch"}`

### Terminal 2 — Flutter app:

```bash
cd ~/pixel_match
flutter pub get
flutter run
```

Should show "PixelMatch — Welcome".

---

## 19. Verification Checklist

- [ ] PostgreSQL running, `pixelmatch` database exists with all 6 tables and indexes
- [ ] `go run main.go` starts without errors, health endpoint responds
- [ ] `flutter pub get` succeeds
- [ ] `flutter run` launches and shows "PixelMatch — Welcome"
- [ ] All directories in both projects exist
- [ ] `ApiClient` compiles (test by importing in main.dart temporarily)

---

## What Phase 2 Expects

Phase 2 implements auth: Go handlers for register/login with JWT, the Flutter `AuthService` using `ApiClient`, `AuthProvider`, and the three onboarding screens. It assumes the Go server, database, and Flutter project are all working from this phase.
