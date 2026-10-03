import 'package:flutter/material.dart';

/// SaveStream Mobile V2 design tokens (design handoff, Phase 7 final).
abstract final class SsColors {
  static const Color brandPrimary = Color(0xFF6D49F4);
  static const Color brandPrimaryDark = Color(0xFF968CFF);
  static const Color brandAccent = Color(0xFFC4B5FD);

  /// Background of the official brand mark, launcher icon and native splash.
  static const Color brandMark = Color(0xFF4F46E5);

  static const Color success = Color(0xFF007742);
  static const Color successDark = Color(0xFF3FD18A);
  static const Color warning = Color(0xFF8A5D00);
  static const Color warningDark = Color(0xFFF0B43C);
  static const Color error = Color(0xFFE31029);
  static const Color errorDark = Color(0xFFFF5468);
  static const Color recording = Color(0xFFE31029);
  static const Color recordingDark = Color(0xFFFF5468);
}

abstract final class SsSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

abstract final class SsRadii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;

  static const double cta = 14;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
  static const BorderRadius button = BorderRadius.all(Radius.circular(cta));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(xl),
  );
}
