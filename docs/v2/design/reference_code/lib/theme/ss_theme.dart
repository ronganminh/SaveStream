// lib/theme/ss_theme.dart — SaveStream Mobile V2 · final tokens (Phase 7/8)
// Nguồn: design/SaveStream V2 Flutter Handoff.dc.html. Không hardcode màu trong widget.
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

const ssLightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF6D49F4),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFF0F0FF),
  onPrimaryContainer: Color(0xFF3A1FB0),
  secondary: Color(0xFF626671),
  onSecondary: Color(0xFFFFFFFF),
  error: Color(0xFFE31029),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF0E111A),
  surfaceContainerLowest: Color(0xFFF9FAFC), // scaffold
  surfaceContainerHighest: Color(0xFFF2F3F7), // surfaceSubtle
  onSurfaceVariant: Color(0xFF626671),
  outline: Color(0xFFDBDEE4),
  outlineVariant: Color(0xFFEEF0F4),
  scrim: Color(0x80090B10),
);

const ssDarkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF968CFF),
  onPrimary: Color(0xFF120E2E),
  primaryContainer: Color(0xFF1F1B40),
  onPrimaryContainer: Color(0xFFD9D5FF),
  secondary: Color(0xFF9BA1AC),
  onSecondary: Color(0xFF090B10),
  error: Color(0xFFFF5468),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFF11141A),
  onSurface: Color(0xFFECEEF2),
  surfaceContainerLowest: Color(0xFF090B10),
  surfaceContainerHighest: Color(0xFF181C24),
  onSurfaceVariant: Color(0xFF9BA1AC),
  outline: Color(0xFF262B35),
  outlineVariant: Color(0xFF1C2028),
  scrim: Color(0xA6000000),
);

@immutable
class SsColors extends ThemeExtension<SsColors> {
  const SsColors({
    required this.recording,
    required this.disabled,
    required this.primaryPressed,
    required this.recordingSubtle,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.onWarningSubtle,
    required this.warningSubtle,
    required this.info,
    required this.infoSubtle,
    required this.local,
    required this.localSubtle,
    required this.cloud,
    required this.cloudSubtle,
    required this.player,
    required this.onPlayer,
    required this.onPlayerMuted,
    required this.scrim,
  });

  final Color recording, disabled, primaryPressed, recordingSubtle, success, successSubtle,
      warning, onWarningSubtle, warningSubtle, info, infoSubtle, local, localSubtle, cloud,
      cloudSubtle, player, onPlayer, onPlayerMuted, scrim;

  static const light = SsColors(
    recording: Color(0xFFE31029),
    disabled: Color(0xFFA6AAB4),
    primaryPressed: Color(0xFF5A36E0),
    recordingSubtle: Color(0xFFFDECEE),
    success: Color(0xFF007742),
    successSubtle: Color(0xFFE6F4EC),
    warning: Color(0xFFD38F00),
    onWarningSubtle: Color(0xFF8A5D00),
    warningSubtle: Color(0xFFFDF4E1),
    info: Color(0xFF0074C8),
    infoSubtle: Color(0xFFE6F1FA),
    local: Color(0xFF0B7A75),
    localSubtle: Color(0xFFE3F3F2),
    cloud: Color(0xFF2F6FE4),
    cloudSubtle: Color(0xFFEAF0FD),
    player: Color(0xFF12141B),
    onPlayer: Color(0xFFF7F8FA),
    onPlayerMuted: Color(0xFFA3A8B3),
    scrim: Color(0x80090B10),
  );

  static const dark = SsColors(
    recording: Color(0xFFFF5468),
    disabled: Color(0xFF5A606B),
    primaryPressed: Color(0xFF8278F5),
    recordingSubtle: Color(0xFF2B1117),
    success: Color(0xFF3FD18A),
    successSubtle: Color(0xFF0D2419),
    warning: Color(0xFFF0B43C),
    onWarningSubtle: Color(0xFFF0B43C),
    warningSubtle: Color(0xFF2A2111),
    info: Color(0xFF5BB0FF),
    infoSubtle: Color(0xFF0E2033),
    local: Color(0xFF4CCFC5),
    localSubtle: Color(0xFF0E2827),
    cloud: Color(0xFF7EA8FF),
    cloudSubtle: Color(0xFF141F3A),
    player: Color(0xFF04060A),
    onPlayer: Color(0xFFF7F8FA),
    onPlayerMuted: Color(0xFF8F95A1),
    scrim: Color(0xA6000000),
  );

  @override
  SsColors copyWith() => this;

  @override
  SsColors lerp(ThemeExtension<SsColors>? other, double t) {
    if (other is! SsColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return SsColors(
      recording: l(recording, other.recording),
      disabled: l(disabled, other.disabled),
      primaryPressed: l(primaryPressed, other.primaryPressed),
      recordingSubtle: l(recordingSubtle, other.recordingSubtle),
      success: l(success, other.success),
      successSubtle: l(successSubtle, other.successSubtle),
      warning: l(warning, other.warning),
      onWarningSubtle: l(onWarningSubtle, other.onWarningSubtle),
      warningSubtle: l(warningSubtle, other.warningSubtle),
      info: l(info, other.info),
      infoSubtle: l(infoSubtle, other.infoSubtle),
      local: l(local, other.local),
      localSubtle: l(localSubtle, other.localSubtle),
      cloud: l(cloud, other.cloud),
      cloudSubtle: l(cloudSubtle, other.cloudSubtle),
      player: l(player, other.player),
      onPlayer: l(onPlayer, other.onPlayer),
      onPlayerMuted: l(onPlayerMuted, other.onPlayerMuted),
      scrim: l(scrim, other.scrim),
    );
  }
}

const _f = 'Geist';
TextStyle _t(double s, double h, FontWeight w) =>
    TextStyle(fontFamily: _f, fontSize: s, height: h / s, fontWeight: w);

final ssTextTheme = TextTheme(
  displaySmall: _t(32, 40, FontWeight.w700),
  headlineMedium: _t(28, 36, FontWeight.w700),
  headlineSmall: _t(24, 30, FontWeight.w700),
  titleLarge: _t(22, 28, FontWeight.w600),
  titleMedium: _t(18, 24, FontWeight.w600),
  titleSmall: _t(16, 24, FontWeight.w600),
  bodyLarge: _t(16, 24, FontWeight.w400),
  bodyMedium: _t(14, 20, FontWeight.w400),
  bodySmall: _t(13, 18, FontWeight.w400),
  labelLarge: _t(16, 20, FontWeight.w600),
  labelMedium: _t(14, 20, FontWeight.w600),
  labelSmall: _t(12, 16, FontWeight.w500),
);

@immutable
class SsType extends ThemeExtension<SsType> {
  const SsType({required this.timer, required this.mono});
  final TextStyle timer, mono;

  static const base = SsType(
    timer: TextStyle(
        fontFamily: 'Geist Mono',
        fontSize: 40,
        height: 48 / 40,
        fontWeight: FontWeight.w600,
        fontFeatures: [FontFeature.tabularFigures()]),
    mono: TextStyle(
        fontFamily: 'Geist Mono',
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        fontFeatures: [FontFeature.tabularFigures()]),
  );

  @override
  SsType copyWith({TextStyle? timer, TextStyle? mono}) =>
      SsType(timer: timer ?? this.timer, mono: mono ?? this.mono);

  @override
  SsType lerp(ThemeExtension<SsType>? other, double t) => this;
}

abstract final class SsSpace {
  static const xxs = 2.0, xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0;
  static const screenH = 16.0; // paywall/sheet: 24 (>= 390), 20 (< 390)
  static const minTap = 44.0, rowHeight = 52.0, ctaHeight = 52.0;
  static double sheetH(BuildContext c) => MediaQuery.sizeOf(c).width >= 390 ? 24 : 20;
}

abstract final class SsRadius {
  static const sm = 8.0, md = 12.0, card = 16.0, cta = 14.0, dialog = 24.0, sheet = 24.0, pill = 999.0;
}

abstract final class SsMotion {
  static const fast = Duration(milliseconds: 150),
      base = Duration(milliseconds: 200),
      slow = Duration(milliseconds: 250);
  static Duration of(BuildContext c, Duration d) =>
      MediaQuery.of(c).disableAnimations ? Duration.zero : d;
}

ThemeData ssTheme(Brightness b) {
  final light = b == Brightness.light;
  final scheme = light ? ssLightScheme : ssDarkScheme;
  final ss = light ? SsColors.light : SsColors.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: _f,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    textTheme: ssTextTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
    extensions: [ss, SsType.base],
    dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1, space: 1),
    splashFactory: InkSparkle.splashFactory,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsRadius.md), borderSide: BorderSide(color: scheme.outline)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsRadius.md), borderSide: BorderSide(color: scheme.outline)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsRadius.md), borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SsRadius.md), borderSide: BorderSide(color: ss.recording)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => ssTextTheme.labelSmall!.copyWith(
            color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          )),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.onPrimary : scheme.outline),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : scheme.surfaceContainerHighest),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: ss.scrim,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(SsRadius.sheet))),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ss.player,
      contentTextStyle: ssTextTheme.bodyMedium!.copyWith(color: ss.onPlayer),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SsRadius.md)),
    ),
  );
}

extension SsThemeX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  SsColors get ss => Theme.of(this).extension<SsColors>()!;
  SsType get ssType => Theme.of(this).extension<SsType>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}
