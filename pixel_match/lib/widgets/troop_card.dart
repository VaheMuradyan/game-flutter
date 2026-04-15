import 'package:flutter/material.dart';
import '../config/theme.dart';

class TroopCardData {
  final String label;
  final int cost;
  final IconData icon;
  final Color color;
  const TroopCardData({
    required this.label,
    required this.cost,
    required this.icon,
    required this.color,
  });
}

class TroopCard extends StatefulWidget {
  final TroopCardData data;
  final double currentMana;
  final void Function(Offset globalPosition) onDeployAt;

  const TroopCard({
    super.key,
    required this.data,
    required this.currentMana,
    required this.onDeployAt,
  });

  @override
  State<TroopCard> createState() => _TroopCardState();
}

class _TroopCardState extends State<TroopCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _readyCtrl;

  @override
  void initState() {
    super.initState();
    _readyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _readyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = widget.currentMana >= widget.data.cost;
    final card = _buildCard(context, ready, highlight: false);

    if (!ready) return card;

    return Draggable<String>(
      data: widget.data.label,
      feedback: Material(
        color: Colors.transparent,
        child: _buildCard(context, true, highlight: true),
      ),
      childWhenDragging: Opacity(opacity: 0.25, child: card),
      onDragEnd: (details) {
        if (!details.wasAccepted) {
          widget.onDeployAt(details.offset);
        }
      },
      child: card,
    );
  }

  Widget _buildCard(BuildContext context, bool ready,
      {required bool highlight}) {
    final color = widget.data.color;
    return AnimatedBuilder(
      animation: _readyCtrl,
      builder: (context, _) {
        final glow = ready ? (0.4 + 0.4 * _readyCtrl.value) : 0.0;
        return Container(
          width: 78,
          height: 96,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: ready ? AppColors.surface : AppColors.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: ready ? color : Colors.white24,
              width: highlight ? 2.5 : 1.5,
            ),
            boxShadow: ready
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: glow),
                      blurRadius: highlight ? 18 : 10,
                      spreadRadius: highlight ? 1 : 0,
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                widget.data.icon,
                color: ready ? color : Colors.white38,
                size: 28,
              ),
              Text(
                widget.data.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      fontSize: 7,
                      color: ready ? Colors.white : Colors.white38,
                    ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ready ? AppColors.background : AppColors.surface,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: ready
                        ? AppTheme.accentGold.withValues(alpha: 0.7)
                        : Colors.white12,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${widget.data.cost} MP',
                  style: Theme.of(context).textTheme.labelLarge!.copyWith(
                        fontSize: 7,
                        color: ready
                            ? AppTheme.accentGold
                            : Colors.white38,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
