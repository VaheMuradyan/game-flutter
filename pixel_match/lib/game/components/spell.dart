import 'package:flame/components.dart';
import 'dart:ui';

class Spell extends SpriteComponent with HasGameReference {
  final Vector2 target;
  final Color color;
  final int damage;
  final double speed;
  final void Function(Vector2 position, int damage) onImpact;
  bool _exploded = false;

  Spell({
    required this.target,
    required this.color,
    this.damage = 100,
    this.speed = 200.0,
    required this.onImpact,
  });

  @override
  Future<void> onLoad() async {
    try {
      sprite = await Sprite.load('sprites/spell_fireball.png');
    } catch (_) {
      sprite = null;
    }
    size = Vector2(16, 16);
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
    if (sprite != null) {
      super.render(canvas);
    } else {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2,
        Paint()..color = color,
      );
    }
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2 + 4,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }
}
