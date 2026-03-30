# Phase 4 — Game Engine Setup (Flame)

## Goal
Integrate the Flame game engine into the Flutter app. Create the battle arena canvas, pixel-art tower and troop components, and a standalone single-player test mode where the user can tap to deploy troops that walk toward the enemy tower. No networking or real opponent yet — that comes in Phase 5.

> **This phase is Flutter-only.** No Go backend changes needed.

## Prerequisites
Phases 1–3 complete: Flutter project compiles, auth works, `UserModel` / `UserProvider` exist.

---

## 1. Sprite Strategy

All visuals are drawn **programmatically** using Flame's canvas paint calls with hard-coded pixel colours. No external sprite sheet files needed. When real pixel art assets are ready later, swap `render()` methods to use `SpriteComponent`.

### `lib/game/class_colors.dart`

```dart
import 'dart:ui';

class ClassColors {
  static const Map<String, Color> primary = {
    'Warrior': Color(0xFFE74C3C),
    'Mage':    Color(0xFF9B59B6),
    'Archer':  Color(0xFF2ECC71),
    'Rogue':   Color(0xFF34495E),
    'Healer':  Color(0xFF3498DB),
  };

  static Color forClass(String cls) => primary[cls] ?? const Color(0xFFFFFFFF);
}
```

---

## 2. `lib/game/components/arena.dart`

```dart
import 'package:flame/components.dart';
import 'dart:ui';

class Arena extends PositionComponent with HasGameRef {
  @override
  Future<void> onLoad() async {
    size = gameRef.size;
    position = Vector2.zero();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF2C3E50));

    final midY = size.y / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.x, midY),
        Paint()..color = const Color(0xFF7F8C8D)..strokeWidth = 2);

    final gridPaint = Paint()..color = const Color(0xFF34495E)..strokeWidth = 1;
    const gridSize = 32.0;
    for (double x = 0; x < size.x; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }
    for (double y = 0; y < size.y; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
    }
  }
}
```

---

## 3. `lib/game/components/tower.dart`

```dart
import 'package:flame/components.dart';
import 'dart:ui';
import '../../config/constants.dart';

class Tower extends PositionComponent {
  int health;
  final int maxHealth;
  final bool isPlayer;
  final Color color;

  Tower({required this.isPlayer, required this.color,
      this.maxHealth = AppConstants.startingTowerHealth})
      : health = AppConstants.startingTowerHealth;

  @override
  Future<void> onLoad() async {
    size = Vector2(64, 80);
    anchor = Anchor.center;
  }

  void takeDamage(int damage) {
    health = (health - damage).clamp(0, maxHealth);
  }

  bool get isDestroyed => health <= 0;

  @override
  void render(Canvas canvas) {
    final bodyRect = Rect.fromLTWH(0, 16, size.x, size.y - 16);
    canvas.drawRect(bodyRect, Paint()..color = color);

    const bw = 12.0;
    for (double x = 0; x < size.x; x += bw * 2) {
      canvas.drawRect(Rect.fromLTWH(x, 8, bw, 12), Paint()..color = color);
    }

    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 6), Paint()..color = const Color(0xFF555555));

    final ratio = health / maxHealth;
    final barColor = ratio > 0.5 ? const Color(0xFF2ECC71)
        : ratio > 0.25 ? const Color(0xFFE67E22) : const Color(0xFFE74C3C);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x * ratio, 6), Paint()..color = barColor);
  }
}
```

---

## 4. `lib/game/components/troop.dart`

```dart
import 'package:flame/components.dart';
import 'dart:ui';
import 'tower.dart';

class Troop extends PositionComponent with HasGameRef {
  final bool isPlayer;
  final Color color;
  final int damage;
  final double speed;
  Tower? targetTower;
  bool _reachedTarget = false;

  Troop({required this.isPlayer, required this.color, this.damage = 50, this.speed = 60.0});

  @override
  Future<void> onLoad() async {
    size = Vector2(20, 20);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_reachedTarget || targetTower == null) return;
    final direction = (targetTower!.position - position).normalized();
    position += direction * speed * dt;
    if (position.distanceTo(targetTower!.position) < 32) {
      targetTower!.takeDamage(damage);
      _reachedTarget = true;
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(4, 8, 12, 12), Paint()..color = color);
    canvas.drawCircle(const Offset(10, 6), 6, Paint()..color = color);
    canvas.drawCircle(const Offset(8, 5), 1.5, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(const Offset(12, 5), 1.5, Paint()..color = const Color(0xFFFFFFFF));
  }
}
```

---

## 5. `lib/game/components/spell.dart`

```dart
import 'package:flame/components.dart';
import 'dart:ui';

class Spell extends PositionComponent with HasGameRef {
  final Vector2 target;
  final Color color;
  final int damage;
  final double speed;
  final void Function(Vector2 position, int damage) onImpact;
  bool _exploded = false;

  Spell({required this.target, required this.color, this.damage = 100,
      this.speed = 200.0, required this.onImpact});

  @override
  Future<void> onLoad() async {
    size = Vector2(12, 12);
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_exploded) return;
    final direction = (target - position).normalized();
    position += direction * speed * dt;
    if (position.distanceTo(target) < 8) {
      _exploded = true;
      onImpact(position, damage);
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, Paint()..color = color);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2 + 3,
        Paint()..color = color.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }
}
```

---

## 6. `lib/game/pixel_match_game.dart`

```dart
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'dart:ui';
import 'components/arena.dart';
import 'components/tower.dart';
import 'components/troop.dart';
import 'class_colors.dart';

class PixelMatchGame extends FlameGame with TapCallbacks {
  final String playerClass;
  late Tower playerTower;
  late Tower enemyTower;
  double mana = 5.0;
  static const double maxMana = 10.0;
  static const double manaRegen = 1.0;
  static const double troopCost = 3.0;
  double _aiTimer = 0;

  // Multiplayer fields (used in Phase 5)
  String? battleId;
  String? localUid;
  bool isMultiplayer = false;
  void Function(double x, double y)? onTroopDeployed;
  void Function(int damage)? onTowerHit;
  void Function(bool playerWon)? onBattleEnd;

  PixelMatchGame({required this.playerClass});

  @override
  Future<void> onLoad() async {
    add(Arena());

    final playerColor = ClassColors.forClass(playerClass);
    playerTower = Tower(isPlayer: true, color: playerColor);
    playerTower.position = Vector2(size.x / 2, size.y - 80);
    add(playerTower);

    enemyTower = Tower(isPlayer: false, color: const Color(0xFFE74C3C));
    enemyTower.position = Vector2(size.x / 2, 80);
    add(enemyTower);
  }

  @override
  void update(double dt) {
    super.update(dt);
    mana = (mana + manaRegen * dt).clamp(0, maxMana);

    // AI only in single-player mode
    if (!isMultiplayer) {
      _aiTimer += dt;
      if (_aiTimer >= 3.0) {
        _aiTimer = 0;
        _spawnEnemyTroop();
      }
    }

    if (enemyTower.isDestroyed) {
      onBattleEnd?.call(true);
      pauseEngine();
    } else if (playerTower.isDestroyed) {
      onBattleEnd?.call(false);
      pauseEngine();
    }
  }

  void _spawnEnemyTroop() {
    final troop = Troop(isPlayer: false, color: const Color(0xFFE74C3C))
      ..position = Vector2(
        enemyTower.position.x + ((_aiTimer * 37).toInt() % 60 - 30).toDouble(),
        enemyTower.position.y + 50,
      )
      ..targetTower = playerTower;
    add(troop);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (event.localPosition.y < size.y / 2 && mana >= troopCost) {
      mana -= troopCost;
      final x = event.localPosition.x;
      final y = size.y / 2 + 20;
      _spawnPlayerTroop(x, y);
      if (isMultiplayer) onTroopDeployed?.call(x, y);
    }
  }

  void _spawnPlayerTroop(double x, double y) {
    final troop = Troop(isPlayer: true, color: ClassColors.forClass(playerClass))
      ..position = Vector2(x, y)
      ..targetTower = enemyTower;
    add(troop);
  }

  /// Called when server relays opponent troop (Phase 5).
  void spawnRemoteTroop(double x, double y) {
    final troop = Troop(isPlayer: false, color: const Color(0xFFE74C3C))
      ..position = Vector2(x, size.y / 2 - 20)
      ..targetTower = playerTower;
    add(troop);
  }

  void applyRemoteDamage(int targetIdx, int healthRemaining) {
    if (targetIdx == 0) playerTower.health = healthRemaining;
    else enemyTower.health = healthRemaining;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final barWidth = size.x - 32;
    const barHeight = 12.0;
    final barY = size.y - 20;
    canvas.drawRect(Rect.fromLTWH(16, barY, barWidth, barHeight),
        Paint()..color = const Color(0xFF333333));
    canvas.drawRect(Rect.fromLTWH(16, barY, barWidth * (mana / maxMana), barHeight),
        Paint()..color = const Color(0xFF3498DB));
    final tp = TextPainter(
      text: TextSpan(text: 'MANA ${mana.toInt()}/${maxMana.toInt()}',
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(16, barY - 14));
  }
}
```

---

## 7. `lib/screens/battle/battle_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../game/pixel_match_game.dart';
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

  @override
  void initState() {
    super.initState();
    _game = PixelMatchGame(playerClass: widget.playerClass)
      ..onBattleEnd = (won) => setState(() => _playerWon = won);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        GameWidget(game: _game),
        SafeArea(child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop())),
        if (_playerWon != null)
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
      ]),
    );
  }
}
```

---

## 8. Add battle route to `lib/config/routes.dart`

```dart
GoRoute(
  path: '/battle',
  builder: (context, state) {
    final playerClass = state.extra as String? ?? 'Warrior';
    return BattleScreen(playerClass: playerClass);
  },
),
```

Import: `import '../screens/battle/battle_screen.dart';`

---

## 9. Update Home screen with Battle button

Replace `lib/screens/home/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      body: SafeArea(child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('ARENA', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          if (user != null)
            Text('${user.characterClass} · Lv ${user.level}',
                style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          ElevatedButton.icon(icon: const Icon(Icons.sports_esports),
              label: const Text('BATTLE'),
              onPressed: () => context.push('/battle', extra: user?.characterClass ?? 'Warrior')),
          const SizedBox(height: 12),
          OutlinedButton.icon(icon: const Icon(Icons.person), label: const Text('PROFILE'),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppTheme.secondaryColor),
                  foregroundColor: AppTheme.secondaryColor),
              onPressed: () => context.push('/profile')),
        ],
      ))),
    );
  }
}
```

---

## 10. Verification Checklist

- [ ] BATTLE button opens the Flame game screen
- [ ] Arena shows grid, player tower (bottom), enemy tower (top)
- [ ] Tapping top half deploys player troop (costs 3 mana)
- [ ] Enemy troops auto-spawn every 3 seconds
- [ ] Towers lose health, health bars update
- [ ] VICTORY/DEFEAT overlay when a tower hits 0 HP
- [ ] Mana bar fills over time at bottom of screen
- [ ] Back button returns to Home

---

## What Phase 5 Expects

Phase 5 adds real-time multiplayer: Go WebSocket battle server, matchmaking queue, synchronized battle state between two players. It will reuse `PixelMatchGame` with `isMultiplayer = true`.
