import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings_store.dart';

final class SharedPreferencesAppSettingsStore implements AppSettingsStore {
  SharedPreferencesAppSettingsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> readString(String key) => _preferences.getString(key);

  @override
  Future<void> writeString(String key, String value) {
    return _preferences.setString(key, value);
  }
}
