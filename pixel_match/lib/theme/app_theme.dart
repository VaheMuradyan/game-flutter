import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

export 'app_colors.dart';

/// Central `ThemeData` for PixelMatch.
///
/// Every screen should consume `Theme.of(context)` or the `AppTheme.*`
/// constants — no raw hex values in widgets. Typography uses
/// `PressStart2P` for headlines (pixel-art voice) and a cleaner mono-ish
/// body ramp for readability at small sizes.
class AppTheme {
  AppTheme._();

  // --- Backwards-compatible color accessors ---
  // Kept so older code that references `AppTheme.primaryColor` keeps working
  // after the migration to the new `AppColors` token set.
  static const Color primaryColor = AppColors.primary;
  static const Color secondaryColor = AppColors.accent;
  static const Color backgroundColor = AppColors.background;
  static const Color surfaceColor = AppColors.surface;
  static const Color accentGold = AppColors.highlight;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textSecondary = AppColors.textSecondary;

  static const Color bronzeColor = AppColors.leagueBronze;
  static const Color silverColor = AppColors.leagueSilver;
  static const Color goldColor = AppColors.leagueGold;
  static const Color diamondColor = AppColors.leagueDiamond;
  static const Color legendColor = AppColors.leagueLegend;

  // --- Spacing scale (4px grid) ---
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space8 = 32;

  // --- Radius scale ---
  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 12;

  /// Two-font pixel ramp:
  ///  - `PressStart2P` for display / headline / title — the loud pixel-shout
  ///    voice used for hero titles, screen headers, and card headings.
  ///  - `VT323` for body, labels, and captions — a pixel-style terminal font
  ///    that stays readable down to ~14px, where `PressStart2P` becomes a
  ///    blurry brick. Both are pulled from Google Fonts at runtime.
  ///
  /// Sizes are tuned so the body text is actually legible: `VT323` has tall
  /// x-height and reads ~30% smaller than a typical sans at the same px, so
  /// body is bumped up into the 16–20px range where `PressStart2P` would
  /// previously have been 9–12px.
  static TextTheme _buildTextTheme() {
    // Display / headline / title — PressStart2P (chunky pixel voice).
    final display = GoogleFonts.pressStart2pTextTheme(
      const TextTheme(
        // Display / hero titles
        displayLarge: TextStyle(fontSize: 28, color: AppColors.textPrimary, height: 1.3),
        displayMedium: TextStyle(fontSize: 22, color: AppColors.textPrimary, height: 1.3),
        displaySmall: TextStyle(fontSize: 18, color: AppColors.textPrimary, height: 1.3),

        // Section headlines
        headlineLarge: TextStyle(fontSize: 18, color: AppColors.textPrimary, height: 1.35),
        headlineMedium: TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.35),
        headlineSmall: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.35),

        // Titles / card headings (still PressStart2P — short strings only)
        titleLarge: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4, letterSpacing: 0.5),
        titleMedium: TextStyle(fontSize: 11, color: AppColors.textPrimary, height: 1.4, letterSpacing: 0.5),
        titleSmall: TextStyle(fontSize: 9, color: AppColors.textSecondary, height: 1.4, letterSpacing: 0.5),
      ),
    );

    // Body / labels — VT323, a pixel-style terminal font that stays readable.
    final body = GoogleFonts.vt323TextTheme(
      const TextTheme(
        // Body copy — profile bios, descriptions, chat messages
        bodyLarge: TextStyle(fontSize: 20, color: AppColors.textPrimary, height: 1.3),
        bodyMedium: TextStyle(fontSize: 18, color: AppColors.textSecondary, height: 1.3),
        bodySmall: TextStyle(fontSize: 16, color: AppColors.textMuted, height: 1.3),

        // Labels / buttons / captions
        labelLarge: TextStyle(fontSize: 18, color: AppColors.textPrimary, letterSpacing: 0.5),
        labelMedium: TextStyle(fontSize: 16, color: AppColors.textPrimary, letterSpacing: 0.5),
        labelSmall: TextStyle(fontSize: 14, color: AppColors.textSecondary, letterSpacing: 0.5),
      ),
    );

    return display.copyWith(
      bodyLarge: body.bodyLarge,
      bodyMedium: body.bodyMedium,
      bodySmall: body.bodySmall,
      labelLarge: body.labelLarge,
      labelMedium: body.labelMedium,
      labelSmall: body.labelSmall,
    );
  }

  static ThemeData get darkTheme {
    final textTheme = _buildTextTheme();
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        secondary: AppColors.accent,
        onSecondary: AppColors.textOnAccent,
        tertiary: AppColors.highlight,
        error: AppColors.danger,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceAlt,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: textTheme.titleLarge,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: textTheme.bodyMedium,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
