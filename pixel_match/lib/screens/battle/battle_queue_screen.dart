import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/battle_provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class BattleQueueScreen extends StatefulWidget {
  const BattleQueueScreen({super.key});
  @override
  State<BattleQueueScreen> createState() => _BattleQueueScreenState();
}

class _BattleQueueScreenState extends State<BattleQueueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      if (user != null) {
        final bp = Provider.of<BattleProvider>(context, listen: false);
        bp.setPreBattleStats(user.level, user.league);
        bp.startSearching(user.uid, user.characterClass);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BattleProvider>(builder: (context, bp, _) {
      if (bp.state == BattleState.battleActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/battle'));
      }
      return Scaffold(body: SafeArea(child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryColor),
          const SizedBox(height: 24),
          Text('SEARCHING FOR OPPONENT...', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 32),
          OutlinedButton(
            onPressed: () { bp.cancelSearch(); context.pop(); },
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryColor),
                foregroundColor: AppTheme.primaryColor),
            child: const Text('CANCEL'),
          ),
        ],
      ))));
    });
  }
}
