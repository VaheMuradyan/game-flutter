import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../config/constants.dart';

class BattleResultScreen extends StatefulWidget {
  final bool won;
  final int xpDelta;
  final int level;
  final String league;
  final int damageDealt;
  final int troopsDeployed;
  final Duration matchDuration;
  final VoidCallback onRematch;
  final VoidCallback onClose;

  const BattleResultScreen({
    super.key,
    required this.won,
    required this.xpDelta,
    required this.level,
    required this.league,
    required this.damageDealt,
    required this.troopsDeployed,
    required this.matchDuration,
    required this.onRematch,
    required this.onClose,
  });

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _leagueProgress {
    final range = AppConstants.leagueRanges[widget.league];
    if (range == null || range.length < 2) return 0;
    final min = range[0];
    final max = range[1];
    final span = max - min + 1;
    return ((widget.level - min + 1) / span).clamp(0.0, 1.0);
  }

  Color get _leagueColor {
    switch (widget.league) {
      case 'Bronze':
        return AppTheme.bronzeColor;
      case 'Silver':
        return AppTheme.silverColor;
      case 'Gold':
        return AppTheme.goldColor;
      case 'Diamond':
        return AppTheme.diamondColor;
      case 'Legend':
        return AppTheme.legendColor;
    }
    return AppTheme.accentGold;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.won ? AppTheme.accentGold : AppTheme.primaryColor;

    return FadeTransition(
      opacity: _ctrl,
      child: Container(
        color: Colors.black.withValues(alpha: 0.88),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween<double>(begin: 0.6, end: 1.0).animate(
                    CurvedAnimation(
                        parent: _ctrl, curve: Curves.elasticOut),
                  ),
                  child: Text(
                    widget.won ? 'VICTORY!' : 'DEFEAT',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge!
                        .copyWith(
                          fontSize: 32,
                          color: accent,
                          shadows: [
                            Shadow(
                              color: accent.withValues(alpha: 0.7),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.6), width: 1),
                  ),
                  child: Text(
                    '${widget.xpDelta >= 0 ? '+' : ''}${widget.xpDelta} XP',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium!
                        .copyWith(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 160,
                  height: 160,
                  child: AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) {
                      final progressValue = _leagueProgress * _ctrl.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: progressValue,
                              strokeWidth: 8,
                              backgroundColor: Colors.white12,
                              valueColor: AlwaysStoppedAnimation(_leagueColor),
                            ),
                          ),
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: _leagueColor, width: 2),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('LVL',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white70,
                                        fontFamily: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.fontFamily)),
                                const SizedBox(height: 2),
                                Text('${widget.level}',
                                    style: TextStyle(
                                        fontSize: 28,
                                        color: _leagueColor,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: Theme.of(context)
                                            .textTheme
                                            .headlineLarge
                                            ?.fontFamily)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.league.toUpperCase()} LEAGUE',
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge!
                      .copyWith(color: _leagueColor, fontSize: 10),
                ),
                const SizedBox(height: 24),
                _statRow('DAMAGE DEALT', '${widget.damageDealt}'),
                const SizedBox(height: 6),
                _statRow('TROOPS DEPLOYED', '${widget.troopsDeployed}'),
                const SizedBox(height: 6),
                _statRow('DURATION', _formatDuration(widget.matchDuration)),
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      onPressed: widget.onClose,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      child: Text('ARENA',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge!
                              .copyWith(fontSize: 9)),
                    ),
                    const SizedBox(width: 14),
                    ElevatedButton(
                      onPressed: widget.onRematch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      child: Text('REMATCH',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge!
                              .copyWith(
                                fontSize: 9,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              )),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
        border: const Border(
          left: BorderSide(color: AppTheme.secondaryColor, width: 3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge!
                  .copyWith(fontSize: 8, color: Colors.white70)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge!
                  .copyWith(
                      fontSize: 10,
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
