import '../config/constants.dart';
import '../config/theme.dart';
import 'package:flutter/material.dart';

class LeagueHelper {
  static String leagueForLevel(int level) {
    for (final entry in AppConstants.leagueRanges.entries) {
      if (level >= entry.value[0] && level <= entry.value[1]) return entry.key;
    }
    return 'Bronze';
  }

  static Color colorForLeague(String league) {
    switch (league) {
      case 'Silver': return AppTheme.silverColor;
      case 'Gold': return AppTheme.goldColor;
      case 'Diamond': return AppTheme.diamondColor;
      case 'Legend': return AppTheme.legendColor;
      default: return AppTheme.bronzeColor;
    }
  }
}
