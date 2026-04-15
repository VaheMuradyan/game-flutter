import 'package:flutter/material.dart';
import '../config/theme.dart';

class TowerHealthBar extends StatefulWidget {
  final int health;
  final int maxHealth;
  final String label;
  final Color accent;
  final bool isEnemy;

  const TowerHealthBar({
    super.key,
    required this.health,
    required this.maxHealth,
    required this.label,
    required this.accent,
    this.isEnemy = false,
  });

  @override
  State<TowerHealthBar> createState() => _TowerHealthBarState();
}

class _TowerHealthBarState extends State<TowerHealthBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  int _lastHealth = 0;
  DateTime? _flashAt;

  @override
  void initState() {
    super.initState();
    _lastHealth = widget.health;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant TowerHealthBar old) {
    super.didUpdateWidget(old);
    if (widget.health < _lastHealth) {
      _flashAt = DateTime.now();
    }
    _lastHealth = widget.health;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = (widget.health / widget.maxHealth).clamp(0.0, 1.0);
    final isLow = ratio <= 0.25 && widget.health > 0;
    final fillColor = widget.isEnemy
        ? AppColors.primary
        : (ratio > 0.5
            ? AppColors.success
            : ratio > 0.25
                ? AppColors.warning
                : AppColors.danger);

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (context, _) {
        final pulse = isLow ? (0.5 + 0.5 * _pulseCtrl.value) : 0.0;
        final flashMs = _flashAt == null
            ? 9999
            : DateTime.now().difference(_flashAt!).inMilliseconds;
        final flash = (1 - (flashMs / 250)).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: widget.accent.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: isLow
                ? [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.6 * pulse),
                      blurRadius: 16,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.label,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge!
                        .copyWith(color: widget.accent, fontSize: 8),
                  ),
                  Text(
                    '${widget.health}/${widget.maxHealth} HP',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge!
                        .copyWith(color: Colors.white, fontSize: 7),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Stack(
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                          color: AppColors.border, width: 1),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1.0, end: ratio),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOut,
                      builder: (context, value, _) => FractionallySizedBox(
                        widthFactor: value,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                                fillColor, Colors.white, flash * 0.85)!,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    fillColor.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
