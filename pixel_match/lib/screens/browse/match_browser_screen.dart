import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/match_provider.dart';
import '../../config/theme.dart';
import '../../widgets/swipe_card.dart';

class MatchBrowserScreen extends StatefulWidget {
  const MatchBrowserScreen({super.key});
  @override
  State<MatchBrowserScreen> createState() => _MatchBrowserScreenState();
}

class _MatchBrowserScreenState extends State<MatchBrowserScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MatchProvider>(context, listen: false).loadProfiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BROWSE'), centerTitle: true,
          backgroundColor: Colors.transparent, elevation: 0),
      body: Consumer<MatchProvider>(builder: (context, mp, _) {
        if (mp.loading) return const Center(child: CircularProgressIndicator());

        if (mp.remainingSwipes <= 0) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('Daily swipe limit reached!', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('Come back tomorrow or go Premium.', style: Theme.of(context).textTheme.bodyMedium),
          ]));
        }

        if (!mp.hasProfiles) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 16),
            Text('No more profiles at your level.', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('Win battles to level up and see more!', style: Theme.of(context).textTheme.bodyMedium),
          ]));
        }

        final profile = mp.currentProfile!;

        return Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${mp.remainingSwipes} swipes remaining',
                  style: Theme.of(context).textTheme.labelLarge)),
          const SizedBox(height: 8),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SwipeCard(key: ValueKey(profile.uid), user: profile,
                onSwipeRight: () async {
                  final isMatch = await mp.like(profile.uid);
                  if (isMatch && context.mounted) _showMatchDialog(context, profile.displayName);
                },
                onSwipeLeft: () => mp.pass()))),
          Padding(padding: const EdgeInsets.all(24), child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(heroTag: 'pass', backgroundColor: Colors.redAccent,
                  onPressed: () => mp.pass(), child: const Icon(Icons.close)),
              FloatingActionButton(heroTag: 'like', backgroundColor: Colors.greenAccent,
                  onPressed: () async {
                    final isMatch = await mp.like(profile.uid);
                    if (isMatch && context.mounted) _showMatchDialog(context, profile.displayName);
                  }, child: const Icon(Icons.favorite)),
            ],
          )),
        ]);
      }),
    );
  }

  void _showMatchDialog(BuildContext context, String name) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppTheme.surfaceColor,
      title: Text("IT'S A MATCH!", style: TextStyle(color: AppTheme.accentGold)),
      content: Text('You and $name liked each other!'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('KEEP SWIPING')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('SAY HI')),
      ],
    ));
  }
}
