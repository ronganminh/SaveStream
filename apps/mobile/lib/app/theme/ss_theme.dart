import 'package:flutter/material.dart';

import 'ss_semantic_colors.dart';
import 'ss_tokens.dart';

abstract final class SsTheme {
  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: SsColors.brandPrimary,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF0F0FF),
    onPrimaryContainer: Color(0xFF3A1FB0),
    secondary: Color(0xFF626671),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFF2F3F7),
    onSecondaryContainer: Color(0xFF0E111A),
    tertiary: Color(0xFF8A5D00),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFDF4E1),
    onTertiaryContainer: Color(0xFF8A5D00),
    error: SsColors.error,
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFDECEE),
    onErrorContainer: Color(0xFF9F0B1D),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF0E111A),
    surfaceContainerLowest: Color(0xFFF9FAFC),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF6F7FA),
    surfaceContainerHigh: Color(0xFFF2F3F7),
    surfaceContainerHighest: Color(0xFFF2F3F7),
    onSurfaceVariant: Color(0xFF626671),
    outline: Color(0xFFDBDEE4),
    outlineVariant: Color(0xFFEEF0F4),
    scrim: Color(0x80090B10),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: SsColors.brandPrimaryDark,
    onPrimary: Color(0xFF120E2E),
    primaryContainer: Color(0xFF1F1B40),
    onPrimaryContainer: Color(0xFFD9D5FF),
    secondary: Color(0xFF9BA1AC),
    onSecondary: Color(0xFF090B10),
    secondaryContainer: Color(0xFF181C24),
    onSecondaryContainer: Color(0xFFECEEF2),
    tertiary: Color(0xFFF0B43C),
    onTertiary: Color(0xFF2A2111),
    tertiaryContainer: Color(0xFF2A2111),
    onTertiaryContainer: Color(0xFFF0B43C),
    error: SsColors.errorDark,
    onError: Color(0xFF2B1117),
    errorContainer: Color(0xFF2B1117),
    onErrorContainer: Color(0xFFFFB3BC),
    surface: Color(0xFF11141A),
    onSurface: Color(0xFFECEEF2),
    surfaceContainerLowest: Color(0xFF090B10),
    surfaceContainerLow: Color(0xFF11141A),
    surfaceContainer: Color(0xFF151921),
    surfaceContainerHigh: Color(0xFF181C24),
    surfaceContainerHighest: Color(0xFF181C24),
    onSurfaceVariant: Color(0xFF9BA1AC),
    outline: Color(0xFF262B35),
    outlineVariant: Color(0xFF1C2028),
    scrim: Color(0xA6000000),
  );

  static TextStyle _text(double size, double lineHeight, FontWeight weight) {
    return TextStyle(
      fontFamily: SsTypography.uiFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme colorScheme = isDark ? _darkScheme : _lightScheme;
    final TextTheme textTheme =
        TextTheme(
          displaySmall: _text(32, 40, FontWeight.w700),
          headlineMedium: _text(28, 36, FontWeight.w700),
          headlineSmall: _text(24, 30, FontWeight.w700),
          titleLarge: _text(22, 28, FontWeight.w600),
          titleMedium: _text(18, 24, FontWeight.w600),
          titleSmall: _text(16, 24, FontWeight.w600),
          bodyLarge: _text(16, 24, FontWeight.w400),
          bodyMedium: _text(14, 20, FontWeight.w400),
          bodySmall: _text(13, 18, FontWeight.w400),
          labelLarge: _text(16, 20, FontWeight.w600),
          labelMedium: _text(14, 20, FontWeight.w600),
          labelSmall: _text(12, 16, FontWeight.w500),
        ).apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        );

    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: SsRadii.field,
      borderSide: BorderSide(color: colorScheme.outline),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: SsTypography.uiFamily,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surfaceContainerLowest,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: colorScheme.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SsSpacing.lg,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const RoundedRectangleBorder(borderRadius: SsRadii.button),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: const RoundedRectangleBorder(borderRadius: SsRadii.button),
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const RoundedRectangleBorder(borderRadius: SsRadii.button),
          textStyle: textTheme.labelMedium,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: colorScheme.outline),
        backgroundColor: colorScheme.surface,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: textTheme.labelMedium,
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          final bool selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall!.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        extendedTextStyle: textTheme.labelLarge,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((
          Set<WidgetState> states,
        ) {
          return states.contains(WidgetState.selected)
              ? Colors.transparent
              : colorScheme.outline;
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(SsRadii.xl)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: colorScheme.scrim,
        shape: const RoundedRectangleBorder(borderRadius: SsRadii.sheet),
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF04060A)
            : const Color(0xFF12141B),
        contentTextStyle: textTheme.bodyMedium!.copyWith(
          color: const Color(0xFFF7F8FA),
        ),
        shape: const RoundedRectangleBorder(borderRadius: SsRadii.field),
      ),
      extensions: <ThemeExtension<dynamic>>[
        SsSemanticColors(
          success: isDark ? SsColors.successDark : SsColors.success,
          warning: isDark ? SsColors.warningDark : SsColors.warning,
          error: isDark ? SsColors.errorDark : SsColors.error,
          recording: isDark ? SsColors.recordingDark : SsColors.recording,
          info: isDark ? SsColors.infoDark : SsColors.info,
          local: isDark ? SsColors.localDark : SsColors.local,
          cloud: isDark ? SsColors.cloudDark : SsColors.cloud,
          successSubtle: isDark
              ? SsColors.successSubtleDark
              : SsColors.successSubtle,
          warningSubtle: isDark
              ? SsColors.warningSubtleDark
              : SsColors.warningSubtle,
          errorSubtle: isDark ? SsColors.errorSubtleDark : SsColors.errorSubtle,
          infoSubtle: isDark ? SsColors.infoSubtleDark : SsColors.infoSubtle,
          localSubtle: isDark ? SsColors.localSubtleDark : SsColors.localSubtle,
          cloudSubtle: isDark ? SsColors.cloudSubtleDark : SsColors.cloudSubtle,
        ),
      ],
    );
  }
}
