/// AVerifyEmail · AVerifyEmailError · AVerified — email verification.
///
/// The backend verifies with the one-time link token from the email
/// (`POST /v1/auth/verify-email`); there is no 6-digit code endpoint, so this
/// screen asks the user to open the link and handles the `?token=` deep link.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/session/app_session_controller.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../domain/repositories/auth_repository.dart';
import 'check_email_screen.dart';
import 'controllers/auth_controller.dart';
import 'widgets/auth_v2_parts.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    required this.repository,
    required this.session,
    this.initialToken,
    this.justSent = false,
    super.key,
  });

  final AuthRepository repository;
  final AppSessionController session;
  final String? initialToken;

  /// True right after sign-up sent the email: resend starts on cooldown.
  final bool justSent;

  static const Duration resendCooldown = Duration(seconds: 60);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  late final AuthController _controller;
  bool _verifying = false;
  bool _verified = false;
  bool _linkFailed = false;
  String? _lastHandledToken;
  Timer? _cooldownTimer;
  int _cooldownLeft = 0;

  @override
  void initState() {
    super.initState();
    _controller = AuthController(
      repository: widget.repository,
      session: widget.session,
    );
    if (widget.justSent && (widget.initialToken ?? '').trim().isEmpty) {
      _startCooldown();
    }
    _scheduleTokenVerification(widget.initialToken);
  }

  @override
  void didUpdateWidget(covariant VerifyEmailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialToken != oldWidget.initialToken) {
      _scheduleTokenVerification(widget.initialToken);
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownLeft = VerifyEmailScreen.resendCooldown.inSeconds;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownLeft -= 1;
        if (_cooldownLeft <= 0) {
          _cooldownLeft = 0;
          timer.cancel();
        }
      });
    });
  }

  void _scheduleTokenVerification(String? rawToken) {
    final String token = rawToken?.trim() ?? '';
    if (token.isEmpty || token == _lastHandledToken) return;
    _lastHandledToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _verify(token);
    });
  }

  Future<void> _verify(String token) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _linkFailed = false;
    });
    final bool verified = await _controller.verifyEmail(token: token);
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verified = verified;
      _linkFailed = !verified;
    });
  }

  Future<void> _resend(String email) async {
    final bool sent = await _controller.resendVerification(email: email);
    if (!mounted) return;
    if (sent) {
      setState(() => _linkFailed = false);
      _startCooldown();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.v2VerificationSent)));
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.signIn);
    }
  }

  void _leaveVerified(String route) {
    // Verifying by link does not sign the user in: email accounts sign in
    // with their password next, then land on Home or Add channel.
    context.go(widget.session.isAuthenticated ? route : AppRoutes.signIn);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (_verified) {
      return SsV2Page(
        child: SsV2StatusBody(
          glyph: SsV2IconGlyph.check,
          tone: SsV2TileTone.success,
          title: l10n.v2VerifiedTitle,
          body: l10n.v2VerifiedBody,
          extra: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SsV2StatusChip(
              label: l10n.v2FreeMinutesChip,
              tone: SsV2ChipTone.brand,
              fontSize: 14,
            ),
          ),
          actions: <Widget>[
            SsV2Button(
              label: l10n.v2AddFirstChannel,
              onPressed: () => _leaveVerified(AppRoutes.addChannel),
            ),
            SsV2Button(
              label: l10n.v2GoToHome,
              variant: SsV2ButtonVariant.text,
              onPressed: () => _leaveVerified(AppRoutes.home),
            ),
          ],
        ),
      );
    }

    return SsV2Page(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return _buildPending(context);
        },
      ),
    );
  }

  Widget _buildPending(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final String? email = widget.session.pendingVerificationEmail;
    final AuthFailureCode? failure = _controller.failure;
    final bool showBanner =
        failure != null && failure != AuthFailureCode.invalidToken;
    final String cooldown =
        '${_cooldownLeft ~/ 60}:${(_cooldownLeft % 60).toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SsV2Header(onBack: _back),
        Expanded(
          child: SsV2FillScroll(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
            gap: 20,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: palette.tint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: SsV2Icon(
                    SsV2IconGlyph.mail,
                    size: 30,
                    color: palette.link,
                  ),
                ),
              ),
              SsV2TitleBlock(
                title: l10n.v2VerifyTitle,
                subtitle: email == null
                    ? Text(l10n.v2VerifyBodyGeneric)
                    : Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(text: l10n.v2VerifyBodyLead),
                            TextSpan(
                              text: email,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: palette.text,
                              ),
                            ),
                            TextSpan(text: l10n.v2VerifyBodyTail),
                          ],
                        ),
                      ),
              ),
              if (showBanner) AuthErrorBanner(failure: failure),
              if (_verifying)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const SsV2Spinner(size: 20, stroke: 3),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        l10n.v2Verifying,
                        style: TextStyle(
                          fontSize: 14,
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              if (_linkFailed && !showBanner)
                SsV2InlineError(
                  message: l10n.v2VerifyLinkError,
                  fontSize: 14,
                  center: true,
                ),
              if (email != null)
                Wrap(
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    Text(
                      '${l10n.v2DidntGetIt} ',
                      style: TextStyle(fontSize: 14, color: palette.textMuted),
                    ),
                    if (_cooldownLeft > 0)
                      Text(
                        l10n.v2ResendIn(cooldown),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.textMuted,
                        ),
                      )
                    else
                      SsV2Link(
                        label: l10n.v2Resend,
                        onPressed: _controller.isLoading
                            ? null
                            : () => _resend(email),
                      ),
                  ],
                ),
              const Spacer(),
              SsV2Button(label: l10n.v2OpenEmailApp, onPressed: openEmailApp),
              Center(
                child: SsV2Link(
                  label: l10n.v2UseDifferentEmail,
                  onPressed: () => context.go(AppRoutes.register),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
