class AppConstants {
  // Server — change this to your server's IP
  static const String apiBaseUrl = 'http://YOUR_SERVER_IP:8080';
  static const String wsBaseUrl = 'ws://YOUR_SERVER_IP:8080';

  // XP
  static const int xpPerWin = 50;
  static const int xpPerLoss = -20;
  static const int startingXp = 0;
  static const int startingLevel = 1;

  // Battle
  static const int battleDurationSeconds = 180;
  static const int startingTowerHealth = 1000;
  static const double manaRegenPerSecond = 1.0;
  static const int maxMana = 10;

  // Leagues
  static const Map<String, List<int>> leagueRanges = {
    'Bronze': [1, 10],
    'Silver': [11, 30],
    'Gold': [31, 60],
    'Diamond': [61, 99],
    'Legend': [100, 9999],
  };

  // Character classes
  static const List<String> characterClasses = [
    'Warrior',
    'Mage',
    'Archer',
    'Rogue',
    'Healer',
  ];

  // Swipe limits (free tier)
  static const int dailyFreeSwipes = 20;

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
