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

  static const Color local = Color(0xFF0B7A75);
  static const Color localDark = Color(0xFF4CCFC5);
  static const Color localSubtle = Color(0xFFE3F3F2);
  static const Color localSubtleDark = Color(0xFF0E2827);
  static const Color cloud = Color(0xFF2F6FE4);
  static const Color cloudDark = Color(0xFF7EA8FF);
  static const Color cloudSubtle = Color(0xFFEAF0FD);
  static const Color cloudSubtleDark = Color(0xFF141F3A);
}

abstract final class SsSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

abstract final class SsTypography {
  static const String uiFamily = 'Geist';
  static const String monoFamily = 'Geist Mono';

  static const TextStyle timer = TextStyle(
    fontFamily: monoFamily,
    fontSize: 40,
    height: 48 / 40,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
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
