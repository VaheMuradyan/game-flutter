import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_match/utils/league_helper.dart';

void main() {
  group('LeagueHelper.leagueForLevel', () {
    test('level 1 is Bronze', () {
      expect(LeagueHelper.leagueForLevel(1), 'Bronze');
    });

    test('level 10 is Bronze', () {
      expect(LeagueHelper.leagueForLevel(10), 'Bronze');
    });

    test('level 11 is Silver', () {
      expect(LeagueHelper.leagueForLevel(11), 'Silver');
    });

    test('level 31 is Gold', () {
      expect(LeagueHelper.leagueForLevel(31), 'Gold');
    });

    test('level 61 is Diamond', () {
      expect(LeagueHelper.leagueForLevel(61), 'Diamond');
    });

    test('level 100 is Legend', () {
      expect(LeagueHelper.leagueForLevel(100), 'Legend');
    });
  });
}
