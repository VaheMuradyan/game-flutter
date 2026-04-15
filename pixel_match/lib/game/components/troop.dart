import 'package:flame/components.dart';
import 'dart:ui';
import 'tower.dart';
import '../../config/constants.dart';

class Troop extends SpriteComponent with HasGameReference {
  final bool isPlayer;
  final Color color;
  final String characterClass;
  final int damage;
  final double speed;
  Tower? targetTower;
  void Function(Vector2 position, int damage)? onHit;
  bool _reachedTarget = false;

  // Hoisted per-instance scratch buffers — previously `.normalized()` and
  // subtraction allocated two Vector2s every update tick per troop.
  final Vector2 _direction = Vector2.zero();
  late final Paint _bodyPaint;

  // Defaults mirror design_reference/balance_sheet.md §4/§5.
  Troop({
    required this.isPlayer,
    required this.color,
    this.characterClass = 'Warrior',
    int? damage,
    double? speed,
  })  : damage = damage ?? AppConstants.troopBaseDamage,
        speed = speed ?? AppConstants.troopSpeed {
    _bodyPaint = Paint()..color = color;
  }

  @override
  Future<void> onLoad() async {
    final spriteName = isPlayer
        ? 'sprites/troop_${characterClass.toLowerCase()}.png'
        : 'sprites/troop_warrior.png';
    try {
      sprite = await Sprite.load(spriteName);
    } catch (_) {
      try {
        sprite = await Sprite.load('sprites/troop_warrior.png');
      } catch (_) {
        sprite = null;
      }
    }
    size = Vector2(24, 24);
    anchor = Anchor.center;

    if (!isPlayer) {
      flipVertically();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_reachedTarget || targetTower == null) return;
    final target = targetTower!.position;
    _direction
      ..setFrom(target)
      ..sub(position);
    final distSq = _direction.length2;
    if (distSq < 32 * 32) {
      targetTower!.takeDamage(damage);
      onHit?.call(target.clone(), damage);
      _reachedTarget = true;
      removeFromParent();
      return;
    }
    if (distSq > 0) {
      _direction.scale(1.0 / _direction.length);
    }
    position.x += _direction.x * speed * dt;
    position.y += _direction.y * speed * dt;
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
    } else {
      canvas.drawRect(const Rect.fromLTWH(4, 8, 16, 14), _bodyPaint);
      canvas.drawCircle(const Offset(12, 6), 6, _bodyPaint);
    }
  }
}
