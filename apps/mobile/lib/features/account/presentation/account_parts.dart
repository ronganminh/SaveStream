import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/ss_tokens.dart';
import '../../../core/widgets/v2/ss_v2_widgets.dart';

/// Back from an Account screen; the Account tab when opened directly.
void accountBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.settings);
  }
}

enum AccountRowTone { brand, neutral, danger }

/// A titled group of rows ("Recording", "Help & legal"): 13/700 muted label
/// over a white card with 1px dividers between the rows.
class AccountSection extends StatelessWidget {
  const AccountSection({required this.children, this.label, super.key});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Container(height: 1, color: palette.divider));
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Semantics(
              header: true,
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: palette.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows,
          ),
        ),
      ],
    );
  }
}

/// A row in an [AccountSection]: 40px icon tile, 16/600 title, optional
/// 13px muted subtitle and a trailing chevron (or [trailing]).
class AccountRow extends StatelessWidget {
  const AccountRow({
    required this.glyph,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.tone = AccountRowTone.brand,
    this.chevron = true,
    this.trailing,
    super.key,
  });

  final SsV2IconGlyph glyph;
  final String title;
  final String? subtitle;
  final AccountRowTone tone;
  final bool chevron;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final (Color tileBg, Color tileFg) = switch (tone) {
      AccountRowTone.brand => (palette.tint, palette.link),
      AccountRowTone.neutral => (
        palette.neutralBackground,
        palette.neutralText,
      ),
      AccountRowTone.danger => (palette.errorBackground, palette.errorText),
    };
    final Widget? end =
        trailing ??
        (chevron
            ? SsV2Icon(
                SsV2IconGlyph.chevronRight,
                size: 20,
                color: palette.textMuted,
              )
            : null);
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        // min-height 56 inside 8px padding, as drawn (72px rows).
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SsV2Icon(glyph, size: 20, color: tileFg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tone == AccountRowTone.danger
                              ? palette.errorText
                              : palette.text,
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (end != null) ...<Widget>[const SizedBox(width: 14), end],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small muted line under a status body ("Error ID: …", "Appeals: …").
class AccountFootnote extends StatelessWidget {
  const AccountFootnote({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: palette.textMuted),
    );
  }
}

/// The artboard dialog without an icon: 22/800 title, muted body and
/// end-aligned Cancel / primary action. Completes with true on confirm.
Future<bool?> showAccountConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String cancelLabel,
  required String confirmLabel,
  Key? confirmKey,
}) {
  final SsV2Palette palette = SsV2Palette.of(context);
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierColor: palette.scrim,
    builder: (BuildContext dialogContext) {
      ButtonStyle style(Color background, Color foreground) =>
          TextButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            fixedSize: const Size.fromHeight(52),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontFamily: SsTypography.uiFamily,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          );
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
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: palette.textMuted,
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: style(Colors.transparent, palette.link),
                      child: Text(cancelLabel),
                    ),
                    TextButton(
                      key: confirmKey,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: style(palette.primary, palette.onPrimary),
                      child: Text(confirmLabel),
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
