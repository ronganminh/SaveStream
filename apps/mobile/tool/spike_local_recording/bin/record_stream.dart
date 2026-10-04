import 'dart:convert';
import 'dart:io';

import '../stream_probe.dart';

Future<void> main(List<String> args) async {
  final _CliOptions? options = _CliOptions.tryParse(args);
  if (options == null) {
    stderr.writeln(
      'Usage: dart run tool/spike_local_recording/bin/record_stream.dart '
      '--url <live-url> --output <file> [--seconds 60] '
      '[--header Name:Value ...]',
    );
    exitCode = 64;
    return;
  }

  final StreamProbe probe = StreamProbe();
  final StreamProbeResult result = await probe.run(
    StreamProbeRequest(
      uri: options.uri,
      outputFile: File(options.outputPath),
      maxDuration: Duration(seconds: options.seconds),
      headers: options.headers,
    ),
  );

  stdout.writeln(const JsonEncoder.withIndent('  ').convert(result.toJson()));
  if (result.statusCode < 200 ||
      result.statusCode >= 300 ||
      result.bytesWritten == 0) {
    exitCode = 2;
  }
}

final class _CliOptions {
  const _CliOptions({
    required this.uri,
    required this.outputPath,
    required this.seconds,
    required this.headers,
  });

  final Uri uri;
  final String outputPath;
  final int seconds;
  final Map<String, String> headers;

  static _CliOptions? tryParse(List<String> args) {
    Uri? uri;
    String? outputPath;
    int seconds = 60;
    final Map<String, String> headers = <String, String>{};

    for (int index = 0; index < args.length; index += 1) {
      final String arg = args[index];
      if (arg == '--url' && index + 1 < args.length) {
        uri = Uri.tryParse(args[++index]);
      } else if (arg == '--output' && index + 1 < args.length) {
        outputPath = args[++index];
      } else if (arg == '--seconds' && index + 1 < args.length) {
        final int? parsed = int.tryParse(args[++index]);
        if (parsed == null || parsed <= 0) {
          return null;
        }
        seconds = parsed;
      } else if (arg == '--header' && index + 1 < args.length) {
        final String raw = args[++index];
        final int colon = raw.indexOf(':');
        if (colon <= 0 || colon == raw.length - 1) {
          return null;
        }
        headers[raw.substring(0, colon).trim()] = raw.substring(colon + 1).trim();
      } else {
        return null;
      }
    }

    if (uri == null ||
        !uri.hasScheme ||
        outputPath == null ||
        outputPath.isEmpty) {
      return null;
    }

    return _CliOptions(
      uri: uri,
      outputPath: outputPath,
      seconds: seconds,
      headers: headers,
    );
  }
}
