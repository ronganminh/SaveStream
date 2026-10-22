// System v2 screens (No connection, Server error, Maintenance, Update
// required) at 390×844 over the signed-in app, driven by the real
// mechanisms: connectivity and GET /v1/app/status (fakes here). See
// screenshot_harness.dart for writing the PNGs.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/app_settings_controller.dart';
import 'package:savestream_mobile/app/savestream_app.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/api/api_exception.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/app_status/domain/models/app_status.dart';
import 'package:savestream_mobile/features/app_status/domain/repositories/app_status_repository.dart';
import 'package:savestream_mobile/features/app_status/presentation/system_status_providers.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/channels/domain/repositories/watch_repository.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/domain/repositories/recording_repository.dart';
import 'package:savestream_mobile/features/settings/domain/models/app_notification.dart';
import 'package:savestream_mobile/features/settings/domain/repositories/notifications_repository.dart';
import 'package:savestream_mobile/features/v2_foundation/v2_foundation_providers.dart'
    show appStatusRepositoryProvider;
import 'package:savestream_mobile/platform/contracts/connectivity_service.dart';
import 'package:savestream_mobile/platform/platform_providers.dart';

import 'screenshot_harness.dart';

AppConfig _config() => AppConfig(
  environment: AppEnvironment.local,
  apiBaseUrl: Uri.parse('http://localhost:8000'),
);

AppStatus _status({
  String minimum = '2.0.0',
  bool maintenance = false,
  DateTime? eta,
}) => AppStatus(
  minSupportedVersion: MinimumSupportedVersion(android: minimum, ios: minimum),
  maintenance: MaintenanceStatus(active: maintenance, eta: eta),
);

void main() {
  setUpAll(loadBundledFonts);

  Future<void> pumpSystem(
    WidgetTester tester, {
    required _FakeStatus status,
    _FakeConnectivity? connectivity,
  }) async {
    usePhoneView(tester);
    final AppSessionController session = AppSessionController();
    final AppSettingsController settings = AppSettingsController();
    addTearDown(session.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      screenshotFrame(
        SaveStreamApp(
          config: _config(),
          session: session,
          settings: settings,
          watchRepository: _FakeWatches(),
          recordingRepository: _FakeRecordings(),
          notificationsRepository: _FakeNotifications(),
          extraOverrides: <Override>[
            appStatusRepositoryProvider.overrideWithValue(status),
            appVersionProvider.overrideWith((_) async => '2.0.1'),
            connectivityServiceProvider.overrideWithValue(
              connectivity ?? _FakeConnectivity(),
            ),
          ],
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('AOffline', (WidgetTester tester) async {
    final _FakeConnectivity connectivity = _FakeConnectivity(isOnline: false);
    await pumpSystem(
      tester,
      status: _FakeStatus(() async => _status()),
      connectivity: connectivity,
    );
    expect(find.text('No connection'), findsOneWidget);
    expect(
      find.text(
        'Check your Wi-Fi or mobile data. Your channels are still watched '
        'and recorded in the cloud.',
      ),
      findsOneWidget,
    );
    await captureScreen(tester, 'AOffline');

    // Back online: Try again checks the connection again.
    connectivity.isOnline = true;
    await tester.tap(
      find.byKey(const ValueKey<String>('system-offline-retry')),
    );
    await settle(tester);
    expect(find.text('No connection'), findsNothing);
    expect(find.byKey(const ValueKey<String>('nav-account')), findsOneWidget);
  });

  testWidgets('AServerError', (WidgetTester tester) async {
    int calls = 0;
    await pumpSystem(
      tester,
      status: _FakeStatus(() async {
        calls += 1;
        if (calls == 1) {
          throw const ApiException(
            kind: ApiExceptionKind.server,
            retryable: true,
            statusCode: 500,
            requestId: 'req_01J9ZR2W8KD4',
          );
        }
        return _status();
      }),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Error ID: req_01J9ZR2W8KD4'), findsOneWidget);
    expect(find.text('Contact support'), findsOneWidget);
    await captureScreen(tester, 'AServerError');

    await tester.tap(find.byKey(const ValueKey<String>('system-server-retry')));
    await settle(tester);
    expect(calls, 2);
    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets('AMaintenance', (WidgetTester tester) async {
    await pumpSystem(
      tester,
      status: _FakeStatus(
        () async =>
            _status(maintenance: true, eta: DateTime.utc(2030, 1, 15, 14, 30)),
      ),
    );
    expect(find.text('Down for maintenance'), findsOneWidget);
    expect(
      find.text(
        'We’re upgrading SaveStream. Expected back by Jan 15 14:30 UTC. '
        'Recordings already saved are safe.',
      ),
      findsOneWidget,
    );
    expect(find.text('Check status'), findsOneWidget);
    await captureScreen(tester, 'AMaintenance');
  });

  testWidgets('AForceUpdate', (WidgetTester tester) async {
    await pumpSystem(
      tester,
      status: _FakeStatus(() async => _status(minimum: '2.1.0')),
    );
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Installed 2.0.1 · required 2.1.0'), findsOneWidget);
    expect(find.text('Update on Google Play'), findsOneWidget);
    // The app underneath can't be used.
    expect(
      find.byKey(const ValueKey<String>('nav-account')).hitTestable(),
      findsNothing,
    );
    await captureScreen(tester, 'AForceUpdate');
  });

  testWidgets('a supported version opens the app', (WidgetTester tester) async {
    await pumpSystem(
      tester,
      status: _FakeStatus(() async => _status(minimum: '2.0.1')),
    );
    expect(find.text('Update required'), findsNothing);
    expect(find.byKey(const ValueKey<String>('nav-account')), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
  await tester.pumpAndSettle();
}

class _FakeStatus implements AppStatusRepository {
  _FakeStatus(this._answer);

  final Future<AppStatus> Function() _answer;

  @override
  Future<AppStatus> getStatus() => _answer();
}

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity({this.isOnline = true});

  bool isOnline;

  @override
  Stream<bool> get online => Stream<bool>.value(isOnline);
}

class _FakeWatches implements WatchRepository {
  @override
  Future<List<WatchSummary>> listWatches() async => const <WatchSummary>[];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeRecordings implements RecordingRepository {
  @override
  Future<List<RecordingSummary>> listRecordings() async =>
      const <RecordingSummary>[];

  @override
  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  }) async =>
      const RecordingPage(items: <RecordingSummary>[], nextCursor: null);

  @override
  Stream<RecordingSummary?> watchRecording(String id) =>
      const Stream<RecordingSummary?>.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeNotifications implements NotificationsRepository {
  @override
  Future<NotificationPage> listNotifications({String? cursor}) async {
    return const NotificationPage(items: <AppNotification>[]);
  }

  @override
  Future<AppNotification> markRead(String notificationId) =>
      throw UnimplementedError();

  @override
  Future<int> markAllRead() async => 0;
}
