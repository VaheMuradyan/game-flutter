import 'package:flame/components.dart';
import 'dart:ui';
import 'tower.dart';

class Troop extends SpriteComponent with HasGameReference {
  final bool isPlayer;
  final Color color;
  final String characterClass;
  final int damage;
  final double speed;
  Tower? targetTower;
  bool _reachedTarget = false;

  Troop({
    required this.isPlayer,
    required this.color,
    this.characterClass = 'Warrior',
    this.damage = 50,
    this.speed = 60.0,
  });

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
    if (sprite != null) {
      super.render(canvas);
    } else {
      // Fallback drawing
      canvas.drawRect(
        const Rect.fromLTWH(4, 8, 16, 14),
        Paint()..color = color,
      );
      canvas.drawCircle(
        const Offset(12, 6),
        6,
        Paint()..color = color,
      );
    }
  }
}
