import 'package:flame/components.dart';
import 'dart:ui';
import '../../config/constants.dart';

class Tower extends SpriteComponent with HasGameReference {
  int health;
  final int maxHealth;
  final bool isPlayer;
  final Color color;

  Tower({required this.isPlayer, required this.color,
      this.maxHealth = AppConstants.startingTowerHealth})
      : health = AppConstants.startingTowerHealth;

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
      // Fallback drawing if sprite missing
      final bodyRect = Rect.fromLTWH(0, 12, size.x, size.y - 12);
      canvas.drawRect(bodyRect, Paint()..color = color);
      const bw = 10.0;
      for (double x = 0; x < size.x; x += bw * 2) {
        canvas.drawRect(Rect.fromLTWH(x, 4, bw, 10), Paint()..color = color);
      }
    }

    // Health bar
    const barWidth = 48.0;
    const barHeight = 6.0;
    const barX = 0.0;
    final barY = isPlayer ? size.y + 4 : -barHeight - 4;

    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barWidth, barHeight),
      Paint()..color = const Color(0xFF333333),
    );

    final ratio = health / maxHealth;
    final fillColor = ratio > 0.5
        ? const Color(0xFF2ECC71)
        : ratio > 0.25
            ? const Color(0xFFF39C12)
            : const Color(0xFFE74C3C);
    canvas.drawRect(
      Rect.fromLTWH(barX, barY, barWidth * ratio, barHeight),
      Paint()..color = fillColor,
    );
  }
}
