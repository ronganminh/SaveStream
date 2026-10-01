import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/core/api/api_client.dart';
import 'package:savestream_mobile/core/api/memory_access_token_store.dart';
import 'package:savestream_mobile/core/config/app_config.dart';
import 'package:savestream_mobile/core/config/app_environment.dart';
import 'package:savestream_mobile/features/auth/data/remote/auth_public_api.dart';
import 'package:savestream_mobile/features/billing/data/repositories/api_billing_repository.dart';
import 'package:savestream_mobile/features/billing/domain/models/billing_models.dart';
import 'package:savestream_mobile/features/channels/data/repositories/api_watch_repository.dart';
import 'package:savestream_mobile/features/channels/domain/models/watch_summary.dart';
import 'package:savestream_mobile/features/credits/data/repositories/api_credits_repository.dart';
import 'package:savestream_mobile/features/recordings/data/repositories/api_recording_repository.dart';
import 'package:savestream_mobile/features/recordings/domain/models/recording_summary.dart';
import 'package:savestream_mobile/features/settings/data/repositories/api_profile_repository.dart';

void main() {
  final bool enabled = Platform.environment['MOBILE_BACKEND_E2E'] == '1';

  test(
    'mobile repositories complete the real backend critical path',
    () async {
      final Uri apiBaseUrl = Uri.parse(
        Platform.environment['MOBILE_BACKEND_API_URL'] ??
            'http://127.0.0.1:8000',
      );
      final Uri mailhogBaseUrl = Uri.parse(
        Platform.environment['MOBILE_BACKEND_MAILHOG_URL'] ??
            'http://127.0.0.1:8025',
      );
      final String paymentSecret =
          Platform.environment['MOBILE_BACKEND_PAYMENT_SECRET'] ??
          'savestream-fake-payment-secret';
      final AppConfig config = AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: apiBaseUrl,
      );
      final ApiClient publicClient = ApiClient(config: config);
      final DioAuthPublicApi authApi = DioAuthPublicApi(publicClient);
      final Dio rawDio = Dio();
      ApiClient? authenticatedClient;
      ApiWatchRepository? watchRepository;
      ApiRecordingRepository? recordingRepository;
      String? watchId;
      String? recordingId;

      final String unique = DateTime.now().microsecondsSinceEpoch.toString();
      final String email = 'mobile-e2e-$unique@example.test';
      const String password = 'E2E-Password-123!';

      try {
        await authApi.register(email: email, password: password);
        final String verificationToken = await _waitForVerificationToken(
          rawDio,
          mailhogBaseUrl,
          email,
        );
        await authApi.verifyEmail(token: verificationToken);

        final tokens = await authApi.login(email: email, password: password);
        final MemoryAccessTokenStore accessTokenStore =
            MemoryAccessTokenStore()..setAccessToken(tokens.accessToken);
        authenticatedClient = ApiClient(
          config: config,
          accessTokenProvider: accessTokenStore,
        );

        final profileRepository = ApiProfileRepository(
          apiClient: authenticatedClient,
        );
        final profile = await profileRepository.getProfile();
        expect(profile.email, email);
        expect(profile.emailVerified, isTrue);

        watchRepository = ApiWatchRepository(apiClient: authenticatedClient);
        final watch = await watchRepository.createWatch(
          const CreateWatchCommand(
            sourceType: WatchSourceType.roomId,
            sourceValue: 'e2e-room',
            autoRecord: false,
          ),
        );
        watchId = watch.id;
        expect(watch.status, WatchStatus.active);

        final billingRepository = ApiBillingRepository(
          apiClient: authenticatedClient,
        );
        final creditsRepository = ApiCreditsRepository(
          apiClient: authenticatedClient,
        );
        final BillingSnapshot billing = await billingRepository.getSnapshot();
        expect(billing.packages, isNotEmpty);
        final CreditPackage package = billing.packages.first;

        final initialBalance = await creditsRepository.getBalance();
        expect(initialBalance.posted, 0);

        final PaymentOrder? created = await billingRepository.createPaymentOrder(
          package.id,
        );
        expect(created, isNotNull);
        final CheckoutSession? checkout = await billingRepository.createCheckout(
          orderId: created!.id,
          returnUri: Uri.parse('https://example.test/payment-return'),
        );
        expect(checkout, isNotNull);
        expect(checkout!.paymentOrder.status, PaymentOrderStatus.pending);

        final pendingBalance = await creditsRepository.getBalance();
        expect(pendingBalance.posted, 0);

        await _markPaymentPaid(
          rawDio,
          apiBaseUrl,
          paymentSecret,
          checkout.paymentOrder,
        );
        final PaymentOrder? paid = await billingRepository.refreshPaymentOrder(
          created.id,
        );
        expect(paid?.status, PaymentOrderStatus.paid);

        final fundedBalance = await creditsRepository.getBalance();
        expect(fundedBalance.posted, package.credits);

        recordingRepository = ApiRecordingRepository(
          apiClient: authenticatedClient,
        );
        final recording = await recordingRepository.createRecording(
          const CreateRecordingCommand(
            sourceType: RecordingSourceType.roomId,
            sourceValue: 'e2e-room',
            maxDurationSeconds: 3,
          ),
        );
        recordingId = recording.id;

        final RecordingSummary terminal = await _waitForTerminalRecording(
          recordingRepository,
          recording.id,
        );
        expect(terminal.status, RecordingStatus.completed);

        final artifacts = await recordingRepository.listArtifacts(recording.id);
        expect(artifacts, hasLength(1));
        final download = await recordingRepository.createArtifactDownloadUrl(
          artifacts.single.id,
        );
        expect(download.uri.hasScheme, isTrue);

        final settledBalance = await creditsRepository.getBalance();
        expect(settledBalance.posted, package.credits - 1);
      } finally {
        if (recordingId != null && recordingRepository != null) {
          try {
            await recordingRepository.deleteRecording(recordingId);
          } on Object {
            // Best-effort E2E cleanup.
          }
        }
        if (watchId != null && watchRepository != null) {
          try {
            await watchRepository.deleteWatch(watchId);
          } on Object {
            // Best-effort E2E cleanup.
          }
        }
        if (authenticatedClient != null) {
          try {
            await authenticatedClient.delete<Object?>(
              '/v1/me',
              decoder: (_) => null,
            );
          } on Object {
            // Best-effort E2E cleanup.
          }
          authenticatedClient.close(force: true);
        }
        publicClient.close(force: true);
        rawDio.close(force: true);
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<String> _waitForVerificationToken(
  Dio dio,
  Uri mailhogBaseUrl,
  String email,
) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 45));

  while (DateTime.now().isBefore(deadline)) {
    final Response<Object?> response = await dio.getUri<Object?>(
      mailhogBaseUrl.resolve('/api/v2/messages'),
    );
    final Object? body = response.data;
    if (body is Map && body['items'] is List) {
      for (final Object? rawItem in body['items'] as List) {
        if (rawItem is! Map) continue;
        final String itemJson = jsonEncode(rawItem);
        if (!itemJson.contains(email)) continue;

        final List<String> candidates = <String>[
          if (rawItem['Raw'] is Map)
            ((rawItem['Raw'] as Map)['Data'] ?? '').toString(),
          if (rawItem['Content'] is Map)
            ((rawItem['Content'] as Map)['Body'] ?? '').toString(),
          itemJson,
        ];
        for (final String candidate in candidates) {
          final String decoded = _decodeQuotedPrintable(candidate);
          final RegExpMatch? match = RegExp(
            r'verify-email\?token=([^\s<>"&]+)',
          ).firstMatch(decoded);
          if (match != null) {
            return Uri.decodeComponent(match.group(1)!);
          }
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  throw TimeoutException('Verification email was not delivered.');
}

String _decodeQuotedPrintable(String input) {
  final String joined = input
      .replaceAll('=\r\n', '')
      .replaceAll('=\n', '');
  return joined.replaceAllMapped(RegExp(r'=([0-9A-Fa-f]{2})'), (
    RegExpMatch match,
  ) {
    return String.fromCharCode(int.parse(match.group(1)!, radix: 16));
  });
}

Future<void> _markPaymentPaid(
  Dio dio,
  Uri apiBaseUrl,
  String secret,
  PaymentOrder order,
) async {
  final String? paymentReference = order.providerReference;
  if (paymentReference == null || paymentReference.isEmpty) {
    throw StateError('Checkout did not provide a payment reference.');
  }

  final Map<String, Object?> event = <String, Object?>{
    'id': 'mobile-e2e-${DateTime.now().microsecondsSinceEpoch}',
    'type': 'payment.paid',
    'payment_reference': paymentReference,
    'amount_minor': order.amount.amountMinor,
    'currency': order.amount.currency,
  };
  final String raw = jsonEncode(event);
  final String signature = Hmac(
    sha256,
    utf8.encode(secret),
  ).convert(utf8.encode(raw)).toString();

  final Response<Object?> response = await dio.postUri<Object?>(
    apiBaseUrl.resolve('/v1/webhooks/payments/fake'),
    data: raw,
    options: Options(
      headers: <String, Object?>{
        Headers.contentTypeHeader: Headers.jsonContentType,
        'X-Payment-Signature': signature,
      },
      responseType: ResponseType.plain,
      validateStatus: (int? status) => status == 204,
    ),
  );
  expect(response.statusCode, 204);
}

Future<RecordingSummary> _waitForTerminalRecording(
  ApiRecordingRepository repository,
  String recordingId,
) async {
  final DateTime deadline = DateTime.now().add(const Duration(seconds: 90));

  while (DateTime.now().isBefore(deadline)) {
    final RecordingSummary? recording = await repository.getRecording(
      recordingId,
    );
    if (recording != null && !recording.isActiveLifecycle) {
      return recording;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  throw TimeoutException('Recording did not reach a terminal state.');
}
