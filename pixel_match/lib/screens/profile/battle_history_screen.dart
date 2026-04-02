import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/api_client.dart';
import '../../config/theme.dart';
import '../../models/battle_model.dart';

class BattleHistoryScreen extends StatefulWidget {
  final String uid;
  const BattleHistoryScreen({super.key, required this.uid});
  @override
  State<BattleHistoryScreen> createState() => _BattleHistoryScreenState();
}

class _BattleHistoryScreenState extends State<BattleHistoryScreen> {
  List<BattleModel> _battles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final resp = await ApiClient.get('/api/battles/history');
    final list = resp['battles'] as List? ?? [];
    _battles = list.map((j) => BattleModel.fromJson(j as Map<String, dynamic>)).toList();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BATTLE HISTORY'), centerTitle: true,
          backgroundColor: Colors.transparent, elevation: 0),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _battles.isEmpty
              ? const Center(child: Text('No battles yet.', style: TextStyle(color: AppTheme.textSecondary)))
              : ListView.builder(padding: const EdgeInsets.all(8), itemCount: _battles.length,
                  itemBuilder: (context, i) {
        final b = _battles[i];
        final won = b.winnerUid == widget.uid;
        final dateStr = DateFormat('MMM d, h:mm a').format(b.createdAt);
        return Container(
          margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(4),
              border: Border.all(color: (won ? AppTheme.secondaryColor : AppTheme.primaryColor).withOpacity(0.4))),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle,
                color: (won ? AppTheme.secondaryColor : AppTheme.primaryColor).withOpacity(0.2)),
                child: Center(child: Text(won ? 'W' : 'L', style: TextStyle(
                    color: won ? AppTheme.secondaryColor : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold, fontSize: 18)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(won ? 'Victory' : 'Defeat', style: Theme.of(context).textTheme.bodyLarge),
              Text(dateStr, style: Theme.of(context).textTheme.bodyMedium),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${won ? "+" : "-"}${b.xpAwarded} XP', style: TextStyle(
                  color: won ? AppTheme.secondaryColor : AppTheme.primaryColor, fontWeight: FontWeight.bold)),
              Text('HP: ${b.player1Uid == widget.uid ? b.player1Health : b.player2Health}',
                  style: Theme.of(context).textTheme.labelLarge),
            ]),
          ]),
        );
      }),
    );
  }
}
