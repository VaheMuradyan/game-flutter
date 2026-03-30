# Phase 2 — Auth & Onboarding

## Goal
Implement user registration and login on the Go backend with JWT authentication. Build the Flutter `AuthService`, `AuthProvider`, and three onboarding screens: Welcome → Class Selection → Profile Setup. When this phase is complete, a user can register, pick a character class, set their display name, and land on the Home screen as an authenticated user with a valid JWT token stored locally.

> **No Firebase.** Auth is handled entirely by the Go server with bcrypt password hashing and JWT tokens.

## Prerequisites
Phase 1 complete: Go server runs, PostgreSQL has all tables, Flutter project compiles.

---

## 1. Go: User Model — `models/user.go`

```go
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
```

---

## 2. Go: JWT Middleware — `middleware/auth.go`

```go
package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"pixelmatch-server/config"
)

func AuthRequired(cfg *config.Config) gin.HandlerFunc {
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
		})

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

		c.Set("uid", claims["uid"])
		c.Next()
	}
}

func GenerateToken(uid string, secret string) (string, error) {
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"uid": uid,
	})
	return token.SignedString([]byte(secret))
}
```

---

## 3. Go: Auth Handlers — `handlers/auth.go`

```go
package handlers

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/middleware"
	"pixelmatch-server/models"
)

type AuthHandler struct {
	Cfg *config.Config
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to hash password"})
		return
	}

	// Insert user
	var user models.User
	err = database.DB.QueryRow(`
		INSERT INTO users (email, password_hash)
		VALUES ($1, $2)
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, req.Email, string(hash)).Scan(
		&user.UID, &user.Email, &user.DisplayName, &user.CharacterClass,
		&user.PhotoUrl, &user.Level, &user.XP, &user.League,
		&user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "email already registered"})
		return
	}

	// Generate JWT
	token, err := middleware.GenerateToken(user.UID, h.Cfg.JWTSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create token"})
		return
	}

	c.JSON(http.StatusCreated, models.AuthResponse{Token: token, User: user})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	var passwordHash string
	err := database.DB.QueryRow(`
		SELECT uid, email, password_hash, display_name, character_class, photo_url,
		       level, xp, league, wins, losses, is_premium, created_at
		FROM users WHERE email = $1
	`, req.Email).Scan(
		&user.UID, &user.Email, &passwordHash, &user.DisplayName,
		&user.CharacterClass, &user.PhotoUrl, &user.Level, &user.XP,
		&user.League, &user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err == sql.ErrNoRows {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "database error"})
		return
	}

	if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	token, err := middleware.GenerateToken(user.UID, h.Cfg.JWTSecret)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create token"})
		return
	}

	c.JSON(http.StatusOK, models.AuthResponse{Token: token, User: user})
}

func (h *AuthHandler) CompleteOnboarding(c *gin.Context) {
	uid := c.GetString("uid")

	var req models.OnboardingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validate character class
	validClasses := map[string]bool{
		"Warrior": true, "Mage": true, "Archer": true,
		"Rogue": true, "Healer": true,
	}
	if !validClasses[req.CharacterClass] {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid character class"})
		return
	}

	var user models.User
	err := database.DB.QueryRow(`
		UPDATE users SET display_name = $1, character_class = $2
		WHERE uid = $3
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, req.DisplayName, req.CharacterClass, uid).Scan(
		&user.UID, &user.Email, &user.DisplayName, &user.CharacterClass,
		&user.PhotoUrl, &user.Level, &user.XP, &user.League,
		&user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "update failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": user})
}

func (h *AuthHandler) GetMe(c *gin.Context) {
	uid := c.GetString("uid")

	var user models.User
	err := database.DB.QueryRow(`
		SELECT uid, email, display_name, character_class, photo_url,
		       level, xp, league, wins, losses, is_premium, created_at
		FROM users WHERE uid = $1
	`, uid).Scan(
		&user.UID, &user.Email, &user.DisplayName, &user.CharacterClass,
		&user.PhotoUrl, &user.Level, &user.XP, &user.League,
		&user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": user})
}
```

---

## 4. Update `main.go` — Add Auth Routes

```go
package main

import (
	"log"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/handlers"
	"pixelmatch-server/middleware"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()
	database.Connect(cfg)

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	r.Static("/uploads", cfg.UploadDir)

	authHandler := &handlers.AuthHandler{Cfg: cfg}

	api := r.Group("/api")
	{
		auth := api.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
		}

		protected := api.Group("")
		protected.Use(middleware.AuthRequired(cfg))
		{
			protected.GET("/me", authHandler.GetMe)
			protected.PUT("/onboarding", authHandler.CompleteOnboarding)
		}
	}

	log.Printf("PixelMatch server starting on :%s", cfg.ServerPort)
	r.Run(":" + cfg.ServerPort)
}
```

---

## 5. Flutter: `lib/models/user_model.dart`

```dart
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String characterClass;
  final String photoUrl;
  final int level;
  final int xp;
  final String league;
  final int wins;
  final int losses;
  final bool isPremium;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.characterClass,
    this.photoUrl = '',
    this.level = 1,
    this.xp = 0,
    this.league = 'Bronze',
    this.wins = 0,
    this.losses = 0,
    this.isPremium = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      displayName: json['displayName'] ?? '',
      characterClass: json['characterClass'] ?? 'Warrior',
      photoUrl: json['photoUrl'] ?? '',
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      league: json['league'] ?? 'Bronze',
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      isPremium: json['isPremium'] ?? false,
    );
  }

  bool get isOnboarded => displayName.isNotEmpty;

  UserModel copyWith({
    String? displayName,
    String? characterClass,
    String? photoUrl,
    int? level,
    int? xp,
    String? league,
    int? wins,
    int? losses,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      characterClass: characterClass ?? this.characterClass,
      photoUrl: photoUrl ?? this.photoUrl,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      league: league ?? this.league,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      isPremium: isPremium,
    );
  }
}
```

---

## 6. Flutter: `lib/services/auth_service.dart`

```dart
import '../config/api_client.dart';
import '../models/user_model.dart';

class AuthService {
  Future<({String token, UserModel user})> register(
      String email, String password) async {
    final resp = await ApiClient.post('/api/auth/register', {
      'email': email,
      'password': password,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return (
      token: resp['token'] as String,
      user: UserModel.fromJson(resp['user'] as Map<String, dynamic>),
    );
  }

  Future<({String token, UserModel user})> login(
      String email, String password) async {
    final resp = await ApiClient.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return (
      token: resp['token'] as String,
      user: UserModel.fromJson(resp['user'] as Map<String, dynamic>),
    );
  }

  Future<UserModel> completeOnboarding(
      String displayName, String characterClass) async {
    final resp = await ApiClient.put('/api/onboarding', {
      'displayName': displayName,
      'characterClass': characterClass,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }

  Future<UserModel> getMe() async {
    final resp = await ApiClient.get('/api/me');
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }
}
```

---

## 7. Flutter: `lib/providers/auth_provider.dart`

```dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../config/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Onboarding transient state
  String _selectedClass = '';

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isOnboarded => _user != null && _user!.isOnboarded;
  String get selectedClass => _selectedClass;

  void setSelectedClass(String cls) {
    _selectedClass = cls;
    notifyListeners();
  }

  /// Try to restore session from saved JWT token.
  Future<void> tryAutoLogin() async {
    final token = await ApiClient.getToken();
    if (token == null) return;
    try {
      _user = await _authService.getMe();
      notifyListeners();
    } catch (_) {
      await ApiClient.clearToken();
    }
  }

  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.register(email, password);
      await ApiClient.saveToken(result.token);
      _user = result.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _authService.login(email, password);
      await ApiClient.saveToken(result.token);
      _user = result.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeOnboarding(String displayName) async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.completeOnboarding(displayName, _selectedClass);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await ApiClient.clearToken();
    _user = null;
    _selectedClass = '';
    notifyListeners();
  }
}
```

---

## 8. Update `lib/app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';

class PixelMatchApp extends StatelessWidget {
  const PixelMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp.router(
        title: 'PixelMatch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
```

---

## 9. Update `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PixelMatchApp());
}
```

---

## 10. Update `lib/config/routes.dart`

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/onboarding/class_selection_screen.dart';
import '../screens/onboarding/profile_setup_screen.dart';
import '../screens/home/home_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final loc = state.matchedLocation;
    final isOnWelcome = loc == '/';
    final isOnOnboarding = loc.startsWith('/onboarding');

    if (!auth.isAuthenticated && !isOnWelcome) return '/';
    if (auth.isAuthenticated && !auth.isOnboarded && !isOnOnboarding) {
      return '/onboarding/class';
    }
    if (auth.isAuthenticated && auth.isOnboarded && (isOnWelcome || isOnOnboarding)) {
      return '/home';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, s) => const WelcomeScreen()),
    GoRoute(path: '/onboarding/class', builder: (_, s) => const ClassSelectionScreen()),
    GoRoute(path: '/onboarding/profile', builder: (_, s) => const ProfileSetupScreen()),
    GoRoute(path: '/home', builder: (_, s) => const HomeScreen()),
  ],
);
```

---

## 11. `lib/screens/onboarding/welcome_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _checkedAutoLogin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedAutoLogin) {
      _checkedAutoLogin = true;
      Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
    }
  }

  void _showAuthSheet(BuildContext context, {required bool isSignUp}) {
    _emailCtrl.clear();
    _passCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isSignUp ? 'CREATE ACCOUNT' : 'LOG IN',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.isLoading) return const CircularProgressIndicator();
                  return Column(
                    children: [
                      if (auth.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(auth.errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final email = _emailCtrl.text.trim();
                            final pass = _passCtrl.text.trim();
                            bool success;
                            if (isSignUp) {
                              success = await auth.register(email, pass);
                            } else {
                              success = await auth.login(email, pass);
                            }
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                              if (auth.isOnboarded) {
                                context.go('/home');
                              } else {
                                context.go('/onboarding/class');
                              }
                            }
                          },
                          child: Text(isSignUp ? 'SIGN UP' : 'LOG IN'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_fire_department,
                    size: 80, color: AppTheme.primaryColor),
                const SizedBox(height: 16),
                Text('PIXELMATCH',
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text('Level up your love life',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showAuthSheet(context, isSignUp: true),
                    child: const Text('SIGN UP'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showAuthSheet(context, isSignUp: false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.secondaryColor),
                      foregroundColor: AppTheme.secondaryColor,
                    ),
                    child: const Text('LOG IN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 12. `lib/screens/onboarding/class_selection_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

class ClassSelectionScreen extends StatelessWidget {
  const ClassSelectionScreen({super.key});

  static const Map<String, Map<String, String>> classInfo = {
    'Warrior': {'style': 'Tank, defensive', 'hint': 'Strong, protective, reliable', 'icon': '🛡️'},
    'Mage': {'style': 'Spells, clever combos', 'hint': 'Intellectual, creative, strategic', 'icon': '🔮'},
    'Archer': {'style': 'Fast, hit-and-run', 'hint': 'Adventurous, free-spirited', 'icon': '🏹'},
    'Rogue': {'style': 'Tricks, sneaky plays', 'hint': 'Mysterious, spontaneous', 'icon': '🗡️'},
    'Healer': {'style': 'Support, team-focused', 'hint': 'Caring, empathetic, nurturing', 'icon': '💚'},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHOOSE YOUR CLASS'),
        centerTitle: true,
        backgroundColor: Colors.transparent, elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Your class hints at your personality',
                    style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: AppConstants.characterClasses.length,
                    itemBuilder: (context, index) {
                      final cls = AppConstants.characterClasses[index];
                      final info = classInfo[cls]!;
                      final isSelected = auth.selectedClass == cls;
                      return GestureDetector(
                        onTap: () => auth.setSelectedClass(cls),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.2)
                                : AppTheme.surfaceColor,
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(info['icon']!, style: const TextStyle(fontSize: 32)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cls, style: Theme.of(context).textTheme.bodyLarge),
                                    const SizedBox(height: 4),
                                    Text(info['style']!, style: Theme.of(context).textTheme.bodyMedium),
                                    Text(info['hint']!,
                                        style: Theme.of(context).textTheme.bodyMedium
                                            ?.copyWith(color: AppTheme.accentGold)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: AppTheme.primaryColor),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.selectedClass.isEmpty
                        ? null
                        : () => context.go('/onboarding/profile'),
                    child: const Text('NEXT'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

---

## 13. `lib/screens/onboarding/profile_setup_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();

  Future<void> _finish() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final success = await auth.completeOnboarding(name);
    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SET UP PROFILE'),
        centerTitle: true,
        backgroundColor: Colors.transparent, elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Photo upload will be added in Phase 3
            CircleAvatar(
              radius: 56,
              backgroundColor: AppTheme.surfaceColor,
              child: const Icon(Icons.person, size: 48, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text('Photo upload coming soon',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'What should others call you?',
              ),
              maxLength: 20,
            ),
            const Spacer(),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _finish,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('START BATTLING'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 14. Verification Checklist

- [ ] `go run main.go` starts the Go server on port 8080
- [ ] `POST /api/auth/register` with `{"email":"test@test.com","password":"123456"}` returns a JWT token and user object
- [ ] `POST /api/auth/login` with same credentials returns a token
- [ ] `GET /api/me` with `Authorization: Bearer <token>` returns the user
- [ ] `PUT /api/onboarding` with `{"displayName":"TestUser","characterClass":"Mage"}` updates the user
- [ ] Flutter app: sign up → class selection → profile setup → Home screen
- [ ] Returning user: login → goes straight to Home (if already onboarded)
- [ ] JWT token is saved to SharedPreferences and restored on app restart

---

## What Phase 3 Expects

Phase 3 builds the Profile screen, photo upload (Flutter → Go → disk), `UserProvider`, and profile card widget. It expects the Go auth endpoints and Flutter auth flow from this phase to work.
