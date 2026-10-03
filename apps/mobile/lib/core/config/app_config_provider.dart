import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

final Provider<AppConfig> appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('AppConfig is not configured for this application scope.');
});
