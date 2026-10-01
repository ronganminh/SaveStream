import 'api_error.dart';

enum ApiExceptionKind {
  api,
  unauthorized,
  insufficientCredits,
  conflict,
  rateLimited,
  server,
  network,
  timeout,
  malformedResponse,
}

final class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.retryable,
    this.apiError,
    this.statusCode,
    this.requestId,
  });

  final ApiExceptionKind kind;
  final ApiError? apiError;
  final int? statusCode;
  final String? requestId;
  final bool retryable;

  String get code {
    final String? backendCode = apiError?.code;
    if (backendCode != null && backendCode.isNotEmpty) {
      return backendCode;
    }

    return switch (kind) {
      ApiExceptionKind.api => 'API_ERROR',
      ApiExceptionKind.unauthorized => 'UNAUTHORIZED',
      ApiExceptionKind.insufficientCredits => 'INSUFFICIENT_CREDITS',
      ApiExceptionKind.conflict => 'CONFLICT',
      ApiExceptionKind.rateLimited => 'RATE_LIMITED',
      ApiExceptionKind.server => 'SERVER_ERROR',
      ApiExceptionKind.network => 'NETWORK_ERROR',
      ApiExceptionKind.timeout => 'TIMEOUT',
      ApiExceptionKind.malformedResponse => 'MALFORMED_RESPONSE',
    };
  }

  String get message {
    final String? backendMessage = apiError?.message;
    if (backendMessage != null && backendMessage.isNotEmpty) {
      return backendMessage;
    }

    return switch (kind) {
      ApiExceptionKind.network => 'Network request failed.',
      ApiExceptionKind.timeout => 'Network request timed out.',
      ApiExceptionKind.malformedResponse => 'The server response was malformed.',
      _ => 'The API request failed.',
    };
  }

  @override
  String toString() {
    return 'ApiException('
        'kind: $kind, '
        'code: $code, '
        'statusCode: $statusCode, '
        'requestId: $requestId, '
        'retryable: $retryable'
        ')';
  }
}
