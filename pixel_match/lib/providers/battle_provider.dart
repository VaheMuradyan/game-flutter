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
  int? previousLevel;
  String? previousLeague;

  void setPreBattleStats(int level, String league) {
    previousLevel = level;
    previousLeague = league;
  }

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
    previousLevel = null;
    previousLeague = null;
    _cleanup();
    notifyListeners();
  }

  void _cleanup() { _sub?.cancel(); _ws.dispose(); }

  @override
  void dispose() { _cleanup(); super.dispose(); }
}
