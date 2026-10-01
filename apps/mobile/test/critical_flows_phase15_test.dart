import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/widgets/savestream_widgets.dart';
import 'package:savestream_mobile/features/billing/domain/models/billing_models.dart';
import 'package:savestream_mobile/features/billing/presentation/billing_screen.dart';
import 'package:savestream_mobile/features/billing/presentation/controllers/billing_providers.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/domain/repositories/recording_repository.dart';
import 'package:savestream_mobile/features/recordings/presentation/recording_detail_screen.dart';

void main() {
  AppConfig testConfig() {
    return AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    );
  }

  testWidgets('critical flow launch -> onboarding -> login -> home', (
    WidgetTester tester,
  ) async {
    final AppSessionController session = AppSessionController(
      hasCompletedOnboarding: false,
      authStatus: AppAuthStatus.unauthenticated,
    );

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), session: session),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to SaveStream'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Record responsibly'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    final Finder getStarted = find.widgetWithText(FilledButton, 'Get started');
    await tester.ensureVisible(getStarted);
    await tester.tap(getStarted);
    await tester.pumpAndSettle();

    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alex@example.com');
    await tester.enterText(fields.at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(session.isAuthenticated, isTrue);
    expect(find.text('Welcome back, Alex'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('critical flow add channel -> channel detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();

    await tester.tap(find.text('Channels'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.byTooltip('Add channel').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '@phase15_creator');

    final Finder addButton = find.widgetWithText(
      FilledButton,
      'Add & start monitoring',
    );
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pump();

    expect(
      find.text(
        'Confirm that you are authorized to record this stream before continuing.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(addButton);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('Channel detail'), findsOneWidget);
    expect(find.text('@phase15_creator'), findsOneWidget);
    expect(find.text('Monitoring settings'), findsOneWidget);
  });

  testWidgets('critical flow active recording -> stop -> stopped', (
    WidgetTester tester,
  ) async {
    final _TerminalStopRecordingRepository repository =
        _TerminalStopRecordingRepository();

    await tester.pumpWidget(
      SaveStreamApp(config: testConfig(), recordingRepository: repository),
    );
    await tester.pump();

    await tester.tap(find.text('Recordings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Ada Live'), findsOneWidget);
    await tester.tap(find.text('Ada Live'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(RecordingDetailScreen), findsOneWidget);
    final Finder detailScrollable = find
        .descendant(
          of: find.byType(RecordingDetailScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Stop recording'),
      320,
      scrollable: detailScrollable,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Stop recording'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(repository.stopCalls, 1);
    expect(find.text('Stop recording'), findsNothing);

    final Finder stoppedChip = find.widgetWithText(SsStatusChip, 'Stopped');
    await tester.scrollUntilVisible(
      stoppedChip,
      -320,
      scrollable: detailScrollable,
    );
    await tester.pumpAndSettle();

    expect(stoppedChip, findsOneWidget);
  });

  testWidgets('critical flow billing -> pending -> paid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(SaveStreamApp(config: testConfig()));
    await tester.pump();

    await tester.tap(find.text('Settings'));
    await tester.pump();
    await tester.tap(find.text('Billing'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(BillingScreen), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Buy package').first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    final Finder billingScrollable = find
        .descendant(
          of: find.byType(BillingScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    final Finder checkStatus = find.widgetWithText(
      OutlinedButton,
      'Check payment status',
    );
    await tester.scrollUntilVisible(
      checkStatus,
      240,
      scrollable: billingScrollable,
    );
    await tester.drag(billingScrollable, const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(SsStatusChip, 'Pending'), findsOneWidget);

    await tester.tap(checkStatus);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(BillingScreen)),
    );
    final BillingSnapshot snapshot = container
        .read(billingSnapshotProvider)
        .requireValue;

    expect(snapshot.orders.first.status, PaymentOrderStatus.paid);
  });
}

final class _TerminalStopRecordingRepository implements RecordingRepository {
  _TerminalStopRecordingRepository()
    : _recording = RecordingSummary(
        id: 'rec-terminal',
        sourceType: RecordingSourceType.username,
        sourceValue: 'ada_live',
        creatorDisplayName: 'Ada Live',
        creatorUsername: '@ada_live',
        status: RecordingStatus.recording,
        actions: const RecordingActions(
          canStop: true,
          canRetry: false,
          canDelete: false,
        ),
        startedAt: DateTime.utc(2026, 10, 1, 8),
        durationSeconds: 180,
        bytesRecorded: 1024,
      );

  RecordingSummary _recording;
  final StreamController<RecordingSummary?> _updates =
      StreamController<RecordingSummary?>.broadcast(sync: true);
  int stopCalls = 0;

  @override
  Future<List<RecordingSummary>> listRecordings() async => <RecordingSummary>[
    _recording,
  ];

  @override
  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  }) async {
    return RecordingPage(
      items: <RecordingSummary>[_recording],
      nextCursor: null,
    );
  }

  @override
  Future<RecordingSummary?> getRecording(String id) async => _recording;

  @override
  Future<RecordingSummary> createRecording(
    CreateRecordingCommand command,
  ) async {
    return _recording;
  }

  @override
  Future<RecordingSummary?> stopRecording(String id) async {
    stopCalls += 1;
    _recording = _recording.copyWith(
      status: RecordingStatus.stopped,
      actions: const RecordingActions(
        canStop: false,
        canRetry: false,
        canDelete: true,
      ),
      endedAt: DateTime.utc(2026, 10, 1, 8, 5),
    );
    _updates.add(_recording);
    return _recording;
  }

  @override
  Future<RecordingSummary?> retryRecording(String id) async => _recording;

  @override
  Future<void> deleteRecording(String id) async {}

  @override
  Future<List<RecordingArtifactSummary>> listArtifacts(
    String recordingId,
  ) async {
    return const <RecordingArtifactSummary>[];
  }

  @override
  Future<ArtifactDownloadUrl> createArtifactDownloadUrl(
    String artifactId,
  ) async {
    return ArtifactDownloadUrl(
      uri: Uri.parse('https://example.com/artifact.mp4'),
      expiresAt: DateTime.utc(2026, 10, 1, 12),
    );
  }

  @override
  Stream<RecordingSummary?> watchRecording(String id) async* {
    yield _recording;
    yield* _updates.stream;
  }
}
