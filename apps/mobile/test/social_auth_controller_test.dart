import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:savestream_mobile/app/session/app_session_controller.dart';
import 'package:savestream_mobile/core/legal/legal_consent.dart';
import 'package:savestream_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:savestream_mobile/features/auth/presentation/controllers/auth_controller.dart';
import 'package:savestream_mobile/features/auth/presentation/widgets/auth_v2_parts.dart';
import 'package:savestream_mobile/l10n/l10n.dart';

void main() {
  group('social auth controller', () {
    test('successful Google login reuses the normal session', () async {
      final repository = _FakeSocialRepository();
      final session = AppSessionController(
        authStatus: AppAuthStatus.unauthenticated,
      );
      final controller = AuthController(
        repository: repository,
        session: session,
      );

      expect(await controller.signInSocial(SocialAuthProvider.google), isTrue);
      expect(repository.lastProvider, SocialAuthProvider.google);
      expect(session.authStatus, AppAuthStatus.authenticated);
      expect(controller.failure, isNull);
      controller.dispose();
    });

    test(
      'cancelling Apple login does not show an error or create a session',
      () async {
        final repository = _FakeSocialRepository(
          failure: AuthFailureCode.cancelled,
        );
        final session = AppSessionController(
          authStatus: AppAuthStatus.unauthenticated,
        );
        final controller = AuthController(
          repository: repository,
          session: session,
        );

        expect(
          await controller.signInSocial(SocialAuthProvider.apple),
          isFalse,
        );
        expect(session.authStatus, AppAuthStatus.unauthenticated);
        expect(controller.failure, isNull);
        expect(controller.isLoading, isFalse);
        controller.dispose();
      },
    );

    test('existing email conflict requires secure account linking', () async {
      final repository = _FakeSocialRepository(
        failure: AuthFailureCode.accountLinkRequired,
      );
      final session = AppSessionController(
        authStatus: AppAuthStatus.unauthenticated,
      );
      final controller = AuthController(
        repository: repository,
        session: session,
      );

      expect(await controller.signInSocial(SocialAuthProvider.google), isFalse);
      expect(controller.failure, AuthFailureCode.accountLinkRequired);
      expect(session.authStatus, AppAuthStatus.unauthenticated);
      controller.dispose();
    });
  });

  group('social auth buttons', () {
    Widget host(bool showApple) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SocialSignInButtons(onProvider: (_) {}, showApple: showApple),
      ),
    );

    testWidgets('hides Apple sign-in outside iOS', (WidgetTester tester) async {
      await tester.pumpWidget(host(false));
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
    });

    testWidgets('keeps Apple sign-in on iOS', (WidgetTester tester) async {
      await tester.pumpWidget(host(true));
      expect(find.text('Continue with Apple'), findsOneWidget);
    });
  });
}

final class _FakeSocialRepository
    implements AuthRepository, SocialAuthRepository {
  _FakeSocialRepository({this.failure});

  final AuthFailureCode? failure;
  SocialAuthProvider? lastProvider;

  @override
  Future<void> signInSocial(
    SocialAuthProvider provider, {
    LegalConsent? consent,
  }) async {
    lastProvider = provider;
    if (failure case final code?) {
      throw AuthException(code);
    }
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> register({
    required String email,
    required String password,
    LegalConsent? consent,
  }) async {}

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
