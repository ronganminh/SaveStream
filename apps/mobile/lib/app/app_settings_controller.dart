import 'dart:async';

import 'package:flutter/material.dart';

import '../core/storage/app_settings_store.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('en'),
    AppSettingsStore? store,
  }) : _themeMode = themeMode,
       _locale = locale,
       _store = store ?? MemoryAppSettingsStore();

  static const String _themeKey = 'settings.theme';
  static const String _localeKey = 'settings.locale';

  final AppSettingsStore _store;
  ThemeMode _themeMode;
  Locale _locale;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  Future<void> initialize() async {
    final String? themeValue = await _store.readString(_themeKey);
    final String? localeValue = await _store.readString(_localeKey);

    final ThemeMode restoredTheme = _parseTheme(themeValue) ?? _themeMode;
    final Locale restoredLocale = _parseLocale(localeValue) ?? _locale;
    final bool changed =
        restoredTheme != _themeMode || restoredLocale != _locale;

    _themeMode = restoredTheme;
    _locale = restoredLocale;

    if (changed) {
      notifyListeners();
    }
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }
    _themeMode = value;
    notifyListeners();
    unawaited(_store.writeString(_themeKey, value.name));
  }

  void setLocale(Locale value) {
    if (_locale == value) {
      return;
    }
    _locale = value;
    notifyListeners();
    unawaited(_store.writeString(_localeKey, value.languageCode));
  }

  ThemeMode? _parseTheme(String? value) {
    for (final ThemeMode mode in ThemeMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return null;
  }

  Locale? _parseLocale(String? value) {
    return switch (value) {
      'en' => const Locale('en'),
      'vi' => const Locale('vi'),
      _ => null,
    };
  }
}
