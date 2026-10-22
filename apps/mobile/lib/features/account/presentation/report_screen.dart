/// AReport · AReportSent — report content or request removal.
///
/// Abuse / removal reports go to POST /v1/public/reports (the web /report
/// form's endpoint, a case in Admin → Safety). When that endpoint needs its
/// web-only Turnstile challenge, or for a copyright notice (which needs the
/// full notice the web form collects), the web /report form opens in the
/// browser instead; nothing is pretended to be sent.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/app_config_provider.dart';
import '../../../core/external_links.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/widgets/auth_v2_parts.dart' show validateEmail;
import '../../credits/presentation/credits_v2_parts.dart' show showCreditsToast;
import '../../settings/domain/models/user_profile.dart';
import '../../settings/presentation/controllers/settings_providers.dart';
import '../data/report_repository.dart';
import 'account_parts.dart';
import 'account_providers.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  final TextEditingController _target = TextEditingController(text: '@');
  final TextEditingController _details = TextEditingController();
  final TextEditingController _email = TextEditingController();
  late final TapGestureRecognizer _copyright = TapGestureRecognizer()
    ..onTap = () =>
        openExternalUrl(ref.read(appConfigProvider).copyrightPolicyUrl);
  ReportCategory _category = ReportCategory.recordingMyLive;
  bool _emailFilled = false;
  bool _sending = false;
  String? _targetError;
  String? _detailsError;
  String? _emailError;
  String? _formError;

  @override
  void dispose() {
    _target.dispose();
    _details.dispose();
    _email.dispose();
    _copyright.dispose();
    super.dispose();
  }

  Future<void> _openWebForm() async {
    final AppConfig config = ref.read(appConfigProvider);
    await openExternalUrl(
      config.reportFormUrl(abuse: _category != ReportCategory.copyright),
    );
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    FocusScope.of(context).unfocus();
    if (_category == ReportCategory.copyright) {
      await _openWebForm();
      return;
    }
    final String target = _target.text.trim();
    setState(() {
      _formError = null;
      _targetError = target.isEmpty || target == '@'
          ? l10n.acReportTargetRequired
          : null;
      _detailsError = _details.text.trim().isEmpty
          ? l10n.acReportDetailsRequired
          : null;
      _emailError = validateEmail(l10n, _email.text);
    });
    if (_targetError != null || _detailsError != null || _emailError != null) {
      return;
    }
    setState(() => _sending = true);
    final String email = _email.text.trim();
    try {
      final String reference = await ref
          .read(reportRepositoryProvider)
          .submit(
            ContentReport(
              category: _category,
              target: target,
              details: _details.text,
              email: email,
            ),
          );
      if (!mounted) return;
      context.pushReplacement(
        AppRoutes.reportSentLocation(reference: reference, email: email),
      );
    } on ReportNeedsWebFormException {
      // The endpoint wants the web challenge: finish on the web form.
      if (!mounted) return;
      showCreditsToast(context, l10n.acReportWebNeeded);
      await _openWebForm();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = error.kind == ApiExceptionKind.rateLimited
            ? l10n.rateLimitedMessage
            : l10n.acReportFailed(AppConfig.abuseEmail);
      });
    } on Object {
      if (mounted) {
        setState(() => _formError = l10n.acReportFailed(AppConfig.abuseEmail));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final UserProfile? profile = ref.watch(profileProvider).value;
    if (!_emailFilled && profile != null) {
      _emailFilled = true;
      if (_email.text.isEmpty) _email.text = profile.email;
    }
    final bool copyright = _category == ReportCategory.copyright;
    final TextStyle footnote = TextStyle(
      fontSize: 12,
      height: 1.5,
      color: palette.textMuted,
    );
    final List<(ReportCategory, String)> options = <(ReportCategory, String)>[
      (ReportCategory.recordingMyLive, l10n.acReportLive),
      (ReportCategory.copyright, l10n.acReportCopyright),
      (ReportCategory.removeRecordingOfMe, l10n.acReportRemoveMe),
      (ReportCategory.other, l10n.acReportOther),
    ];

    return SsV2Page(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SsV2Header(
            onBack: () => accountBack(context),
            title: l10n.acReportTitle,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: ssV2Gap(<Widget>[
                Text(
                  l10n.acReportIntro,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: palette.textMuted,
                  ),
                ),
                Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        l10n.acReportQuestion,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final (ReportCategory value, String label)
                          in options)
                        _RadioRow(
                          key: ValueKey<String>('report-${value.name}'),
                          label: label,
                          selected: _category == value,
                          onTap: () => setState(() {
                            _category = value;
                            _formError = null;
                          }),
                        ),
                    ],
                  ),
                ),
                if (copyright)
                  SsV2Banner(
                    tone: SsV2Tone.info,
                    child: Text(l10n.acReportCopyrightWeb),
                  )
                else ...<Widget>[
                  SsV2TextField(
                    fieldKey: const ValueKey<String>('report-target'),
                    label: l10n.acReportTarget,
                    controller: _target,
                    errorText: _targetError,
                    maxLength: 2048,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        l10n.acReportDetails,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _DetailsField(
                        controller: _details,
                        hint: l10n.acReportDetailsHint,
                        label: l10n.acReportDetails,
                        errorText: _detailsError,
                      ),
                    ],
                  ),
                  SsV2TextField(
                    fieldKey: const ValueKey<String>('report-email'),
                    label: l10n.acReportEmail,
                    controller: _email,
                    errorText: _emailError,
                    maxLength: 320,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.email],
                    autocorrect: false,
                  ),
                ],
                if (_formError != null)
                  SsV2Banner(tone: SsV2Tone.error, child: Text(_formError!)),
                SsV2Button(
                  key: const ValueKey<String>('report-send'),
                  label: copyright
                      ? l10n.acReportContinueWeb
                      : l10n.acReportSend,
                  isLoading: _sending,
                  onPressed: _submit,
                ),
                Text.rich(
                  TextSpan(
                    style: footnote,
                    children: <InlineSpan>[
                      TextSpan(text: l10n.acReportFootPrefix),
                      TextSpan(
                        text: l10n.acReportFootLink,
                        recognizer: _copyright,
                        style: TextStyle(
                          color: palette.link,
                          decoration: TextDecoration.underline,
                          decorationColor: palette.link,
                        ),
                      ),
                      TextSpan(
                        text: l10n.acReportFootSuffix(AppConfig.abuseEmail),
                      ),
                    ],
                  ),
                ),
              ], 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: <Widget>[
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? palette.primary : palette.textMuted,
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: selected
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 110px "Details" box (its label sits above it, as drawn).
class _DetailsField extends StatelessWidget {
  const _DetailsField({
    required this.controller,
    required this.hint,
    required this.label,
    this.errorText,
  });

  final TextEditingController controller;
  final String hint;
  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final bool hasError = errorText != null;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          label: label,
          child: TextField(
            key: const ValueKey<String>('report-details'),
            controller: controller,
            minLines: 4,
            maxLines: 8,
            // The server takes 10,000; the category line goes first.
            maxLength: 9800,
            keyboardType: TextInputType.multiline,
            cursorColor: palette.primary,
            style: TextStyle(fontSize: 15, height: 1.4, color: palette.text),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: palette.disabled,
              ),
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: border(
                hasError ? palette.error : palette.border,
                hasError ? 2 : 1,
              ),
              focusedBorder: border(
                hasError ? palette.error : palette.primary,
                2,
              ),
              border: border(palette.border, 1),
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 6),
          SsV2InlineError(message: errorText!),
        ],
      ],
    );
  }
}

/// AReportSent — the case reference and where the reply goes.
class ReportSentScreen extends StatelessWidget {
  const ReportSentScreen({
    required this.reference,
    required this.email,
    super.key,
  });

  final String reference;
  final String email;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SsV2Page(
      child: SsV2StatusBody(
        glyph: SsV2IconGlyph.check,
        tone: SsV2TileTone.success,
        title: l10n.acReportSentTitle,
        body: l10n.acReportSentBody(email, reference),
        actions: <Widget>[
          SsV2Button(
            key: const ValueKey<String>('report-done'),
            label: l10n.acDone,
            onPressed: () => accountBack(context),
          ),
        ],
      ),
    );
  }
}
