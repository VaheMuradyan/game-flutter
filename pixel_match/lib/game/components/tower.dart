import 'package:flame/components.dart';
import 'dart:ui';
import '../../config/constants.dart';

class Tower extends SpriteComponent with HasGameReference {
  int health;
  final int maxHealth;
  final bool isPlayer;
  final Color color;

  // Hoisted — previously allocated per frame in render().
  late final Paint _bodyPaint;

  Tower({required this.isPlayer, required this.color,
      this.maxHealth = AppConstants.startingTowerHealth})
      : health = AppConstants.startingTowerHealth {
    _bodyPaint = Paint()..color = color;
  }

  @override
  Future<void> onLoad() async {
    final imageName =
        isPlayer ? 'sprites/tower_player.png' : 'sprites/tower_enemy.png';
    try {
      sprite = await Sprite.load(imageName);
    } catch (_) {
      sprite = null;
    }
    size = Vector2(48, 64);
    anchor = Anchor.center;
  }

  void takeDamage(int damage) {
    health = (health - damage).clamp(0, maxHealth);
  }

  bool get isDestroyed => health <= 0;

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
    } else {
      final bodyRect = Rect.fromLTWH(0, 12, size.x, size.y - 12);
      canvas.drawRect(bodyRect, _bodyPaint);
      const bw = 10.0;
      for (double x = 0; x < size.x; x += bw * 2) {
        canvas.drawRect(Rect.fromLTWH(x, 4, bw, 10), _bodyPaint);
      }
    }
  }
}
