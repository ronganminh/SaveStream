import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';
import '../../../l10n/l10n.dart';
import '../../home/domain/models/home_credits.dart';
import '../../home/presentation/home_screen.dart' show formatRecordingMinutes;

/// Back from a Credits screen; Recording time when it was opened directly.
void creditsBack(BuildContext context, {String fallback = AppRoutes.home}) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

Future<void> openExternalUrl(Uri url) async {
  try {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } on Object {
    // Nothing to open it with; the screen stays as it is.
  }
}

/// "Oct 21" in the app locale.
String creditsShortDate(BuildContext context, DateTime value) =>
    DateFormat.MMMd(
      Localizations.localeOf(context).toString(),
    ).format(value.toLocal());

/// "Oct 15, 2026" in the app locale.
String creditsLongDate(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(value.toLocal());

/// The purple (amber when low, red when out) "Recording time left" card.
class CreditsBalanceCard extends StatelessWidget {
  const CreditsBalanceCard({required this.credits, super.key});

  final HomeCredits credits;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SsV2Palette palette = SsV2Palette.of(context);
    final Color background = switch (credits.tone) {
      HomeCreditsTone.normal => palette.primary,
      HomeCreditsTone.low => palette.warningCard,
      HomeCreditsTone.out => palette.error,
    };
    const Color white = Colors.white;
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(22),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: ssV2Gap(<Widget>[
              Text(
                l10n.crBalanceLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: white.withValues(alpha: 0.9),
                ),
              ),
              Text(
                formatRecordingMinutes(l10n, credits.minutes),
                key: const ValueKey<String>('credits-balance'),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.68,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              if (credits.progress != null)
                SsV2ProgressBar(
                  value: credits.progress!,
                  track: white.withValues(alpha: 0.28),
                  fill: white,
                ),
              Text(
                l10n.crBalanceCaption,
                style: TextStyle(
                  fontSize: 13,
                  color: white.withValues(alpha: 0.92),
                ),
              ),
            ], 10),
          ),
        ),
      ),
    );
  }
}

/// Rounded square icon tile (40×40, 12px radius).
class CreditsIconTile extends StatelessWidget {
  const CreditsIconTile({
    required this.glyph,
    required this.background,
    required this.foreground,
    super.key,
  });

  final SsV2IconGlyph glyph;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SsV2Icon(glyph, size: 20, color: foreground),
    );
  }
}

/// Full-width 52px button on the tint background ("Watch ad · +5 min"),
/// grey when disabled.
class CreditsTintButton extends StatelessWidget {
  const CreditsTintButton({
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final String label;
  final SsV2IconGlyph glyph;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final bool enabled = onPressed != null && !busy;
    final Color foreground = enabled || busy ? palette.link : palette.disabled;
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: palette.tint,
        foregroundColor: palette.link,
        disabledBackgroundColor: busy ? palette.tint : palette.skeleton,
        disabledForegroundColor: foreground,
        fixedSize: const Size.fromHeight(52),
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: SsTypography.uiFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (busy)
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: foreground,
              ),
            )
          else
            SsV2Icon(glyph, size: 20, color: foreground),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(height: 1.26),
            ),
          ),
        ],
      ),
    );
  }
}

/// Counts down to [until] once a second, as "m:ss".
class CreditsCountdown extends StatefulWidget {
  const CreditsCountdown({
    required this.until,
    required this.now,
    required this.builder,
    required this.onDone,
    super.key,
  });

  final DateTime until;
  final DateTime Function() now;
  final Widget Function(BuildContext context, String remaining) builder;
  final VoidCallback onDone;

  @override
  State<CreditsCountdown> createState() => _CreditsCountdownState();
}

class _CreditsCountdownState extends State<CreditsCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!widget.until.isAfter(widget.now())) {
        _timer?.cancel();
        widget.onDone();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Duration left = widget.until.difference(widget.now());
    final int seconds = left.isNegative ? 0 : left.inSeconds;
    final String text =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return widget.builder(context, text);
  }
}

/// A list row: bold title and muted subtitle, trailing value, divider below.
class CreditsListRow extends StatelessWidget {
  const CreditsListRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.trailingColor,
    super.key,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.divider)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: palette.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: trailingColor ?? palette.text,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Small text link in the artboard style (14/700, 40px tall).
class CreditsTextLink extends StatelessWidget {
  const CreditsTextLink({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: palette.link,
        disabledForegroundColor: palette.disabled,
        fixedSize: const Size.fromHeight(40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: SsTypography.uiFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}

/// Centered dialog in the artboard style: 40px icon tile, 22/800 title,
/// muted body and end-aligned actions.
Future<void> showCreditsDialog({
  required BuildContext context,
  required SsV2IconGlyph glyph,
  required SsV2Tone tone,
  required String title,
  required List<Widget> body,
  required List<CreditsDialogAction> actions,
}) {
  final SsV2Palette palette = SsV2Palette.of(context);
  final (Color tileBg, Color tileFg) = switch (tone) {
    SsV2Tone.error => (palette.errorBackground, palette.errorText),
    SsV2Tone.success => (palette.successBackground, palette.success),
    SsV2Tone.warning => (palette.warningBackground, palette.warning),
    SsV2Tone.info => (palette.infoBackground, palette.info),
    SsV2Tone.brand => (palette.tint, palette.link),
  };
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierColor: palette.scrim,
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: DefaultTextStyle(
          style: ssV2BaseText(palette),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: ssV2Gap(<Widget>[
                Center(
                  child: CreditsIconTile(
                    glyph: glyph,
                    background: tileBg,
                    foreground: tileFg,
                  ),
                ),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                DefaultTextStyle.merge(
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: palette.textMuted,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: ssV2Gap(body, 12),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final CreditsDialogAction action in actions)
                      _DialogButton(
                        action: action,
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          action.onPressed?.call();
                        },
                      ),
                  ],
                ),
              ], 16),
            ),
          ),
        ),
      );
    },
  );
}

class CreditsDialogAction {
  const CreditsDialogAction({
    required this.label,
    this.primary = false,
    this.onPressed,
  });

  final String label;
  final bool primary;
  final VoidCallback? onPressed;
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({required this.action, required this.onPressed});

  final CreditsDialogAction action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final ButtonStyle style = ButtonStyle(
      fixedSize: const WidgetStatePropertyAll<Size>(Size.fromHeight(52)),
      padding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(horizontal: 20),
      ),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      textStyle: const WidgetStatePropertyAll<TextStyle>(
        TextStyle(
          fontFamily: SsTypography.uiFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (action.primary) {
      return FilledButton(
        onPressed: onPressed,
        style: style.copyWith(
          backgroundColor: WidgetStatePropertyAll<Color>(palette.primary),
          foregroundColor: WidgetStatePropertyAll<Color>(palette.onPrimary),
          elevation: const WidgetStatePropertyAll<double>(0),
        ),
        child: Text(action.label),
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: style.copyWith(
        foregroundColor: WidgetStatePropertyAll<Color>(palette.link),
      ),
      child: Text(action.label),
    );
  }
}

/// The dark floating message ("+5 minutes added to your balance").
void showCreditsToast(BuildContext context, String message) {
  final SsV2Palette palette = SsV2Palette.of(context);
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: const Color(0xFF2B2840),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(
          message,
          style: ssV2BaseText(
            palette,
          ).copyWith(fontSize: 14, color: Colors.white),
        ),
      ),
    );
}
