final class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    required this.retryable,
    required this.details,
    this.requestId,
    this.httpStatus,
  });

  final String code;
  final String message;
  final String? requestId;
  final bool retryable;
  final Map<String, Object?> details;
  final int? httpStatus;
}
