import 'package:flutter/material.dart';

/// SaveStream Mobile V2 design tokens (design handoff, Phase 7 final).
abstract final class SsColors {
  static const Color brandPrimary = Color(0xFF4F46E5);
  static const Color brandPrimaryDark = Color(0xFF818CF8);
  static const Color brandAccent = Color(0xFFC4B5FD);

  static const Color success = Color(0xFF007742);
  static const Color successDark = Color(0xFF3FD18A);
  static const Color warning = Color(0xFF8A5D00);
  static const Color warningDark = Color(0xFFF0B43C);
  static const Color error = Color(0xFFE31029);
  static const Color errorDark = Color(0xFFFF5468);
  static const Color recording = Color(0xFFE31029);
  static const Color recordingDark = Color(0xFFFF5468);
  static const Color info = Color(0xFF0074C8);
  static const Color infoDark = Color(0xFF5BB0FF);

  static const Color successSubtle = Color(0xFFE6F4EC);
  static const Color successSubtleDark = Color(0xFF0D2419);
  static const Color warningSubtle = Color(0xFFFDF4E1);
  static const Color warningSubtleDark = Color(0xFF2A2111);
  static const Color errorSubtle = Color(0xFFFDECEE);
  static const Color errorSubtleDark = Color(0xFF2B1117);
  static const Color infoSubtle = Color(0xFFE6F1FA);
  static const Color infoSubtleDark = Color(0xFF0E2033);
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
