import 'package:flutter/material.dart';

@immutable
class SsSemanticColors extends ThemeExtension<SsSemanticColors> {
  const SsSemanticColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.recording,
    required this.info,
    required this.successSubtle,
    required this.warningSubtle,
    required this.errorSubtle,
    required this.infoSubtle,
  });

  final Color success;
  final Color warning;
  final Color error;
  final Color recording;
  final Color info;

  /// Tinted backgrounds that pair with the matching foreground tone.
  final Color successSubtle;
  final Color warningSubtle;
  final Color errorSubtle;
  final Color infoSubtle;

  @override
  SsSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? recording,
    Color? info,
    Color? successSubtle,
    Color? warningSubtle,
    Color? errorSubtle,
    Color? infoSubtle,
  }) {
    return SsSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      recording: recording ?? this.recording,
      info: info ?? this.info,
      successSubtle: successSubtle ?? this.successSubtle,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      errorSubtle: errorSubtle ?? this.errorSubtle,
      infoSubtle: infoSubtle ?? this.infoSubtle,
    );
  }

  @override
  SsSemanticColors lerp(covariant SsSemanticColors? other, double t) {
    if (other == null) {
      return this;
    }
    return SsSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      recording: Color.lerp(recording, other.recording, t)!,
      info: Color.lerp(info, other.info, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      errorSubtle: Color.lerp(errorSubtle, other.errorSubtle, t)!,
      infoSubtle: Color.lerp(infoSubtle, other.infoSubtle, t)!,
    );
  }
}

extension SsSemanticColorsContext on BuildContext {
  SsSemanticColors get semanticColors =>
      Theme.of(this).extension<SsSemanticColors>()!;
}
