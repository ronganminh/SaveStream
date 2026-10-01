import 'package:flutter/material.dart';

abstract final class SsColors {
  static const Color brandPrimary = Color(0xFF4F46E5);
  static const Color brandPrimaryDark = Color(0xFF818CF8);
  static const Color brandAccent = Color(0xFFC4B5FD);
  static const Color success = Color(0xFF15803D);
  static const Color successDark = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFB45309);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color error = Color(0xFFB91C1C);
  static const Color errorDark = Color(0xFFF87171);
  static const Color recording = Color(0xFFDC2626);
  static const Color recordingDark = Color(0xFFFB7185);
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

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius field = BorderRadius.all(Radius.circular(md));
}
