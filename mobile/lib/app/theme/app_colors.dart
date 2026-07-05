import 'package:flutter/material.dart';

/// Raw brand palette for FairShare — the single source of truth for our colors.
///
/// IMPORTANT: we never sprinkle these hex values across the app. Screens and
/// widgets read *semantic roles* from the theme instead
/// (e.g. `Theme.of(context).colorScheme.primary`). That indirection is what
/// lets us re-skin the entire app from one place and stay correct in BOTH
/// light and dark mode. Hardcoding `Color(0xFFBFDFE2)` in a widget would break
/// dark mode and violate our "no hardcoded values" rule.
class AppColors {
  AppColors._(); // Private ctor: this class is a namespace, never instantiated.

  // ---- Light theme brand colors ----
  static const lightPrimary = Color(0xFFBFDFE2);
  static const lightSecondary = Color(0xFFFFDB7B);
  static const lightAccent = Color(0xFFFFFAC2);
  static const lightBackground = Color(0xFFF7EDEF);

  // ---- Dark theme brand colors ----
  static const darkPrimary = Color(0xFF935073);
  static const darkSecondary = Color(0xFFF6DBC0);
  static const darkAccent = Color(0xFFF8F4E9);
  static const darkBackground = Color(0xFF502D55);
}
