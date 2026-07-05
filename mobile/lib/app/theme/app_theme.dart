import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the light and dark [ThemeData] for FairShare.
///
/// STRATEGY (worth understanding — it's the heart of Material 3 theming):
/// A Material 3 [ColorScheme] has ~30 "roles" (primary, onPrimary,
/// primaryContainer, surface, outline, error, ...). Defining all 30 by hand is
/// tedious and easy to get wrong (bad contrast = unreadable text). So we:
///   1. Generate a COMPLETE, accessible palette with [ColorScheme.fromSeed].
///   2. Override only the handful of roles our brand pins down, and set the
///      matching `onX` (text/icon) colors so contrast stays readable.
/// This gives brand fidelity AND completeness.
class AppTheme {
  AppTheme._();

  /// Our design system's default corner radius.
  static const double radius = 16.0;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.lightPrimary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.lightPrimary,
      // Our primary is very light, so text/icons ON it must be dark to be legible.
      onPrimary: const Color(0xFF0E2E31),
      secondary: AppColors.lightSecondary,
      onSecondary: const Color(0xFF3A2E00),
      tertiary: AppColors.lightAccent,
      onTertiary: const Color(0xFF3A3800),
      surface: Colors.white, // cards sit just above the tinted page background
      onSurface: const Color(0xFF1A1A1A),
    );
    return _base(scheme, AppColors.lightBackground);
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.darkPrimary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.darkPrimary,
      onPrimary: Colors.white,
      secondary: AppColors.darkSecondary,
      onSecondary: const Color(0xFF3A2E1E),
      tertiary: AppColors.darkAccent,
      onTertiary: const Color(0xFF2E2A20),
      surface: const Color(0xFF5E3862), // card color, lifted above the bg
      onSurface: const Color(0xFFF3E9EE),
    );
    return _base(scheme, AppColors.darkBackground);
  }

  /// Component styling shared by both themes, so light/dark stay consistent.
  static ThemeData _base(ColorScheme scheme, Color scaffoldBg) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      // Flat, soft app bars — our design rule bans heavy shadows.
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
      ),
      // Cards: subtle elevation + 16px corners.
      cardTheme: CardThemeData(
        elevation: 1,
        clipBehavior: Clip.antiAlias,
        shape: shape,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 1,
        backgroundColor: scheme.surface,
      ),
    );
  }
}
