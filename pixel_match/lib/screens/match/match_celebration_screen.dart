import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

class MatchCelebrationScreen extends StatefulWidget {
  final String myName;
  final String theirName;
  final String chatId;

  const MatchCelebrationScreen({
    super.key,
    required this.myName,
    required this.theirName,
    required this.chatId,
  });

  @override
  State<MatchCelebrationScreen> createState() => _MatchCelebrationScreenState();
}

class _MatchCelebrationScreenState extends State<MatchCelebrationScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _confetti.play();
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/browse');
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.35),
                    AppTheme.backgroundColor,
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              gravity: 0.2,
              emissionFrequency: 0.05,
              colors: const [
                AppTheme.primaryColor,
                AppTheme.secondaryColor,
                AppTheme.accentGold,
                Colors.white,
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _iconFrame(Icons.favorite, AppTheme.primaryColor)
                        .animate()
                        .scale(
                            begin: const Offset(0, 0),
                            duration: 500.ms,
                            curve: Curves.elasticOut)
                        .then()
                        .shake(hz: 2, duration: 400.ms),
                    const SizedBox(width: 20),
                    _iconFrame(Icons.bolt, AppTheme.accentGold)
                        .animate(delay: 200.ms)
                        .scale(
                            begin: const Offset(0, 0),
                            duration: 500.ms,
                            curve: Curves.elasticOut),
                    const SizedBox(width: 20),
                    _iconFrame(Icons.favorite, AppTheme.primaryColor)
                        .animate(delay: 400.ms)
                        .scale(
                            begin: const Offset(0, 0),
                            duration: 500.ms,
                            curve: Curves.elasticOut)
                        .then()
                        .shake(hz: 2, duration: 400.ms),
                  ]),
                  const SizedBox(height: 36),
                  Text(
                    "IT'S A MATCH!",
                    textAlign: TextAlign.center,
                    style: textTheme.displayMedium
                        ?.copyWith(color: AppTheme.accentGold),
                  )
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 400.ms)
                      .slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.myName} & ${widget.theirName}',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ).animate().fadeIn(delay: 800.ms, duration: 400.ms),
                  const SizedBox(height: 8),
                  Text(
                    'Prove yourself on the battlefield.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium,
                  ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
                  const SizedBox(height: 48),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        icon: const Icon(Icons.flash_on),
                        label: const Text('BATTLE NOW'),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          context.go('/battle/queue');
                        },
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 1100.ms, duration: 400.ms)
                      .slideY(begin: 0.3, end: 0)
                      .then()
                      .shimmer(
                          duration: 1800.ms,
                          color: Colors.white.withValues(alpha: 0.25)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.textSecondary),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: widget.chatId.isEmpty
                          ? null
                          : () => context.go('/chat/${widget.chatId}'),
                      child: const Text('SEND A MESSAGE'),
                    ),
                  ).animate().fadeIn(delay: 1250.ms, duration: 400.ms),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/browse'),
                    child: const Text('KEEP SWIPING'),
                  ).animate().fadeIn(delay: 1400.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _iconFrame(IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border.all(color: color, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, size: 56, color: color),
      );
}
