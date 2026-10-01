import 'package:dio/dio.dart';

import 'api_error.dart';
import 'api_exception.dart';
import 'api_request_id.dart';

final class ApiErrorParser {
  const ApiErrorParser();

  ApiException fromDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          kind: ApiExceptionKind.timeout,
          retryable: true,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          kind: ApiExceptionKind.network,
          retryable: true,
        );
      case DioExceptionType.badResponse:
        final Response<dynamic>? response = exception.response;
        if (response == null) {
          return const ApiException(
            kind: ApiExceptionKind.malformedResponse,
            retryable: false,
          );
        }
        return _fromResponse(response);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return const ApiException(
          kind: ApiExceptionKind.network,
          retryable: false,
        );
      case DioExceptionType.unknown:
        return const ApiException(
          kind: ApiExceptionKind.network,
          retryable: true,
        );
    }
  }

  ApiException _fromResponse(Response<dynamic> response) {
    final int? statusCode = response.statusCode;
    final String? headerRequestId = requestIdFromHeaders(response.headers);
    final Object? data = response.data;

    if (data is! Map) {
      return ApiException(
        kind: ApiExceptionKind.malformedResponse,
        statusCode: statusCode,
        requestId: headerRequestId,
        retryable: false,
      );
    }

    final Object? rawError = data['error'];
    if (rawError is! Map) {
      return ApiException(
        kind: ApiExceptionKind.malformedResponse,
        statusCode: statusCode,
        requestId: headerRequestId,
        retryable: false,
      );
    }

    final Object? rawCode = rawError['code'];
    final Object? rawMessage = rawError['message'];
    if (rawCode is! String ||
        rawCode.trim().isEmpty ||
        rawMessage is! String ||
        rawMessage.trim().isEmpty) {
      return ApiException(
        kind: ApiExceptionKind.malformedResponse,
        statusCode: statusCode,
        requestId: headerRequestId,
        retryable: false,
      );
    }

    final String? envelopeRequestId = switch (rawError['request_id']) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => null,
    };
    final String? requestId = envelopeRequestId ?? headerRequestId;
    final bool retryable = rawError['retryable'] is bool
        ? rawError['retryable'] as bool
        : false;
    final Map<String, Object?> details = _details(rawError['details']);

    final ApiError apiError = ApiError(
      code: rawCode.trim(),
      message: rawMessage.trim(),
      requestId: requestId,
      retryable: retryable,
      details: details,
      httpStatus: statusCode,
    );

    return ApiException(
      kind: _kindFor(statusCode),
      apiError: apiError,
      statusCode: statusCode,
      requestId: requestId,
      retryable: retryable,
    );
  }

  ApiExceptionKind _kindFor(int? statusCode) {
    return switch (statusCode) {
      401 => ApiExceptionKind.unauthorized,
      402 => ApiExceptionKind.insufficientCredits,
      409 => ApiExceptionKind.conflict,
      429 => ApiExceptionKind.rateLimited,
      final int status when status >= 500 => ApiExceptionKind.server,
      _ => ApiExceptionKind.api,
    };
  }

  Map<String, Object?> _details(Object? value) {
    if (value is! Map) {
      return const <String, Object?>{};
    }

    final Map<String, Object?> result = <String, Object?>{};
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      result[entry.key.toString()] = entry.value;
    }
    return Map<String, Object?>.unmodifiable(result);
  }
}
