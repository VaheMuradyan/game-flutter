import 'dart:ui';

class ClassColors {
  static const Map<String, Color> primary = {
    'Warrior': Color(0xFFE74C3C),
    'Mage':    Color(0xFF9B59B6),
    'Archer':  Color(0xFF2ECC71),
    'Rogue':   Color(0xFF34495E),
    'Healer':  Color(0xFF3498DB),
  };

  static Color forClass(String cls) => primary[cls] ?? const Color(0xFFFFFFFF);
}
