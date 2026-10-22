import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/ss_tokens.dart';
import '../../../app/theme/ss_v2_palette.dart';
import 'ss_v2_icons.dart';

export '../../../app/theme/ss_v2_palette.dart';
export 'ss_v2_icons.dart';

/// Base text style of v2 screens: the bundled font at CSS "normal" line
/// height (no inherited Material line height), matching the artboards.
TextStyle ssV2BaseText(SsV2Palette palette) {
  return TextStyle(
    fontFamily: SsTypography.uiFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: palette.text,
    decoration: TextDecoration.none,
  );
}

/// Page frame for v2 screens: artboard background, base text style, safe area.
class SsV2Page extends StatelessWidget {
  const SsV2Page({
    required this.child,
    this.bottomNavigationBar,
    this.safeBottom = true,
    super.key,
  });

  final Widget child;
  final Widget? bottomNavigationBar;
  final bool safeBottom;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      bottomNavigationBar: bottomNavigationBar,
      body: DefaultTextStyle(
        style: ssV2BaseText(palette),
        child: SafeArea(bottom: safeBottom, child: child),
      ),
    );
  }
}

/// Column that fills the viewport (so a spacer can push actions to the
/// bottom, as drawn) and scrolls when the keyboard or large text needs it.
class SsV2FillScroll extends StatelessWidget {
  const SsV2FillScroll({
    required this.children,
    this.padding = EdgeInsets.zero,
    this.gap = 0,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - padding.vertical),
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _withGaps(children, gap),
              ),
            ),
          ),
        );
      },
    );
  }
}

List<Widget> _withGaps(List<Widget> children, double gap) {
  if (gap <= 0) return children;
  final List<Widget> result = <Widget>[];
  for (int i = 0; i < children.length; i++) {
    if (i > 0 && children[i] is! Spacer && children[i - 1] is! Spacer) {
      result.add(SizedBox(height: gap));
    }
    result.add(children[i]);
  }
  return result;
}

/// Inserts [gap] between children, like CSS `gap` in a flex column.
List<Widget> ssV2Gap(List<Widget> children, double gap) =>
    _withGaps(children, gap);

enum SsV2ButtonVariant { primary, outlined, text, danger }

enum SsV2ButtonSize { regular, small }

class SsV2Button extends StatelessWidget {
  const SsV2Button({
    required this.label,
    required this.onPressed,
    this.variant = SsV2ButtonVariant.primary,
    this.size = SsV2ButtonSize.regular,
    this.leading,
    this.isLoading = false,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final SsV2ButtonVariant variant;
  final SsV2ButtonSize size;
  final Widget? leading;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final bool small = size == SsV2ButtonSize.small;
    final double height = small ? 40 : 52;
    final BorderRadius radius = BorderRadius.circular(small ? 12 : 14);
    final TextStyle textStyle = TextStyle(
      fontFamily: SsTypography.uiFamily,
      fontSize: small ? 14 : 16,
      fontWeight: FontWeight.w700,
    );
    final Color foreground = switch (variant) {
      SsV2ButtonVariant.primary => palette.onPrimary,
      SsV2ButtonVariant.outlined => palette.text,
      SsV2ButtonVariant.text => palette.link,
      SsV2ButtonVariant.danger => Colors.white,
    };
    final Widget content = isLoading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                SizedBox(width: variant == SsV2ButtonVariant.outlined ? 10 : 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.26),
                ),
              ),
            ],
          );
    final VoidCallback? handler = isLoading ? null : onPressed;
    final Size minimum = Size(expand ? double.infinity : 0, height);
    const EdgeInsets padding = EdgeInsets.symmetric(horizontal: 12);
    final bool danger = variant == SsV2ButtonVariant.danger;
    final Color filled = danger ? palette.error : palette.primary;
    final Color onFilled = danger ? Colors.white : palette.onPrimary;
    final Widget button = switch (variant) {
      SsV2ButtonVariant.primary || SsV2ButtonVariant.danger => FilledButton(
        onPressed: handler,
        style: FilledButton.styleFrom(
          backgroundColor: filled,
          foregroundColor: onFilled,
          disabledBackgroundColor: isLoading
              ? filled
              : filled.withValues(alpha: 0.45),
          disabledForegroundColor: onFilled,
          minimumSize: minimum,
          fixedSize: Size.fromHeight(height),
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textStyle,
          elevation: 0,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: content,
      ),
      SsV2ButtonVariant.outlined => OutlinedButton(
        onPressed: handler,
        style: OutlinedButton.styleFrom(
          backgroundColor: palette.surface,
          foregroundColor: palette.text,
          disabledForegroundColor: palette.text.withValues(alpha: 0.5),
          minimumSize: minimum,
          fixedSize: Size.fromHeight(height),
          padding: padding,
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: content,
      ),
      SsV2ButtonVariant.text => TextButton(
        onPressed: handler,
        style: TextButton.styleFrom(
          foregroundColor: palette.link,
          minimumSize: minimum,
          fixedSize: Size.fromHeight(height),
          padding: padding,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: textStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: content,
      ),
    };
    return button;
  }
}

/// Inline bold link (e.g. "Forgot password?", "Sign in").
class SsV2Link extends StatelessWidget {
  const SsV2Link({
    required this.label,
    required this.onPressed,
    this.fontSize = 14,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Semantics(
      button: true,
      link: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: palette.link,
          ),
        ),
      ),
    );
  }
}

/// 64px top bar with a 48px back button, an optional title and trailing
/// actions (e.g. a text button).
class SsV2Header extends StatelessWidget {
  const SsV2Header({
    this.onBack,
    this.title,
    this.backLabel,
    this.actions = const <Widget>[],
    super.key,
  });

  final VoidCallback? onBack;
  final String? title;
  final String? backLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return SizedBox(
      height: 64,
      child: Padding(
        padding: EdgeInsets.fromLTRB(onBack == null ? 20 : 4, 0, 8, 0),
        child: Row(
          children: <Widget>[
            if (onBack != null) ...<Widget>[
              SizedBox.square(
                dimension: 48,
                child: IconButton(
                  tooltip:
                      backLabel ??
                      MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                  icon: SsV2Icon(SsV2IconGlyph.back, color: palette.text),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Semantics(
                header: title != null,
                child: Text(
                  title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.22,
                  ),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Page title block: 28/800 heading with an optional muted subtitle.
class SsV2TitleBlock extends StatelessWidget {
  const SsV2TitleBlock({required this.title, this.subtitle, super.key});

  final String title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: palette.textMuted,
            ),
            child: subtitle!,
          ),
        ],
      ],
    );
  }
}

/// Outlined text field with the label resting on the border (artboard style).
class SsV2TextField extends StatelessWidget {
  const SsV2TextField({
    required this.label,
    required this.controller,
    this.errorText,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.fieldKey,
    this.hintText,
    this.autocorrect,
    this.readOnly = false,
    this.maxLength,
    this.minLines,
    this.maxLines = 1,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  /// Shown as drawn but not editable (e.g. an email the server can't
  /// change).
  final bool readOnly;
  final int? maxLength;
  final int? minLines;
  final int? maxLines;
  final String? errorText;
  final String? helperText;
  final String? hintText;
  final bool? autocorrect;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final bool hasError = errorText != null;
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
      gapPadding: 4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextFormField(
          key: fieldKey,
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: obscureText ? 1 : maxLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          obscureText: obscureText,
          autocorrect: autocorrect ?? !obscureText,
          enableSuggestions: autocorrect ?? !obscureText,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          cursorColor: palette.primary,
          style: TextStyle(
            fontFamily: SsTypography.uiFamily,
            fontSize: 16,
            height: 1.26,
            color: palette.text,
          ),
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            hintStyle: TextStyle(
              fontFamily: SsTypography.uiFamily,
              fontSize: 16,
              height: 1.26,
              color: palette.disabled,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            floatingLabelStyle: TextStyle(
              fontFamily: SsTypography.uiFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: hasError ? palette.errorText : palette.textMuted,
            ),
            labelStyle: TextStyle(
              fontFamily: SsTypography.uiFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: hasError ? palette.errorText : palette.textMuted,
            ),
            filled: false,
            isDense: false,
            counterText: '',
            contentPadding: EdgeInsets.fromLTRB(
              13,
              18,
              suffix == null ? 16 : 4,
              18,
            ),
            suffixIcon: suffix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: suffix,
                  ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 52,
              minHeight: 48,
            ),
            border: border(palette.border, 1),
            enabledBorder: border(
              hasError ? palette.error : palette.border,
              hasError ? 2 : 1,
            ),
            focusedBorder: border(
              hasError ? palette.error : palette.primary,
              2,
            ),
            disabledBorder: border(palette.divider, 1),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 6),
          SsV2InlineError(message: errorText!),
        ] else if (helperText != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: TextStyle(fontSize: 13, color: palette.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Password variant of [SsV2TextField] with the eye toggle.
class SsV2PasswordField extends StatefulWidget {
  const SsV2PasswordField({
    required this.label,
    required this.controller,
    this.errorText,
    this.helperText,
    this.textInputAction,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.showLabel = 'Show password',
    this.hideLabel = 'Hide password',
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final String? helperText;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String showLabel;
  final String hideLabel;

  @override
  State<SsV2PasswordField> createState() => _SsV2PasswordFieldState();
}

class _SsV2PasswordFieldState extends State<SsV2PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return SsV2TextField(
      label: widget.label,
      controller: widget.controller,
      errorText: widget.errorText,
      helperText: widget.helperText,
      obscureText: !_visible,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffix: SizedBox.square(
        dimension: 48,
        child: IconButton(
          tooltip: _visible ? widget.hideLabel : widget.showLabel,
          onPressed: () => setState(() => _visible = !_visible),
          icon: SsV2Icon(
            _visible ? SsV2IconGlyph.eyeOff : SsV2IconGlyph.eye,
            size: 22,
            color: palette.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Red icon + message shown under an invalid field.
class SsV2InlineError extends StatelessWidget {
  const SsV2InlineError({
    required this.message,
    this.fontSize = 13,
    this.center = false,
    super.key,
  });

  final String message;
  final double fontSize;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: center
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: (fontSize * 1.26 - 16) / 2),
            child: SsV2Icon(
              SsV2IconGlyph.alert,
              size: 16,
              color: palette.errorText,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(fontSize: fontSize, color: palette.errorText),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Continue with Google" outlined button.
class SsV2GoogleButton extends StatelessWidget {
  const SsV2GoogleButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SsV2Button(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      variant: SsV2ButtonVariant.outlined,
      leading: const SsV2GoogleMark(),
    );
  }
}

/// Divider with a centered "or".
class SsV2OrDivider extends StatelessWidget {
  const SsV2OrDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final Widget line = Expanded(
      child: Container(height: 1, color: palette.divider),
    );
    return Row(
      children: <Widget>[
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: palette.textMuted),
          ),
        ),
        line,
      ],
    );
  }
}

enum SsV2Tone { error, warning, info, success, brand }

/// Rounded status box with icon (error/warning banners): optional bold
/// title, body and actions stacked 10px apart.
class SsV2Banner extends StatelessWidget {
  const SsV2Banner({
    required this.tone,
    required this.child,
    this.title,
    this.actions = const <Widget>[],
    this.glyph,
    super.key,
  });

  final SsV2Tone tone;
  final String? title;
  final Widget child;
  final List<Widget> actions;

  /// Overrides the tone's default icon.
  final SsV2IconGlyph? glyph;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final (
      Color background,
      Color iconColor,
      SsV2IconGlyph defaultGlyph,
    ) = switch (tone) {
      SsV2Tone.error => (
        palette.errorBackground,
        palette.errorText,
        SsV2IconGlyph.alert,
      ),
      SsV2Tone.warning => (
        palette.warningBackground,
        palette.warning,
        SsV2IconGlyph.clock,
      ),
      SsV2Tone.info => (
        palette.infoBackground,
        palette.info,
        SsV2IconGlyph.alert,
      ),
      SsV2Tone.success => (
        palette.successBackground,
        palette.success,
        SsV2IconGlyph.check,
      ),
      SsV2Tone.brand => (palette.tint, palette.link, SsV2IconGlyph.alert),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: SsV2Icon(
                glyph ?? defaultGlyph,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: palette.text,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (title != null) ...<Widget>[
                      Text(
                        title!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                    ],
                    child,
                    if (actions.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: actions),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SsV2ChipTone {
  waiting,
  recording,
  liveNotRecording,
  paused,
  brand,
  alert,
  success,
  neutral,
}

class SsV2StatusChip extends StatelessWidget {
  const SsV2StatusChip({
    required this.label,
    required this.tone,
    this.fontSize = 12,
    this.dot = false,
    super.key,
  });

  final String label;
  final SsV2ChipTone tone;
  final double fontSize;

  /// Leading 7px dot in the text color.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final (Color bg, Color fg, Color? border) = switch (tone) {
      SsV2ChipTone.waiting => (palette.infoBackground, palette.info, null),
      SsV2ChipTone.recording => (palette.error, Colors.white, null),
      SsV2ChipTone.liveNotRecording => (
        palette.surface,
        palette.errorText,
        palette.error,
      ),
      SsV2ChipTone.paused => (palette.warningBackground, palette.warning, null),
      SsV2ChipTone.brand => (palette.tint, palette.link, null),
      SsV2ChipTone.alert => (palette.errorBackground, palette.errorText, null),
      SsV2ChipTone.success => (
        palette.successBackground,
        palette.success,
        null,
      ),
      SsV2ChipTone.neutral => (
        palette.neutralBackground,
        palette.neutralText,
        null,
      ),
    };
    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: border == null ? 10 : 8.5,
        vertical: border == null ? 4 : 2.5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
      child: dot
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(child: text),
              ],
            )
          : text,
    );
  }
}

/// Initials avatar with the artboard color pairs and optional LIVE ring.
class SsV2Avatar extends StatelessWidget {
  const SsV2Avatar({
    required this.name,
    this.size = 44,
    this.liveRing = false,
    this.fontSize,
    this.brand = false,
    super.key,
  });

  final String name;
  final double size;
  final bool liveRing;

  /// The brand (purple) pair instead of one picked from [name] (the
  /// signed-in user's own avatar).
  final bool brand;

  /// Initials size; defaults to 17 from 48px and 15 below.
  final double? fontSize;

  static const List<(Color, Color)> _pairs = <(Color, Color)>[
    (Color(0xFFCFC4FF), Color(0xFF3D1FD0)),
    (Color(0xFFBFE3D5), Color(0xFF0B5E41)),
    (Color(0xFFFFE1B8), Color(0xFF8A4F00)),
    (Color(0xFFCDE0FB), Color(0xFF1D5FC4)),
    (Color(0xFFF9CFD8), Color(0xFFB0102E)),
  ];

  static String initialsFor(String raw) {
    final String cleaned = raw.replaceAll('@', '').trim();
    final List<String> parts = cleaned
        .split(RegExp(r'[\s_.\-]+'))
        .where((String part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, math.min(2, parts.first.length))
          .toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  static (Color, Color) colorsFor(String raw) {
    int hash = 0;
    for (final int unit in raw.toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _pairs[hash % _pairs.length];
  }

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final (Color bg, Color fg) = brand ? _pairs.first : colorsFor(name);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: liveRing
              ? <BoxShadow>[
                  BoxShadow(color: palette.error, spreadRadius: 5),
                  BoxShadow(color: palette.surface, spreadRadius: 3),
                ]
              : null,
        ),
        child: Text(
          initialsFor(name),
          style: TextStyle(
            fontSize: fontSize ?? (size >= 48 ? 17 : 15),
            fontWeight: FontWeight.w800,
            color: fg,
          ),
        ),
      ),
    );
  }
}

/// White card with the artboard border and 20px radius.
class SsV2Card extends StatelessWidget {
  const SsV2Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: child,
    );
  }
}

class SsV2SectionHeader extends StatelessWidget {
  const SsV2SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (actionLabel != null)
          SsV2Link(label: actionLabel!, onPressed: onAction),
      ],
    );
  }
}

/// Pill progress bar (8px).
class SsV2ProgressBar extends StatelessWidget {
  const SsV2ProgressBar({
    required this.value,
    required this.track,
    required this.fill,
    super.key,
  });

  final double value;
  final Color track;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: track),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1).toDouble(),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing placeholder block for loading skeletons.
class SsV2Skeleton extends StatefulWidget {
  const SsV2Skeleton({
    this.width,
    this.height = 14,
    this.radius = 8,
    this.widthFactor,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;
  final double? widthFactor;

  @override
  State<SsV2Skeleton> createState() => _SsV2SkeletonState();
}

class _SsV2SkeletonState extends State<SsV2Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final Widget block = AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // CSS `pulse`: opacity 1 → .45 at 50% → 1, ease.
        final double t = Curves.ease.transform(
          1 - (2 * _controller.value - 1).abs(),
        );
        return Opacity(opacity: 1 - 0.55 * t, child: child);
      },
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: palette.skeleton,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
    if (widget.widthFactor != null) {
      return FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widget.widthFactor,
        child: block,
      );
    }
    return block;
  }
}

/// Ring spinner: tinted track with a primary top quarter, rotating.
class SsV2Spinner extends StatefulWidget {
  const SsV2Spinner({this.size = 28, this.stroke = 3, super.key});

  final double size;
  final double stroke;

  @override
  State<SsV2Spinner> createState() => _SsV2SpinnerState();
}

class _SsV2SpinnerState extends State<SsV2Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return ExcludeSemantics(
      child: RotationTransition(
        turns: _controller,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _RingPainter(
            track: palette.tint,
            arc: palette.primary,
            stroke: widget.stroke,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.track,
    required this.arc,
    required this.stroke,
  });

  final Color track;
  final Color arc;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(stroke / 2);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    canvas.drawArc(
      rect,
      -math.pi * 3 / 4,
      math.pi / 2,
      false,
      paint..color = arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.track != track || oldDelegate.arc != arc;
}

/// Page dots for onboarding (active dot is a 24px pill).
class SsV2PageDots extends StatelessWidget {
  const SsV2PageDots({
    required this.count,
    required this.index,
    required this.semanticLabel,
    super.key,
  });

  final int count;
  final int index;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (int i = 0; i < count; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == index ? palette.primary : palette.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum SsV2TileTone { brand, success, error, warning, neutral }

/// Centered status screen body: 96px icon tile, title, body and actions.
class SsV2StatusBody extends StatelessWidget {
  const SsV2StatusBody({
    required this.glyph,
    required this.tone,
    required this.title,
    required this.body,
    required this.actions,
    this.extra,
    this.bodySpan,
    super.key,
  });

  final SsV2IconGlyph glyph;
  final SsV2TileTone tone;
  final String title;
  final String body;

  /// Rich body (e.g. a bold time) shown instead of [body], which stays the
  /// plain-text label.
  final InlineSpan? bodySpan;
  final Widget? extra;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final (Color bg, Color fg) = switch (tone) {
      SsV2TileTone.brand => (palette.tint, palette.link),
      SsV2TileTone.success => (palette.successBackground, palette.success),
      SsV2TileTone.error => (palette.errorBackground, palette.errorText),
      SsV2TileTone.warning => (palette.warningBackground, palette.warning),
      SsV2TileTone.neutral => (palette.neutralBackground, palette.neutralText),
    };
    // The body is at most 310 wide. A ConstrainedBox would report its
    // intrinsic height at the full width (fewer lines), and the
    // IntrinsicHeight in SsV2FillScroll would then clip it on short
    // screens, so the inset is computed as padding instead.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          _build(context, palette, bg, fg, constraints.maxWidth),
    );
  }

  Widget _build(
    BuildContext context,
    SsV2Palette palette,
    Color bg,
    Color fg,
    double maxWidth,
  ) {
    final double bodyInset = math.max(0, (maxWidth - 48 - 310) / 2);
    return SsV2FillScroll(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
      children: <Widget>[
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  alignment: Alignment.center,
                  child: SsV2Icon(glyph, size: 44, color: fg),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.26,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: bodyInset),
                  child: Text.rich(
                    bodySpan ?? TextSpan(text: body),
                    semanticsLabel: body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: palette.textMuted,
                    ),
                  ),
                ),
                if (extra != null) ...<Widget>[
                  const SizedBox(height: 16),
                  extra!,
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...ssV2Gap(actions, 10),
      ],
    );
  }
}

/// "Not affiliated with TikTok or ByteDance" footnote.
class SsV2Disclaimer extends StatelessWidget {
  const SsV2Disclaimer({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, height: 1.5, color: palette.textMuted),
    );
  }
}

class SsV2NavItem {
  const SsV2NavItem({
    required this.id,
    required this.label,
    required this.glyph,
  });

  /// Stable id; the destination is keyed `nav-<id>`.
  final String id;
  final String label;
  final SsV2IconGlyph glyph;
}

/// 80px bottom navigation with the 64×32 pill indicator.
class SsV2BottomNav extends StatelessWidget {
  const SsV2BottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<SsV2NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.divider)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 79,
          backgroundColor: palette.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          indicatorColor: palette.tint,
          indicatorShape: const StadiumBorder(),
          labelPadding: const EdgeInsets.only(top: 4),
          labelTextStyle: WidgetStateProperty.resolveWith((
            Set<WidgetState> states,
          ) {
            final bool selected = states.contains(WidgetState.selected);
            return TextStyle(
              fontFamily: SsTypography.uiFamily,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? palette.text : palette.textMuted,
            );
          }),
        ),
        child: NavigationBar(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          destinations: <NavigationDestination>[
            for (final SsV2NavItem item in items)
              NavigationDestination(
                key: ValueKey<String>('nav-${item.id}'),
                icon: SsV2Icon(item.glyph, size: 22, color: palette.textMuted),
                selectedIcon: SsV2Icon(
                  item.glyph,
                  size: 22,
                  color: palette.link,
                ),
                label: item.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// 20px checkbox in the brand color, with an error outline.
class SsV2Checkbox extends StatelessWidget {
  const SsV2Checkbox({
    required this.value,
    required this.onChanged,
    this.hasError = false,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: hasError
          ? BoxDecoration(
              border: Border.all(color: palette.error, width: 2),
              borderRadius: BorderRadius.circular(5),
            )
          : null,
      child: SizedBox.square(
        dimension: 20,
        child: Checkbox(
          value: value,
          onChanged: (bool? next) => onChanged(next ?? false),
          activeColor: palette.primary,
          checkColor: Colors.white,
          side: BorderSide(color: palette.textMuted, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

/// 52×32 artboard switch: brand track with a 24px white thumb when on, grey
/// outlined track with a 16px thumb when off. [onChanged] null disables it.
class SsV2Switch extends StatelessWidget {
  const SsV2Switch({
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    final bool enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: SizedBox(
            width: 52,
            height: 48,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 52,
                height: 32,
                decoration: BoxDecoration(
                  color: value
                      ? palette.primary.withValues(alpha: enabled ? 1 : 0.45)
                      : palette.skeleton,
                  borderRadius: BorderRadius.circular(99),
                  border: value
                      ? null
                      : Border.all(color: palette.disabled, width: 2),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 150),
                  alignment: value
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      width: value ? 24 : 16,
                      height: value ? 24 : 16,
                      decoration: BoxDecoration(
                        color: value ? Colors.white : palette.disabled,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings row: bold 15px title, optional muted subtitle, trailing switch.
class SsV2SwitchRow extends StatelessWidget {
  const SsV2SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final SsV2Palette palette = SsV2Palette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 13, color: palette.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SsV2Switch(value: value, onChanged: onChanged, semanticLabel: title),
        ],
      ),
    );
  }
}

/// Bottom sheet in the artboard style: page background, 28px top corners,
/// 36×4 handle, 12/20/28 padding, over the whole screen (bottom bar too).
Future<T?> showSsV2Sheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final SsV2Palette palette = SsV2Palette.of(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: palette.background,
    barrierColor: palette.scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) {
      final MediaQueryData media = MediaQuery.of(sheetContext);
      return DefaultTextStyle(
        style: ssV2BaseText(palette),
        child: Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              28 + media.viewPadding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                builder(sheetContext),
              ],
            ),
          ),
        ),
      );
    },
  );
}
