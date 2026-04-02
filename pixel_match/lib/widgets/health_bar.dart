import 'package:flutter/material.dart';
import '../config/theme.dart';

class HealthBar extends StatelessWidget {
  final double progress;
  final Color fillColor;
  final Color bgColor;
  final double height;
  final String? label;

  const HealthBar({super.key, required this.progress,
      this.fillColor = AppTheme.secondaryColor,
      this.bgColor = const Color(0xFF333333),
      this.height = 16, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Text(label!, style: Theme.of(context).textTheme.labelLarge)),
        Container(
          height: height,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(2)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ],
    );
  }
}
