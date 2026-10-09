import 'package:flutter/material.dart';

@immutable
class SsSemanticColors extends ThemeExtension<SsSemanticColors> {
  const SsSemanticColors({
    required this.success,
    required this.warning,
    required this.error,
    required this.recording,
    required this.info,
    required this.local,
    required this.cloud,
    required this.successSubtle,
    required this.warningSubtle,
    required this.errorSubtle,
    required this.infoSubtle,
    required this.localSubtle,
    required this.cloudSubtle,
  });

  final Color success;
  final Color warning;
  final Color error;
  final Color recording;
  final Color info;
  final Color local;
  final Color cloud;

  /// Tinted backgrounds that pair with the matching foreground tone.
  final Color successSubtle;
  final Color warningSubtle;
  final Color errorSubtle;
  final Color infoSubtle;
  final Color localSubtle;
  final Color cloudSubtle;

  @override
  SsSemanticColors copyWith({
    Color? success,
    Color? warning,
    Color? error,
    Color? recording,
    Color? info,
    Color? local,
    Color? cloud,
    Color? successSubtle,
    Color? warningSubtle,
    Color? errorSubtle,
    Color? infoSubtle,
    Color? localSubtle,
    Color? cloudSubtle,
  }) {
    return SsSemanticColors(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      recording: recording ?? this.recording,
      info: info ?? this.info,
      local: local ?? this.local,
      cloud: cloud ?? this.cloud,
      successSubtle: successSubtle ?? this.successSubtle,
      warningSubtle: warningSubtle ?? this.warningSubtle,
      errorSubtle: errorSubtle ?? this.errorSubtle,
      infoSubtle: infoSubtle ?? this.infoSubtle,
      localSubtle: localSubtle ?? this.localSubtle,
      cloudSubtle: cloudSubtle ?? this.cloudSubtle,
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
      local: Color.lerp(local, other.local, t)!,
      cloud: Color.lerp(cloud, other.cloud, t)!,
      successSubtle: Color.lerp(successSubtle, other.successSubtle, t)!,
      warningSubtle: Color.lerp(warningSubtle, other.warningSubtle, t)!,
      errorSubtle: Color.lerp(errorSubtle, other.errorSubtle, t)!,
      infoSubtle: Color.lerp(infoSubtle, other.infoSubtle, t)!,
      localSubtle: Color.lerp(localSubtle, other.localSubtle, t)!,
      cloudSubtle: Color.lerp(cloudSubtle, other.cloudSubtle, t)!,
    );
  }
}

extension SsSemanticColorsContext on BuildContext {
  SsSemanticColors get semanticColors {
    final ThemeData theme = Theme.of(this);
    final SsSemanticColors? semantic = theme.extension<SsSemanticColors>();
    if (semantic != null) return semantic;

    final ColorScheme colors = theme.colorScheme;
    return SsSemanticColors(
      success: colors.tertiary,
      warning: colors.secondary,
      error: colors.error,
      recording: colors.error,
      info: colors.primary,
      local: colors.primary,
      cloud: colors.primary,
      successSubtle: colors.tertiaryContainer,
      warningSubtle: colors.secondaryContainer,
      errorSubtle: colors.errorContainer,
      infoSubtle: colors.primaryContainer,
      localSubtle: colors.primaryContainer,
      cloudSubtle: colors.primaryContainer,
    );
  }
}
