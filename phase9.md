# Phase 9 — Leaderboard & Stats

## Goal
Build Go endpoints for global/league leaderboard and battle history. Build Flutter screens to display them. When this phase is complete, users can see top players and review past battles.

## Prerequisites
Phases 1–8 complete: users/battles tables populated, XP/level/league correct.

---

## 1. Go: Leaderboard & Battle History Handlers — `handlers/leaderboard.go`

```go
package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"pixelmatch-server/database"
)

type LeaderboardHandler struct{}

func (h *LeaderboardHandler) GetGlobalLeaderboard(c *gin.Context) {
	rows, err := database.DB.Query(`
		SELECT uid, display_name, character_class, level, xp, league, wins
		FROM users
		WHERE display_name != ''
		ORDER BY xp DESC
		LIMIT 50
	`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	entries := []map[string]interface{}{}
	for rows.Next() {
		var uid, name, class_, league string
		var level, xp, wins int
		rows.Scan(&uid, &name, &class_, &level, &xp, &league, &wins)
		entries = append(entries, map[string]interface{}{
			"uid": uid, "displayName": name, "characterClass": class_,
			"level": level, "xp": xp, "league": league, "wins": wins,
		})
	}
	c.JSON(http.StatusOK, gin.H{"entries": entries})
}

func (h *LeaderboardHandler) GetLeagueLeaderboard(c *gin.Context) {
	league := c.Param("league")

	rows, err := database.DB.Query(`
		SELECT uid, display_name, character_class, level, xp, league, wins
		FROM users
		WHERE league = $1 AND display_name != ''
		ORDER BY xp DESC
		LIMIT 50
	`, league)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	entries := []map[string]interface{}{}
	for rows.Next() {
		var uid, name, class_, lg string
		var level, xp, wins int
		rows.Scan(&uid, &name, &class_, &level, &xp, &lg, &wins)
		entries = append(entries, map[string]interface{}{
			"uid": uid, "displayName": name, "characterClass": class_,
			"level": level, "xp": xp, "league": lg, "wins": wins,
		})
	}
	c.JSON(http.StatusOK, gin.H{"entries": entries})
}

func (h *LeaderboardHandler) GetBattleHistory(c *gin.Context) {
	uid := c.GetString("uid")

	rows, err := database.DB.Query(`
		SELECT id, player1_uid, player2_uid, winner_uid,
		       player1_health, player2_health, duration, xp_awarded, created_at
		FROM battles
		WHERE player1_uid = $1 OR player2_uid = $1
		ORDER BY created_at DESC
		LIMIT 30
	`, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "query failed"})
		return
	}
	defer rows.Close()

	battles := []map[string]interface{}{}
	for rows.Next() {
		var id, p1, p2, winner string
		var p1h, p2h, dur, xp int
		var createdAt interface{}
		rows.Scan(&id, &p1, &p2, &winner, &p1h, &p2h, &dur, &xp, &createdAt)
		battles = append(battles, map[string]interface{}{
			"id": id, "player1Uid": p1, "player2Uid": p2, "winnerUid": winner,
			"player1Health": p1h, "player2Health": p2h, "duration": dur,
			"xpAwarded": xp, "createdAt": createdAt,
		})
	}
	c.JSON(http.StatusOK, gin.H{"battles": battles})
}
```

---

## 2. Register Routes in `main.go`

Inside the `protected` group:

```go
lbHandler := &handlers.LeaderboardHandler{}

protected.GET("/leaderboard", lbHandler.GetGlobalLeaderboard)
protected.GET("/leaderboard/:league", lbHandler.GetLeagueLeaderboard)
protected.GET("/battles/history", lbHandler.GetBattleHistory)
```

---

## 3. Flutter: `lib/screens/leaderboard/leaderboard_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../../config/api_client.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../utils/league_helper.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = ['Global', ...AppConstants.leagueRanges.keys];
  Map<String, List<Map<String, dynamic>>> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final global = await ApiClient.get('/api/leaderboard');
    _data['Global'] = List<Map<String, dynamic>>.from(global['entries'] ?? []);

    for (final league in AppConstants.leagueRanges.keys) {
      final resp = await ApiClient.get('/api/leaderboard/$league');
      _data[league] = List<Map<String, dynamic>>.from(resp['entries'] ?? []);
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LEADERBOARD'), centerTitle: true,
          backgroundColor: Colors.transparent, elevation: 0,
          bottom: TabBar(controller: _tabCtrl, isScrollable: true,
              indicatorColor: AppTheme.accentGold,
              tabs: _tabs.map((t) => Tab(text: t.toUpperCase())).toList())),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: _tabs.map((tab) {
        final list = _data[tab] ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No players yet.', style: TextStyle(color: AppTheme.textSecondary)));
        }
        return ListView.builder(padding: const EdgeInsets.all(8), itemCount: list.length,
            itemBuilder: (context, i) {
          final e = list[i];
          final league = e['league'] ?? 'Bronze';
          final color = LeagueHelper.colorForLeague(league);
          return Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: i < 3 ? AppTheme.accentGold.withOpacity(0.08 * (3 - i)) : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(4),
              border: i < 3 ? Border.all(color: AppTheme.accentGold.withOpacity(0.3)) : null),
            child: Row(children: [
              SizedBox(width: 36, child: Text('#${i + 1}', style: TextStyle(
                  fontWeight: FontWeight.bold, color: i == 0 ? AppTheme.accentGold : AppTheme.textPrimary, fontSize: 14))),
              Container(width: 36, height: 36, decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color.withOpacity(0.2)),
                  child: Center(child: Text((e['characterClass'] ?? 'W')[0],
                      style: TextStyle(color: color, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e['displayName'] ?? 'Unknown', style: Theme.of(context).textTheme.bodyLarge),
                Text('$league · Lv ${e['level']}', style: TextStyle(color: color, fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${e['xp']} XP', style: Theme.of(context).textTheme.bodyMedium),
                Text('${e['wins'] ?? 0} W', style: Theme.of(context).textTheme.labelLarge),
              ]),
            ]),
          );
        });
      }).toList()),
    );
  }
}
```

---

## 4. Flutter: `lib/screens/profile/battle_history_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/api_client.dart';
import '../../config/theme.dart';
import '../../models/battle_model.dart';

class BattleHistoryScreen extends StatefulWidget {
  final String uid;
  const BattleHistoryScreen({super.key, required this.uid});
  @override
  State<BattleHistoryScreen> createState() => _BattleHistoryScreenState();
}

class _BattleHistoryScreenState extends State<BattleHistoryScreen> {
  List<BattleModel> _battles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final resp = await ApiClient.get('/api/battles/history');
    final list = resp['battles'] as List? ?? [];
    _battles = list.map((j) => BattleModel.fromJson(j as Map<String, dynamic>)).toList();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BATTLE HISTORY'), centerTitle: true,
          backgroundColor: Colors.transparent, elevation: 0),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _battles.isEmpty
              ? const Center(child: Text('No battles yet.', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _battles.length,
                  itemBuilder: (context, i) {
        final b = _battles[i];
        final won = b.winnerUid == widget.uid;
        final dateStr = DateFormat('MMM d, h:mm a').format(b.createdAt);
        return Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(4),
              border: Border.all(color: (won ? AppTheme.secondaryColor : AppTheme.primaryColor).withOpacity(0.4))),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle,
                color: (won ? AppTheme.secondaryColor : AppTheme.primaryColor).withOpacity(0.2)),
                child: Center(child: Text(won ? 'W' : 'L', style: TextStyle(
                    color: won ? AppTheme.secondaryColor : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold, fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(won ? 'Victory' : 'Defeat', style: Theme.of(context).textTheme.bodyLarge),
              Text(dateStr, style: Theme.of(context).textTheme.bodyMedium),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${won ? "+" : "-"}${b.xpAwarded} XP', style: TextStyle(
                  color: won ? AppTheme.secondaryColor : AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              Text('HP: ${b.player1Uid == widget.uid ? b.player1Health : b.player2Health}',
                  style: Theme.of(context).textTheme.labelLarge),
            ]),
          ]),
        );
      }),
    );
  }
}
```

---

## 5. Add routes

```dart
GoRoute(path: '/leaderboard', builder: (_, s) => const LeaderboardScreen()),
GoRoute(path: '/battle-history/:uid', builder: (_, s) => BattleHistoryScreen(uid: s.pathParameters['uid']!)),
```

---

## 6. Add navigation buttons

Home screen: Leaderboard button. Profile screen: Battle History button.

---

## 7. Verification Checklist

- [ ] `GET /api/leaderboard` returns top 50 users sorted by XP
- [ ] `GET /api/leaderboard/Bronze` filters to Bronze league
- [ ] `GET /api/battles/history` returns user's battles sorted by date
- [ ] Flutter leaderboard screen shows tabs for Global + each league
- [ ] Top 3 entries have gold highlights
- [ ] Battle history shows W/L, date, XP, remaining HP
- [ ] Empty states display correctly

---

## What Phase 10 Expects

Phase 10 is final polish: bottom navigation shell, page transitions, and final Home screen layout. No new Go endpoints needed.
