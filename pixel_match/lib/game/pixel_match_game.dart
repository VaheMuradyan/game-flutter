import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'components/arena.dart';
import 'components/tower.dart';
import 'components/troop.dart';
import 'components/spell.dart';
import 'class_colors.dart';
import 'battle_audio.dart';
import '../config/constants.dart';
import '../services/audio_service.dart';

class PixelMatchGame extends FlameGame with TapCallbacks {
  final String playerClass;
  late Tower playerTower;
  late Tower enemyTower;
  // Tunables live in AppConstants, mirrored from design_reference/balance_sheet.md.
  double mana = AppConstants.startingMana;
  double _aiTimer = 0;
  double _matchElapsed = 0;
  bool _ended = false;
  int _lastTickedSecond = -1;

  // Stats (for victory/defeat screen)
  int damageDealt = 0;
  int troopsDeployed = 0;

  // HUD-observable state
  final ValueNotifier<int> playerHealthNotifier =
      ValueNotifier<int>(AppConstants.startingTowerHealth);
  final ValueNotifier<int> enemyHealthNotifier =
      ValueNotifier<int>(AppConstants.startingTowerHealth);
  final ValueNotifier<double> manaNotifier =
      ValueNotifier<double>(AppConstants.startingMana);
  final ValueNotifier<int> timeRemainingNotifier =
      ValueNotifier<int>(AppConstants.battleDurationSeconds);

  // Multiplayer fields
  String? battleId;
  String? localUid;
  bool isMultiplayer = false;
  void Function(double x, double y)? onTroopDeployed;
  void Function(int damage)? onTowerHit;
  void Function(bool playerWon)? onBattleEnd;
  void Function(int damage)? onSpellHit;

  final Random _rng = Random();

  PixelMatchGame({required this.playerClass});

  @override
  Future<void> onLoad() async {
    await BattleAudio.preload();
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
    if (_ended) return;

    mana = (mana + AppConstants.manaRegenPerSecond * dt)
        .clamp(0, AppConstants.maxMana.toDouble());
    manaNotifier.value = mana;

    playerHealthNotifier.value = playerTower.health;
    enemyHealthNotifier.value = enemyTower.health;

    _matchElapsed += dt;
    final remaining =
        (AppConstants.battleDurationSeconds - _matchElapsed)
            .clamp(0, AppConstants.battleDurationSeconds.toDouble())
            .toInt();
    timeRemainingNotifier.value = remaining;

    if (remaining <= 5 && remaining > 0 && remaining != _lastTickedSecond) {
      _lastTickedSecond = remaining;
      AudioService.instance.countdownTick();
    }

    final maxHp = AppConstants.startingTowerHealth.toDouble();
    AudioService.instance.escalateIfNeeded(
      playerTower.health / maxHp,
      enemyTower.health / maxHp,
    );

    if (!isMultiplayer) {
      _aiTimer += dt;
      if (_aiTimer >= 3.0) {
        _aiTimer = 0;
        _spawnEnemyTroop();
      }
    }

    if (enemyTower.isDestroyed) {
      _finishMatch(true);
    } else if (playerTower.isDestroyed) {
      _finishMatch(false);
    } else if (remaining <= 0 && !isMultiplayer) {
      _finishMatch(enemyTower.health < playerTower.health);
    }
  }

  void _finishMatch(bool won) {
    if (_ended) return;
    _ended = true;
    AudioService.instance.towerDestroyed();
    if (won) {
      BattleAudio.victory();
    } else {
      BattleAudio.defeat();
    }
    HapticFeedback.heavyImpact();
    onBattleEnd?.call(won);
    pauseEngine();
  }

  Duration get matchDuration =>
      Duration(seconds: _matchElapsed.toInt());

  void _spawnEnemyTroop() {
    final troop = Troop(isPlayer: false, color: const Color(0xFFE74C3C))
      ..position = Vector2(
        enemyTower.position.x + ((_aiTimer * 37).toInt() % 60 - 30).toDouble(),
        enemyTower.position.y + 50,
      )
      ..targetTower = playerTower
      ..onHit = (pos, dmg) => spawnTowerHit(pos, dmg, isPlayerTower: true);
    add(troop);
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (event.localPosition.y < size.y / 2) {
      _tryDeployAt(event.localPosition.x, size.y / 2 + 20);
    }
  }

  /// Deploy troop at a screen-local position (from drag-drop on troop card).
  void deployTroopAt(double x, double y) {
    if (y >= size.y / 2) return;
    _tryDeployAt(x, size.y / 2 + 20);
  }

  void _tryDeployAt(double x, double y) {
    if (_ended || mana < AppConstants.troopCost) return;
    mana -= AppConstants.troopCost;
    manaNotifier.value = mana;
    troopsDeployed += 1;
    _spawnPlayerTroop(x, y);
    BattleAudio.troopDeploy();
    HapticFeedback.mediumImpact();
    if (isMultiplayer) onTroopDeployed?.call(x, y);
  }

  void _spawnPlayerTroop(double x, double y) {
    final troop = Troop(
      isPlayer: true,
      color: ClassColors.forClass(playerClass),
      characterClass: playerClass,
    )
      ..position = Vector2(x, y)
      ..targetTower = enemyTower
      ..onHit = (pos, dmg) {
        damageDealt += dmg;
        spawnTowerHit(pos, dmg, isPlayerTower: false);
        if (isMultiplayer) onTowerHit?.call(dmg);
      };
    add(troop);
  }

  void spawnRemoteTroop(double x, double y) {
    final troop = Troop(isPlayer: false, color: const Color(0xFFE74C3C))
      ..position = Vector2(x, size.y / 2 - 20)
      ..targetTower = playerTower
      ..onHit = (pos, dmg) => spawnTowerHit(pos, dmg, isPlayerTower: true);
    add(troop);
  }

  void applyRemoteDamage(int targetIdx, int healthRemaining) {
    if (targetIdx == 0) {
      playerTower.health = healthRemaining;
    } else {
      enemyTower.health = healthRemaining;
    }
  }

  void spawnTowerHit(Vector2 position, int damage,
      {required bool isPlayerTower}) {
    HapticFeedback.lightImpact();
    AudioService.instance.towerHit();

    add(ParticleSystemComponent(
      position: position.clone(),
      particle: Particle.generate(
        count: 14,
        lifespan: 0.55,
        generator: (i) {
          final angle = _rng.nextDouble() * 2 * pi;
          final speed = 40 + _rng.nextDouble() * 90;
          return AcceleratedParticle(
            acceleration: Vector2(0, 120),
            speed: Vector2(cos(angle) * speed, sin(angle) * speed - 30),
            child: CircleParticle(
              radius: 1.8 + _rng.nextDouble() * 1.6,
              paint: Paint()
                ..color = const Color(0xFFFFD93D),
            ),
          );
        },
      ),
    ));

    final txt = TextComponent(
      text: '-$damage',
      position: position.clone() + Vector2(0, -24),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Color(0xFFE74C3C), blurRadius: 4),
          ],
        ),
      ),
    );
    txt.add(MoveEffect.by(
      Vector2(0, -40),
      EffectController(duration: 0.8, curve: Curves.easeOut),
    ));
    txt.add(RemoveEffect(delay: 0.8));
    add(txt);
  }

  void castSpell() {
    if (_ended || mana < AppConstants.spellCost) return;
    mana -= AppConstants.spellCost;
    manaNotifier.value = mana;
    BattleAudio.spellCast();
    HapticFeedback.mediumImpact();
    final spell = Spell(
      target: enemyTower.position.clone(),
      color: ClassColors.forClass(playerClass),
      damage: AppConstants.spellDamage,
      onImpact: (position, damage) {
        enemyTower.health -= damage;
        if (enemyTower.health < 0) enemyTower.health = 0;
        damageDealt += damage;
        spawnTowerHit(position, damage, isPlayerTower: false);
        onSpellHit?.call(damage);
      },
    )..position = playerTower.position.clone();
    add(spell);
  }

  @override
  void onRemove() {
    playerHealthNotifier.dispose();
    enemyHealthNotifier.dispose();
    manaNotifier.dispose();
    timeRemainingNotifier.dispose();
    super.onRemove();
  }
}
