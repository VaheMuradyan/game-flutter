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
