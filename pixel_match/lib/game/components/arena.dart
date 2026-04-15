import 'package:flame/components.dart';
import 'dart:ui';

class Arena extends SpriteComponent with HasGameReference {
  // Hoisted paints — previously re-allocated every frame.
  static final Paint _bgPaint = Paint()..color = const Color(0xFF2C3E50);
  static final Paint _midLinePaint = Paint()
    ..color = const Color(0xFF7F8C8D)
    ..strokeWidth = 2;
  static final Paint _gridPaint = Paint()
    ..color = const Color(0xFF34495E)
    ..strokeWidth = 1;

  @override
  Future<void> onLoad() async {
    try {
      sprite = await Sprite.load('images/arena_bg.png');
    } catch (_) {
      sprite = null;
    }
    size = game.size;
    position = Vector2.zero();
    priority = -1;
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
      return;
    }
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _bgPaint);
    final midY = size.y / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.x, midY), _midLinePaint);
    const gridSize = 32.0;
    for (double x = 0; x < size.x; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), _gridPaint);
    }
    for (double y = 0; y < size.y; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), _gridPaint);
    }
  }
}
