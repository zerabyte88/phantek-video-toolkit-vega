// SPDX-License-Identifier: MIT
// Copyright (C) 2026 zerabyte88

import 'package:flutter/material.dart';

class AppTheme {
  static const _primaryColor = Color(0xFF2563EB);
  static const _secondaryColor = Color(0xFF0E7C86);

  /// Button/accent colors of the animated themes, matching their cards in Settings.
  static const snowfallAccent = Color(0xFF38BDF8);
  static const midnightAccent = Color(0xFFA78BFA);
  static const daylightAccent = Color(0xFFFBBF24);

  static ThemeData getTheme(String mode, {double cardOpacity = 1.0}) {
    switch (mode) {
      case 'oled_sakura':
      case 'sakura':
        return buildSakuraTheme(cardOpacity: cardOpacity);
      case 'oled_midnight':
        return buildOledTheme(
          cardOpacity: cardOpacity,
          primary: midnightAccent,
          onPrimary: Colors.black,
        );
      case 'oled_pure':
      case 'pure_oled':
      case 'oled':
        return buildOledTheme(cardOpacity: cardOpacity);
      case 'light':
        return buildLightTheme(
          cardOpacity: cardOpacity,
          primary: daylightAccent,
          onPrimary: Colors.white,
        );
      case 'light_clean':
      case 'clean_light':
        return buildLightTheme(cardOpacity: cardOpacity);
      case 'oled_snowfall':
      case 'dark':
      default:
        return buildDarkTheme(
          cardOpacity: cardOpacity,
          primary: snowfallAccent,
          onPrimary: Colors.black,
        );
    }
  }

  /// Sakura theme getter
  static ThemeData get sakuraTheme => buildSakuraTheme();

  /// Sakura theme builder
  static ThemeData buildSakuraTheme({double cardOpacity = 1.0}) {
    const sakuraPrimary = Color(0xFFF472B6);
    const sakuraSecondary = Color(0xFFFDA4AF);
    const scaffoldBg = Colors.black;
    const surfaceBg = Color(0xFF140D13);
    const outlineColor = Color(0xFF381525);
    const textPrimary = Color(0xFFFFF1F2);
    const textSecondary = Color(0xFFD4A5B8);

    final effectiveSurface = cardOpacity < 1.0
        ? surfaceBg.withAlpha(
            (255 * cardOpacity.clamp(0.5, 1.0)).round().clamp(0, 255),
          )
        : surfaceBg;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: sakuraPrimary,
        onPrimary: Colors.white,
        secondary: sakuraSecondary,
        surface: effectiveSurface,
        onSurface: textPrimary,
        outline: outlineColor,
        outlineVariant: const Color(0xFF220C17),
      ),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: effectiveSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: outlineColor, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sakuraPrimary,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: outlineColor, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceBg,
        selectedColor: sakuraPrimary,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: outlineColor, width: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        checkmarkColor: Colors.black,
        showCheckmark: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: sakuraPrimary,
        inactiveTrackColor: sakuraPrimary.withAlpha(35),
        thumbColor: sakuraPrimary,
        overlayColor: sakuraPrimary.withAlpha(25),
        valueIndicatorColor: sakuraPrimary,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
        ),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: sakuraPrimary,
        circularTrackColor: Color(0xFF28101C),
        linearTrackColor: Color(0xFF28101C),
      ),
      dividerTheme: const DividerThemeData(color: outlineColor, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Colors.black
              : const Color(0xFF835A6D),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? sakuraPrimary
              : const Color(0xFF28101C),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceBg,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outlineColor),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 15, color: textPrimary, height: 1.5),
        bodyMedium: TextStyle(fontSize: 13, color: textSecondary, height: 1.5),
        bodySmall: TextStyle(
          fontSize: 11,
          color: Color(0xFF835A6D),
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    );
  }

  /// Snowfall theme getter
  static ThemeData get darkTheme => buildDarkTheme();

  /// Snowfall theme builder
  static ThemeData buildDarkTheme({
    double cardOpacity = 1.0,
    Color primary = _primaryColor,
    Color onPrimary = Colors.white,
  }) {
    const scaffoldBg = Colors.black;
    const surfaceBg = Color(0xFF0D1830);
    const outlineColor = Color(0xFF1F3254);
    const textPrimary = Color(0xFFF8FAFC);
    const textSecondary = Color(0xFF94A3B8);

    final effectiveSurface = cardOpacity < 1.0
        ? surfaceBg.withAlpha(
            (255 * cardOpacity.clamp(0.5, 1.0)).round().clamp(0, 255),
          )
        : surfaceBg;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: _secondaryColor,
        surface: effectiveSurface,
        onSurface: textPrimary,
        outline: outlineColor,
        outlineVariant: const Color(0xFF1F3254),
      ),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: effectiveSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: outlineColor, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: outlineColor, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF0D1830),
        selectedColor: primary,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: onPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: outlineColor, width: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        checkmarkColor: onPrimary,
        showCheckmark: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: primary.withAlpha(35),
        thumbColor: primary,
        overlayColor: primary.withAlpha(25),
        valueIndicatorColor: primary,
        valueIndicatorTextStyle: TextStyle(
          color: onPrimary,
          fontWeight: FontWeight.w600,
        ),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: const Color(0xFF1F3254),
        linearTrackColor: const Color(0xFF1F3254),
      ),
      dividerTheme: const DividerThemeData(color: outlineColor, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? onPrimary
              : const Color(0xFF64748B),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary
              : const Color(0xFF1F3254),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0D1830),
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outlineColor),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 15, color: textPrimary, height: 1.5),
        bodyMedium: TextStyle(fontSize: 13, color: textSecondary, height: 1.5),
        bodySmall: TextStyle(
          fontSize: 11,
          color: Color(0xFF64748B),
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    );
  }

  /// Pure OLED theme getter
  static ThemeData get oledTheme => buildOledTheme();

  /// Pure OLED theme builder
  static ThemeData buildOledTheme({
    double cardOpacity = 1.0,
    Color primary = _primaryColor,
    Color onPrimary = Colors.white,
  }) {
    const scaffoldBg = Colors.black;
    const surfaceBg = Color(0xFF111620);
    const outlineColor = Color(0xFF283042);
    const textPrimary = Color(0xFFFAFAFA);
    const textSecondary = Color(0xFFA1A1AA);

    final effectiveSurface = cardOpacity < 1.0
        ? surfaceBg.withAlpha(
            (255 * cardOpacity.clamp(0.5, 1.0)).round().clamp(0, 255),
          )
        : surfaceBg;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: onPrimary,
        secondary: _secondaryColor,
        surface: effectiveSurface,
        onSurface: textPrimary,
        outline: outlineColor,
        outlineVariant: const Color(0xFF18181B),
      ),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: effectiveSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: outlineColor, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: outlineColor, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceBg,
        selectedColor: primary,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: onPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: outlineColor, width: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        checkmarkColor: onPrimary,
        showCheckmark: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: primary.withAlpha(35),
        thumbColor: primary,
        overlayColor: primary.withAlpha(25),
        valueIndicatorColor: primary,
        valueIndicatorTextStyle: TextStyle(
          color: onPrimary,
          fontWeight: FontWeight.w600,
        ),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: const Color(0xFF283042),
        linearTrackColor: const Color(0xFF283042),
      ),
      dividerTheme: const DividerThemeData(color: outlineColor, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? onPrimary
              : const Color(0xFF71717A),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary
              : const Color(0xFF283042),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceBg,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: outlineColor),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 15, color: textPrimary, height: 1.5),
        bodyMedium: TextStyle(fontSize: 13, color: textSecondary, height: 1.5),
        bodySmall: TextStyle(
          fontSize: 11,
          color: Color(0xFF71717A),
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    );
  }

  /// Light theme getter
  static ThemeData get lightTheme => buildLightTheme();

  /// Light theme builder
  static ThemeData buildLightTheme({
    double cardOpacity = 1.0,
    Color primary = _primaryColor,
    Color onPrimary = Colors.white,
  }) {
    const scaffoldBg = Color(0xFFEDF2FA);
    const surfaceBg = Color(0xFFFFFFFF);
    const outlineColor = Color(0xFFD5DEEE);
    const textPrimary = Color(0xFF0F172A);
    const textSecondary = Color(0xFF475569);

    final effectiveSurface = cardOpacity < 1.0
        ? surfaceBg.withAlpha(
            (255 * cardOpacity.clamp(0.5, 1.0)).round().clamp(0, 255),
          )
        : surfaceBg;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        secondary: _secondaryColor,
        surface: effectiveSurface,
        onSurface: textPrimary,
        outline: outlineColor,
        outlineVariant: const Color(0xFFE6EDF8),
      ),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceBg,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: effectiveSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: outlineColor, width: 1.0),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: outlineColor, width: 1.0),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFE6EDF8),
        selectedColor: primary,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: onPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: outlineColor, width: 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        checkmarkColor: onPrimary,
        showCheckmark: false,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primary,
        inactiveTrackColor: primary.withAlpha(30),
        thumbColor: primary,
        overlayColor: primary.withAlpha(20),
        valueIndicatorColor: primary,
        valueIndicatorTextStyle: TextStyle(
          color: onPrimary,
          fontWeight: FontWeight.w600,
        ),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        circularTrackColor: const Color(0xFFD5DEEE),
        linearTrackColor: const Color(0xFFD5DEEE),
      ),
      dividerTheme: const DividerThemeData(color: outlineColor, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? onPrimary
              : const Color(0xFF94A3B8),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary
              : const Color(0xFFD5DEEE),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 15, color: textPrimary, height: 1.5),
        bodyMedium: TextStyle(fontSize: 13, color: textSecondary, height: 1.5),
        bodySmall: TextStyle(
          fontSize: 11,
          color: Color(0xFF94A3B8),
          height: 1.4,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    );
  }
}
