import 'package:flutter/material.dart';
import '../utils/league_helper.dart';

class LevelBadge extends StatelessWidget {
  final int level;
  final String league;
  final double size;

  const LevelBadge({super.key, required this.level, required this.league, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final color = LeagueHelper.colorForLeague(league);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color, width: 2),
      ),
      child: Center(
        child: Text('$level',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: size * 0.35)),
      ),
    );
  }
}
