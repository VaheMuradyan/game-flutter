import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _tabs = [
    ('/home', Icons.sports_esports, 'Arena'),
    ('/browse', Icons.favorite, 'Browse'),
    ('/chats', Icons.chat, 'Chats'),
    ('/profile', Icons.person, 'Profile'),
  ];

  int _currentIndex(String location) {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex(location),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surfaceColor,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondary,
        selectedFontSize: 10, unselectedFontSize: 10,
        onTap: (i) => context.go(_tabs[i].$1),
        items: _tabs.map((t) => BottomNavigationBarItem(icon: Icon(t.$2), label: t.$3)).toList(),
      ),
    );
  }
}
