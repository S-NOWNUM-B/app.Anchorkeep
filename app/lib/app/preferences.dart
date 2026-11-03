// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _preferences = SharedPreferencesAsync();

/// Тема и язык доступны ещё до разблокировки сейфа.
class ThemeModeController extends Notifier<ThemeMode> {
  bool _changed = false;

  @override
  ThemeMode build() {
    unawaited(_load());
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final saved = await _preferences.getString('ui.theme');
      if (ref.mounted && !_changed) {
        state = ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
      }
    } catch (_) {}
  }

  void setMode(ThemeMode value) {
    _changed = true;
    state = value;
    unawaited(
      _preferences.setString('ui.theme', value.name).catchError((Object _) {}),
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class LanguageController extends Notifier<Locale> {
  bool _changed = false;

  @override
  Locale build() {
    unawaited(_load());
    return const Locale('ru');
  }

  Future<void> _load() async {
    try {
      final saved = await _preferences.getString('ui.language');
      if (ref.mounted && !_changed && (saved == 'ru' || saved == 'en')) {
        state = Locale(saved!);
      }
    } catch (_) {}
  }

  void setLanguage(Locale value) {
    if (value.languageCode != 'ru' && value.languageCode != 'en') return;
    _changed = true;
    state = value;
    unawaited(
      _preferences
          .setString('ui.language', value.languageCode)
          .catchError((Object _) {}),
    );
  }

  void toggle() => setLanguage(
    state.languageCode == 'ru' ? const Locale('en') : const Locale('ru'),
  );
}

final languageProvider = NotifierProvider<LanguageController, Locale>(
  LanguageController.new,
);
