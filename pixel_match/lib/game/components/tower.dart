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
