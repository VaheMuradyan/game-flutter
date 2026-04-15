import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/onboarding/welcome_screen.dart';
import '../screens/onboarding/class_selection_screen.dart';
import '../screens/onboarding/profile_setup_screen.dart';
import '../screens/home/home_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/browse/match_browser_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/battle_history_screen.dart';
import '../screens/battle/battle_queue_screen.dart';
import '../screens/battle/battle_screen.dart';
import '../screens/match/match_celebration_screen.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/premium/premium_screen.dart';
import '../screens/settings/settings_screen.dart';

CustomTransitionPage _pixelPage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey, child: child,
    transitionsBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child)),
    transitionDuration: const Duration(milliseconds: 250));
}

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final loc = state.matchedLocation;
    if (!auth.isAuthenticated && loc != '/') return '/';
    if (auth.isAuthenticated && !auth.isOnboarded && !loc.startsWith('/onboarding')) return '/onboarding/class';
    if (auth.isAuthenticated && auth.isOnboarded && (loc == '/' || loc.startsWith('/onboarding'))) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, s) => const WelcomeScreen()),
    GoRoute(path: '/onboarding/class', builder: (_, s) => const ClassSelectionScreen()),
    GoRoute(path: '/onboarding/profile', builder: (_, s) => const ProfileSetupScreen()),

    // Tabbed shell
    ShellRoute(
      builder: (_, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, s) => const HomeScreen()),
        GoRoute(path: '/browse', builder: (_, s) => const MatchBrowserScreen()),
        GoRoute(path: '/chats', builder: (_, s) => const ChatListScreen()),
        GoRoute(path: '/profile', builder: (_, s) => const ProfileScreen()),
      ],
    ),

    // Full-screen (outside tabs)
    GoRoute(path: '/battle/queue', pageBuilder: (_, s) => _pixelPage(const BattleQueueScreen(), s)),
    GoRoute(path: '/battle', pageBuilder: (_, s) =>
        _pixelPage(BattleScreen(playerClass: s.extra as String? ?? 'Warrior'), s)),
    GoRoute(path: '/chat/:chatId', pageBuilder: (_, s) =>
        _pixelPage(ChatScreen(chatId: s.pathParameters['chatId']!), s)),
    GoRoute(path: '/leaderboard', pageBuilder: (_, s) => _pixelPage(const LeaderboardScreen(), s)),
    GoRoute(path: '/premium', pageBuilder: (_, s) => _pixelPage(const PremiumScreen(), s)),
    GoRoute(path: '/settings', pageBuilder: (_, s) => _pixelPage(const SettingsScreen(), s)),
    GoRoute(path: '/battle-history/:uid', pageBuilder: (_, s) =>
        _pixelPage(BattleHistoryScreen(uid: s.pathParameters['uid']!), s)),
    GoRoute(path: '/match-celebration', pageBuilder: (_, s) {
      final e = s.extra as Map<String, String>;
      return _pixelPage(MatchCelebrationScreen(
          myName: e['myName']!, theirName: e['theirName']!, chatId: e['chatId']!), s);
    }),
  ],
);
