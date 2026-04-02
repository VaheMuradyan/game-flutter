import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

class MatchCelebrationScreen extends StatelessWidget {
  final String myName;
  final String theirName;
  final String chatId;
  const MatchCelebrationScreen({super.key, required this.myName,
      required this.theirName, required this.chatId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('\u2764\uFE0F', style: TextStyle(fontSize: 48)).animate()
              .scale(begin: const Offset(0, 0), duration: 500.ms).then().shake(hz: 2, duration: 400.ms),
          const SizedBox(width: 24),
          const Text('\u2694\uFE0F', style: TextStyle(fontSize: 48)).animate(delay: 200.ms)
              .scale(begin: const Offset(0, 0), duration: 500.ms),
          const SizedBox(width: 24),
          const Text('\u2764\uFE0F', style: TextStyle(fontSize: 48)).animate(delay: 400.ms)
              .scale(begin: const Offset(0, 0), duration: 500.ms).then().shake(hz: 2, duration: 400.ms),
        ]),
        const SizedBox(height: 32),
        Text("IT'S A MATCH!", style: TextStyle(fontSize: 28, color: AppTheme.accentGold,
                fontWeight: FontWeight.bold)).animate().fadeIn(delay: 600.ms, duration: 400.ms),
        const SizedBox(height: 12),
        Text('$myName & $theirName', style: Theme.of(context).textTheme.bodyLarge)
            .animate().fadeIn(delay: 800.ms, duration: 400.ms),
        const SizedBox(height: 48),
        ElevatedButton(onPressed: () => context.go('/chat/$chatId'),
            child: const Text('SEND A MESSAGE')).animate().fadeIn(delay: 1200.ms, duration: 400.ms),
        const SizedBox(height: 12),
        TextButton(onPressed: () => context.go('/browse'), child: const Text('KEEP SWIPING')),
      ],
    )));
  }
}
