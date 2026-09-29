import 'package:flutter/material.dart';

@immutable
class SsSemanticColors extends ThemeExtension<SsSemanticColors> {
  const SsSemanticColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.recording,
  });

  final Color success;
  final Color warning;
  final Color error;
  final Color recording;

  @override
  SsSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? recording,
  }) {
    return SsSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      recording: recording ?? this.recording,
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
    );
  }
}

extension SsSemanticColorsContext on BuildContext {
  SsSemanticColors get semanticColors =>
      Theme.of(this).extension<SsSemanticColors>()!;
}
