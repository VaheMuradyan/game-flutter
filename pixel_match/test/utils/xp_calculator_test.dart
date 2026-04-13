import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_match/utils/xp_calculator.dart';

void main() {
  group('XpCalculator', () {
    test('xpForLevel returns 0 for level 1', () {
      expect(XpCalculator.xpForLevel(1), 0);
    });

    test('xpForLevel returns 100 for level 2', () {
      expect(XpCalculator.xpForLevel(2), 100);
    });

    test('levelForXp returns 1 for 0 XP', () {
      expect(XpCalculator.levelForXp(0), 1);
    });

    test('levelForXp returns 2 for 100 XP', () {
      expect(XpCalculator.levelForXp(100), 2);
    });

    test('levelForXp returns 1 for negative XP', () {
      expect(XpCalculator.levelForXp(-50), 1);
    });

    test('progressToNextLevel at level start is 0', () {
      expect(XpCalculator.progressToNextLevel(0), 0.0);
    });

    test('progressToNextLevel at 50 XP is 0.5', () {
      expect(XpCalculator.progressToNextLevel(50), 0.5);
    });
  });
}
