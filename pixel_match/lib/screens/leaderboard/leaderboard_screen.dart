import 'package:flutter/material.dart';
import '../../config/api_client.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../utils/league_helper.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _tabs = ['Global', ...AppConstants.leagueRanges.keys];
  Map<String, List<Map<String, dynamic>>> _data = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final global = await ApiClient.get('/api/leaderboard');
    _data['Global'] = List<Map<String, dynamic>>.from(global['entries'] ?? []);

    for (final league in AppConstants.leagueRanges.keys) {
      final resp = await ApiClient.get('/api/leaderboard/$league');
      _data[league] = List<Map<String, dynamic>>.from(resp['entries'] ?? []);
    }
    setState(() => _loading = false);
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LEADERBOARD'), centerTitle: true,
          backgroundColor: Colors.transparent, elevation: 0,
          bottom: TabBar(controller: _tabCtrl, isScrollable: true,
              indicatorColor: AppTheme.accentGold,
              tabs: _tabs.map((t) => Tab(text: t.toUpperCase())).toList())),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabCtrl, children: _tabs.map((tab) {
        final list = _data[tab] ?? [];
        if (list.isEmpty) {
          return const Center(child: Text('No players yet.', style: TextStyle(color: AppTheme.textSecondary)));
        }
        return ListView.builder(padding: const EdgeInsets.all(8), itemCount: list.length,
            itemBuilder: (context, i) {
          final e = list[i];
          final league = e['league'] ?? 'Bronze';
          final color = LeagueHelper.colorForLeague(league);
          return Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: i < 3 ? AppTheme.accentGold.withOpacity(0.08 * (3 - i)) : AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(4),
              border: i < 3 ? Border.all(color: AppTheme.accentGold.withOpacity(0.3)) : null),
            child: Row(children: [
              SizedBox(width: 36, child: Text('#${i + 1}', style: TextStyle(
                  fontWeight: FontWeight.bold, color: i == 0 ? AppTheme.accentGold : AppTheme.textPrimary, fontSize: 14))),
              Container(width: 36, height: 36, decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color.withOpacity(0.2)),
                  child: Center(child: Text((e['characterClass'] ?? 'W')[0],
                      style: TextStyle(color: color, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e['displayName'] ?? 'Unknown', style: Theme.of(context).textTheme.bodyLarge),
                Text('$league · Lv ${e['level']}', style: TextStyle(color: color, fontSize: 11)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${e['xp']} XP', style: Theme.of(context).textTheme.bodyMedium),
                Text('${e['wins'] ?? 0} W', style: Theme.of(context).textTheme.labelLarge),
              ]),
            ]),
          );
        });
      }).toList()),
    );
  }
}
