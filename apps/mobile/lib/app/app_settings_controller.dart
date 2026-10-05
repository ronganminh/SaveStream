import 'dart:async';

import 'package:flutter/material.dart';

import '../core/storage/app_settings_store.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('en'),
    bool hasCompletedIntro = true,
    bool useSystemLocale = false,
    AppSettingsStore? store,
  }) : _themeMode = themeMode,
       _locale = locale,
       _useSystemLocale = useSystemLocale,
       _hasCompletedIntro = hasCompletedIntro,
       _store = store ?? MemoryAppSettingsStore();

  static const String _themeKey = 'settings.theme';
  static const String _localeKey = 'settings.locale';
  static const String _introKey = 'onboarding.intro.completed';

  final AppSettingsStore _store;
  ThemeMode _themeMode;
  Locale _locale;
  bool _useSystemLocale;
  bool _hasCompletedIntro;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get useSystemLocale => _useSystemLocale;
  bool get hasCompletedIntro => _hasCompletedIntro;

  Future<void> initialize() async {
    final String? themeValue = await _store.readString(_themeKey);
    final String? localeValue = await _store.readString(_localeKey);
    final String? introValue = await _store.readString(_introKey);

    final ThemeMode restoredTheme = _parseTheme(themeValue) ?? _themeMode;
    final bool restoredUseSystemLocale = localeValue == 'system';
    final Locale restoredLocale = restoredUseSystemLocale
        ? _systemLocale()
        : (_parseLocale(localeValue) ?? _locale);
    // A missing key means this install has not completed the V2 introduction.
    // Tests/previews that do not call initialize keep the constructor default.
    final bool restoredIntro = introValue == 'true';
    final bool changed =
        restoredTheme != _themeMode ||
        restoredLocale != _locale ||
        restoredUseSystemLocale != _useSystemLocale ||
        restoredIntro != _hasCompletedIntro;

    _themeMode = restoredTheme;
    _locale = restoredLocale;
    _useSystemLocale = restoredUseSystemLocale;
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
    if (_locale == value && !_useSystemLocale) {
      return;
    }
    _locale = value;
    _useSystemLocale = false;
    notifyListeners();
    unawaited(_store.writeString(_localeKey, value.languageCode));
  }

  void setSystemLocale() {
    final Locale value = _systemLocale();
    if (_useSystemLocale && _locale == value) {
      return;
    }
    _locale = value;
    _useSystemLocale = true;
    notifyListeners();
    unawaited(_store.writeString(_localeKey, 'system'));
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

  Locale _systemLocale() {
    final String languageCode =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return languageCode == 'vi' ? const Locale('vi') : const Locale('en');
  }
}
