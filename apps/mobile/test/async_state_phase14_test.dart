import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/mock/mock_repository_base.dart';
import 'package:savestream_mobile/core/widgets/savestream_widgets.dart';
import 'package:savestream_mobile/l10n/l10n.dart';

void main() {
  Widget testApp(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('offline async error is retryable and exposes request ID', (
    WidgetTester tester,
  ) async {
    bool retried = false;

    await tester.pumpWidget(
      testApp(
        SsAsyncErrorState(
          error: const ApiException(
            kind: ApiExceptionKind.network,
            requestId: 'req_offline',
            retryable: true,
          ),
          onRetry: () {
            retried = true;
          },
        ),
      ),
    );

    expect(find.text("You're offline"), findsOneWidget);
    expect(find.text('Request ID: req_offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('non-retryable API error has support detail without Retry', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        SsAsyncErrorState(
          error: const ApiException(
            kind: ApiExceptionKind.conflict,
            requestId: 'req_conflict',
            retryable: false,
          ),
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('This can’t be completed'), findsOneWidget);
    expect(find.text('Request ID: req_conflict'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('retry override is authoritative for recoverable mock errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        SsAsyncErrorState(
          error: const MockRepositoryException(MockFailureKind.server),
          retryableOverride: false,
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('This can’t be completed'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('refresh frame keeps stale content visible with progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        const SsAsyncRefreshFrame(
          isRefreshing: true,
          child: Center(child: Text('Existing content')),
        ),
      ),
    );

    expect(find.text('Existing content'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
