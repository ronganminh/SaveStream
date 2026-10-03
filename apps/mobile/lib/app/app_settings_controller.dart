import 'dart:async';

import 'package:flutter/material.dart';

import '../core/storage/app_settings_store.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('en'),
    bool hasCompletedIntro = true,
    AppSettingsStore? store,
  }) : _themeMode = themeMode,
       _locale = locale,
       _hasCompletedIntro = hasCompletedIntro,
       _store = store ?? MemoryAppSettingsStore();

  static const String _themeKey = 'settings.theme';
  static const String _localeKey = 'settings.locale';
  static const String _introKey = 'onboarding.intro.completed';

  final AppSettingsStore _store;
  ThemeMode _themeMode;
  Locale _locale;
  bool _hasCompletedIntro;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get hasCompletedIntro => _hasCompletedIntro;

  Future<void> initialize() async {
    final String? themeValue = await _store.readString(_themeKey);
    final String? localeValue = await _store.readString(_localeKey);
    final String? introValue = await _store.readString(_introKey);

    final ThemeMode restoredTheme = _parseTheme(themeValue) ?? _themeMode;
    final Locale restoredLocale = _parseLocale(localeValue) ?? _locale;
    // A missing key means this install has not completed the V2 introduction.
    // Tests/previews that do not call initialize keep the constructor default.
    final bool restoredIntro = introValue == 'true';
    final bool changed =
        restoredTheme != _themeMode ||
        restoredLocale != _locale ||
        restoredIntro != _hasCompletedIntro;

    _themeMode = restoredTheme;
    _locale = restoredLocale;
    _hasCompletedIntro = restoredIntro;

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

  Future<void> markIntroCompleted() async {
    if (!_hasCompletedIntro) {
      _hasCompletedIntro = true;
      notifyListeners();
    }
    await _store.writeString(_introKey, 'true');
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
