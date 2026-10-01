final class ApiTimeouts {
  const ApiTimeouts({
    this.connect = const Duration(seconds: 10),
    this.send = const Duration(seconds: 15),
    this.receive = const Duration(seconds: 30),
  });

  final Duration connect;
  final Duration send;
  final Duration receive;
}
