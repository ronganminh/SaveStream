import 'package:flutter/material.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('en'),
  }) : _themeMode = themeMode,
       _locale = locale;

  ThemeMode _themeMode;
  Locale _locale;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }
    _themeMode = value;
    notifyListeners();
  }

  void setLocale(Locale value) {
    if (_locale == value) {
      return;
    }
    _locale = value;
    notifyListeners();
  }
}
