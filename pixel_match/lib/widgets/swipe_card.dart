import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'pixel_card.dart';

class SwipeCard extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSwipeRight;
  final VoidCallback onSwipeLeft;
  const SwipeCard({super.key, required this.user, required this.onSwipeRight, required this.onSwipeLeft});
  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  double _dx = 0, _dy = 0, _angle = 0;

  void _onPanUpdate(DragUpdateDetails d) => setState(() {
    _dx += d.delta.dx; _dy += d.delta.dy; _angle = _dx / 300 * 0.3;
  });

  void _onPanEnd(DragEndDetails d) {
    if (_dx > 100) widget.onSwipeRight();
    else if (_dx < -100) widget.onSwipeLeft();
    setState(() { _dx = 0; _dy = 0; _angle = 0; });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: _onPanUpdate, onPanEnd: _onPanEnd,
      child: Transform.translate(offset: Offset(_dx, _dy),
        child: Transform.rotate(angle: _angle, child: Stack(children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.65,
              child: PixelCard(user: widget.user, showStats: true)),
          if (_dx > 30) Positioned(top: 24, left: 24, child: _indicator('LIKE', Colors.green)),
          if (_dx < -30) Positioned(top: 24, right: 24, child: _indicator('NOPE', Colors.red)),
        ]))),
    );
  }

  Widget _indicator(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(border: Border.all(color: color, width: 3), borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
  );
}
