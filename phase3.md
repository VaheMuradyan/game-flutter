# Phase 3 — Profile System

## Goal
Build the Go user profile endpoints (get user, update profile, upload photo), the Flutter `UserProvider`, profile screen, profile card widget, and photo upload. When this phase is complete, users see a rich profile page showing their level, league badge, class, stats, and can change their name/photo.

> **No Firebase.** Photos are uploaded to the Go server and stored on disk in the `uploads/` folder. URLs point to `http://SERVER_IP:8080/uploads/filename.jpg`.

## Prerequisites
Phases 1–2 complete: Go server with auth, PostgreSQL with tables, Flutter auth flow works.

---

## 1. Go: User Handlers — `handlers/user.go`

```go
package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"pixelmatch-server/config"
	"pixelmatch-server/database"
	"pixelmatch-server/models"
)

type UserHandler struct {
	Cfg *config.Config
}

func (h *UserHandler) GetUser(c *gin.Context) {
	uid := c.Param("uid")

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

func (h *UserHandler) UpdateProfile(c *gin.Context) {
	uid := c.GetString("uid")

	var req struct {
		DisplayName string `json:"displayName"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var user models.User
	err := database.DB.QueryRow(`
		UPDATE users SET display_name = $1 WHERE uid = $2
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, req.DisplayName, uid).Scan(
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

func (h *UserHandler) UploadPhoto(c *gin.Context) {
	uid := c.GetString("uid")

	file, err := c.FormFile("photo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no file uploaded"})
		return
	}

	// Create uploads dir if not exists
	os.MkdirAll(h.Cfg.UploadDir, 0755)

	// Save with unique name
	ext := filepath.Ext(file.Filename)
	filename := fmt.Sprintf("%s_%s%s", uid, uuid.New().String()[:8], ext)
	savePath := filepath.Join(h.Cfg.UploadDir, filename)

	if err := c.SaveUploadedFile(file, savePath); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save file"})
		return
	}

	photoUrl := fmt.Sprintf("/uploads/%s", filename)

	// Update database
	var user models.User
	err = database.DB.QueryRow(`
		UPDATE users SET photo_url = $1 WHERE uid = $2
		RETURNING uid, email, display_name, character_class, photo_url,
		          level, xp, league, wins, losses, is_premium, created_at
	`, photoUrl, uid).Scan(
		&user.UID, &user.Email, &user.DisplayName, &user.CharacterClass,
		&user.PhotoUrl, &user.Level, &user.XP, &user.League,
		&user.Wins, &user.Losses, &user.IsPremium, &user.CreatedAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "db update failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"user": user})
}

// Fetch users at the caller's level or below, excluding the caller.
func (h *UserHandler) GetEligibleProfiles(c *gin.Context) {
	uid := c.GetString("uid")

	rows, err := database.DB.Query(`
		SELECT uid, email, display_name, character_class, photo_url,
		       level, xp, league, wins, losses, is_premium, created_at
		FROM users
		WHERE uid != $1
		  AND level <= (SELECT level FROM users WHERE uid = $1)
		  AND display_name != ''
		ORDER BY RANDOM()
		LIMIT 50
	`, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	users := []models.User{}
	for rows.Next() {
		var u models.User
		rows.Scan(&u.UID, &u.Email, &u.DisplayName, &u.CharacterClass,
			&u.PhotoUrl, &u.Level, &u.XP, &u.League,
			&u.Wins, &u.Losses, &u.IsPremium, &u.CreatedAt)
		users = append(users, u)
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}
```

---

## 2. Register User Routes in `main.go`

Add inside the `protected` group:

```go
userHandler := &handlers.UserHandler{Cfg: cfg}

protected.GET("/users/:uid", userHandler.GetUser)
protected.PUT("/users/profile", userHandler.UpdateProfile)
protected.POST("/users/photo", userHandler.UploadPhoto)
protected.GET("/users/eligible", userHandler.GetEligibleProfiles)
```

---

## 3. Flutter: `lib/services/user_service.dart`

```dart
import '../config/api_client.dart';
import '../models/user_model.dart';

class UserService {
  Future<UserModel> getUser(String uid) async {
    final resp = await ApiClient.get('/api/users/$uid');
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }

  Future<UserModel> updateDisplayName(String name) async {
    final resp = await ApiClient.put('/api/users/profile', {
      'displayName': name,
    });
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }

  Future<UserModel> uploadPhoto(String filePath) async {
    final resp = await ApiClient.uploadFile('/api/users/photo', filePath, 'photo');
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return UserModel.fromJson(resp['user'] as Map<String, dynamic>);
  }

  Future<List<UserModel>> getEligibleProfiles() async {
    final resp = await ApiClient.get('/api/users/eligible');
    if (resp.containsKey('error')) throw Exception(resp['error']);
    final list = resp['users'] as List;
    return list.map((j) => UserModel.fromJson(j as Map<String, dynamic>)).toList();
  }
}
```

---

## 4. Flutter: `lib/providers/user_provider.dart`

```dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

class UserProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  UserModel? _user;

  UserModel? get user => _user;

  Future<void> loadUser(String uid) async {
    _user = await _userService.getUser(uid);
    notifyListeners();
  }

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    _user = await _userService.updateDisplayName(name);
    notifyListeners();
  }

  Future<void> uploadPhoto(String filePath) async {
    _user = await _userService.uploadPhoto(filePath);
    notifyListeners();
  }
}
```

---

## 5. Register `UserProvider` in `lib/app.dart`

Add to `MultiProvider.providers`:

```dart
ChangeNotifierProvider(create: (_) => UserProvider()),
```

Import: `import 'providers/user_provider.dart';`

---

## 6. Flutter: `lib/utils/league_helper.dart`

```dart
import '../config/constants.dart';
import '../config/theme.dart';
import 'package:flutter/material.dart';

class LeagueHelper {
  static String leagueForLevel(int level) {
    for (final entry in AppConstants.leagueRanges.entries) {
      if (level >= entry.value[0] && level <= entry.value[1]) return entry.key;
    }
    return 'Bronze';
  }

  static Color colorForLeague(String league) {
    switch (league) {
      case 'Silver': return AppTheme.silverColor;
      case 'Gold': return AppTheme.goldColor;
      case 'Diamond': return AppTheme.diamondColor;
      case 'Legend': return AppTheme.legendColor;
      default: return AppTheme.bronzeColor;
    }
  }
}
```

---

## 7. Flutter: `lib/widgets/level_badge.dart`

```dart
import 'package:flutter/material.dart';
import '../utils/league_helper.dart';

class LevelBadge extends StatelessWidget {
  final int level;
  final String league;
  final double size;

  const LevelBadge({super.key, required this.level, required this.league, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final color = LeagueHelper.colorForLeague(league);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text('$level',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: size * 0.35)),
      ),
    );
  }
}
```

---

## 8. Flutter: `lib/widgets/pixel_card.dart`

```dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import 'level_badge.dart';

class PixelCard extends StatelessWidget {
  final UserModel user;
  final bool showStats;

  const PixelCard({super.key, required this.user, this.showStats = false});

  String _fullPhotoUrl(String photoUrl) {
    if (photoUrl.isEmpty) return '';
    if (photoUrl.startsWith('http')) return photoUrl;
    return '${AppConstants.apiBaseUrl}$photoUrl';
  }

  @override
  Widget build(BuildContext context) {
    final url = _fullPhotoUrl(user.photoUrl);
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: url.isNotEmpty
                  ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppTheme.surfaceColor),
                      errorWidget: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          Expanded(
            flex: showStats ? 2 : 1,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(user.displayName,
                        style: Theme.of(context).textTheme.bodyLarge, overflow: TextOverflow.ellipsis)),
                    LevelBadge(level: user.level, league: user.league, size: 36),
                  ]),
                  const SizedBox(height: 4),
                  Text('${user.characterClass} · ${user.league}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (showStats) ...[
                    const SizedBox(height: 8),
                    Text(
                      'W ${user.wins}  L ${user.losses}  '
                      'WR ${user.wins + user.losses > 0 ? ((user.wins / (user.wins + user.losses)) * 100).toStringAsFixed(1) : 0}%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
      color: AppTheme.surfaceColor,
      child: const Center(child: Icon(Icons.person, size: 64, color: AppTheme.textSecondary)));
}
```

---

## 9. Flutter: `lib/screens/profile/profile_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/level_badge.dart';
import '../../utils/league_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      Provider.of<UserProvider>(context, listen: false).loadUser(auth.user!.uid);
    }
  }

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null) {
      await Provider.of<UserProvider>(context, listen: false).uploadPhoto(picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(builder: (context, up, _) {
      final user = up.user;
      if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

      final leagueColor = LeagueHelper.colorForLeague(user.league);
      final winRate = user.wins + user.losses > 0
          ? ((user.wins / (user.wins + user.losses)) * 100).toStringAsFixed(1) : '0.0';
      final photoUrl = user.photoUrl.isNotEmpty
          ? (user.photoUrl.startsWith('http') ? user.photoUrl : '${AppConstants.apiBaseUrl}${user.photoUrl}')
          : '';

      return Scaffold(
        appBar: AppBar(title: const Text('PROFILE'), centerTitle: true,
            backgroundColor: Colors.transparent, elevation: 0,
            actions: [
              IconButton(icon: const Icon(Icons.logout), onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).signOut();
              }),
            ]),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            GestureDetector(
              onTap: _changePhoto,
              child: CircleAvatar(radius: 56, backgroundColor: AppTheme.surfaceColor,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty ? const Icon(Icons.camera_alt, size: 32, color: AppTheme.textSecondary) : null),
            ),
            const SizedBox(height: 12),
            Text(user.displayName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('${user.characterClass} · ${user.league}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: leagueColor)),
            const SizedBox(height: 24),
            LevelBadge(level: user.level, league: user.league, size: 72),
            const SizedBox(height: 8),
            Text('Level ${user.level}', style: Theme.of(context).textTheme.bodyLarge),
            Text('${user.xp} XP', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _stat(context, '${user.wins}', 'WINS'),
              _stat(context, '${user.losses}', 'LOSSES'),
              _stat(context, '$winRate%', 'WIN RATE'),
            ]),
          ]),
        ),
      );
    });
  }

  Widget _stat(BuildContext context, String value, String label) => Column(children: [
    Text(value, style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 4),
    Text(label, style: Theme.of(context).textTheme.labelLarge),
  ]);
}
```

---

## 10. Add Profile route to `lib/config/routes.dart`

```dart
GoRoute(path: '/profile', builder: (_, s) => const ProfileScreen()),
```

Import: `import '../screens/profile/profile_screen.dart';`

---

## 11. Verification Checklist

- [ ] `GET /api/users/:uid` returns user data
- [ ] `PUT /api/users/profile` updates display name
- [ ] `POST /api/users/photo` accepts multipart file, saves to `uploads/`, updates photo_url in DB
- [ ] Photo is accessible at `http://SERVER_IP:8080/uploads/filename.jpg`
- [ ] Flutter Profile screen shows photo, name, class, league, level, XP, wins, losses, win rate
- [ ] Tapping avatar opens image picker, uploads to Go server, profile updates
- [ ] `PixelCard` renders correctly

---

## What Phase 4 Expects

Phase 4 integrates the Flame game engine for the battle arena with pixel-art towers and troops. It expects `UserModel` and `UserProvider` to exist so it can read the player's character class.
