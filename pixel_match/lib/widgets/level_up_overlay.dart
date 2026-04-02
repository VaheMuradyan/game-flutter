import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../utils/league_helper.dart';

class LevelUpOverlay extends StatelessWidget {
  final int newLevel;
  final String newLeague;
  final bool leagueChanged;
  final VoidCallback onDismiss;

  const LevelUpOverlay({super.key, required this.newLevel, required this.newLeague,
      required this.leagueChanged, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final leagueColor = LeagueHelper.colorForLeague(newLeague);
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black87,
        child: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LEVEL UP!', style: TextStyle(fontSize: 28, color: AppTheme.accentGold,
                    fontWeight: FontWeight.bold))
                .animate().scale(begin: const Offset(0.5, 0.5), duration: const Duration(milliseconds: 400))
                .then().shake(hz: 3, duration: 300.ms),
            const SizedBox(height: 16),
            Text('Level $newLevel', style: const TextStyle(fontSize: 22, color: Colors.white)),
            if (leagueChanged) ...[
              const SizedBox(height: 12),
              Text('NEW LEAGUE: $newLeague', style: TextStyle(fontSize: 18, color: leagueColor))
                  .animate().fadeIn(delay: 600.ms, duration: 400.ms),
            ],
            const SizedBox(height: 24),
            Text('Tap to continue', style: TextStyle(fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6))),
          ],
        )),
      ),
    );
  }
}
