import 'package:flame/components.dart';
import 'dart:ui';
import 'tower.dart';

class Troop extends PositionComponent with HasGameReference {
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
