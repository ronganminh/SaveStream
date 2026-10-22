import 'package:flutter/material.dart';

/// Colors of the Android v2 artboards (Auth + Home), exposed as a theme
/// extension so v2 widgets read one place. Light values are taken verbatim
/// from the artboards; dark values keep the same roles on a dark surface.
@immutable
class SsV2Palette extends ThemeExtension<SsV2Palette> {
  const SsV2Palette({
    required this.background,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.textConsent,
    required this.primary,
    required this.onPrimary,
    required this.link,
    required this.linkPressed,
    required this.border,
    required this.divider,
    required this.tint,
    required this.tintSoft,
    required this.skeleton,
    required this.error,
    required this.errorText,
    required this.errorBackground,
    required this.success,
    required this.successBackground,
    required this.info,
    required this.infoBackground,
    required this.warning,
    required this.warningBackground,
    required this.warningCard,
    required this.liveText,
    required this.thumbOverlay,
  });

  final Color background;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color textConsent;
  final Color primary;
  final Color onPrimary;

  /// Link and text-button color (#5330F0 in the artboards).
  final Color link;
  final Color linkPressed;
  final Color border;
  final Color divider;
  final Color tint;
  final Color tintSoft;
  final Color skeleton;
  final Color error;
  final Color errorText;
  final Color errorBackground;
  final Color success;
  final Color successBackground;
  final Color info;
  final Color infoBackground;
  final Color warning;
  final Color warningBackground;

  /// Credits card fill when minutes are low.
  final Color warningCard;

  /// Secondary text on the pink "Live now" card.
  final Color liveText;
  final Color thumbOverlay;

  static const SsV2Palette light = SsV2Palette(
    background: Color(0xFFFBFAFE),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF15122B),
    textMuted: Color(0xFF56526F),
    textConsent: Color(0xFF3A3655),
    primary: Color(0xFF6D4AFF),
    onPrimary: Color(0xFFFFFFFF),
    link: Color(0xFF5330F0),
    linkPressed: Color(0xFF3D1FD0),
    border: Color(0xFFD3CDE6),
    divider: Color(0xFFE6E1F4),
    tint: Color(0xFFEEE9FF),
    tintSoft: Color(0xFFF4F1FF),
    skeleton: Color(0xFFECE9F3),
    error: Color(0xFFD7193A),
    errorText: Color(0xFFB0102E),
    errorBackground: Color(0xFFFDE7EB),
    success: Color(0xFF0B7F57),
    successBackground: Color(0xFFE3F5EE),
    info: Color(0xFF1D5FC4),
    infoBackground: Color(0xFFE5EFFD),
    warning: Color(0xFF8A4F00),
    warningBackground: Color(0xFFFFF1D9),
    warningCard: Color(0xFF9A5800),
    liveText: Color(0xFF6B2A37),
    thumbOverlay: Color(0xB315122B),
  );

  static const SsV2Palette dark = SsV2Palette(
    background: Color(0xFF110F1E),
    surface: Color(0xFF1B1830),
    text: Color(0xFFF1EFFA),
    textMuted: Color(0xFFADA8C6),
    textConsent: Color(0xFFCFCBE3),
    primary: Color(0xFF7C5CFF),
    onPrimary: Color(0xFFFFFFFF),
    link: Color(0xFFB4A3FF),
    linkPressed: Color(0xFFD2C8FF),
    border: Color(0xFF3A3556),
    divider: Color(0xFF2C2844),
    tint: Color(0xFF2A2350),
    tintSoft: Color(0xFF221D40),
    skeleton: Color(0xFF2A2640),
    error: Color(0xFFFF5470),
    errorText: Color(0xFFFF8FA2),
    errorBackground: Color(0xFF3A1520),
    success: Color(0xFF3FD19A),
    successBackground: Color(0xFF0F2E24),
    info: Color(0xFF7EAEFF),
    infoBackground: Color(0xFF16264A),
    warning: Color(0xFFF2B866),
    warningBackground: Color(0xFF33240E),
    warningCard: Color(0xFF9A5800),
    liveText: Color(0xFFFFB8C4),
    thumbOverlay: Color(0xB3000000),
  );

  static SsV2Palette of(BuildContext context) {
    return Theme.of(context).extension<SsV2Palette>() ?? light;
  }

  @override
  SsV2Palette copyWith() => this;

  @override
  SsV2Palette lerp(ThemeExtension<SsV2Palette>? other, double t) {
    if (other is! SsV2Palette) return this;
    return t < 0.5 ? this : other;
  }
}
