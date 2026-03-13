import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
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

  const AppColorsExtension({
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
  });

  @override
  ThemeExtension<AppColorsExtension> copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accentIndigo,
    Color? accentCoral,
    Color? onAccent,
    Color? strokeSubtle,
  }) {
    return AppColorsExtension(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accentIndigo: accentIndigo ?? this.accentIndigo,
      accentCoral: accentCoral ?? this.accentCoral,
      onAccent: onAccent ?? this.onAccent,
      strokeSubtle: strokeSubtle ?? this.strokeSubtle,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accentIndigo: Color.lerp(accentIndigo, other.accentIndigo, t)!,
      accentCoral: Color.lerp(accentCoral, other.accentCoral, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      strokeSubtle: Color.lerp(strokeSubtle, other.strokeSubtle, t)!,
    );
  }

  static AppColorsExtension fromScheme(AppColorScheme scheme) {
    return AppColorsExtension(
      bg: scheme.bg,
      surface: scheme.surface,
      surfaceAlt: scheme.surfaceAlt,
      textPrimary: scheme.textPrimary,
      textSecondary: scheme.textSecondary,
      textTertiary: scheme.textTertiary,
      accentIndigo: scheme.accentIndigo,
      accentCoral: scheme.accentCoral,
      onAccent: scheme.onAccent,
      strokeSubtle: scheme.strokeSubtle,
    );
  }
}

class AppTheme {
  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.dmSansTextTheme(base);
  }

  static ThemeData light() {
    const colors = AppColors.light;
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: colors.bg,
      textTheme: _buildTextTheme(base.textTheme),
      colorScheme: ColorScheme.light(
        surface: colors.bg,
        primary: colors.accentIndigo,
        secondary: colors.surface,
        onPrimary: colors.onAccent,
        onSurface: colors.textPrimary,
      ),
      extensions: [AppColorsExtension.fromScheme(colors)],
    );
  }

  static ThemeData dark() {
    const colors = AppColors.dark;
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: colors.bg,
      textTheme: _buildTextTheme(base.textTheme),
      colorScheme: ColorScheme.dark(
        surface: colors.bg,
        primary: colors.accentIndigo,
        secondary: colors.surface,
        onPrimary: colors.onAccent,
        onSurface: colors.textPrimary,
      ),
      extensions: [AppColorsExtension.fromScheme(colors)],
    );
  }
}

extension ThemeExtensionAccess on BuildContext {
  AppColorsExtension get colors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
