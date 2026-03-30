# Phase 5 — Battle System (Real-Time Multiplayer)

## Goal
Add real-time 1v1 multiplayer battles using Go WebSocket server. Build the matchmaking queue, synchronized battle state, and Flutter `BattleProvider` / `WebSocketService`. When this phase is complete, two users can queue up, get matched, and fight a live 3-minute battle.

## Prerequisites
Phases 1–4 complete: single-player battle works in Flame, Go server runs with auth.

---

## 1. Go: Battle Model — `models/battle.go`

```go
package models

import "time"

type Battle struct {
	ID            string    `json:"id"`
	Player1UID    string    `json:"player1Uid"`
	Player2UID    string    `json:"player2Uid"`
	WinnerUID     string    `json:"winnerUid"`
	Player1Health int       `json:"player1Health"`
	Player2Health int       `json:"player2Health"`
	Duration      int       `json:"duration"`
	XPAwarded     int       `json:"xpAwarded"`
	CreatedAt     time.Time `json:"createdAt"`
}
```

---

## 2. Go: WebSocket Battle Server — `websocket/battle_ws.go`

```go
package websocket

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	ws "github.com/gorilla/websocket"
	"pixelmatch-server/database"
)

var upgrader = ws.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Player struct {
	Conn           *ws.Conn
	UID            string
	CharacterClass string
}

type BattleRoom struct {
	ID          string
	Players     [2]*Player
	TowerHealth [2]int
	StartTime   time.Time
	Duration    int
	Ended       bool
	mu          sync.Mutex
}

var (
	queue    []*Player
	queueMu  sync.Mutex
	battles  = make(map[string]*BattleRoom)
	battleMu sync.Mutex
)

func init() {
	// Timer loop to check battle timeouts
	go func() {
		ticker := time.NewTicker(1 * time.Second)
		for range ticker.C {
			battleMu.Lock()
			for _, room := range battles {
				room.checkTimer()
			}
			battleMu.Unlock()
		}
	}()
}

func (r *BattleRoom) broadcast(msg map[string]interface{}) {
	data, _ := json.Marshal(msg)
	for _, p := range r.Players {
		if p != nil && p.Conn != nil {
			p.Conn.WriteMessage(ws.TextMessage, data)
		}
	}
}

func (r *BattleRoom) playerIndex(uid string) int {
	for i, p := range r.Players {
		if p != nil && p.UID == uid {
			return i
		}
	}
	return -1
}

func (r *BattleRoom) applyDamage(attackerUID string, damage int) {
	r.mu.Lock()
	defer r.mu.Unlock()

	i := r.playerIndex(attackerUID)
	if i < 0 {
		return
	}
	targetIdx := 1 - i
	r.TowerHealth[targetIdx] -= damage
	if r.TowerHealth[targetIdx] < 0 {
		r.TowerHealth[targetIdx] = 0
	}

	r.broadcast(map[string]interface{}{
		"type":            "damage",
		"attackerUid":     attackerUID,
		"targetIdx":       targetIdx,
		"damage":          damage,
		"healthRemaining": r.TowerHealth[targetIdx],
	})

	if r.TowerHealth[targetIdx] <= 0 {
		r.endBattle(attackerUID)
	}
}

func (r *BattleRoom) endBattle(winnerUID string) {
	if r.Ended {
		return
	}
	r.Ended = true

	r.broadcast(map[string]interface{}{
		"type":        "battle_end",
		"winnerUid":   winnerUID,
		"towerHealth": r.TowerHealth,
	})

	// Save to database
	go saveBattleResult(r, winnerUID)
}

func (r *BattleRoom) checkTimer() {
	r.mu.Lock()
	defer r.mu.Unlock()

	elapsed := time.Since(r.StartTime).Seconds()
	if elapsed >= float64(r.Duration) && !r.Ended {
		winnerUID := r.Players[0].UID
		if r.TowerHealth[1] > r.TowerHealth[0] {
			winnerUID = r.Players[1].UID
		}
		r.endBattle(winnerUID)
	}
}

func saveBattleResult(room *BattleRoom, winnerUID string) {
	_, err := database.DB.Exec(`
		INSERT INTO battles (player1_uid, player2_uid, winner_uid, player1_health, player2_health, duration, xp_awarded)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`, room.Players[0].UID, room.Players[1].UID, winnerUID,
		room.TowerHealth[0], room.TowerHealth[1], room.Duration, 50)
	if err != nil {
		log.Printf("Failed to save battle: %v", err)
	}

	// Award XP
	awardXP(room.Players[0].UID, room.Players[0].UID == winnerUID)
	awardXP(room.Players[1].UID, room.Players[1].UID == winnerUID)
}

func awardXP(uid string, won bool) {
	delta := -20
	winIncr := 0
	lossIncr := 1
	if won {
		delta = 50
		winIncr = 1
		lossIncr = 0
	}

	// Get current XP
	var currentXP int
	database.DB.QueryRow("SELECT xp FROM users WHERE uid = $1", uid).Scan(&currentXP)

	newXP := currentXP + delta
	if newXP < 0 {
		newXP = 0
	}

	newLevel := (newXP / 100) + 1
	newLeague := leagueForLevel(newLevel)

	database.DB.Exec(`
		UPDATE users SET xp = $1, level = $2, league = $3,
		       wins = wins + $4, losses = losses + $5
		WHERE uid = $6
	`, newXP, newLevel, newLeague, winIncr, lossIncr, uid)
}

func leagueForLevel(level int) string {
	switch {
	case level >= 100:
		return "Legend"
	case level >= 61:
		return "Diamond"
	case level >= 31:
		return "Gold"
	case level >= 11:
		return "Silver"
	default:
		return "Bronze"
	}
}

// HandleBattleWS is the Gin handler for WebSocket connections.
func HandleBattleWS(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("WS upgrade error: %v", err)
		return
	}

	var currentPlayer *Player
	var currentRoomID string

	defer func() {
		conn.Close()
		// Remove from queue
		queueMu.Lock()
		for i, p := range queue {
			if p.Conn == conn {
				queue = append(queue[:i], queue[i+1:]...)
				break
			}
		}
		queueMu.Unlock()

		// End battle if in progress
		if currentRoomID != "" {
			battleMu.Lock()
			room, ok := battles[currentRoomID]
			battleMu.Unlock()
			if ok && !room.Ended && currentPlayer != nil {
				// Award win to the other player
				for _, p := range room.Players {
					if p != nil && p.UID != currentPlayer.UID {
						room.endBattle(p.UID)
						break
					}
				}
			}
		}
	}()

	for {
		_, rawMsg, err := conn.ReadMessage()
		if err != nil {
			break
		}

		var msg map[string]interface{}
		if err := json.Unmarshal(rawMsg, &msg); err != nil {
			continue
		}

		msgType, _ := msg["type"].(string)

		switch msgType {
		case "join_queue":
			uid, _ := msg["uid"].(string)
			charClass, _ := msg["characterClass"].(string)
			currentPlayer = &Player{Conn: conn, UID: uid, CharacterClass: charClass}

			queueMu.Lock()
			queue = append(queue, currentPlayer)

			if len(queue) >= 2 {
				p1 := queue[0]
				p2 := queue[1]
				queue = queue[2:]
				queueMu.Unlock()

				room := &BattleRoom{
					ID:          uuid.New().String(),
					Players:     [2]*Player{p1, p2},
					TowerHealth: [2]int{1000, 1000},
					StartTime:   time.Now(),
					Duration:    180,
				}

				battleMu.Lock()
				battles[room.ID] = room
				battleMu.Unlock()

				if p1.UID == currentPlayer.UID || p2.UID == currentPlayer.UID {
					currentRoomID = room.ID
				}

				room.broadcast(map[string]interface{}{
					"type":     "battle_start",
					"battleId": room.ID,
					"players": []map[string]string{
						{"uid": p1.UID, "characterClass": p1.CharacterClass},
						{"uid": p2.UID, "characterClass": p2.CharacterClass},
					},
				})
			} else {
				queueMu.Unlock()
				data, _ := json.Marshal(map[string]string{"type": "waiting"})
				conn.WriteMessage(ws.TextMessage, data)
			}

		case "deploy_troop":
			battleID, _ := msg["battleId"].(string)
			battleMu.Lock()
			room, ok := battles[battleID]
			battleMu.Unlock()
			if !ok {
				continue
			}
			room.broadcast(map[string]interface{}{
				"type": "troop_deployed",
				"uid":  msg["uid"],
				"x":    msg["x"],
				"y":    msg["y"],
			})

		case "tower_hit":
			battleID, _ := msg["battleId"].(string)
			uid, _ := msg["uid"].(string)
			damage := int(msg["damage"].(float64))
			battleMu.Lock()
			room, ok := battles[battleID]
			battleMu.Unlock()
			if !ok {
				continue
			}
			room.applyDamage(uid, damage)

		case "leave_queue":
			queueMu.Lock()
			for i, p := range queue {
				if p.Conn == conn {
					queue = append(queue[:i], queue[i+1:]...)
					break
				}
			}
			queueMu.Unlock()
		}
	}
}
```

---

## 3. Register WebSocket Route in `main.go`

Add BEFORE `r.Run(...)`:

```go
import "pixelmatch-server/websocket"

// WebSocket route — no auth middleware (auth via message)
r.GET("/ws/battle", websocket.HandleBattleWS)
```

---

## 4. Flutter: `lib/services/websocket_service.dart`

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/constants.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void connect() {
    _channel = WebSocketChannel.connect(Uri.parse('${AppConstants.wsBaseUrl}/ws/battle'));
    _channel!.stream.listen(
      (data) => _controller.add(jsonDecode(data as String)),
      onError: (e) => _controller.addError(e),
      onDone: () {},
    );
  }

  void send(Map<String, dynamic> msg) => _channel?.sink.add(jsonEncode(msg));

  void joinQueue(String uid, String characterClass) =>
      send({'type': 'join_queue', 'uid': uid, 'characterClass': characterClass});

  void leaveQueue(String uid) => send({'type': 'leave_queue', 'uid': uid});

  void deployTroop(String battleId, String uid, double x, double y) =>
      send({'type': 'deploy_troop', 'battleId': battleId, 'uid': uid, 'x': x, 'y': y});

  void reportTowerHit(String battleId, String uid, int damage) =>
      send({'type': 'tower_hit', 'battleId': battleId, 'uid': uid, 'damage': damage});

  void dispose() => _channel?.sink.close();
}
```

---

## 5. Flutter: `lib/models/battle_model.dart`

```dart
class BattleModel {
  final String id;
  final String player1Uid;
  final String player2Uid;
  final String winnerUid;
  final int player1Health;
  final int player2Health;
  final int duration;
  final int xpAwarded;
  final DateTime createdAt;

  BattleModel({
    required this.id, required this.player1Uid, required this.player2Uid,
    required this.winnerUid, required this.player1Health, required this.player2Health,
    required this.duration, required this.xpAwarded, required this.createdAt,
  });

  factory BattleModel.fromJson(Map<String, dynamic> json) => BattleModel(
    id: json['id'] ?? '',
    player1Uid: json['player1Uid'] ?? '',
    player2Uid: json['player2Uid'] ?? '',
    winnerUid: json['winnerUid'] ?? '',
    player1Health: json['player1Health'] ?? 0,
    player2Health: json['player2Health'] ?? 0,
    duration: json['duration'] ?? 0,
    xpAwarded: json['xpAwarded'] ?? 0,
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );
}
```

---

## 6. Flutter: `lib/providers/battle_provider.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/websocket_service.dart';

enum BattleState { idle, searching, battleActive, battleEnded }

class BattleProvider extends ChangeNotifier {
  final WebSocketService _ws = WebSocketService();
  StreamSubscription? _sub;

  BattleState state = BattleState.idle;
  String? battleId;
  String? opponentUid;
  String? opponentClass;
  bool? playerWon;
  String? localUid;

  void startSearching(String uid, String characterClass) {
    localUid = uid;
    state = BattleState.searching;
    notifyListeners();
    _ws.connect();
    _sub = _ws.messages.listen(_handleMessage);
    _ws.joinQueue(uid, characterClass);
  }

  void cancelSearch() {
    if (localUid != null) _ws.leaveQueue(localUid!);
    state = BattleState.idle;
    _cleanup();
    notifyListeners();
  }

  void deployTroop(double x, double y) {
    if (battleId == null || localUid == null) return;
    _ws.deployTroop(battleId!, localUid!, x, y);
  }

  void reportHit(int damage) {
    if (battleId == null || localUid == null) return;
    _ws.reportTowerHit(battleId!, localUid!, damage);
  }

  void _handleMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'waiting':
        state = BattleState.searching;
        notifyListeners();
        break;
      case 'battle_start':
        battleId = msg['battleId'];
        final players = msg['players'] as List;
        final opponent = players.firstWhere((p) => p['uid'] != localUid);
        opponentUid = opponent['uid'];
        opponentClass = opponent['characterClass'];
        state = BattleState.battleActive;
        notifyListeners();
        break;
      case 'battle_end':
        playerWon = msg['winnerUid'] == localUid;
        state = BattleState.battleEnded;
        notifyListeners();
        break;
    }
  }

  void reset() {
    state = BattleState.idle;
    battleId = null;
    opponentUid = null;
    opponentClass = null;
    playerWon = null;
    _cleanup();
    notifyListeners();
  }

  void _cleanup() { _sub?.cancel(); _ws.dispose(); }

  @override
  void dispose() { _cleanup(); super.dispose(); }
}
```

---

## 7. Register `BattleProvider` in `lib/app.dart`

```dart
ChangeNotifierProvider(create: (_) => BattleProvider()),
```

---

## 8. Flutter: `lib/screens/battle/battle_queue_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/battle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class BattleQueueScreen extends StatefulWidget {
  const BattleQueueScreen({super.key});
  @override
  State<BattleQueueScreen> createState() => _BattleQueueScreenState();
}

class _BattleQueueScreenState extends State<BattleQueueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      if (user != null) {
        Provider.of<BattleProvider>(context, listen: false)
            .startSearching(user.uid, user.characterClass);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BattleProvider>(builder: (context, bp, _) {
      if (bp.state == BattleState.battleActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/battle'));
      }
      return Scaffold(body: SafeArea(child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          Text('SEARCHING FOR OPPONENT...', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () { bp.cancelSearch(); context.pop(); },
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryColor),
                foregroundColor: AppTheme.primaryColor),
            child: const Text('CANCEL'),
          ),
        ],
      ))));
    });
  }
}
```

---

## 9. Add routes

```dart
GoRoute(path: '/battle/queue', builder: (_, s) => const BattleQueueScreen()),
```

Update Home screen BATTLE button to navigate to `/battle/queue`.

---

## 10. Wire Multiplayer into Battle Screen

In `BattleScreen.initState()`, check if BattleProvider is in active state and wire multiplayer:

```dart
final bp = Provider.of<BattleProvider>(context, listen: false);
if (bp.state == BattleState.battleActive) {
  _game.isMultiplayer = true;
  _game.battleId = bp.battleId;
  _game.localUid = bp.localUid;
  _game.onTroopDeployed = (x, y) => bp.deployTroop(x, y);
  _game.onTowerHit = (damage) => bp.reportHit(damage);
}
```

Listen to BattleProvider messages for remote troop deployments and damage in the battle screen using a listener.

---

## 11. Verification Checklist

- [ ] Go server starts with WebSocket endpoint at `/ws/battle`
- [ ] Player taps BATTLE → queue screen → "SEARCHING FOR OPPONENT"
- [ ] Two clients connect → matched → both receive `battle_start`
- [ ] Troop deployments relay to opponent
- [ ] Tower damage syncs via server
- [ ] Battle ends on tower destruction, both see VICTORY/DEFEAT
- [ ] Battle result saved to PostgreSQL `battles` table
- [ ] XP, level, league updated in `users` table
- [ ] Disconnecting mid-battle gives win to remaining player

---

## What Phase 6 Expects

Phase 6 builds XP progress UI, level-up overlay, and XP bars on profile/home screens. The XP calculation is already done server-side in this phase. Phase 6 adds the Flutter display logic.
