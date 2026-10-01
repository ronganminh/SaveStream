import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:savestream_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:savestream_mobile/features/billing/domain/models/billing_models.dart';
import 'package:savestream_mobile/features/billing/domain/repositories/billing_repository.dart';
import 'package:savestream_mobile/features/billing/presentation/controllers/billing_providers.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/channels/domain/repositories/watch_repository.dart';
import 'package:savestream_mobile/features/channels/presentation/controllers/watch_providers.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/recordings/domain/repositories/recording_repository.dart';
import 'package:savestream_mobile/features/recordings/presentation/controllers/recording_providers.dart';

void main() {
  group('AuthController', () {
    test('successful sign in authenticates the app session', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository();
      final AppSessionController session = AppSessionController(
        authStatus: AppAuthStatus.unauthenticated,
      );
      final AuthController controller = AuthController(
        repository: repository,
        session: session,
      );

      final bool success = await controller.signIn(
        email: 'alex@example.com',
        password: 'secret',
      );

      expect(success, isTrue);
      expect(session.authStatus, AppAuthStatus.authenticated);
      expect(controller.isLoading, isFalse);
      expect(controller.failure, isNull);
      expect(repository.signInCalls, 1);
    });

    test('email-not-verified failure keeps pending email for verify flow', () async {
      final _FakeAuthRepository repository = _FakeAuthRepository(
        signInFailure: AuthFailureCode.emailNotVerified,
      );
      final AppSessionController session = AppSessionController(
        authStatus: AppAuthStatus.unauthenticated,
      );
      final AuthController controller = AuthController(
        repository: repository,
        session: session,
      );

      final bool success = await controller.signIn(
        email: 'pending@example.com',
        password: 'secret',
      );

      expect(success, isFalse);
      expect(controller.failure, AuthFailureCode.emailNotVerified);
      expect(session.authStatus, AppAuthStatus.unauthenticated);
      expect(session.pendingVerificationEmail, 'pending@example.com');
    });
  });

  group('WatchController', () {
    test('create invalidates list/detail and bumps revision once', () async {
      final _FakeWatchRepository repository = _FakeWatchRepository();
      int listInvalidations = 0;
      final List<String> detailInvalidations = <String>[];
      int revisions = 0;
      final WatchController controller = WatchController(
        repository: repository,
        invalidateList: () => listInvalidations += 1,
        invalidateDetail: detailInvalidations.add,
        notifyChanged: () => revisions += 1,
      );

      final WatchSummary created = await controller.createWatch(
        const CreateWatchCommand(
          sourceType: WatchSourceType.username,
          sourceValue: 'new_creator',
          autoRecord: true,
        ),
      );

      expect(created.id, 'watch-new');
      expect(listInvalidations, 1);
      expect(detailInvalidations, <String>['watch-new']);
      expect(revisions, 1);
    });

    test('failed mutation still reconciles all Watch views', () async {
      final _FakeWatchRepository repository = _FakeWatchRepository(
        failPause: true,
      );
      int listInvalidations = 0;
      int detailInvalidations = 0;
      int revisions = 0;
      final WatchController controller = WatchController(
        repository: repository,
        invalidateList: () => listInvalidations += 1,
        invalidateDetail: (String id) {
          expect(id, 'watch-1');
          detailInvalidations += 1;
        },
        notifyChanged: () => revisions += 1,
      );

      await expectLater(controller.pause('watch-1'), throwsStateError);

      expect(listInvalidations, 1);
      expect(detailInvalidations, 1);
      expect(revisions, 1);
    });
  });

  group('RecordingController', () {
    test('retry invalidates original and replacement recording IDs', () async {
      final _FakeRecordingRepository repository = _FakeRecordingRepository();
      int listRefreshes = 0;
      final List<String> detailRefreshes = <String>[];
      int revisions = 0;
      final RecordingController controller = RecordingController(
        repository: repository,
        refreshList: () => listRefreshes += 1,
        refreshDetail: detailRefreshes.add,
        notifyChanged: () => revisions += 1,
      );

      final RecordingSummary? retried = await controller.retry('rec-failed');

      expect(retried?.id, 'rec-retry');
      expect(listRefreshes, 2);
      expect(detailRefreshes, <String>['rec-failed', 'rec-retry']);
      expect(revisions, 2);
    });

    test('failed stop still reconciles recording state', () async {
      final _FakeRecordingRepository repository = _FakeRecordingRepository(
        failStop: true,
      );
      int listRefreshes = 0;
      int detailRefreshes = 0;
      int revisions = 0;
      final RecordingController controller = RecordingController(
        repository: repository,
        refreshList: () => listRefreshes += 1,
        refreshDetail: (String id) {
          expect(id, 'rec-1');
          detailRefreshes += 1;
        },
        notifyChanged: () => revisions += 1,
      );

      await expectLater(controller.stop('rec-1'), throwsStateError);

      expect(listRefreshes, 1);
      expect(detailRefreshes, 1);
      expect(revisions, 1);
    });
  });

  group('BillingController', () {
    test('mutations notify snapshot listeners after repository calls', () async {
      final _FakeBillingRepository repository = _FakeBillingRepository();
      int changes = 0;
      final BillingController controller = BillingController(
        repository: repository,
        onChanged: () => changes += 1,
      );

      final PaymentOrder? order = await controller.createOrder('pkg-1');
      final CheckoutSession? checkout = await controller.createCheckout(
        orderId: order!.id,
        returnUri: Uri.parse('savestream:/billing/return?order_id=order-1'),
      );
      final PaymentOrder? refreshed = await controller.refreshOrder(order.id);

      expect(order.status, PaymentOrderStatus.created);
      expect(checkout?.paymentOrder.status, PaymentOrderStatus.pending);
      expect(refreshed?.status, PaymentOrderStatus.paid);
      expect(changes, 3);
    });
  });
}

final class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signInFailure});

  final AuthFailureCode? signInFailure;
  int signInCalls = 0;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls += 1;
    final AuthFailureCode? failure = signInFailure;
    if (failure != null) {
      throw AuthException(failure);
    }
  }

  @override
  Future<void> register({required String email, required String password}) async {}

  @override
  Future<void> verifyEmail({required String token}) async {}

  @override
  Future<void> resendVerification({required String email}) async {}

  @override
  Future<void> forgotPassword({required String email}) async {}

  @override
  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

final class _FakeWatchRepository implements WatchRepository {
  _FakeWatchRepository({this.failPause = false});

  final bool failPause;

  @override
  Future<WatchSummary> createWatch(CreateWatchCommand command) async {
    return const WatchSummary(
      id: 'watch-new',
      creatorDisplayName: 'New Creator',
      creatorUsername: '@new_creator',
      status: WatchStatus.active,
      isLive: false,
    );
  }

  @override
  Future<WatchSummary?> pauseWatch(String id) async {
    if (failPause) {
      throw StateError('pause failed');
    }
    return _watch(id, WatchStatus.paused);
  }

  @override
  Future<void> deleteWatch(String id) async {}

  @override
  Future<WatchSummary?> getWatch(String id) async => _watch(id, WatchStatus.active);

  @override
  Future<List<WatchSummary>> listWatches() async => <WatchSummary>[
    _watch('watch-1', WatchStatus.active),
  ];

  @override
  Future<WatchSummary?> resumeWatch(String id) async =>
      _watch(id, WatchStatus.active);

  @override
  Future<WatchSummary?> setAutoRecord(
    String id, {
    required bool enabled,
  }) async {
    return _watch(id, WatchStatus.active).copyWith(autoRecord: enabled);
  }

  WatchSummary _watch(String id, WatchStatus status) {
    return WatchSummary(
      id: id,
      creatorDisplayName: 'Ada Live',
      creatorUsername: '@ada_live',
      status: status,
      isLive: false,
    );
  }
}

final class _FakeRecordingRepository implements RecordingRepository {
  _FakeRecordingRepository({this.failStop = false});

  final bool failStop;

  @override
  Future<RecordingSummary?> retryRecording(String id) async {
    return _recording('rec-retry', RecordingStatus.queued);
  }

  @override
  Future<RecordingSummary?> stopRecording(String id) async {
    if (failStop) {
      throw StateError('stop failed');
    }
    return _recording(id, RecordingStatus.stopRequested);
  }

  @override
  Future<RecordingSummary> createRecording(CreateRecordingCommand command) async {
    return _recording('rec-new', RecordingStatus.queued);
  }

  @override
  Future<void> deleteRecording(String id) async {}

  @override
  Future<RecordingSummary?> getRecording(String id) async =>
      _recording(id, RecordingStatus.recording);

  @override
  Future<List<RecordingSummary>> listRecordings() async =>
      <RecordingSummary>[_recording('rec-1', RecordingStatus.recording)];

  @override
  Future<RecordingPage> listRecordingPage({
    RecordingFilter filter = RecordingFilter.all,
    String? cursor,
    int limit = 4,
  }) async {
    return RecordingPage(
      items: <RecordingSummary>[_recording('rec-1', RecordingStatus.recording)],
      nextCursor: null,
    );
  }

  @override
  Future<List<RecordingArtifactSummary>> listArtifacts(String recordingId) async =>
      const <RecordingArtifactSummary>[];

  @override
  Future<ArtifactDownloadUrl> createArtifactDownloadUrl(String artifactId) async {
    return ArtifactDownloadUrl(
      uri: Uri.parse('https://example.com/artifact.mp4'),
      expiresAt: DateTime.utc(2026, 10, 1, 12),
    );
  }

  @override
  Stream<RecordingSummary?> watchRecording(String id) async* {
    yield await getRecording(id);
  }

  RecordingSummary _recording(String id, RecordingStatus status) {
    return RecordingSummary(
      id: id,
      sourceType: RecordingSourceType.username,
      sourceValue: 'ada_live',
      creatorDisplayName: 'Ada Live',
      creatorUsername: '@ada_live',
      status: status,
      actions: RecordingActions(
        canStop: status == RecordingStatus.recording,
        canRetry: status == RecordingStatus.failed,
        canDelete: !status.isActiveLifecycle,
      ),
      startedAt: DateTime.utc(2026, 10, 1, 8),
      durationSeconds: 10,
    );
  }
}

final class _FakeBillingRepository implements BillingRepository {
  @override
  Future<PaymentOrder?> createPaymentOrder(String packageId) async {
    return _order(PaymentOrderStatus.created);
  }

  @override
  Future<CheckoutSession?> createCheckout({
    required String orderId,
    required Uri returnUri,
  }) async {
    return CheckoutSession(
      checkoutUri: Uri.parse('https://pay.example.com/session'),
      paymentOrder: _order(PaymentOrderStatus.pending),
    );
  }

  @override
  Future<PaymentOrder?> refreshPaymentOrder(String orderId) async {
    return _order(PaymentOrderStatus.paid);
  }

  @override
  Future<BillingSnapshot> getSnapshot() async {
    return const BillingSnapshot(
      packages: <CreditPackage>[],
      orders: <PaymentOrder>[],
    );
  }

  @override
  Stream<PaymentOrder?> watchPaymentOrder(String orderId) async* {
    yield _order(PaymentOrderStatus.paid);
  }

  PaymentOrder _order(PaymentOrderStatus status) {
    return PaymentOrder(
      id: 'order-1',
      packageId: 'pkg-1',
      status: status,
      credits: 25,
      amount: const Money(amountMinor: 999, currency: 'USD'),
      createdAt: DateTime.utc(2026, 10, 1, 8),
      updatedAt: DateTime.utc(2026, 10, 1, 8),
    );
  }
}
