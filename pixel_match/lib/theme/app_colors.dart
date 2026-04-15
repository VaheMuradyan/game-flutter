import 'package:flutter/material.dart';

/// PixelMatch brand palette.
///
/// The identity balances the two halves of the product: the romance side
/// (hot pink / coral) and the battle side (electric cyan). The dark navy
/// base keeps the pixel-art aesthetic readable and ties everything together.
///
/// Use the semantic tokens (primary, accent, danger, success, surface…)
/// from screens and widgets. Raw hex values should not appear outside this
/// file or `app_theme.dart`.
class AppColors {
  AppColors._();

  // --- Brand ---
  // Pink is warmed toward coral (#FF6B6B family) so it reads as arcade/battle
  // rather than generic "dating app magenta", and harmonizes with the battle
  // HUD reference mocks. Cyan stays the same — it already matches. Gold is
  // nudged toward a richer amber so it feels like a retro CRT highlight
  // instead of a web-y lemon yellow.
  static const Color brandPink = Color(0xFFFF6B6B);
  static const Color brandPinkDark = Color(0xFFD94A4A);
  static const Color brandCyan = Color(0xFF4ECDC4);
  static const Color brandCyanDark = Color(0xFF2AA39B);
  static const Color brandGold = Color(0xFFE8C426);

  // --- Semantic roles ---
  static const Color primary = brandPink;
  static const Color primaryDark = brandPinkDark;
  static const Color accent = brandCyan;
  static const Color accentDark = brandCyanDark;
  static const Color highlight = brandGold;

  static const Color danger = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);
  static const Color success = Color(0xFF2ECC71);
  static const Color info = Color(0xFF3D8BFF);

  // --- Surfaces ---
  /// App background — deep navy, darkest layer.
  static const Color background = Color(0xFF0B0B1A);

  /// Cards, sheets, and elevated surfaces.
  static const Color surface = Color(0xFF16162A);

  /// Second-level surface (nested cards, inputs).
  static const Color surfaceAlt = Color(0xFF1F1F3A);

  /// Hairline borders on dark surfaces.
  static const Color border = Color(0x22FFFFFF);

  /// Overlay for modals / scrims.
  static const Color scrim = Color(0xCC000000);

  // --- Text ---
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB8B8D1);
  static const Color textMuted = Color(0xFF7A7A94);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnAccent = Color(0xFF0B0B1A);

  // --- League tiers (kept stable — shown in UI and referenced by league_helper) ---
  static const Color leagueBronze = Color(0xFFCD7F32);
  static const Color leagueSilver = Color(0xFFC0C0C0);
  static const Color leagueGold = Color(0xFFFFD700);
  static const Color leagueDiamond = Color(0xFFB9F2FF);
  static const Color leagueLegend = Color(0xFFFF4500);
}
