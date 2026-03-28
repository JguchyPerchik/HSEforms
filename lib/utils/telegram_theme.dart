// lib/utils/telegram_theme.dart

import 'package:flutter/material.dart';

// ─── Telegram Color Bridge ─────────────────────────────────────────────────────
// Maps Telegram's themeParams to Flutter's ColorScheme / ThemeData.
// Falls back gracefully when running outside of a Telegram Mini App context.

class TelegramThemeParams {
  final Color backgroundColor;
  final Color secondaryBackgroundColor;
  final Color textColor;
  final Color hintColor;
  final Color linkColor;
  final Color buttonColor;
  final Color buttonTextColor;
  final Color accentTextColor;
  final Color destructiveTextColor;
  final Color headerBackgroundColor;
  final Color sectionBackgroundColor;
  final Color sectionSeparatorColor;
  final Brightness brightness;

  const TelegramThemeParams({
    required this.backgroundColor,
    required this.secondaryBackgroundColor,
    required this.textColor,
    required this.hintColor,
    required this.linkColor,
    required this.buttonColor,
    required this.buttonTextColor,
    required this.accentTextColor,
    required this.destructiveTextColor,
    required this.headerBackgroundColor,
    required this.sectionBackgroundColor,
    required this.sectionSeparatorColor,
    required this.brightness,
  });

  // ── Default light fallback (used on web outside Telegram) ─────────────────
  static const TelegramThemeParams light = TelegramThemeParams(
    backgroundColor: Color(0xFFFFFFFF),
    secondaryBackgroundColor: Color(0xFFF4F4F5),
    textColor: Color(0xFF09090B),
    hintColor: Color(0xFF71717A),
    linkColor: Color(0xFF6366F1),
    buttonColor: Color(0xFF6366F1),
    buttonTextColor: Color(0xFFFFFFFF),
    accentTextColor: Color(0xFF6366F1),
    destructiveTextColor: Color(0xFFEF4444),
    headerBackgroundColor: Color(0xFFFFFFFF),
    sectionBackgroundColor: Color(0xFFFFFFFF),
    sectionSeparatorColor: Color(0xFFE4E4E7),
    brightness: Brightness.light,
  );

  // ── Default dark fallback ──────────────────────────────────────────────────
  static const TelegramThemeParams dark = TelegramThemeParams(
    backgroundColor: Color(0xFF09090B),
    secondaryBackgroundColor: Color(0xFF18181B),
    textColor: Color(0xFFFAFAFA),
    hintColor: Color(0xFF71717A),
    linkColor: Color(0xFF818CF8),
    buttonColor: Color(0xFF6366F1),
    buttonTextColor: Color(0xFFFFFFFF),
    accentTextColor: Color(0xFF818CF8),
    destructiveTextColor: Color(0xFFF87171),
    headerBackgroundColor: Color(0xFF09090B),
    sectionBackgroundColor: Color(0xFF18181B),
    sectionSeparatorColor: Color(0xFF27272A),
    brightness: Brightness.dark,
  );

  // ── Parse from Telegram's themeParams map ─────────────────────────────────
  factory TelegramThemeParams.fromTelegramMap(Map<String, dynamic> params) {
    Color parseHex(String? hex, Color fallback) {
      if (hex == null || hex.isEmpty) return fallback;
      try {
        final cleaned = hex.replaceAll('#', '');
        return Color(int.parse('FF$cleaned', radix: 16));
      } catch (_) {
        return fallback;
      }
    }

    final bg = parseHex(params['bg_color'] as String?, const Color(0xFFFFFFFF));
    final isDark = _isColorDark(bg);

    return TelegramThemeParams(
      backgroundColor: bg,
      secondaryBackgroundColor: parseHex(
        params['secondary_bg_color'] as String?,
        isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
      ),
      textColor: parseHex(
        params['text_color'] as String?,
        isDark ? const Color(0xFFFAFAFA) : const Color(0xFF09090B),
      ),
      hintColor: parseHex(
        params['hint_color'] as String?,
        const Color(0xFF71717A),
      ),
      linkColor: parseHex(
        params['link_color'] as String?,
        const Color(0xFF6366F1),
      ),
      buttonColor: parseHex(
        params['button_color'] as String?,
        const Color(0xFF6366F1),
      ),
      buttonTextColor: parseHex(
        params['button_text_color'] as String?,
        const Color(0xFFFFFFFF),
      ),
      accentTextColor: parseHex(
        params['accent_text_color'] as String?,
        const Color(0xFF6366F1),
      ),
      destructiveTextColor: parseHex(
        params['destructive_text_color'] as String?,
        const Color(0xFFEF4444),
      ),
      headerBackgroundColor: parseHex(
        params['header_bg_color'] as String?,
        bg,
      ),
      sectionBackgroundColor: parseHex(
        params['section_bg_color'] as String?,
        bg,
      ),
      sectionSeparatorColor: parseHex(
        params['section_separator_color'] as String?,
        isDark ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
      ),
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
  }

  static bool _isColorDark(Color c) {
    final luminance = (0.299 * c.r + 0.587 * c.g + 0.114 * c.b);
    return luminance < 0.5;
  }

  bool get isDark => brightness == Brightness.dark;

  // ── Convert to Flutter ThemeData ──────────────────────────────────────────
  ThemeData toThemeData({Color? accentOverride}) {
    final accent = accentOverride ?? buttonColor;
    final cs = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: buttonTextColor,
      secondary: accentTextColor,
      onSecondary: buttonTextColor,
      surface: sectionBackgroundColor,
      onSurface: textColor,
      error: destructiveTextColor,
      onError: buttonTextColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: sectionBackgroundColor,
      dividerColor: sectionSeparatorColor,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryBackgroundColor,
        hintStyle: TextStyle(color: hintColor, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: sectionSeparatorColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: sectionSeparatorColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: destructiveTextColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: destructiveTextColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(color: textColor, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: hintColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: buttonTextColor,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
