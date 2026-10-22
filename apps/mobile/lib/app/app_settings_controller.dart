import 'dart:async';

import 'package:flutter/material.dart';

import '../core/storage/app_settings_store.dart';

enum SignInMethod { password, google }

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('en'),
    bool hasCompletedIntro = true,
    bool useSystemLocale = false,
    AppSettingsStore? store,
  }) : _themeMode = themeMode,
       _locale = _released(locale),
       _useSystemLocale = useSystemLocale,
       _hasCompletedIntro = hasCompletedIntro,
       _store = store ?? MemoryAppSettingsStore();

  /// The locales this release runs in. v2.1.0 ships English only: the
  /// Vietnamese strings stay in lib/l10n (and in the generated delegate) but
  /// are not enabled. A stored or device preference for any other language
  /// resolves to English. Add `Locale('vi')` here to turn Vietnamese back on.
  static const List<Locale> releaseLocales = <Locale>[Locale('en')];

  /// Whether the Language choice is offered (only with more than one locale).
  static bool get languageChoiceEnabled => releaseLocales.length > 1;

  static const String _themeKey = 'settings.theme';
  static const String _localeKey = 'settings.locale';
  static const String _introKey = 'onboarding.intro.completed';
  static const String _signInMethodKey = 'auth.sign_in_method';

  final AppSettingsStore _store;
  ThemeMode _themeMode;
  Locale _locale;
  bool _useSystemLocale;
  bool _hasCompletedIntro;
  SignInMethod? _signInMethod;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  bool get useSystemLocale => _useSystemLocale;
  bool get hasCompletedIntro => _hasCompletedIntro;

  /// How this device last signed in (the server does not say), for the
  /// Profile screen's password / Google row. Null before the first sign-in.
  SignInMethod? get signInMethod => _signInMethod;

  Future<void> initialize() async {
    final String? themeValue = await _store.readString(_themeKey);
    final String? localeValue = await _store.readString(_localeKey);
    final String? introValue = await _store.readString(_introKey);
    final String? methodValue = await _store.readString(_signInMethodKey);
    for (final SignInMethod method in SignInMethod.values) {
      if (method.name == methodValue) _signInMethod = method;
    }

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

  void setLocale(Locale requested) {
    final Locale value = _released(requested);
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

  void setSignInMethod(SignInMethod value) {
    if (_signInMethod == value) return;
    _signInMethod = value;
    notifyListeners();
    unawaited(_store.writeString(_signInMethodKey, value.name));
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
    if (value == null) return null;
    return _released(Locale(value));
  }

  Locale _systemLocale() =>
      _released(WidgetsBinding.instance.platformDispatcher.locale);

  /// [value] when this release enables its language, otherwise English.
  static Locale _released(Locale value) {
    for (final Locale locale in releaseLocales) {
      if (locale.languageCode == value.languageCode) return locale;
    }
    return const Locale('en');
  }
}
