import 'package:flame/components.dart';
import 'dart:ui';

class Arena extends PositionComponent with HasGameReference {
  @override
  Future<void> onLoad() async {
    size = game.size;
    position = Vector2.zero();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0xFF2C3E50));

    final midY = size.y / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.x, midY),
        Paint()..color = const Color(0xFF7F8C8D)..strokeWidth = 2);

    final gridPaint = Paint()..color = const Color(0xFF34495E)..strokeWidth = 1;
    const gridSize = 32.0;
    for (double x = 0; x < size.x; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }
    for (double y = 0; y < size.y; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
    }
  }
}
