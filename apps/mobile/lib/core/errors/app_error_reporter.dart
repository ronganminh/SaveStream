import 'package:flutter/foundation.dart';

class AppErrorReporter {
  const AppErrorReporter();

  void reportFlutterError(FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  }

  void reportUnhandled(Object error, StackTrace stackTrace) {
    debugPrint('Unhandled SaveStream error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
