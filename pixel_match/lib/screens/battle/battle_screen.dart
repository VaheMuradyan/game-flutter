import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';
import '../../game/pixel_match_game.dart';
import '../../game/battle_audio.dart';
import '../../services/audio_service.dart';
import '../../game/class_colors.dart';
import '../../providers/battle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/level_up_overlay.dart';
import '../../widgets/tower_health_bar.dart';
import '../../widgets/troop_card.dart';
import '../../widgets/battle_result_screen.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

class BattleScreen extends StatefulWidget {
  final String playerClass;
  const BattleScreen({super.key, required this.playerClass});
  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late PixelMatchGame _game;
  final GlobalKey _gameKey = GlobalKey();
  bool? _playerWon;
  int _xpDelta = 0;
  bool _showLevelUp = false;
  int? _newLevel;
  String? _newLeague;
  bool _leagueChanged = false;
  StreamSubscription? _wsSub;
  late final List<TroopCardData> _cachedCards;

  @override
  void initState() {
    super.initState();
    BattleAudio.battleStart();
    _cachedCards = _buildCards();
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
    if (_playerWon != null) return;
    setState(() {
      _playerWon = won;
      _xpDelta = won ? AppConstants.xpPerWin : AppConstants.xpPerLoss;
    });

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
    AudioService.instance.reset();
    super.dispose();
  }

  void _handleCardDrop(Offset globalOffset) {
    final renderBox =
        _gameKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final local = renderBox.globalToLocal(globalOffset);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > renderBox.size.width ||
        local.dy > renderBox.size.height) {
      return;
    }
    _game.deployTroopAt(local.dx, local.dy);
  }

  List<TroopCardData> _buildCards() => [
        TroopCardData(
          label: 'Warrior',
          cost: 3,
          icon: Icons.gavel,
          color: ClassColors.forClass('Warrior'),
        ),
        TroopCardData(
          label: 'Mage',
          cost: 3,
          icon: Icons.auto_awesome,
          color: ClassColors.forClass('Mage'),
        ),
        TroopCardData(
          label: 'Archer',
          cost: 3,
          icon: Icons.my_location,
          color: ClassColors.forClass('Archer'),
        ),
        TroopCardData(
          label: 'Rogue',
          cost: 3,
          icon: Icons.flash_on,
          color: ClassColors.forClass('Rogue'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final playerAccent = ClassColors.forClass(widget.playerClass);
    // Narrowed from full Provider.of — only need the user, not all notifications.
    final user = context.select<UserProvider, UserModel?>((p) => p.user);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: GameWidget(key: _gameKey, game: _game),
          ),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topHud(),
              const Spacer(),
              _bottomHud(playerAccent, user?.level ?? 1),
            ],
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: SafeArea(
            child: Material(
              color: AppTheme.surfaceColor.withValues(alpha: 0.8),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
        if (_playerWon != null && !_showLevelUp)
          BattleResultScreen(
            won: _playerWon!,
            xpDelta: _xpDelta,
            level: user?.level ?? 1,
            league: user?.league ?? 'Bronze',
            damageDealt: _game.damageDealt,
            troopsDeployed: _game.troopsDeployed,
            matchDuration: _game.matchDuration,
            onRematch: () {
              Navigator.of(context).pop();
            },
            onClose: () => Navigator.of(context).pop(),
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

  Widget _topHud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 8, 12, 4),
      child: Column(
        children: [
          ValueListenableBuilder<int>(
            valueListenable: _game.enemyHealthNotifier,
            builder: (context, health, _) => TowerHealthBar(
              health: health,
              maxHealth: AppConstants.startingTowerHealth,
              label: 'ENEMY TOWER',
              accent: AppTheme.primaryColor,
              isEnemy: true,
            ),
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<int>(
            valueListenable: _game.timeRemainingNotifier,
            builder: (context, remaining, _) => _TimerBadge(
              secondsRemaining: remaining,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomHud(Color playerAccent, int playerLevel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: _cachedCards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final data = _cachedCards[i];
                return ValueListenableBuilder<double>(
                  valueListenable: _game.manaNotifier,
                  builder: (context, mana, _) => TroopCard(
                    data: data,
                    currentMana: mana,
                    onDeployAt: _handleCardDrop,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<double>(
            valueListenable: _game.manaNotifier,
            builder: (context, mana, _) =>
                _ManaBar(
                    mana: mana, maxMana: AppConstants.maxMana.toDouble()),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<int>(
            valueListenable: _game.playerHealthNotifier,
            builder: (context, health, _) => Row(
              children: [
                Expanded(
                  child: TowerHealthBar(
                    health: health,
                    maxHealth: AppConstants.startingTowerHealth,
                    label: 'YOUR TOWER',
                    accent: playerAccent,
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  heroTag: 'spell',
                  backgroundColor: AppTheme.accentGold,
                  onPressed: () => _game.castSpell(),
                  child: const Icon(Icons.auto_fix_high,
                      size: 20, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerBadge extends StatelessWidget {
  final int secondsRemaining;
  const _TimerBadge({required this.secondsRemaining});

  @override
  Widget build(BuildContext context) {
    final urgent = secondsRemaining <= 30 && secondsRemaining > 0;
    final color = urgent ? AppTheme.primaryColor : AppTheme.accentGold;
    final mm = (secondsRemaining ~/ 60).toString().padLeft(1, '0');
    final ss = (secondsRemaining % 60).toString().padLeft(2, '0');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: urgent ? 1.08 : 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, scale, _) => Transform.scale(
        scale: scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1.5),
            boxShadow: urgent
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 14,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TIME LEFT',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge!
                    .copyWith(fontSize: 7, color: Colors.white70),
              ),
              const SizedBox(height: 2),
              Text(
                '$mm:$ss',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium!
                    .copyWith(fontSize: 20, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManaBar extends StatelessWidget {
  final double mana;
  final double maxMana;
  const _ManaBar({required this.mana, required this.maxMana});

  @override
  Widget build(BuildContext context) {
    final ratio = (mana / maxMana).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: AppTheme.secondaryColor.withValues(alpha: 0.6),
            width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MANA',
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                    fontSize: 8, color: AppTheme.secondaryColor),
              ),
              Text(
                '${mana.toInt()}/${maxMana.toInt()}',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge!
                    .copyWith(fontSize: 8, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppTheme.secondaryColor.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
