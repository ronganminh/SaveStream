/// AVerifyCode · AVerifyChecking · AVerifyDone · AVerifyNotYet ·
/// AVerifyExpired — prove a channel is yours with a code in its TikTok bio.
///
/// `POST /v1/watches/{id}/verification` returns the current code (or a new
/// one), `POST …/verification/check` asks the server to read the bio. The
/// expiry shown is the server's `expires_at`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/ss_feedback.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../home/presentation/controllers/home_dashboard_controller.dart';
import '../domain/models/channel_verification.dart';
import '../domain/models/watch_summary.dart';
import 'channel_v2_parts.dart';
import 'controllers/watch_providers.dart';

enum _Phase {
  loading,
  loadError,
  code,
  checking,
  notYet,
  retryLater,
  expired,
  verified,
}

class VerifyOwnershipScreen extends ConsumerStatefulWidget {
  const VerifyOwnershipScreen({required this.watchId, super.key});

  final String watchId;

  @override
  ConsumerState<VerifyOwnershipScreen> createState() =>
      _VerifyOwnershipScreenState();
}

class _VerifyOwnershipScreenState extends ConsumerState<VerifyOwnershipScreen> {
  _Phase _phase = _Phase.loading;
  ChannelVerification? _verification;
  String? _lastCode;
  String? _loadError;
  String? _actionError;
  String? _autoRecordError;
  bool _autoRecordBusy = false;
  Timer? _expiryTicker;

  @override
  void initState() {
    super.initState();
    _start();
    // Re-evaluate the server's expires_at while the screen is open.
    _expiryTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiryTicker?.cancel();
    super.dispose();
  }

  DateTime _now() => ref.read(homeClockProvider)().toUtc();

  Future<void> _start() async {
    setState(() {
      if (_verification == null) _phase = _Phase.loading;
      _loadError = null;
      _actionError = null;
    });
    try {
      final ChannelVerification result = await ref
          .read(channelVerificationRepositoryProvider)
          .startVerification(widget.watchId);
      if (!mounted) return;
      if (result.verified ||
          result.result == VerificationCheckResult.verified) {
        await _onVerified(result);
        return;
      }
      setState(() {
        _verification = result;
        _lastCode = result.code ?? _lastCode;
        _phase = _Phase.code;
      });
    } on Object catch (error) {
      if (!mounted) return;
      final AppLocalizations l10n = context.l10n;
      setState(() {
        _loadError = error is ApiException && error.statusCode == 429
            ? l10n.v2TooManyCodes
            : l10n.v2VerifyLoadError;
        if (_verification == null) {
          _phase = _Phase.loadError;
        } else {
          _actionError = _loadError;
        }
      });
    }
  }

  Future<void> _check() async {
    setState(() {
      _phase = _Phase.checking;
      _actionError = null;
    });
    try {
      final ChannelVerification result = await ref
          .read(channelVerificationRepositoryProvider)
          .checkVerification(widget.watchId);
      if (!mounted) return;
      if (result.verified ||
          result.result == VerificationCheckResult.verified) {
        await _onVerified(result);
        return;
      }
      setState(() {
        _verification = result;
        _lastCode = result.code ?? _lastCode;
        _phase = result.result == VerificationCheckResult.retryLater
            ? _Phase.retryLater
            : _Phase.notYet;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is ApiException && error.code == 'VERIFICATION_EXPIRED') {
          _phase = _Phase.expired;
        } else {
          _phase = _Phase.code;
          _actionError = context.l10n.v2ActionFailed;
        }
      });
    }
  }

  Future<void> _onVerified(ChannelVerification result) async {
    setState(() {
      _verification = result;
      _phase = _Phase.verified;
    });
    final WatchController controller = ref.read(watchControllerProvider);
    controller.refresh(widget.watchId);
    // New channels are added with recording and alerts off until verified;
    // turn both on now, as the "verified" screen shows.
    await _setAutoRecord(true);
    try {
      await controller.setNotifyOnLive(widget.watchId, enabled: true);
    } on Object {
      // Alerts can be switched on from the channel screen.
    }
  }

  Future<void> _setAutoRecord(bool enabled) async {
    setState(() {
      _autoRecordBusy = true;
      _autoRecordError = null;
    });
    try {
      await ref
          .read(watchControllerProvider)
          .setAutoRecord(widget.watchId, enabled: enabled);
    } on Object catch (error) {
      if (!mounted) return;
      final AppLocalizations l10n = context.l10n;
      setState(() {
        _autoRecordError = error is ApiException && error.statusCode == 403
            ? l10n.v2AutoRecordNeedsMinutes
            : l10n.v2ActionFailed;
      });
    } finally {
      if (mounted) setState(() => _autoRecordBusy = false);
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.channelDetail(widget.watchId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final WatchSummary? watch = ref
        .watch(watchDetailProvider(widget.watchId))
        .value;
    final String? handle = watch == null ? null : channelHandle(watch);
    final ChannelVerification? verification = _verification;
    _Phase phase = _phase;
    // A code past its server expiry can't be checked any more.
    if (verification != null &&
        verification.isExpiredAt(_now()) &&
        (phase == _Phase.code ||
            phase == _Phase.notYet ||
            phase == _Phase.retryLater)) {
      phase = _Phase.expired;
    }

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ChannelsTopBar(
            title: l10n.v2VerifyOwnershipTitle,
            subtitle: handle,
            onBack: _leave,
          ),
          Expanded(
            child: switch (phase) {
              _Phase.loading => const Center(child: SsV2Spinner()),
              _Phase.loadError => _LoadError(
                message: _loadError ?? l10n.v2VerifyLoadError,
                onRetry: _start,
                onCancel: _leave,
              ),
              _Phase.verified => _Verified(
                watchId: widget.watchId,
                handle: handle ?? '',
                code: _lastCode,
                autoRecord: watch?.autoRecord ?? false,
                busy: _autoRecordBusy,
                error: _autoRecordError,
                onAutoRecord: _setAutoRecord,
              ),
              _ => _CodeBody(
                phase: phase,
                verification: verification!,
                handle: handle ?? '',
                now: _now(),
                actionError: _actionError,
                onCheck: _check,
                onNewCode: _start,
                onLater: _leave,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _CodeBody extends StatelessWidget {
  const _CodeBody({
    required this.phase,
    required this.verification,
    required this.handle,
    required this.now,
    required this.actionError,
    required this.onCheck,
    required this.onNewCode,
    required this.onLater,
  });

  final _Phase phase;
  final ChannelVerification verification;
  final String handle;
  final DateTime now;
  final String? actionError;
  final VoidCallback onCheck;
  final VoidCallback onNewCode;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final String code = verification.code ?? '';
    final bool expired = phase == _Phase.expired;
    final bool showSteps = phase == _Phase.code || phase == _Phase.checking;

    final Widget? status = switch (phase) {
      _Phase.checking => const _CheckingStatus(),
      _Phase.notYet => SsV2Banner(
        tone: SsV2Tone.warning,
        glyph: SsV2IconGlyph.alert,
        title: l10n.v2CodeNotFoundTitle(code),
        child: Text(l10n.v2CodeNotFoundBody),
      ),
      _Phase.retryLater => SsV2Banner(
        tone: SsV2Tone.warning,
        glyph: SsV2IconGlyph.clock,
        title: l10n.v2RetryLaterTitle,
        child: Text(
          l10n.v2RetryLaterBody(verification.retryAfterSeconds ?? 10),
        ),
      ),
      _Phase.expired => SsV2Banner(
        tone: SsV2Tone.error,
        glyph: SsV2IconGlyph.clock,
        title: l10n.v2CodeExpiredTitle,
        child: Text(l10n.v2CodeExpiredBody),
      ),
      _ => null,
    };

    final List<Widget> actions = switch (phase) {
      _Phase.checking => <Widget>[_DisabledButton(label: l10n.v2Checking)],
      _Phase.expired => <Widget>[
        SsV2Button(label: l10n.v2GetNewCode, onPressed: onNewCode),
        SsV2Button(
          label: l10n.v2Cancel,
          variant: SsV2ButtonVariant.text,
          onPressed: onLater,
        ),
      ],
      _ => <Widget>[
        SsV2Button(
          label: phase == _Phase.code ? l10n.v2CheckMyBio : l10n.v2CheckAgain,
          onPressed: onCheck,
        ),
        SsV2Button(
          label: l10n.v2DoItLater,
          variant: SsV2ButtonVariant.text,
          onPressed: onLater,
        ),
      ],
    };

    final TextStyle bold = TextStyle(
      fontWeight: FontWeight.w700,
      color: palette.text,
    );
    return SsV2FillScroll(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      gap: 18,
      children: <Widget>[
        Text.rich(
          TextSpan(
            children: <InlineSpan>[
              TextSpan(text: l10n.v2VerifyIntroLead),
              TextSpan(text: handle, style: bold),
              TextSpan(text: l10n.v2VerifyIntroTail),
            ],
          ),
          style: TextStyle(fontSize: 15, height: 1.5, color: palette.textMuted),
        ),
        _CodeCard(
          code: code,
          expiresAt: verification.expiresAt,
          now: now,
          expired: expired,
        ),
        if (showSteps) const _Steps(),
        if (status != null) status,
        if (actionError != null) SsV2InlineError(message: actionError!),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: ssV2Gap(actions, 8),
        ),
      ],
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.code,
    required this.expiresAt,
    required this.now,
    required this.expired,
  });

  final String code;
  final DateTime? expiresAt;
  final DateTime now;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final DateTime? expires = expiresAt;
    final String? expiry = expired
        ? l10n.v2Expired
        : expires == null
        ? null
        : l10n.v2ExpiresIn(
            // Whole minutes left until the server's expires_at, rounded up.
            ((expires.difference(now).inSeconds + 59) ~/ 60).clamp(1, 1 << 20),
          );
    return Opacity(
      opacity: expired ? 0.55 : 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.divider),
        ),
        child: Column(
          children: <Widget>[
            Text(
              l10n.v2YourVerificationCode,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                code,
                key: const ValueKey<String>('verification-code'),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: <Widget>[
                Material(
                  color: palette.tint,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: expired || code.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: code));
                            if (context.mounted) {
                              SsSnackbar.show(context, l10n.v2CodeCopied);
                            }
                          },
                    child: SizedBox(
                      height: 40,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SsV2Icon(
                              SsV2IconGlyph.copy,
                              size: 18,
                              color: palette.link,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.v2CopyCode,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: palette.link,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (expiry != null)
                  Text(
                    expiry,
                    style: TextStyle(fontSize: 13, color: palette.textMuted),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    const TextStyle bold = TextStyle(fontWeight: FontWeight.w700);
    final List<(String, String, String)> steps = <(String, String, String)>[
      (l10n.v2VerifyStep1Lead, l10n.v2VerifyStep1Bold, l10n.v2VerifyStep1Tail),
      (l10n.v2VerifyStep2Lead, l10n.v2VerifyStep2Bold, l10n.v2VerifyStep2Tail),
      (l10n.v2VerifyStep3Lead, l10n.v2VerifyStep3Bold, l10n.v2VerifyStep3Tail),
    ];
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 15, height: 1.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: ssV2Gap(<Widget>[
          for (int i = 0; i < steps.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 22,
                  child: Text('${i + 1}.', textAlign: TextAlign.right),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: steps[i].$1),
                        TextSpan(text: steps[i].$2, style: bold),
                        TextSpan(text: steps[i].$3),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ], 8),
      ),
    );
  }
}

class _CheckingStatus extends StatelessWidget {
  const _CheckingStatus();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.tintSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            const SsV2Spinner(size: 24, stroke: 3),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: l10n.v2CheckingBioTitle,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' ${l10n.v2CheckingBioBody}'),
                  ],
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The grey "Checking…" button drawn while the check runs.
class _DisabledButton extends StatelessWidget {
  const _DisabledButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Semantics(
      button: true,
      enabled: false,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.skeleton,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.disabled,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({
    required this.message,
    required this.onRetry,
    required this.onCancel,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsV2FillScroll(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
      gap: 18,
      children: <Widget>[
        SsV2Banner(tone: SsV2Tone.error, child: Text(message)),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: ssV2Gap(<Widget>[
            SsV2Button(label: l10n.v2Retry, onPressed: onRetry),
            SsV2Button(
              label: l10n.v2Cancel,
              variant: SsV2ButtonVariant.text,
              onPressed: onCancel,
            ),
          ], 8),
        ),
      ],
    );
  }
}

class _Verified extends StatelessWidget {
  const _Verified({
    required this.watchId,
    required this.handle,
    required this.code,
    required this.autoRecord,
    required this.busy,
    required this.error,
    required this.onAutoRecord,
  });

  final String watchId;
  final String handle;
  final String? code;
  final bool autoRecord;
  final bool busy;
  final String? error;
  final ValueChanged<bool> onAutoRecord;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    return SsV2StatusBody(
      glyph: SsV2IconGlyph.shield,
      tone: SsV2TileTone.success,
      title: l10n.v2ChannelVerifiedTitle(handle),
      body: code == null
          ? l10n.v2ChannelVerifiedBodyNoCode
          : l10n.v2ChannelVerifiedBody(code!),
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.divider),
            ),
            child: SsV2SwitchRow(
              title: l10n.v2AutoRecordWhenLive,
              subtitle: l10n.v2UsesRecordingMinutes,
              value: autoRecord,
              onChanged: busy ? null : onAutoRecord,
            ),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: 8),
            SsV2InlineError(message: error!),
          ],
        ],
      ),
      actions: <Widget>[
        SsV2Button(
          label: l10n.v2GoToChannel,
          onPressed: () => context.go(AppRoutes.channelDetail(watchId)),
        ),
        SsV2Button(
          label: l10n.v2AddAnotherChannel,
          variant: SsV2ButtonVariant.text,
          onPressed: () => context.go(AppRoutes.addChannel),
        ),
      ],
    );
  }
}
