# Phase 7 — Match Browser (Swiping UI)

## Goal
Build the Tinder-style swipe screen. Users swipe right (like) or left (pass) on profiles at their level or below. Likes are stored in PostgreSQL. If both users liked each other, a match + chat are created. Daily free swipe limit enforced.

## Prerequisites
Phases 1–6 complete: `GET /api/users/eligible` exists, XP/level/league are accurate.

---

## 1. Go: Matchmaking Handlers — `handlers/matchmaking.go`

```go
package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"pixelmatch-server/database"
	"pixelmatch-server/models"
)

type MatchmakingHandler struct{}

func (h *MatchmakingHandler) RecordLike(c *gin.Context) {
	uid := c.GetString("uid")

	var req struct {
		LikedUID string `json:"likedUid" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if uid == req.LikedUID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "cannot like yourself"})
		return
	}

	// Check daily limit (20 free swipes)
	var todayCount int
	database.DB.QueryRow(`
		SELECT COUNT(*) FROM likes
		WHERE liker_uid = $1 AND created_at >= CURRENT_DATE
	`, uid).Scan(&todayCount)

	// Check if premium
	var isPremium bool
	database.DB.QueryRow("SELECT is_premium FROM users WHERE uid = $1", uid).Scan(&isPremium)

	if !isPremium && todayCount >= 20 {
		c.JSON(http.StatusForbidden, gin.H{"error": "daily swipe limit reached"})
		return
	}

	// Insert the like
	_, err := database.DB.Exec(`
		INSERT INTO likes (liker_uid, liked_uid) VALUES ($1, $2)
		ON CONFLICT (liker_uid, liked_uid) DO NOTHING
	`, uid, req.LikedUID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to record like"})
		return
	}

	// Check for mutual like
	var reverseExists bool
	database.DB.QueryRow(`
		SELECT EXISTS(SELECT 1 FROM likes WHERE liker_uid = $1 AND liked_uid = $2)
	`, req.LikedUID, uid).Scan(&reverseExists)

	if reverseExists {
		// Check if already matched
		var alreadyMatched bool
		database.DB.QueryRow(`
			SELECT EXISTS(
				SELECT 1 FROM matches
				WHERE (user1_uid = $1 AND user2_uid = $2)
				   OR (user1_uid = $2 AND user2_uid = $1)
			)
		`, uid, req.LikedUID).Scan(&alreadyMatched)

		if !alreadyMatched {
			chatID := uuid.New().String()
			matchID := uuid.New().String()

			database.DB.Exec(`
				INSERT INTO matches (id, user1_uid, user2_uid, chat_id)
				VALUES ($1, $2, $3, $4)
			`, matchID, uid, req.LikedUID, chatID)

			database.DB.Exec(`
				INSERT INTO chats (id, match_id) VALUES ($1, $2)
			`, chatID, matchID)

			c.JSON(http.StatusOK, gin.H{
				"match":  true,
				"chatId": chatID,
			})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"match": false})
}

func (h *MatchmakingHandler) GetSwipesToday(c *gin.Context) {
	uid := c.GetString("uid")
	var count int
	database.DB.QueryRow(`
		SELECT COUNT(*) FROM likes WHERE liker_uid = $1 AND created_at >= CURRENT_DATE
	`, uid).Scan(&count)

	var isPremium bool
	database.DB.QueryRow("SELECT is_premium FROM users WHERE uid = $1", uid).Scan(&isPremium)

	limit := 20
	if isPremium {
		limit = 9999
	}

	c.JSON(http.StatusOK, gin.H{
		"count":     count,
		"limit":     limit,
		"remaining": max(0, limit-count),
	})
}

func (h *MatchmakingHandler) GetMatches(c *gin.Context) {
	uid := c.GetString("uid")

	rows, err := database.DB.Query(`
		SELECT m.id, m.user1_uid, m.user2_uid, m.chat_id, m.matched_at,
		       u.uid, u.display_name, u.character_class, u.photo_url,
		       u.level, u.league, u.wins, u.losses
		FROM matches m
		JOIN users u ON u.uid = CASE WHEN m.user1_uid = $1 THEN m.user2_uid ELSE m.user1_uid END
		WHERE m.user1_uid = $1 OR m.user2_uid = $1
		ORDER BY m.matched_at DESC
	`, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	type MatchWithUser struct {
		models.Match
		OtherUser models.User `json:"otherUser"`
	}

	matches := []MatchWithUser{}
	for rows.Next() {
		var m models.Match
		var u models.User
		rows.Scan(&m.ID, &m.User1UID, &m.User2UID, &m.ChatID, &m.MatchedAt,
			&u.UID, &u.DisplayName, &u.CharacterClass, &u.PhotoUrl,
			&u.Level, &u.League, &u.Wins, &u.Losses)
		matches = append(matches, MatchWithUser{Match: m, OtherUser: u})
	}

	c.JSON(http.StatusOK, gin.H{"matches": matches})
}

func (h *MatchmakingHandler) GetLikedUIDs(c *gin.Context) {
	uid := c.GetString("uid")

	rows, err := database.DB.Query("SELECT liked_uid FROM likes WHERE liker_uid = $1", uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	uids := []string{}
	for rows.Next() {
		var likedUID string
		rows.Scan(&likedUID)
		uids = append(uids, likedUID)
	}
	c.JSON(http.StatusOK, gin.H{"likedUids": uids})
}

func max(a, b int) int {
	if a > b { return a }
	return b
}
```

---

## 2. Go: Match Model — `models/match.go`

```go
package models

import "time"

type Match struct {
	ID        string    `json:"id"`
	User1UID  string    `json:"user1Uid"`
	User2UID  string    `json:"user2Uid"`
	ChatID    string    `json:"chatId"`
	MatchedAt time.Time `json:"matchedAt"`
}
```

---

## 3. Register Matchmaking Routes in `main.go`

Inside the `protected` group:

```go
matchHandler := &handlers.MatchmakingHandler{}

protected.POST("/likes", matchHandler.RecordLike)
protected.GET("/likes/today", matchHandler.GetSwipesToday)
protected.GET("/likes/uids", matchHandler.GetLikedUIDs)
protected.GET("/matches", matchHandler.GetMatches)
```

---

## 4. Flutter: `lib/services/matchmaking_service.dart`

```dart
import '../config/api_client.dart';
import '../models/user_model.dart';

class MatchmakingService {
  Future<({bool isMatch, String? chatId})> recordLike(String likedUid) async {
    final resp = await ApiClient.post('/api/likes', {'likedUid': likedUid});
    if (resp.containsKey('error')) throw Exception(resp['error']);
    return (
      isMatch: resp['match'] == true,
      chatId: resp['chatId'] as String?,
    );
  }

  Future<({int count, int limit, int remaining})> getSwipesToday() async {
    final resp = await ApiClient.get('/api/likes/today');
    return (
      count: resp['count'] as int,
      limit: resp['limit'] as int,
      remaining: resp['remaining'] as int,
    );
  }

  Future<Set<String>> getLikedUids() async {
    final resp = await ApiClient.get('/api/likes/uids');
    final list = resp['likedUids'] as List;
    return list.map((e) => e as String).toSet();
  }
}
```

---

## 5. Flutter: `lib/models/match_model.dart`

```dart
import 'user_model.dart';

class MatchModel {
  final String id;
  final String user1Uid;
  final String user2Uid;
  final String chatId;
  final DateTime matchedAt;
  final UserModel? otherUser;

  MatchModel({required this.id, required this.user1Uid, required this.user2Uid,
      required this.chatId, required this.matchedAt, this.otherUser});

  factory MatchModel.fromJson(Map<String, dynamic> json) => MatchModel(
    id: json['id'] ?? '',
    user1Uid: json['user1Uid'] ?? '',
    user2Uid: json['user2Uid'] ?? '',
    chatId: json['chatId'] ?? '',
    matchedAt: DateTime.tryParse(json['matchedAt'] ?? '') ?? DateTime.now(),
    otherUser: json['otherUser'] != null
        ? UserModel.fromJson(json['otherUser']) : null,
  );

  String otherUid(String myUid) => user1Uid == myUid ? user2Uid : user1Uid;
}
```

---

## 6. Flutter: `lib/providers/match_provider.dart`

```dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/matchmaking_service.dart';
import '../config/constants.dart';

class MatchProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  final MatchmakingService _matchmakingService = MatchmakingService();

  List<UserModel> _profiles = [];
  int _currentIndex = 0;
  int _remainingSwipes = AppConstants.dailyFreeSwipes;
  bool _loading = false;
  bool? _lastSwipeWasMatch;
  String? _lastMatchChatId;

  List<UserModel> get profiles => _profiles;
  int get currentIndex => _currentIndex;
  int get remainingSwipes => _remainingSwipes;
  bool get loading => _loading;
  bool get hasProfiles => _currentIndex < _profiles.length;
  UserModel? get currentProfile => hasProfiles ? _profiles[_currentIndex] : null;
  bool? get lastSwipeWasMatch => _lastSwipeWasMatch;
  String? get lastMatchChatId => _lastMatchChatId;

  Future<void> loadProfiles() async {
    _loading = true;
    _lastSwipeWasMatch = null;
    notifyListeners();

    final all = await _userService.getEligibleProfiles();
    final liked = await _matchmakingService.getLikedUids();
    _profiles = all.where((u) => !liked.contains(u.uid)).toList();
    _profiles.shuffle();
    _currentIndex = 0;

    final swipeInfo = await _matchmakingService.getSwipesToday();
    _remainingSwipes = swipeInfo.remaining;

    _loading = false;
    notifyListeners();
  }

  Future<bool> like(String theirUid) async {
    _remainingSwipes--;
    final result = await _matchmakingService.recordLike(theirUid);
    _lastSwipeWasMatch = result.isMatch;
    _lastMatchChatId = result.chatId;
    _currentIndex++;
    notifyListeners();
    return result.isMatch;
  }

  void pass() {
    _lastSwipeWasMatch = null;
    _lastMatchChatId = null;
    _currentIndex++;
    notifyListeners();
  }

  void clearMatchFlag() {
    _lastSwipeWasMatch = null;
    _lastMatchChatId = null;
    notifyListeners();
  }
}
```

---

## 7. Register `MatchProvider` in `lib/app.dart`

```dart
ChangeNotifierProvider(create: (_) => MatchProvider()),
```

---

## 8. Flutter: `lib/widgets/swipe_card.dart`

```dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'pixel_card.dart';

class SwipeCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  const SwipeCard({super.key, required this.user, required this.onSwipeRight, required this.onSwipeLeft});
  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  double _dx = 0, _dy = 0, _angle = 0;

  void _onPanUpdate(DragUpdateDetails d) => setState(() {
    _dx += d.delta.dx; _dy += d.delta.dy; _angle = _dx / 300 * 0.3;
  });

  void _onPanEnd(DragEndDetails d) {
    if (_dx > 100) widget.onSwipeRight();
    else if (_dx < -100) widget.onSwipeLeft();
    setState(() { _dx = 0; _dy = 0; _angle = 0; });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate, onPanEnd: _onPanEnd,
      child: Transform.translate(offset: Offset(_dx, _dy),
        child: Transform.rotate(angle: _angle, child: Stack(children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.65,
              child: PixelCard(user: widget.user, showStats: true)),
          if (_dx > 30) Positioned(top: 24, left: 24, child: _indicator('LIKE', Colors.green)),
          if (_dx < -30) Positioned(top: 24, right: 24, child: _indicator('NOPE', Colors.red)),
        ]))),
    );
  }

  Widget _indicator(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(border: Border.all(color: color, width: 3), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
  );
}
```

---

## 9. Flutter: `lib/screens/browse/match_browser_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../../config/theme.dart';
import '../../widgets/swipe_card.dart';

class MatchBrowserScreen extends StatefulWidget {
  const MatchBrowserScreen({super.key});
  @override
  State<MatchBrowserScreen> createState() => _MatchBrowserScreenState();
}

class _MatchBrowserScreenState extends State<MatchBrowserScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MatchProvider>(context, listen: false).loadProfiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BROWSE'), centerTitle: true,
          backgroundColor: Colors.transparent, elevation: 0),
      body: Consumer<MatchProvider>(builder: (context, mp, _) {
        if (mp.loading) return const Center(child: CircularProgressIndicator());

        if (mp.remainingSwipes <= 0) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('Daily swipe limit reached!', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('Come back tomorrow or go Premium.', style: Theme.of(context).textTheme.bodyMedium),
          ]));
        }

        if (!mp.hasProfiles) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('No more profiles at your level.', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('Win battles to level up and see more!', style: Theme.of(context).textTheme.bodyMedium),
          ]));
        }

        final profile = mp.currentProfile!;

        return Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${mp.remainingSwipes} swipes remaining',
                  style: Theme.of(context).textTheme.labelLarge)),
          const SizedBox(height: 8),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SwipeCard(key: ValueKey(profile.uid), user: profile,
                onSwipeRight: () async {
                  final isMatch = await mp.like(profile.uid);
                  if (isMatch && context.mounted) _showMatchDialog(context, profile.displayName);
                },
                onSwipeLeft: () => mp.pass()))),
          Padding(padding: const EdgeInsets.all(24), child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(heroTag: 'pass', backgroundColor: Colors.redAccent,
                  onPressed: () => mp.pass(), child: const Icon(Icons.close)),
              FloatingActionButton(heroTag: 'like', backgroundColor: Colors.greenAccent,
                  onPressed: () async {
                    final isMatch = await mp.like(profile.uid);
                    if (isMatch && context.mounted) _showMatchDialog(context, profile.displayName);
                  }, child: const Icon(Icons.favorite)),
            ],
          )),
        ]);
      }),
    );
  }

  void _showMatchDialog(BuildContext context, String name) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      title: Text("IT'S A MATCH!", style: TextStyle(color: AppTheme.accentGold)),
      content: Text('You and $name liked each other!'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('KEEP SWIPING')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('SAY HI')),
      ],
    ));
  }
}
```

---

## 10. Add route and nav button

Route: `GoRoute(path: '/browse', builder: (_, s) => const MatchBrowserScreen())`

Home screen button:
```dart
OutlinedButton.icon(icon: const Icon(Icons.favorite), label: const Text('BROWSE MATCHES'),
    style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primaryColor),
        foregroundColor: AppTheme.primaryColor),
    onPressed: () => context.push('/browse')),
```

---

## 11. Verification Checklist

- [ ] `POST /api/likes` records a like, returns `{match: false}` for one-sided
- [ ] Mutual like returns `{match: true, chatId: "..."}` and creates `matches` + `chats` rows
- [ ] `GET /api/likes/today` returns correct count/limit/remaining
- [ ] `GET /api/users/eligible` filters by level
- [ ] Flutter: swipe right → like recorded → match dialog if mutual
- [ ] Swipe left → next card, no like recorded
- [ ] Daily limit enforced — limit message after 20 swipes
- [ ] Already-liked profiles hidden
- [ ] Empty state prompts leveling up

---

## What Phase 8 Expects

Phase 8 builds chat: Go message endpoints, Flutter chat screens, pixel emotes. It expects `matches` and `chats` tables to be populated from this phase.
