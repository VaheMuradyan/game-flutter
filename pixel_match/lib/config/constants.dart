import 'environment.dart';

class AppConstants {
  // Server — configured via --dart-define at build time
  static String get apiBaseUrl => Environment.apiHost;
  static String get wsBaseUrl => Environment.wsHost;

  // All tunable values below mirror design_reference/balance_sheet.md.
  // Server constants in pixelmatch-server/config/game_constants.go must match.

  // XP — balance_sheet.md §1
  static const int xpPerWin = 75;
  static const int xpPerLoss = -10;
  static const int startingXp = 0;
  static const int startingLevel = 1;

  // Battle — balance_sheet.md §3, §4
  static const int battleDurationSeconds = 150;
  static const int startingTowerHealth = 1200;
  static const double manaRegenPerSecond = 1.0;
  static const int maxMana = 10;
  static const double startingMana = 5.0;
  static const double troopCost = 3.0;
  static const int troopBaseDamage = 50;
  static const double troopSpeed = 60.0;
  static const double spellCost = 5.0;
  static const int spellDamage = 80;

  // Leagues — balance_sheet.md §2
  static const Map<String, List<int>> leagueRanges = {
    'Bronze': [1, 5],
    'Silver': [6, 12],
    'Gold': [13, 22],
    'Diamond': [23, 40],
    'Legend': [41, 9999],
  };

  // Character classes
  static const List<String> characterClasses = [
    'Warrior',
    'Mage',
    'Archer',
    'Rogue',
    'Healer',
  ];

  // Swipe limits — balance_sheet.md §6
  static const int dailyFreeSwipes = 25;

  // Pixel emotes
  static const List<Map<String, String>> pixelEmotes = [
    {'code': 'sword', 'emoji': '\u2694\uFE0F', 'label': 'Battle!'},
    {'code': 'heart', 'emoji': '\u2764\uFE0F', 'label': 'Love'},
    {'code': 'fire', 'emoji': '\uD83D\uDD25', 'label': 'Fire'},
    {'code': 'trophy', 'emoji': '\uD83C\uDFC6', 'label': 'Winner'},
    {'code': 'shield', 'emoji': '\uD83D\uDEE1\uFE0F', 'label': 'Defend'},
    {'code': 'laugh', 'emoji': '\uD83D\uDE02', 'label': 'LOL'},
    {'code': 'wave', 'emoji': '\uD83D\uDC4B', 'label': 'Hey'},
    {'code': 'crown', 'emoji': '\uD83D\uDC51', 'label': 'King'},
  ];
}
