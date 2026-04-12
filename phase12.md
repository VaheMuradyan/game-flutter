# Phase 12 — Flutter Cleanup & Code Quality

## Goal
Eliminate duplicated code, fix the API client to check HTTP status codes, remove unused dependencies, add environment-based server configuration, integrate the orphaned Spell component into battles, upgrade chat from HTTP polling to WebSocket, and write a proper project README. When this phase is complete, the Flutter codebase is clean, DRY, and production-ready.

> **NO NEW FEATURES.** This phase is purely about code quality and maintainability.

## Prerequisites
Phase 11 complete: Go backend is hardened and the API contract is stable.

---

## 1. Shared Photo URL Helper — `lib/utils/photo_url_helper.dart`

The pattern `photoUrl.startsWith('http') ? photoUrl : '${AppConstants.apiBaseUrl}$photoUrl'` appears in 4 files. Extract it.

```dart
import '../config/constants.dart';

class PhotoUrlHelper {
  /// Returns the full URL for a user photo.
  /// Server-stored paths like `/uploads/abc.jpg` get the API base prepended.
  /// External URLs (already starting with http) pass through unchanged.
  static String fullUrl(String photoUrl) {
    if (photoUrl.isEmpty) return '';
    if (photoUrl.startsWith('http')) return photoUrl;
    return '${AppConstants.apiBaseUrl}$photoUrl';
  }
}
```

Now update the 4 files that inline this logic:

**`lib/screens/home/home_screen.dart`** — replace the inline URL construction in the `CircleAvatar`:

```dart
import '../../utils/photo_url_helper.dart';

// In build(), replace:
//   backgroundImage: user.photoUrl.isNotEmpty
//       ? NetworkImage(user.photoUrl.startsWith('http')
//           ? user.photoUrl : '${AppConstants.apiBaseUrl}${user.photoUrl}')
//       : null,
// With:
backgroundImage: user.photoUrl.isNotEmpty
    ? NetworkImage(PhotoUrlHelper.fullUrl(user.photoUrl))
    : null,
```

**`lib/screens/profile/profile_screen.dart`** — same change in the profile avatar.

**`lib/screens/chat/chat_list_screen.dart`** — same change in the chat list avatar.

**`lib/widgets/pixel_card.dart`** — replace the `_fullPhotoUrl` method:

```dart
import '../utils/photo_url_helper.dart';

// Remove the private _fullPhotoUrl method entirely.
// Replace all calls to _fullPhotoUrl(url) with PhotoUrlHelper.fullUrl(url)
```

---

## 2. Consolidate `leagueForLevel()` — Remove Duplicate

`leagueForLevel()` is implemented identically in both `lib/utils/xp_calculator.dart` (line 17) and `lib/utils/league_helper.dart` (line 6).

**Keep it in `league_helper.dart`** (since that file also has `colorForLeague` — they belong together).

**Remove from `xp_calculator.dart`:**

```dart
// lib/utils/xp_calculator.dart — FINAL VERSION (leagueForLevel removed)
class XpCalculator {
  static int xpForLevel(int level) => level <= 1 ? 0 : (level - 1) * 100;

  static int levelForXp(int xp) => xp < 0 ? 1 : (xp ~/ 100) + 1;

  static double progressToNextLevel(int xp) {
    final currentLevel = levelForXp(xp);
    final currentThreshold = xpForLevel(currentLevel);
    final nextThreshold = xpForLevel(currentLevel + 1);
    final range = nextThreshold - currentThreshold;
    if (range <= 0) return 0;
    return (xp - currentThreshold) / range;
  }
}
```

Then grep for `XpCalculator.leagueForLevel` across all `.dart` files and replace with `LeagueHelper.leagueForLevel`, adding the import where needed.

---

## 3. HTTP Status Code Checking — `lib/config/api_client.dart`

The current client never checks `resp.statusCode` — a 500 response gets blindly `jsonDecode`d and may crash.

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

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

  /// Parses response body and throws [ApiException] on non-2xx status.
  static Map<String, dynamic> _handleResponse(http.Response resp) {
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body;
    }
    final msg = body['error'] as String? ?? 'Request failed (${resp.statusCode})';
    throw ApiException(resp.statusCode, msg);
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final resp = await http.get(url, headers: await _headers());
    return _handleResponse(resp);
  }

  static Future<Map<String, dynamic>> post(
      String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final resp = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(resp);
  }

  static Future<Map<String, dynamic>> put(
      String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final resp = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _handleResponse(resp);
  }

  static Future<Map<String, dynamic>> uploadFile(
      String path, String filePath, String fieldName) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$path');
    final request = http.MultipartRequest('POST', url);
    final token = await getToken();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));
    final streamResp = await request.send();
    final resp = await http.Response.fromStream(streamResp);
    return _handleResponse(resp);
  }
}
```

Update callers (providers/services) to catch `ApiException` where needed — most already handle the `error` key in responses, so wrap their try/catch to also handle `ApiException`.

---

## 4. Remove Unused Dependencies — `pubspec.yaml`

**Remove `flutter_card_swiper`** — the project uses a manual `SwipeCard` widget instead. Confirmed: never imported in any `.dart` file.

```yaml
# DELETE this line from pubspec.yaml:
#   flutter_card_swiper: ^7.0.0
```

Run `flutter pub get` after removal to update `pubspec.lock`.

**Keep `intl`** — it IS used in `battle_history_screen.dart` for `DateFormat`.

---

## 5. Remove Unused Field — `lib/providers/chat_provider.dart`

The `_currentChatId` field is set on line 29 and cleared on line 37 but never read for any logic. Remove it.

```dart
// lib/providers/chat_provider.dart — changes only

// REMOVE these lines:
//   // ignore: unused_field
//   String? _currentChatId;

// In startListening(), REMOVE:
//   _currentChatId = chatId;

// In stopListening(), REMOVE:
//   _currentChatId = null;
```

---

## 6. Environment-Based Configuration — `lib/config/environment.dart`

Replace the hardcoded `YOUR_SERVER_IP` placeholder with build-time configuration using `--dart-define`.

```dart
class Environment {
  static const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'http://localhost:8080',
  );

  static const String wsHost = String.fromEnvironment(
    'WS_HOST',
    defaultValue: 'ws://localhost:8080',
  );
}
```

**Update `lib/config/constants.dart`:**

```dart
import 'environment.dart';

class AppConstants {
  // Server — configured via --dart-define at build time
  static String get apiBaseUrl => Environment.apiHost;
  static String get wsBaseUrl => Environment.wsHost;

  // ... rest unchanged
}
```

**Usage at build time:**

```bash
# Development (local)
flutter run --dart-define=API_HOST=http://10.0.2.2:8080 --dart-define=WS_HOST=ws://10.0.2.2:8080

# Production
flutter run --dart-define=API_HOST=https://api.pixelmatch.com --dart-define=WS_HOST=wss://api.pixelmatch.com
```

---

## 7. Integrate Spell Component into Battle

`lib/game/components/spell.dart` exists with full render/update logic but is never imported. Add spell casting to the battle — costs 5 mana, does 100 damage directly to enemy tower.

**Update `lib/game/pixel_match_game.dart`:**

```dart
import 'components/spell.dart';

class PixelMatchGame extends FlameGame with TapCallbacks {
  // ... existing fields ...

  static const double spellCost = 5.0;
  void Function(int damage)? onSpellHit;

  // Add a method to cast a spell (called from battle screen UI)
  void castSpell() {
    if (mana >= spellCost) {
      mana -= spellCost;
      final spell = Spell(
        target: enemyTower.position.clone(),
        color: ClassColors.forClass(playerClass),
        damage: 100,
        onImpact: (position, damage) {
          enemyTower.health -= damage;
          if (enemyTower.health < 0) enemyTower.health = 0;
          onSpellHit?.call(damage);
          if (enemyTower.isDestroyed) {
            onBattleEnd?.call(true);
            pauseEngine();
          }
        },
      )..position = playerTower.position.clone();
      add(spell);
    }
  }

  // ... rest unchanged ...
}
```

**Update `lib/screens/battle/battle_screen.dart`** — add a spell button next to the game widget:

```dart
// In the battle UI, add a button:
Positioned(
  bottom: 48,
  right: 16,
  child: FloatingActionButton(
    mini: true,
    backgroundColor: AppTheme.accentGold,
    onPressed: () => game.castSpell(),
    child: const Icon(Icons.auto_fix_high, size: 20),
  ),
),
```

---

## 8. Upgrade Chat to WebSocket — Go Endpoint

Add a lightweight chat WebSocket endpoint to the Go server so Flutter doesn't need 2-second HTTP polling.

**Go: Add to `websocket/chat_ws.go`:**

```go
package websocket

import (
	"encoding/json"
	"log/slog"
	"sync"

	"github.com/gin-gonic/gin"
	ws "github.com/gorilla/websocket"
)

var (
	chatRooms   = make(map[string][]*ws.Conn)
	chatRoomsMu sync.Mutex
)

func HandleChatWS(c *gin.Context) {
	chatID := c.Param("chatId")
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		slog.Error("chat WS upgrade error", "err", err)
		return
	}

	chatRoomsMu.Lock()
	chatRooms[chatID] = append(chatRooms[chatID], conn)
	chatRoomsMu.Unlock()

	defer func() {
		conn.Close()
		chatRoomsMu.Lock()
		conns := chatRooms[chatID]
		for i, c := range conns {
			if c == conn {
				chatRooms[chatID] = append(conns[:i], conns[i+1:]...)
				break
			}
		}
		if len(chatRooms[chatID]) == 0 {
			delete(chatRooms, chatID)
		}
		chatRoomsMu.Unlock()
	}()

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			break
		}
		// Broadcast to all connections in this chat room
		chatRoomsMu.Lock()
		for _, c := range chatRooms[chatID] {
			if c != conn {
				c.WriteMessage(ws.TextMessage, raw)
			}
		}
		chatRoomsMu.Unlock()
	}
}

// BroadcastToChat sends a message to all WebSocket connections in a chat room.
// Called from the HTTP SendMessage handler after saving to DB.
func BroadcastToChat(chatID string, msg interface{}) {
	data, err := json.Marshal(msg)
	if err != nil {
		return
	}
	chatRoomsMu.Lock()
	defer chatRoomsMu.Unlock()
	for _, c := range chatRooms[chatID] {
		c.WriteMessage(ws.TextMessage, data)
	}
}
```

**Go: Register route in `main.go`:**

```go
r.GET("/ws/chat/:chatId", websocket.HandleChatWS)
```

**Flutter: Update `lib/providers/chat_provider.dart`** to use WebSocket with HTTP polling fallback:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/message_model.dart';
import '../models/match_model.dart';
import '../services/chat_service.dart';
import '../config/api_client.dart';
import '../config/constants.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();

  List<MatchModel> _matches = [];
  List<MessageModel> _messages = [];
  WebSocketChannel? _channel;
  StreamSubscription? _wsSub;

  List<MatchModel> get matches => _matches;
  List<MessageModel> get messages => _messages;

  Future<void> loadMatches() async {
    final resp = await ApiClient.get('/api/matches');
    final list = resp['matches'] as List;
    _matches = list.map((j) => MatchModel.fromJson(j as Map<String, dynamic>)).toList();
    notifyListeners();
  }

  void startListening(String chatId) {
    _loadMessages(chatId);
    _connectWebSocket(chatId);
  }

  void _connectWebSocket(String chatId) {
    final uri = Uri.parse('${AppConstants.wsBaseUrl}/ws/chat/$chatId');
    _channel = WebSocketChannel.connect(uri);
    _wsSub = _channel!.stream.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        final msg = MessageModel.fromJson(json);
        _messages.add(msg);
        notifyListeners();
      },
      onError: (_) {},
      onDone: () {},
    );
  }

  void stopListening() {
    _wsSub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  Future<void> _loadMessages(String chatId) async {
    _messages = await _chatService.getMessages(chatId);
    notifyListeners();
  }

  Future<void> sendText(String chatId, String text) async {
    await _chatService.sendMessage(chatId, text);
  }

  Future<void> sendEmote(String chatId, String emoteCode) async {
    await _chatService.sendMessage(chatId, emoteCode, type: 'emote');
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
```

**Update `handlers/chat.go` `SendMessage`** — after inserting the message, broadcast via WebSocket:

```go
// After the INSERT ... RETURNING, add:
websocket.BroadcastToChat(chatID, msg)
```

---

## 9. Replace README — `pixel_match/README.md`

```markdown
# PixelMatch

A real-time multiplayer dating + tower-defense battle game built with Flutter and Go.

## Architecture

- **Frontend:** Flutter (Flame game engine, Provider state management, GoRouter)
- **Backend:** Go (Gin HTTP, Gorilla WebSocket, PostgreSQL)
- **Auth:** JWT tokens stored in SharedPreferences

## Running Locally

### Backend

```bash
cd pixelmatch-server
export DB_HOST=localhost DB_USER=pixelmatch DB_PASSWORD=pixelmatch_secret_2024 DB_NAME=pixelmatch
go run main.go
```

### Frontend

```bash
cd pixel_match
flutter pub get
flutter run --dart-define=API_HOST=http://10.0.2.2:8080 --dart-define=WS_HOST=ws://10.0.2.2:8080
```

## Features

- Register / login with email + password (JWT)
- Choose character class (Warrior, Mage, Archer, Rogue, Healer)
- Real-time 1v1 tower-defense battles via WebSocket
- Swipe-based profile matching (Tinder-style)
- In-app chat with text and pixel emotes
- XP / level / league progression system
- Global and league leaderboards
- Profile photo upload

## Project Structure

```
pixel_match/lib/
├── config/       # Theme, routes, constants, API client
├── game/         # Flame engine: arena, tower, troop, spell
├── models/       # Data classes (User, Battle, Match, Message)
├── providers/    # State management (Auth, User, Battle, Match, Chat)
├── screens/      # UI screens (onboarding, home, battle, browse, chat, profile, leaderboard)
├── services/     # API communication layer
├── utils/        # XP calculator, league helper, photo URL helper
└── widgets/      # Reusable components (PixelCard, LevelBadge, HealthBar, SwipeCard)
```
```

---

## 10. Verification Checklist

### Deduplication
- [ ] Photo URL construction exists only in `PhotoUrlHelper.fullUrl()` — no inline URL building in screens
- [ ] `leagueForLevel()` exists only in `LeagueHelper` — removed from `XpCalculator`
- [ ] `_currentChatId` removed from `ChatProvider`

### API Client
- [ ] `ApiClient.get()` throws `ApiException` on 4xx/5xx status codes
- [ ] `ApiClient.post()` throws `ApiException` on 4xx/5xx status codes
- [ ] `ApiClient.put()` throws `ApiException` on 4xx/5xx status codes
- [ ] `ApiClient.uploadFile()` throws `ApiException` on 4xx/5xx status codes

### Dependencies
- [ ] `flutter_card_swiper` removed from `pubspec.yaml`
- [ ] `flutter pub get` succeeds with no errors

### Environment Config
- [ ] App connects to server using `--dart-define=API_HOST=...` value
- [ ] Default `localhost:8080` works without explicit define
- [ ] No hardcoded `YOUR_SERVER_IP` remains

### Spell Integration
- [ ] Spell button visible on battle screen
- [ ] Casting a spell costs 5 mana
- [ ] Spell projectile flies to enemy tower and deals 100 damage
- [ ] Tower destruction via spell triggers battle end

### Chat WebSocket
- [ ] New Go endpoint `/ws/chat/:chatId` accepts WebSocket connections
- [ ] Messages sent by one user appear instantly for the other (no 2-second delay)
- [ ] Chat still works if WebSocket fails (HTTP fallback via initial message load)

### README
- [ ] `pixel_match/README.md` describes the project, setup, and features

### End-to-End
- [ ] `flutter analyze` passes with no errors
- [ ] App compiles and runs on Android emulator
- [ ] All existing functionality still works

---

## What Phase 13 Expects
A clean, maintainable Flutter codebase with no duplicated code, proper error handling, environment configuration, and real-time chat. Ready for UI design iteration with Google Stitch MCP.

## New Files Created in This Phase
```
pixel_match/lib/
├── utils/photo_url_helper.dart   (shared photo URL builder)
├── config/environment.dart       (build-time env config)
pixelmatch-server/
├── websocket/chat_ws.go          (chat WebSocket endpoint)
```

## Files Modified
```
pixel_match/lib/
├── config/api_client.dart        (added ApiException + status checking)
├── config/constants.dart         (use Environment for URLs)
├── providers/chat_provider.dart  (WebSocket instead of polling, removed unused field)
├── utils/xp_calculator.dart      (removed duplicate leagueForLevel)
├── game/pixel_match_game.dart    (spell integration)
├── screens/battle/battle_screen.dart (spell button)
├── screens/home/home_screen.dart (use PhotoUrlHelper)
├── screens/profile/profile_screen.dart (use PhotoUrlHelper)
├── screens/chat/chat_list_screen.dart (use PhotoUrlHelper)
├── widgets/pixel_card.dart       (use PhotoUrlHelper)
├── pubspec.yaml                  (removed flutter_card_swiper)
└── README.md                     (project-specific)
pixelmatch-server/
├── main.go                       (register /ws/chat/:chatId)
├── handlers/chat.go              (broadcast after send)
```
