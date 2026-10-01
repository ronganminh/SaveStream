final class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    required this.statusCode,
    this.requestId,
  });

  final T data;
  final int statusCode;
  final String? requestId;
}
