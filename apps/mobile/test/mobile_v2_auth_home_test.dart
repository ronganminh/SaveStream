import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/api/memory_access_token_store.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/core/legal/legal_consent.dart';
import 'package:savestream_mobile/core/widgets/v2/ss_v2_icons.dart';
import 'package:savestream_mobile/features/auth/data/remote/auth_protected_api.dart';
import 'package:savestream_mobile/features/auth/data/remote/auth_public_api.dart';
import 'package:savestream_mobile/features/auth/data/repositories/api_auth_repository.dart';
import 'package:savestream_mobile/features/auth/data/session/auth_session_manager.dart';
import 'package:savestream_mobile/features/auth/data/session/refresh_token_store.dart';
import 'package:savestream_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:savestream_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:savestream_mobile/features/channels/data/remote/watch_api_models.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/credits/data/api_credits_repository.dart';
import 'package:savestream_mobile/features/credits/domain/credit_balance.dart';
import 'package:savestream_mobile/features/entitlement/data/repositories/api_entitlement_repository.dart';
import 'package:savestream_mobile/features/entitlement/domain/models/entitlement.dart';
import 'package:savestream_mobile/features/home/domain/models/home_credits.dart';

void main() {
  group('sign-up consent', () {
    test(
      'register sends the 18+/Terms/Privacy/AUP consent as mobile',
      () async {
        Map<String, Object?>? body;
        final DioAuthPublicApi api = DioAuthPublicApi(
          _client((RequestOptions options) {
            expect(options.path, '/v1/auth/register');
            body = Map<String, Object?>.from(options.data as Map);
            return _json(201, <String, Object?>{'message': 'ok'});
          }),
        );

        await api.register(
          email: 'alex@example.com',
          password: 'password-123',
          consent: LegalConsent.current,
        );

        expect(body!['client_type'], 'mobile');
        expect(body!['consent'], <String, Object?>{
          'age_confirmed': true,
          'terms_version': '2026-10-14',
          'privacy_version': '2026-10-14',
          'aup_accepted': true,
          'aup_version': '2026-10-05',
        });
      },
    );

    test('Google sign-in sends consent only when given', () async {
      final List<Map<String, Object?>> bodies = <Map<String, Object?>>[];
      final DioAuthPublicApi api = DioAuthPublicApi(
        _client((RequestOptions options) {
          bodies.add(Map<String, Object?>.from(options.data as Map));
          return _json(200, <String, Object?>{
            'access_token': 'access',
            'refresh_token': 'refresh',
            'token_type': 'Bearer',
            'expires_in': 900,
          });
        }),
      );

      await api.socialLogin(idToken: 'id-token-0123456789abcdef');
      await api.socialLogin(
        idToken: 'id-token-0123456789abcdef',
        consent: LegalConsent.current,
      );

      expect(bodies[0].containsKey('consent'), isFalse);
      expect(
        (bodies[1]['consent']! as Map<Object?, Object?>)['aup_accepted'],
        isTrue,
      );
    });

    test(
      'LEGAL_CONSENT_REQUIRED and LEGAL_VERSION_OUTDATED map to codes',
      () async {
        for (final (String code, int status, AuthFailureCode expected)
            in <(String, int, AuthFailureCode)>[
              ('LEGAL_CONSENT_REQUIRED', 428, AuthFailureCode.consentRequired),
              ('LEGAL_VERSION_OUTDATED', 409, AuthFailureCode.legalOutdated),
            ]) {
          final DioAuthPublicApi publicApi = DioAuthPublicApi(
            _client((RequestOptions options) => _error(status, code)),
          );
          final ApiAuthRepository repository = ApiAuthRepository(
            publicApi: publicApi,
            protectedApi: const _NoopProtectedApi(),
            sessionManager: AuthSessionManager(
              publicApi: publicApi,
              accessTokenStore: MemoryAccessTokenStore(),
              refreshTokenStore: MemoryRefreshTokenStore(),
              appSession: AppSessionController(
                authStatus: AppAuthStatus.unauthenticated,
              ),
            ),
          );
          await expectLater(
            repository.register(
              email: 'alex@example.com',
              password: 'password-123',
              consent: LegalConsent.current,
            ),
            throwsA(
              isA<AuthException>().having(
                (AuthException e) => e.code,
                'code',
                expected,
              ),
            ),
          );
        }
      },
    );
  });

  group('Google cancel', () {
    test('a sign-in that finishes after Cancel is signed out again', () async {
      final Completer<void> google = Completer<void>();
      final _SocialRepo repository = _SocialRepo(google.future);
      final AppSessionController session = AppSessionController(
        authStatus: AppAuthStatus.unauthenticated,
      );
      final AuthController controller = AuthController(
        repository: repository,
        session: session,
      );

      final Future<bool> result = controller.signInSocial(
        SocialAuthProvider.google,
      );
      expect(controller.socialInProgress, isTrue);
      controller.cancelSocial();
      expect(controller.socialInProgress, isFalse);
      google.complete();

      expect(await result, isFalse);
      expect(repository.logouts, 1);
      expect(session.isAuthenticated, isFalse);
      controller.dispose();
    });
  });

  group('home data', () {
    test('entitlement reads email_verified and trial flags', () async {
      final Entitlement entitlement = await ApiEntitlementRepository(
        apiClient: _client(
          (RequestOptions options) => _json(200, <String, Object?>{
            ..._entitlementJson(),
            'email_verified': true,
            'trial_recording': true,
            'can_auto_record': true,
          }),
        ),
      ).getEntitlement();

      expect(entitlement.emailVerified, isTrue);
      expect(entitlement.trialRecording, isTrue);
      expect(entitlement.canAutoRecord, isTrue);
    });

    test('credits balance decodes refund debt (optional)', () {
      final CreditBalance withDebt = decodeCreditBalance(<String, Object?>{
        'posted': 5,
        'reserved': 1,
        'available': 4,
        'refund_debt': 30,
      });
      expect(withDebt.available, 4);
      expect(withDebt.hasRefundDebt, isTrue);
      final CreditBalance noDebt = decodeCreditBalance(<String, Object?>{
        'posted': 5,
        'reserved': 0,
        'available': 5,
      });
      expect(noDebt.refundDebt, 0);
    });

    test('watch maps verification and active recording fields', () {
      final WatchSummary watch = WatchApiModel.fromJson(<String, Object?>{
        'id': 'w1',
        'source': <String, Object?>{'type': 'username', 'value': 'my_shop'},
        'creator': null,
        'status': 'active',
        'live_status': 'live',
        'auto_record': true,
        'auto_record_state': 'active',
        'active_recording_id': 'r1',
        'last_checked_at': null,
        'next_check_at': null,
        'last_live_at': null,
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:00:00Z',
        'verification_required': true,
        'verification_due_at': '2026-11-01T00:00:00Z',
      }).toDomain();

      expect(watch.activeRecordingId, 'r1');
      expect(watch.verificationRequired, isTrue);
      expect(watch.verificationDueAt, DateTime.utc(2026, 11, 1));
    });

    test('credits card tone and caption follow minutes and purchases', () {
      HomeCredits credits(int minutes, {bool purchased = false, int debt = 0}) {
        return HomeCredits.from(
          _entitlement(minutes: minutes, purchased: purchased),
          CreditBalance(
            posted: minutes,
            reserved: 0,
            available: minutes,
            refundDebt: debt,
          ),
        );
      }

      expect(credits(10).caption, HomeCreditsCaption.trial);
      expect(credits(10).progress, 1);
      expect(credits(2).tone, HomeCreditsTone.low);
      expect(credits(2).trialMinutesUsed, 8);
      expect(credits(0).tone, HomeCreditsTone.out);
      expect(credits(0).caption, HomeCreditsCaption.paused);
      expect(credits(760, purchased: true).tone, HomeCreditsTone.normal);
      expect(credits(760, purchased: true).progress, isNull);
      expect(credits(10, purchased: true).tone, HomeCreditsTone.low);
      final HomeCredits owed = credits(120, purchased: true, debt: 30);
      expect(owed.tone, HomeCreditsTone.out);
      expect(owed.minutes, 0);
      expect(owed.refundDebt, 30);
    });
  });

  test('SVG path parser handles relative arcs and implicit commands', () {
    final Rect bounds = parseSvgPathData(
      'M12 8v5M12 16h.01M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18z',
    ).getBounds();
    expect(bounds.left, closeTo(3, 0.01));
    expect(bounds.right, closeTo(21, 0.01));
    expect(bounds.top, closeTo(3, 0.01));
    expect(bounds.bottom, closeTo(21, 0.01));
  });
}

Entitlement _entitlement({required int minutes, required bool purchased}) {
  return Entitlement(
    plan: purchased ? Plan.pro : Plan.free,
    hasPurchased: purchased,
    emailVerified: true,
    cloudMinutesAvailable: minutes,
    limits: const EntitlementLimits(
      maxWatches: 3,
      maxConcurrentCloudRecordings: 1,
      cloudRetentionDays: 30,
    ),
    watchCount: 0,
    local: LocalEntitlement(
      enabled: false,
      unlimited: false,
      dailyMinutes: 0,
      minutesRemaining: 0,
      resetsAt: DateTime.utc(2026, 10, 23),
      rewardsUsedToday: 0,
      rewardsCapPerDay: 0,
      minutesPerReward: 0,
      extensionsCapPerRecording: 0,
    ),
    updatedAt: DateTime.utc(2026, 10, 22),
  );
}

Map<String, Object?> _entitlementJson() => <String, Object?>{
  'plan': 'free',
  'has_purchased': false,
  'cloud_minutes_available': 10,
  'limits': <String, Object?>{
    'max_watches': 3,
    'max_concurrent_cloud_recordings': 1,
    'cloud_retention_days': 7,
  },
  'watch_count': 0,
  'local': <String, Object?>{
    'enabled': false,
    'unlimited': false,
    'daily_minutes': 0,
    'minutes_remaining': 0,
    'resets_at': '2026-10-23T00:00:00Z',
    'rewards_used_today': 0,
    'rewards_cap_per_day': 0,
    'minutes_per_reward': 0,
    'extensions_cap_per_recording': 0,
  },
  'updated_at': '2026-10-22T00:00:00Z',
};

ApiClient _client(FutureOr<ResponseBody> Function(RequestOptions) handler) {
  final Dio dio = Dio()..httpClientAdapter = _Adapter(handler);
  return ApiClient(
    config: AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: Uri.parse('http://localhost:8000'),
    ),
    dio: dio,
  );
}

ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

ResponseBody _error(int status, String code) => _json(status, <String, Object?>{
  'error': <String, Object?>{
    'code': code,
    'message': 'Any message',
    'request_id': 'req-1',
    'retryable': false,
    'details': const <String, Object?>{},
  },
});

final class _Adapter implements HttpClientAdapter {
  _Adapter(this._handler);

  final FutureOr<ResponseBody> Function(RequestOptions) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _handler(options);

  @override
  void close({bool force = false}) {}
}

final class _NoopProtectedApi implements AuthProtectedApi {
  const _NoopProtectedApi();

  @override
  Future<void> logout() async {}

  @override
  Future<void> deleteAccount() async {}
}

final class _SocialRepo implements AuthRepository, SocialAuthRepository {
  _SocialRepo(this._google);

  final Future<void> _google;
  int logouts = 0;

  @override
  Future<void> signInSocial(
    SocialAuthProvider provider, {
    LegalConsent? consent,
  }) => _google;

  @override
  Future<void> logout() async => logouts += 1;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
