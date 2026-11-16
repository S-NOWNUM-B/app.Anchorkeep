// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

/// Палитра Obsidian Gold из Figma UI Kit v0.1.
class VaultColors {
  const VaultColors({
    required this.canvas,
    required this.surface,
    required this.elevated,
    required this.soft,
    required this.line,
    required this.ink,
    required this.muted,
    required this.gold,
    required this.goldSoft,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color canvas;
  final Color surface;
  final Color elevated;
  final Color soft;
  final Color line;
  final Color ink;
  final Color muted;
  final Color gold;
  final Color goldSoft;
  final Color success;
  final Color warning;
  final Color danger;

  static const light = VaultColors(
    canvas: Color(0xFFF8F7F3),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    soft: Color(0xFFF0EEE8),
    line: Color(0xFFE6E3DC),
    ink: Color(0xFF1B1C1E),
    muted: Color(0xFF70757A),
    gold: Color(0xFFC99B43),
    goldSoft: Color(0xFFF4E9D1),
    success: Color(0xFF307852),
    warning: Color(0xFF9A6723),
    danger: Color(0xFFB64D46),
  );

  static const dark = VaultColors(
    canvas: Color(0xFF151719),
    surface: Color(0xFF222529),
    elevated: Color(0xFF292D31),
    soft: Color(0xFF303337),
    line: Color(0xFF363B3F),
    ink: Color(0xFFF7F5F1),
    muted: Color(0xFFACB0B4),
    gold: Color(0xFFD6AD5B),
    goldSoft: Color(0xFF383121),
    success: Color(0xFF9ACFAF),
    warning: Color(0xFFE4C484),
    danger: Color(0xFFF2A29C),
  );

  static VaultColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Общая сетка: на узком телефоне поля не прижимаются к краям, а на
/// широком окне рабочая область остаётся удобной для чтения.
abstract final class VaultLayout {
  static double gutter(double width) {
    if (width < 360) return 16;
    if (width < 600) return 20;
    if (width < 900) return 24;
    return 28;
  }

  static double heading(double width) => width < 360 ? 23 : 27;
}

abstract final class AppTheme {
  static final light = _build(VaultColors.light, Brightness.light);
  static final dark = _build(VaultColors.dark, Brightness.dark);

  static ThemeData _build(VaultColors c, Brightness brightness) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: c.gold,
          brightness: brightness,
        ).copyWith(
          primary: c.gold,
          onPrimary: brightness == Brightness.light
              ? Colors.white
              : const Color(0xFF1B1C1E),
          primaryContainer: c.goldSoft,
          onPrimaryContainer: c.ink,
          secondary: c.ink,
          onSecondary: c.canvas,
          surface: c.surface,
          onSurface: c.ink,
          error: c.danger,
          outline: c.line,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.canvas,
      dividerColor: c.line,
      appBarTheme: AppBarTheme(
        backgroundColor: c.canvas,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.line),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.gold,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: c.gold.withValues(alpha: .42),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: .8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.line),
          minimumSize: const Size(0, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.gold),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 18,
        shadowColor: Colors.black.withValues(alpha: .12),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.line),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        textStyle: TextStyle(color: c.ink, fontSize: 13),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: c.line),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.elevated,
        contentTextStyle: TextStyle(color: c.ink, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: TextStyle(color: c.muted, fontSize: 13),
        labelStyle: TextStyle(color: c.muted, fontSize: 13),
        floatingLabelStyle: TextStyle(color: c.gold, fontSize: 13),
        prefixIconColor: c.muted,
        suffixIconColor: c.muted,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.line),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.gold, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.danger),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.danger, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: c.line.withValues(alpha: .65)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
