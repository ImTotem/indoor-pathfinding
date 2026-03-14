import 'package:flutter/material.dart';

class AppColors {
  // Light mode
  static const light = AppColorScheme(
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFF6F7F8),
    surfaceAlt: Color(0xFFE0E7FF),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9CA3AF),
    accentIndigo: Color(0xFF2563EB),
    accentCoral: Color(0xFF2563EB),
    onAccent: Color(0xFFFFFFFF),
    strokeSubtle: Color(0xFFF3F4F6),
    card: Color(0xFFFFFFFF),
    foreground: Color(0xFF111111),
    muted: Color(0xFFF2F3F0),
    mutedForeground: Color(0xFF666666),
    primary: Color(0xFFFF8400),
    secondary: Color(0xFFE7E8E5),
    secondaryForeground: Color(0xFF111111),
    border: Color(0xFFCBCCC9),
  );

  // Dark mode
  static const dark = AppColorScheme(
    bg: Color(0xFF0B0F17),
    surface: Color(0xFF1A2230),
    surfaceAlt: Color(0xFF202B3D),
    textPrimary: Color(0xFFF2F5F8),
    textSecondary: Color(0xFFA7B0BF),
    textTertiary: Color(0xFF8A94A6),
    accentIndigo: Color(0xFF4F7DFF),
    accentCoral: Color(0xFF3B82F6),
    onAccent: Color(0xFFFFFFFF),
    strokeSubtle: Color(0xFF2B3442),
    card: Color(0xFF1A1A1A),
    foreground: Color(0xFFFFFFFF),
    muted: Color(0xFF2E2E2E),
    mutedForeground: Color(0xFFB8B9B6),
    primary: Color(0xFFFF8400),
    secondary: Color(0xFF2E2E2E),
    secondaryForeground: Color(0xFFFFFFFF),
    border: Color(0xFF2E2E2E),
  );
}

class AppColorScheme {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accentIndigo;
  final Color accentCoral;
  final Color onAccent;
  final Color strokeSubtle;
  final Color card;
  final Color foreground;
  final Color muted;
  final Color mutedForeground;
  final Color primary;
  final Color secondary;
  final Color secondaryForeground;
  final Color border;

  const AppColorScheme({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentIndigo,
    required this.accentCoral,
    required this.onAccent,
    required this.strokeSubtle,
    required this.card,
    required this.foreground,
    required this.muted,
    required this.mutedForeground,
    required this.primary,
    required this.secondary,
    required this.secondaryForeground,
    required this.border,
  });
}
