import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';
import '../../game/pixel_match_game.dart';
import '../../providers/battle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/level_up_overlay.dart';
import '../../config/theme.dart';

class BattleScreen extends StatefulWidget {
  final String playerClass;
  const BattleScreen({super.key, required this.playerClass});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late PixelMatchGame _game;
  bool? _playerWon;
  bool _showLevelUp = false;
  int? _newLevel;
  String? _newLeague;
  bool _leagueChanged = false;
  StreamSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _game = PixelMatchGame(playerClass: widget.playerClass)
      ..onBattleEnd = (won) => _onBattleEnd(won);

    final bp = Provider.of<BattleProvider>(context, listen: false);
    if (bp.state == BattleState.battleActive) {
      _game.isMultiplayer = true;
      _game.battleId = bp.battleId;
      _game.localUid = bp.localUid;
      _game.onTroopDeployed = (x, y) => bp.deployTroop(x, y);
      _game.onTowerHit = (damage) => bp.reportHit(damage);

      bp.addListener(_onBattleProviderUpdate);
    }
  }

  Future<void> _onBattleEnd(bool won) async {
    setState(() => _playerWon = won);

    final bp = Provider.of<BattleProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    if (auth.user != null) {
      await userProvider.loadUser(auth.user!.uid);
      final updatedUser = userProvider.user;
      if (updatedUser != null && bp.previousLevel != null) {
        if (updatedUser.level > bp.previousLevel!) {
          setState(() {
            _showLevelUp = true;
            _newLevel = updatedUser.level;
            _newLeague = updatedUser.league;
            _leagueChanged = updatedUser.league != bp.previousLeague;
          });
        }
      }
    }
  }

  void _onBattleProviderUpdate() {
    final bp = Provider.of<BattleProvider>(context, listen: false);
    if (bp.state == BattleState.battleEnded && bp.playerWon != null) {
      _onBattleEnd(bp.playerWon!);
      _game.pauseEngine();
    }
  }

  @override
  void dispose() {
    final bp = Provider.of<BattleProvider>(context, listen: false);
    bp.removeListener(_onBattleProviderUpdate);
    _wsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        GameWidget(game: _game),
        SafeArea(child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop())),
        Positioned(
          bottom: 48,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: AppTheme.accentGold,
            onPressed: () => _game.castSpell(),
            child: const Icon(Icons.auto_fix_high, size: 20),
          ),
        ),
        if (_playerWon != null && !_showLevelUp)
          Container(
            color: Colors.black54,
            child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_playerWon! ? 'VICTORY!' : 'DEFEAT',
                    style: TextStyle(fontSize: 32,
                        color: _playerWon! ? AppTheme.accentGold : AppTheme.primaryColor,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text(_playerWon! ? '+50 XP' : '-20 XP',
                    style: const TextStyle(fontSize: 18, color: Colors.white)),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: () => Navigator.of(context).pop(),
                    child: const Text('BACK TO ARENA')),
              ],
            )),
          ),
        if (_showLevelUp)
          LevelUpOverlay(
            newLevel: _newLevel!,
            newLeague: _newLeague!,
            leagueChanged: _leagueChanged,
            onDismiss: () => setState(() => _showLevelUp = false),
          ),
      ]),
    );
  }
}
