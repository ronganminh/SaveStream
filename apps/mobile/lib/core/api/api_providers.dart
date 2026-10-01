import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  throw StateError(
    'Authenticated ApiClient is not configured for this application scope.',
  );
});
