# Phase 6 — XP & League System (UI)

## Goal
Add XP progress bars, level-up overlay animation, and league display to the Flutter app. The actual XP calculation and level/league updates already happen server-side in Phase 5's `awardXP()` function. This phase builds the client-side display and the level-up celebration UX.

> **No Go backend changes needed.** The server already handles XP math. This phase is Flutter-only.

## Prerequisites
Phases 1–5 complete: battles save results, XP/level/league update in PostgreSQL after each battle.

---

## 1. `lib/utils/xp_calculator.dart`

Client-side mirror of the server logic, used for display purposes only.

```dart
import '../config/constants.dart';

class XpCalculator {
  static int xpForLevel(int level) => level <= 1 ? 0 : (level - 1) * 100;

  static int levelForXp(int xp) => xp < 0 ? 1 : (xp ~/ 100) + 1;

  static double progressToNextLevel(int xp) {
    final currentLevel = levelForXp(xp);
    final currentThreshold = xpForLevel(currentLevel);
    final nextThreshold = xpForLevel(currentLevel + 1);
    final range = nextThreshold - currentThreshold;
    if (range <= 0) return 0;
    return (xp - currentThreshold) / range;
  }

  static String leagueForLevel(int level) {
    for (final entry in AppConstants.leagueRanges.entries) {
      if (level >= entry.value[0] && level <= entry.value[1]) return entry.key;
    }
    return 'Bronze';
  }
}
```

---

## 2. `lib/widgets/health_bar.dart`

```dart
import 'package:flutter/material.dart';
import '../config/theme.dart';

class HealthBar extends StatelessWidget {
  final double progress;
  final Color fillColor;
  final Color bgColor;
  final double height;
  final String? label;

  const HealthBar({super.key, required this.progress,
      this.fillColor = AppTheme.secondaryColor,
      this.bgColor = const Color(0xFF333333),
      this.height = 16, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Text(label!, style: Theme.of(context).textTheme.labelLarge)),
        Container(
          height: height,
          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(2)),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(color: fillColor, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ],
    );
  }
}
```

---

## 3. `lib/widgets/level_up_overlay.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';
import '../utils/league_helper.dart';

class LevelUpOverlay extends StatelessWidget {
  final int newLevel;
  final String newLeague;
  final bool leagueChanged;
  final VoidCallback onDismiss;

  const LevelUpOverlay({super.key, required this.newLevel, required this.newLeague,
      required this.leagueChanged, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final leagueColor = LeagueHelper.colorForLeague(newLeague);
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black87,
        child: Center(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LEVEL UP!', style: TextStyle(fontSize: 28, color: AppTheme.accentGold,
                    fontWeight: FontWeight.bold))
                .animate().scale(begin: const Offset(0.5, 0.5), duration: 400.ms)
                .then().shake(hz: 3, duration: 300.ms),
            const SizedBox(height: 16),
            Text('Level $newLevel', style: const TextStyle(fontSize: 22, color: Colors.white)),
            if (leagueChanged) ...[
              const SizedBox(height: 12),
              Text('NEW LEAGUE: $newLeague', style: TextStyle(fontSize: 18, color: leagueColor))
                  .animate().fadeIn(delay: 600.ms, duration: 400.ms),
            ],
            const SizedBox(height: 24),
            Text('Tap to continue', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))),
          ],
        )),
      ),
    );
  }
}
```

---

## 4. Integrate Level-Up Check into Battle Flow

After a battle ends, the Flutter app should re-fetch the user profile to get updated XP/level/league, then compare with the pre-battle values to determine if a level-up occurred.

In `BattleProvider`, add these fields:

```dart
int? previousLevel;
String? previousLeague;

void startSearching(String uid, String characterClass) {
  // ... existing code ...
  // Store current level/league before battle
  // (Caller should set these before calling startSearching)
}

void setPreBattleStats(int level, String league) {
  previousLevel = level;
  previousLeague = league;
}
```

In `BattleScreen`, after battle ends:
1. Re-fetch user profile via `UserProvider.loadUser(uid)`
2. Compare `user.level` with `bp.previousLevel` to detect level-up
3. If level-up, show `LevelUpOverlay`
4. Otherwise show normal VICTORY/DEFEAT overlay

---

## 5. Add XP Progress Bar to Profile Screen

In `ProfileScreen`, below XP text:

```dart
import '../../widgets/health_bar.dart';
import '../../utils/xp_calculator.dart';

// Inside the build method, after XP text:
HealthBar(
  progress: XpCalculator.progressToNextLevel(user.xp),
  fillColor: LeagueHelper.colorForLeague(user.league),
  label: '${user.xp} / ${XpCalculator.xpForLevel(user.level + 1)} XP',
),
```

---

## 6. Add XP Progress Bar to Home Screen

Show a compact XP bar in the Home screen below the class/level info. This will be fully implemented in Phase 10's final Home layout, but for now add:

```dart
import '../../widgets/health_bar.dart';
import '../../utils/xp_calculator.dart';
import '../../utils/league_helper.dart';

// Below the class/level text:
if (user != null)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 48),
    child: HealthBar(
      progress: XpCalculator.progressToNextLevel(user.xp),
      fillColor: LeagueHelper.colorForLeague(user.league),
      height: 10,
    ),
  ),
```

---

## 7. Verification Checklist

- [ ] XP progress bar shows on Profile screen with correct fill
- [ ] XP progress bar shows on Home screen
- [ ] After winning a battle, user profile refreshes with updated XP/level
- [ ] Level-up overlay appears when crossing a level boundary (e.g., 99 → 100 XP = Lv 1 → Lv 2)
- [ ] League change text appears when crossing league boundary (e.g., Lv 10 → 11 = Bronze → Silver)
- [ ] `XpCalculator.progressToNextLevel()` returns correct 0.0–1.0 values
- [ ] Tapping the level-up overlay dismisses it and returns to normal result screen

---

## What Phase 7 Expects

Phase 7 builds the Match Browser (swipe UI). It calls `GET /api/users/eligible` to fetch profiles. It expects the endpoint to return users filtered by level.
