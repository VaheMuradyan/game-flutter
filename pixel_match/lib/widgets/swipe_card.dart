import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../theme/app_colors.dart';
import 'pixel_card.dart';

/// Card body used inside a `CardSwiper`. Physics (tilt, snap-back,
/// velocity release) is owned by the swiper; this widget only renders
/// content and reacts to the drag percentage via directional overlays.
class SwipeCard extends StatelessWidget {
  final UserModel user;
  final double dragPercentX;

  const SwipeCard({super.key, required this.user, this.dragPercentX = 0});

  @override
  Widget build(BuildContext context) {
    final like = (dragPercentX / 100).clamp(0.0, 1.0);
    final nope = (-dragPercentX / 100).clamp(0.0, 1.0);

    return Stack(fit: StackFit.expand, children: [
      PixelCard(user: user, showStats: true),
      if (like > 0)
        Positioned(
          top: 28,
          left: 24,
          child: Opacity(
            opacity: like,
            child: _stamp(context, 'LIKE', AppColors.accent, -0.2),
          ),
        ),
      if (nope > 0)
        Positioned(
          top: 28,
          right: 24,
          child: Opacity(
            opacity: nope,
            child: _stamp(context, 'NOPE', AppColors.primary, 0.2),
          ),
        ),
    ]);
  }

  Widget _stamp(BuildContext context, String text, Color color, double angle) {
    final base = Theme.of(context).textTheme.headlineMedium;
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 4),
          borderRadius: BorderRadius.zero,
          color: Colors.black.withValues(alpha: 0.75),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          text,
          style: base?.copyWith(color: color, fontSize: 20) ??
              TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
