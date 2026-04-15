import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../config/theme.dart';
import '../../widgets/level_badge.dart';
import '../../utils/photo_url_helper.dart';
import '../../widgets/health_bar.dart';
import '../../utils/league_helper.dart';
import '../../utils/xp_calculator.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.user != null) {
      Provider.of<UserProvider>(context, listen: false).loadUser(auth.user!.uid);
    }
  }

  Future<void> _changePhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null) {
      await Provider.of<UserProvider>(context, listen: false).uploadPhoto(picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(builder: (context, up, _) {
      final user = up.user;
      if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

      final leagueColor = LeagueHelper.colorForLeague(user.league);
      final winRate = user.wins + user.losses > 0
          ? ((user.wins / (user.wins + user.losses)) * 100).toStringAsFixed(1) : '0.0';
      final photoUrl = PhotoUrlHelper.fullUrl(user.photoUrl);

      return Scaffold(
        appBar: AppBar(title: const Text('PROFILE'), centerTitle: true,
            backgroundColor: Colors.transparent, elevation: 0,
            actions: [
              IconButton(icon: const Icon(Icons.logout), onPressed: () {
                Provider.of<AuthProvider>(context, listen: false).signOut();
              }),
            ]),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            GestureDetector(
              onTap: _changePhoto,
              child: CircleAvatar(radius: 56, backgroundColor: AppTheme.surfaceColor,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty ? const Icon(Icons.camera_alt, size: 32, color: AppTheme.textSecondary) : null),
            ),
            const SizedBox(height: 12),
            Text(user.displayName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('${user.characterClass} · ${user.league}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: leagueColor)),
            const SizedBox(height: 24),
            LevelBadge(level: user.level, league: user.league, size: 72),
            const SizedBox(height: 8),
            Text('Level ${user.level}', style: Theme.of(context).textTheme.bodyLarge),
            Text('${user.xp} XP', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: HealthBar(
                progress: XpCalculator.progressToNextLevel(user.xp),
                fillColor: LeagueHelper.colorForLeague(user.league),
                label: '${user.xp} / ${XpCalculator.xpForLevel(user.level + 1)} XP',
              ),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _stat(context, '${user.wins}', 'WINS'),
              _stat(context, '${user.losses}', 'LOSSES'),
              _stat(context, '$winRate%', 'WIN RATE'),
            ]),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: const Text('BATTLE HISTORY'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accentGold),
                foregroundColor: AppTheme.accentGold,
              ),
              onPressed: () => context.push('/battle-history/${user.uid}'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: Icon(user.isPremium ? Icons.star : Icons.star_border),
              label: Text(user.isPremium ? 'PREMIUM ACTIVE' : 'GO PREMIUM'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accentGold),
                foregroundColor: AppTheme.accentGold,
              ),
              onPressed: () => context.push('/premium'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('SETTINGS'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.accentGold),
                foregroundColor: AppTheme.accentGold,
              ),
              onPressed: () => context.push('/settings'),
            ),
          ]),
        ),
      );
    });
  }

  Widget _stat(BuildContext context, String value, String label) => Column(children: [
    Text(value, style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 4),
    Text(label, style: Theme.of(context).textTheme.labelLarge),
  ]);
}
