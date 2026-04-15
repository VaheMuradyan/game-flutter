import 'package:flame/components.dart';
import 'dart:ui';

class Spell extends SpriteComponent with HasGameReference {
  final Vector2 target;
  final Color color;
  final int damage;
  final double speed;
  final void Function(Vector2 position, int damage) onImpact;
  bool _exploded = false;

  // Hoisted — previously allocated per frame / per update tick.
  final Vector2 _direction = Vector2.zero();
  late final Paint _corePaint;
  late final Paint _glowPaint;

  Spell({
    required this.target,
    required this.color,
    this.damage = 100,
    this.speed = 200.0,
    required this.onImpact,
  }) {
    _corePaint = Paint()..color = color;
    _glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  }

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
    _direction
      ..setFrom(target)
      ..sub(position);
    final distSq = _direction.length2;
    if (distSq < 8 * 8) {
      _exploded = true;
      onImpact(position, damage);
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
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2,
        _corePaint,
      );
    }
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2 + 4,
      _glowPaint,
    );
  }
}
