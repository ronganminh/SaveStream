final class ApiStreamResponse {
  const ApiStreamResponse({
    required this.stream,
    required this.statusCode,
    this.requestId,
  });

  final Stream<List<int>> stream;
  final int statusCode;
  final String? requestId;
}
