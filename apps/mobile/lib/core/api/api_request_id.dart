import 'package:dio/dio.dart';

String? requestIdFromHeaders(Headers headers) {
  for (final String name in const <String>['x-request-id', 'request-id']) {
    final String? value = headers.value(name)?.trim();
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}
