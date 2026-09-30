abstract interface class AppSettingsStore {
  Future<String?> readString(String key);

  Future<void> writeString(String key, String value);
}

final class MemoryAppSettingsStore implements AppSettingsStore {
  MemoryAppSettingsStore([Map<String, String>? values])
      : _values = values ?? <String, String>{};

  final Map<String, String> _values;

  @override
  Future<String?> readString(String key) async => _values[key];

  @override
  Future<void> writeString(String key, String value) async {
    _values[key] = value;
  }
}
