import 'api_exception.dart';

final class ApiRetryPolicy {
  const ApiRetryPolicy({
    this.maxRetries = 1,
    this.baseDelay = const Duration(milliseconds: 200),
  }) : assert(maxRetries >= 0);

  final int maxRetries;
  final Duration baseDelay;

  bool shouldRetry({
    required String method,
    required int retriesSoFar,
    required ApiException exception,
  }) {
    if (retriesSoFar >= maxRetries || !_isSafeMethod(method)) {
      return false;
    }

    return switch (exception.kind) {
      ApiExceptionKind.network ||
      ApiExceptionKind.timeout ||
      ApiExceptionKind.server => true,
      ApiExceptionKind.rateLimited => exception.retryable,
      _ => false,
    };
  }

  Duration delayForRetry({required int retriesSoFar}) {
    return Duration(
      milliseconds: baseDelay.inMilliseconds * (retriesSoFar + 1),
    );
  }

  bool _isSafeMethod(String method) {
    return switch (method.toUpperCase()) {
      'GET' || 'HEAD' => true,
      _ => false,
    };
  }
}
