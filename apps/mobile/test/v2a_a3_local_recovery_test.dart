import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/features/devices/domain/models/device_registration.dart';
import 'package:savestream_mobile/features/local_recordings/presentation/local_recovery_screen.dart';
import 'package:savestream_mobile/l10n/l10n.dart';
import 'package:savestream_mobile/platform/contracts/local_recovery_service.dart';
import 'package:savestream_mobile/platform/fakes/fake_device_info_service.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

void main() {
  testWidgets('R22 and R23 detect and recover with checklist only', (
    WidgetTester tester,
  ) async {
    final _RecoveryHarness service = _RecoveryHarness(
      candidate: _candidate(),
      outcome: LocalRecoveryOutcome.partial,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRecoveryServiceProvider.overrideWithValue(service),
          deviceInfoServiceProvider.overrideWithValue(
            const FakeDeviceInfoService(platform: DevicePlatform.android),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LocalRecoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recording was interrupted'), findsOneWidget);
    expect(find.textContaining('18:40'), findsOneWidget);
    expect(find.text('Advertisement'), findsNothing);
    expect(find.text('Delete temporary file'), findsOneWidget);

    await tester.tap(find.text('Recover'));
    await tester.pump();

    expect(find.text('Recovering recording'), findsOneWidget);
    expect(find.text('Find temporary file'), findsOneWidget);
    expect(find.text('Repair file tail'), findsOneWidget);
    expect(find.text('Verify duration'), findsOneWidget);
    expect(find.text('Add to Recordings'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);

    service.completeRecovery();
    await tester.pumpAndSettle();

    expect(find.text('Partially recovered'), findsOneWidget);
    expect(find.textContaining('Kept 00:18:40'), findsOneWidget);
    expect(find.text('Reduce interruptions on Android'), findsOneWidget);
    expect(find.text('Advertisement'), findsNothing);
  });

  testWidgets('R25 shows platform failure and delete-temp action', (
    WidgetTester tester,
  ) async {
    final _RecoveryHarness service = _RecoveryHarness(
      candidate: _candidate(),
      outcome: LocalRecoveryOutcome.failed,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRecoveryServiceProvider.overrideWithValue(service),
          deviceInfoServiceProvider.overrideWithValue(
            const FakeDeviceInfoService(platform: DevicePlatform.ios),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LocalRecoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recover'));
    await tester.pump();

    service.completeRecovery();
    await tester.pumpAndSettle();

    expect(find.text('Could not recover recording'), findsOneWidget);
    expect(find.textContaining('iOS stopped SaveStream'), findsOneWidget);
    expect(find.text('Delete temporary file'), findsOneWidget);
    expect(find.text('Next time, keep SaveStream open'), findsOneWidget);
    expect(find.text('Advertisement'), findsNothing);
  });

  testWidgets('recovery timeout still exposes delete-temp action', (
    WidgetTester tester,
  ) async {
    final _RecoveryHarness service = _RecoveryHarness(
      candidate: _candidate(),
      outcome: LocalRecoveryOutcome.failed,
      recoverError: TimeoutException('Recovery timed out'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRecoveryServiceProvider.overrideWithValue(service),
          deviceInfoServiceProvider.overrideWithValue(
            const FakeDeviceInfoService(platform: DevicePlatform.android),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LocalRecoveryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recover'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Recovery timed out'), findsOneWidget);
    expect(find.text('Delete temporary file'), findsOneWidget);
  });
}

LocalRecoveryCandidate _candidate() {
  return LocalRecoveryCandidate(
    tempId: 'temp_1',
    watchId: 'watch_1',
    creatorDisplayName: 'Lina Studio',
    creatorHandle: '@linastudio',
    startedAt: DateTime.utc(2026, 10, 4, 4, 22),
    interruptedAt: DateTime.utc(2026, 10, 4, 4, 41),
    recordedSeconds: 1120,
    sizeBytes: 640 * 1024 * 1024,
  );
}

final class _RecoveryHarness implements LocalRecoveryService {
  _RecoveryHarness({
    required this.candidate,
    required this.outcome,
    this.recoverError,
  });

  LocalRecoveryCandidate? candidate;
  final LocalRecoveryOutcome outcome;
  final Object? recoverError;
  final StreamController<LocalRecoveryProgress> _progress =
      StreamController<LocalRecoveryProgress>.broadcast();
  final Completer<void> _finish = Completer<void>();

  @override
  Future<LocalRecoveryCandidate?> findInterrupted() async => candidate;

  @override
  Stream<LocalRecoveryProgress> watchProgress() => _progress.stream;

  @override
  Future<LocalRecoveryResult> recover(LocalRecoveryCandidate candidate) async {
    final Object? error = recoverError;
    if (error != null) throw error;
    _progress.add(
      const LocalRecoveryProgress(step: LocalRecoveryStep.repairTail),
    );
    await _finish.future;
    _progress.add(
      const LocalRecoveryProgress(step: LocalRecoveryStep.registerRecording),
    );
    final LocalRecoveryResult result = LocalRecoveryResult(
      outcome: outcome,
      candidate: candidate,
      recordedSeconds: candidate.recordedSeconds,
      sizeBytes: candidate.sizeBytes,
      recordingId: outcome == LocalRecoveryOutcome.failed
          ? null
          : 'recording_1',
    );
    if (outcome != LocalRecoveryOutcome.failed) {
      this.candidate = null;
    }
    return result;
  }

  void completeRecovery() {
    if (!_finish.isCompleted) _finish.complete();
  }

  @override
  Future<void> deleteTemporary(String tempId) async {
    if (candidate?.tempId == tempId) candidate = null;
  }
}
