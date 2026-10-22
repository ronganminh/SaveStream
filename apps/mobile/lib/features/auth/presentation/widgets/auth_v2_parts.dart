import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../../l10n/l10n.dart';
import '../../domain/repositories/auth_repository.dart';
import '../auth_validation.dart';
import '../controllers/auth_controller.dart';

/// Opens Account suspended / Account closed when sign-in was refused for
/// that reason (ACCOUNT_SUSPENDED / ACCOUNT_TERMINATED). Returns whether it
/// did.
bool openAccountStatusIfBlocked(
  BuildContext context,
  AuthController controller,
) {
  final AuthFailureCode? failure = controller.failure;
  if (failure != AuthFailureCode.accountSuspended &&
      failure != AuthFailureCode.accountTerminated) {
    return false;
  }
  final AccountStatusDetails details =
      controller.accountStatus ?? const AccountStatusDetails();
  controller.clearFailure();
  context.push(
    AppRoutes.accountStatusLocation(
      closed: failure == AuthFailureCode.accountTerminated,
      reason: details.reason,
      reference: details.reference,
    ),
  );
  return true;
}

/// Bold lead + body copy for an auth failure banner.
(String?, String) authFailureText(AppLocalizations l10n, AuthFailureCode code) {
  return switch (code) {
    AuthFailureCode.invalidCredentials => (
      l10n.v2WrongCredentialsTitle,
      l10n.v2WrongCredentialsBody,
    ),
    AuthFailureCode.emailNotVerified => (
      l10n.v2EmailNotVerifiedTitle,
      l10n.v2EmailNotVerifiedBody,
    ),
    AuthFailureCode.accountLinkRequired => (null, l10n.v2AccountLinkRequired),
    AuthFailureCode.socialUnavailable => (null, l10n.v2SocialUnavailable),
    AuthFailureCode.consentRequired => (null, l10n.v2ConsentRequiredSocial),
    AuthFailureCode.legalOutdated => (null, l10n.v2LegalOutdated),
    AuthFailureCode.cancelled => (null, l10n.v2GoogleErrorBody),
    AuthFailureCode.invalidToken => (null, l10n.authInvalidTokenMessage),
    AuthFailureCode.validation => (null, l10n.authValidationErrorMessage),
    AuthFailureCode.rateLimited => (null, l10n.rateLimitedMessage),
    AuthFailureCode.sessionExpired => (null, l10n.authSessionExpiredMessage),
    AuthFailureCode.server => (null, l10n.authServerErrorMessage),
    AuthFailureCode.offlineLike => (null, l10n.offlineErrorBody),
    AuthFailureCode.accountSuspended => (null, l10n.sysSuspendedTitle),
    AuthFailureCode.accountTerminated => (null, l10n.sysTerminatedTitle),
  };
}

/// Error banner for auth screens ("**Wrong email or password.** Check …").
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({
    required this.failure,
    this.actions = const <Widget>[],
    super.key,
  });

  final AuthFailureCode failure;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final (String? title, String body) = authFailureText(context.l10n, failure);
    return SsV2Banner(
      tone: SsV2Tone.error,
      title: title,
      actions: actions,
      child: Text(body),
    );
  }
}

/// "Continue with Google" (and "Continue with Apple" on iOS only).
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    required this.onProvider,
    this.enabled = true,
    this.showApple,
    super.key,
  });

  final ValueChanged<SocialAuthProvider> onProvider;
  final bool enabled;

  /// Apple sign-in is offered on iOS only. Tests may override.
  final bool? showApple;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool apple = showApple ?? Platform.isIOS;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsV2GoogleButton(
          label: l10n.v2ContinueWithGoogle,
          onPressed: enabled
              ? () => onProvider(SocialAuthProvider.google)
              : null,
        ),
        if (apple) ...<Widget>[
          const SizedBox(height: 10),
          SsV2Button(
            label: 'Continue with Apple',
            variant: SsV2ButtonVariant.outlined,
            leading: const Icon(Icons.apple, size: 22),
            onPressed: enabled
                ? () => onProvider(SocialAuthProvider.apple)
                : null,
          ),
        ],
      ],
    );
  }
}

/// Failures that belong on the Google error screen rather than inline.
bool isGoogleScreenFailure(AuthFailureCode code) {
  return code == AuthFailureCode.server ||
      code == AuthFailureCode.offlineLike ||
      code == AuthFailureCode.rateLimited;
}

/// AGoogleLoading: shown while the Google sheet and the backend exchange run.
class GoogleSignInLoadingBody extends StatelessWidget {
  const GoogleSignInLoadingBody({required this.onCancel, super.key});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsV2StatusBody(
      glyph: SsV2IconGlyph.person,
      tone: SsV2TileTone.brand,
      title: l10n.v2GoogleLoadingTitle,
      body: l10n.v2GoogleLoadingBody,
      extra: const Padding(
        padding: EdgeInsets.only(top: 8),
        child: SsV2Spinner(size: 40, stroke: 4),
      ),
      actions: <Widget>[
        SsV2Button(
          label: l10n.v2Cancel,
          variant: SsV2ButtonVariant.text,
          onPressed: onCancel,
        ),
      ],
    );
  }
}

/// AGoogleError: the Google flow failed for a network/server reason.
class GoogleSignInErrorBody extends StatelessWidget {
  const GoogleSignInErrorBody({
    required this.onRetry,
    required this.onUseEmail,
    super.key,
  });

  final VoidCallback onRetry;
  final VoidCallback onUseEmail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsV2StatusBody(
      glyph: SsV2IconGlyph.alert,
      tone: SsV2TileTone.error,
      title: l10n.v2GoogleErrorTitle,
      body: l10n.v2GoogleErrorBody,
      actions: <Widget>[
        SsV2GoogleButton(label: l10n.v2TryGoogleAgain, onPressed: onRetry),
        SsV2Button(
          label: l10n.v2UseEmailInstead,
          variant: SsV2ButtonVariant.outlined,
          onPressed: onUseEmail,
        ),
      ],
    );
  }
}

/// The single sign-up consent checkbox: 18+, Terms, Privacy and AUP.
class ConsentCheckbox extends StatefulWidget {
  const ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.termsUrl,
    required this.privacyUrl,
    required this.acceptableUseUrl,
    this.showError = false,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Uri termsUrl;
  final Uri privacyUrl;
  final Uri acceptableUseUrl;
  final bool showError;

  @override
  State<ConsentCheckbox> createState() => _ConsentCheckboxState();
}

class _ConsentCheckboxState extends State<ConsentCheckbox> {
  late final TapGestureRecognizer _terms = TapGestureRecognizer()
    ..onTap = () => _open(widget.termsUrl);
  late final TapGestureRecognizer _privacy = TapGestureRecognizer()
    ..onTap = () => _open(widget.privacyUrl);
  late final TapGestureRecognizer _aup = TapGestureRecognizer()
    ..onTap = () => _open(widget.acceptableUseUrl);

  Future<void> _open(Uri url) async {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    _aup.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final TextStyle link = TextStyle(color: palette.link);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MergeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onChanged(!widget.value),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 0),
                  child: SsV2Checkbox(
                    value: widget.value,
                    onChanged: widget.onChanged,
                    hasError: widget.showError,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: l10n.v2ConsentLead),
                        TextSpan(
                          text: l10n.v2TermsOfUse,
                          style: link,
                          recognizer: _terms,
                        ),
                        TextSpan(text: l10n.v2ConsentComma),
                        TextSpan(
                          text: l10n.v2PrivacyPolicy,
                          style: link,
                          recognizer: _privacy,
                        ),
                        TextSpan(text: l10n.v2ConsentAnd),
                        TextSpan(
                          text: l10n.v2AcceptableUsePolicy,
                          style: link,
                          recognizer: _aup,
                        ),
                        TextSpan(text: l10n.v2ConsentTail),
                      ],
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: palette.textConsent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.showError) ...<Widget>[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: SsV2InlineError(message: l10n.v2ConsentError),
          ),
        ],
      ],
    );
  }
}

String? validateEmail(AppLocalizations l10n, String value) {
  if (value.trim().isEmpty) return l10n.v2EmailRequired;
  if (!AuthValidation.isEmail(value)) return l10n.v2EmailInvalid;
  return null;
}
