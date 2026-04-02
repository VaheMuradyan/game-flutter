import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/level_badge.dart';
import '../../widgets/health_bar.dart';
import '../../utils/xp_calculator.dart';
import '../../utils/league_helper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      Provider.of<UserProvider>(context, listen: false).loadUser(auth.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(builder: (context, up, _) {
      final user = up.user;
      if (user == null) return const Center(child: CircularProgressIndicator());
      final leagueColor = LeagueHelper.colorForLeague(user.league);

      return SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
        children: [
          // Player card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: leagueColor.withOpacity(0.3))),
            child: Row(children: [
              CircleAvatar(radius: 32, backgroundColor: AppTheme.surfaceColor,
                  backgroundImage: user.photoUrl.isNotEmpty
                      ? NetworkImage(user.photoUrl.startsWith('http')
                          ? user.photoUrl : '${AppConstants.apiBaseUrl}${user.photoUrl}')
                      : null,
                  child: user.photoUrl.isEmpty ? const Icon(Icons.person) : null),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.displayName, style: Theme.of(context).textTheme.bodyLarge),
                Text('${user.characterClass} · ${user.league}',
                    style: TextStyle(color: leagueColor, fontSize: 11)),
                const SizedBox(height: 8),
                HealthBar(progress: XpCalculator.progressToNextLevel(user.xp),
                    fillColor: leagueColor, height: 8,
                    label: 'Lv ${user.level} · ${user.xp} XP'),
              ])),
              LevelBadge(level: user.level, league: user.league, size: 48),
            ]),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),

          const SizedBox(height: 32),

          // BATTLE button
          SizedBox(width: double.infinity, height: 64,
            child: ElevatedButton.icon(icon: const Icon(Icons.sports_esports, size: 28),
                label: const Text('FIND BATTLE'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor,
                    textStyle: const TextStyle(fontSize: 16)),
                onPressed: () => context.push('/battle/queue')),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 16),

          // Quick stats
          Row(children: [
            _stat(context, '${user.wins}', 'Wins', AppTheme.secondaryColor),
            const SizedBox(width: 12),
            _stat(context, '${user.losses}', 'Losses', AppTheme.primaryColor),
            const SizedBox(width: 12),
            _stat(context, user.league, 'League', leagueColor),
          ]).animate().fadeIn(delay: 400.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Quick links
          _linkTile(context, Icons.leaderboard, AppTheme.accentGold, 'Leaderboard', '/leaderboard'),
          const SizedBox(height: 8),
          _linkTile(context, Icons.history, AppTheme.secondaryColor, 'Battle History', '/battle-history/${user.uid}'),
        ],
      )));
    });
  }

  Widget _stat(BuildContext ctx, String value, String label, Color color) => Expanded(
    child: Container(padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(ctx).textTheme.labelLarge),
        ])));

  Widget _linkTile(BuildContext ctx, IconData icon, Color color, String title, String route) => ListTile(
    leading: Icon(icon, color: color),
    title: Text(title, style: Theme.of(ctx).textTheme.bodyLarge),
    trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
    tileColor: AppTheme.surfaceColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    onTap: () => ctx.push(route));
}
