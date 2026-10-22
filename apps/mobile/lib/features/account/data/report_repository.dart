import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';

/// What the person in the Report form is reporting.
enum ReportCategory {
  /// Someone is recording my LIVE without permission.
  recordingMyLive,

  /// Copyright infringement: a full notice (Copyright Policy §2) is needed,
  /// which only the web /report form collects.
  copyright,

  /// Remove a recording of me.
  removeRecordingOfMe,

  /// Something else.
  other,
}

class ContentReport {
  const ContentReport({
    required this.category,
    required this.target,
    required this.details,
    required this.email,
  });

  final ReportCategory category;

  /// TikTok username, TikTok URL or SaveStream link.
  final String target;
  final String details;
  final String email;
}

/// The public report endpoint wants a Turnstile token (a web-only
/// challenge) and refused the app's report: it must be sent from the web
/// /report form instead.
class ReportNeedsWebFormException implements Exception {
  const ReportNeedsWebFormException();
}

abstract interface class ReportRepository {
  /// Sends an abuse / removal report; returns the case reference
  /// (`SR-…`). Throws [ReportNeedsWebFormException] when the server needs a
  /// web challenge, or [ApiException].
  Future<String> submit(ContentReport report);
}

/// POST /v1/public/reports (`kind: abuse`), the endpoint behind the web
/// /report form. It becomes a case in Admin → Safety.
final class ApiReportRepository implements ReportRepository {
  const ApiReportRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<String> submit(ContentReport report) async {
    try {
      final response = await _apiClient.post<String>(
        '/v1/public/reports',
        data: reportRequestBody(report),
        decoder: (Object? json) {
          if (json is! Map || json['reference'] is! String) {
            throw const FormatException('Expected a report reference.');
          }
          return json['reference'] as String;
        },
      );
      return response.data;
    } on ApiException catch (error) {
      if (error.code == 'CAPTCHA_FAILED') {
        throw const ReportNeedsWebFormException();
      }
      rethrow;
    }
  }
}

/// The request body for an abuse report. Copyright notices are not sent
/// from the app (the server needs the full notice).
Map<String, Object?> reportRequestBody(ContentReport report) {
  assert(report.category != ReportCategory.copyright);
  final String details = report.details.trim();
  return <String, Object?>{
    'kind': 'abuse',
    'email': report.email.trim(),
    'target': report.target.trim(),
    'reporter_role': report.category == ReportCategory.other ? 'other' : 'self',
    // The case is read by the Safety team; the category leads the text.
    'description': '${_categoryLabel(report.category)}\n\n$details',
    // Honeypot of the web form; always empty.
    'website': '',
  };
}

String _categoryLabel(ReportCategory category) => switch (category) {
  ReportCategory.recordingMyLive =>
    '[App] Someone is recording my LIVE without permission',
  ReportCategory.removeRecordingOfMe => '[App] Remove a recording of me',
  ReportCategory.copyright => '[App] Copyright infringement',
  ReportCategory.other => '[App] Something else',
};

/// Previews and tests: answers with a fixed reference.
final class MockReportRepository implements ReportRepository {
  const MockReportRepository();

  @override
  Future<String> submit(ContentReport report) async => 'SR-1044';
}
