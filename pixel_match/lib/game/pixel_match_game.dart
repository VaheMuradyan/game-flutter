import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/painting.dart';
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
    if (targetIdx == 0) {
      playerTower.health = healthRemaining;
    } else {
      enemyTower.health = healthRemaining;
    }
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
