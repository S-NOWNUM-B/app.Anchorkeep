import 'package:flutter/material.dart';

// Базовая M3-тема; токены и цвета уточняются по макетам (AK-06)
abstract final class AppTheme {
  static const _seed = Color(0xFF1B5E7A);

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
  );

  static final dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
  );
}
