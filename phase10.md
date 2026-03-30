# Phase 10 — Polish & Launch Prep

## Goal
Final polish: replace Home screen with a bottom-navigation shell, add page transition animations, create the final Home (Arena) layout, and verify the entire app works end to end. No new Go endpoints needed.

> **NO APP STORE SUBMISSION IN THIS PHASE.** Google Play / App Store publishing, app icons, splash screens, signing keys, and store listings are all deferred to after testing. This phase focuses only on making the app feel complete and polished.

> **NO FIREBASE.** Everything runs on the self-hosted Go + PostgreSQL backend.

## Prerequisites
Phases 1–9 complete: all screens, services, providers, game engine, chat, leaderboard work.

---

## 1. Bottom Navigation Shell — `lib/screens/home/home_shell.dart`

```dart
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
```

---

## 2. Final Home Screen (Arena) — `lib/screens/home/home_screen.dart`

```dart
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
```

---

## 3. Page Transition Helper

In `lib/config/routes.dart`, add:

```dart
CustomTransitionPage _pixelPage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey, child: child,
    transitionsBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child)),
    transitionDuration: const Duration(milliseconds: 250),
  );
}
```

Use `pageBuilder` instead of `builder` on full-screen routes (battle, chat, leaderboard, etc.).

---

## 4. Final `lib/config/routes.dart`

```dart
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
    GoRoute(path: '/battle-history/:uid', pageBuilder: (_, s) =>
        _pixelPage(BattleHistoryScreen(uid: s.pathParameters['uid']!), s)),
    GoRoute(path: '/match-celebration', pageBuilder: (_, s) {
      final e = s.extra as Map<String, String>;
      return _pixelPage(MatchCelebrationScreen(
          myName: e['myName']!, theirName: e['theirName']!, chatId: e['chatId']!), s);
    }),
  ],
);
```

---

## 5. Final `lib/app.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/battle_provider.dart';
import 'providers/match_provider.dart';
import 'providers/chat_provider.dart';

class PixelMatchApp extends StatelessWidget {
  const PixelMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BattleProvider()),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp.router(
        title: 'PixelMatch',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        routerConfig: appRouter,
      ),
    );
  }
}
```

---

## 6. Full Verification Checklist — Entire App

### Auth & Onboarding
- [ ] Sign up → class selection → profile setup → Arena tab
- [ ] Log in → straight to Arena (if onboarded)
- [ ] Sign out → Welcome screen
- [ ] JWT saved locally, auto-login on restart

### Battle
- [ ] FIND BATTLE → queue → match → battle starts
- [ ] Troops deploy, walk, deal damage
- [ ] Mana regenerates, costs 3 per troop
- [ ] Timer ends at 3 minutes, highest HP wins
- [ ] XP/level/league updated in PostgreSQL
- [ ] Battle result saved to `battles` table

### XP & Leagues
- [ ] +50 XP on win, −20 on loss (min 0)
- [ ] Level = (XP ÷ 100) + 1
- [ ] Leagues: Bronze 1–10, Silver 11–30, Gold 31–60, Diamond 61–99, Legend 100+
- [ ] XP bar shows progress on Arena and Profile

### Match Browser
- [ ] Shows profiles at user's level or below
- [ ] Already-liked hidden
- [ ] Swipe right = like, mutual = match
- [ ] Daily limit of 20 free swipes
- [ ] Empty state prompts leveling up

### Chat
- [ ] Match list shows all matches with other user info
- [ ] Text messages send and appear (2-second polling)
- [ ] Pixel emotes work
- [ ] Match celebration animates

### Leaderboard & Stats
- [ ] Global + league tabs, sorted by XP
- [ ] Battle history shows W/L, XP, date

### Navigation
- [ ] Bottom nav: Arena, Browse, Chats, Profile
- [ ] Full-screen routes (battle, chat, leaderboard) hide bottom nav
- [ ] Page transitions are smooth

---

## Summary of All Files Across All 10 Phases

### Go Server (`~/pixelmatch-server/`)
```
go.mod, go.sum, main.go
config/config.go
database/db.go
models/user.go, battle.go, match.go, message.go
handlers/auth.go, user.go, matchmaking.go, chat.go, leaderboard.go
middleware/auth.go
websocket/battle_ws.go
uploads/
```

### Flutter App (`~/pixel_match/`)
```
lib/
├── main.dart, app.dart
├── config/ (constants.dart, theme.dart, routes.dart, api_client.dart)
├── models/ (user_model.dart, battle_model.dart, match_model.dart, message_model.dart)
├── services/ (auth_service.dart, user_service.dart, matchmaking_service.dart, chat_service.dart, websocket_service.dart)
├── providers/ (auth_provider.dart, user_provider.dart, battle_provider.dart, match_provider.dart, chat_provider.dart)
├── screens/
│   ├── onboarding/ (welcome_screen.dart, class_selection_screen.dart, profile_setup_screen.dart)
│   ├── home/ (home_shell.dart, home_screen.dart)
│   ├── battle/ (battle_queue_screen.dart, battle_screen.dart)
│   ├── browse/ (match_browser_screen.dart)
│   ├── match/ (match_celebration_screen.dart)
│   ├── chat/ (chat_list_screen.dart, chat_screen.dart)
│   ├── profile/ (profile_screen.dart, battle_history_screen.dart)
│   └── leaderboard/ (leaderboard_screen.dart)
├── widgets/ (pixel_card.dart, level_badge.dart, health_bar.dart, level_up_overlay.dart, swipe_card.dart)
├── game/ (pixel_match_game.dart, class_colors.dart, components/)
└── utils/ (xp_calculator.dart, league_helper.dart)
```

### Database (PostgreSQL `pixelmatch`)
```
Tables: users, battles, likes, matches, chats, messages
```

---

## What Comes AFTER Phase 10 (not in these files)

These are deferred and should be done manually after the app is tested:
- Google Play developer account ($25) and app signing
- App icon design (1024×1024 pixel art PNG)
- Splash screen
- `flutter build appbundle` and Play Console submission
- iOS: Apple Developer account ($99/year), Xcode signing
- Production PostgreSQL hardening (connection pooling, backups)
- HTTPS via Nginx + Let's Encrypt
- Premium/monetization integration (RevenueCat or in-app purchases)
