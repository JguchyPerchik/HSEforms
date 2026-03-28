// lib/services/telegram_service.dart
// ─── Telegram Mini App Bridge ─────────────────────────────────────────────────
// Wraps `telegram_web_app` package calls with graceful fallbacks for
// running in a regular browser outside of Telegram.

import 'package:flutter/foundation.dart';
import '../../../utils/telegram_theme.dart';

class TelegramService {
  TelegramService._();
  static final TelegramService instance = TelegramService._();

  bool _initialized = false;
  bool _isTelegramContext = false;
  TelegramThemeParams _themeParams = TelegramThemeParams.light;

  bool get isTelegramContext => _isTelegramContext;
  TelegramThemeParams get themeParams => _themeParams;

  /// Initialise the Telegram Web App SDK.
  /// Safe to call on all platforms; is a no-op outside the browser.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      debugPrint('[TelegramService] Not running on web – skipping TMA init.');
      return;
    }

    try {
      // ── Dynamic import to avoid compile errors on non-web targets ──────────
      // In a real project you'd import telegram_web_app directly:
      //
      //   import 'package:telegram_web_app/telegram_web_app.dart';
      //   final twa = TelegramWebApp.instance;
      //   if (twa.isAvailable) { ... }
      //
      // Here we simulate the integration pattern so the code compiles
      // without the package being installed in this scaffold:

      final twaParams = await _tryGetTelegramParams();
      if (twaParams != null) {
        _isTelegramContext = true;
        _themeParams = TelegramThemeParams.fromTelegramMap(twaParams);
        await _tryExpand();
        debugPrint('[TelegramService] ✅ Running inside Telegram Mini App');
        debugPrint('[TelegramService] Theme: ${_themeParams.brightness}');
      } else {
        _isTelegramContext = false;
        // Try to honour the OS dark/light preference on the web
        _themeParams = _detectBrowserTheme();
        debugPrint('[TelegramService] ℹ️ Running in regular browser');
      }
    } catch (e) {
      debugPrint('[TelegramService] ⚠️ Init error: $e');
      _isTelegramContext = false;
      _themeParams = TelegramThemeParams.light;
    }
  }

  // ── Real implementation using the telegram_web_app package ─────────────────
  // Replace the body of this method with actual package calls:
  //
  //   import 'package:telegram_web_app/telegram_web_app.dart';
  //
  //   Future<Map<String, dynamic>?> _tryGetTelegramParams() async {
  //     final twa = TelegramWebApp.instance;
  //     if (!twa.isAvailable) return null;
  //     final params = twa.themeParams;
  //     return {
  //       'bg_color':              params.bgColor,
  //       'secondary_bg_color':    params.secondaryBgColor,
  //       'text_color':            params.textColor,
  //       'hint_color':            params.hintColor,
  //       'link_color':            params.linkColor,
  //       'button_color':          params.buttonColor,
  //       'button_text_color':     params.buttonTextColor,
  //       'accent_text_color':     params.accentTextColor,
  //       'destructive_text_color':params.destructiveTextColor,
  //       'header_bg_color':       params.headerBgColor,
  //       'section_bg_color':      params.sectionBgColor,
  //       'section_separator_color':params.sectionSeparatorColor,
  //     };
  //   }

  Future<Map<String, dynamic>?> _tryGetTelegramParams() async {
    // Stub: detects via JS interop whether window.Telegram.WebApp exists
    // Returns null when running outside Telegram.
    try {
      // js.context['Telegram']?['WebApp']?['initData'] — non-empty = in TMA
      // For actual implementation, uncomment the block above.
      return null; // Replace with real TMA call
    } catch (_) {
      return null;
    }
  }

  Future<void> _tryExpand() async {
    try {
      // TelegramWebApp.instance.expand();
      debugPrint('[TelegramService] expand() called');
    } catch (_) {}
  }

  TelegramThemeParams _detectBrowserTheme() {
    // Could use js.context['matchMedia']('(prefers-color-scheme: dark)')
    // to check OS preference; returns light as safe default.
    return TelegramThemeParams.light;
  }

  /// Call when user taps the Telegram MainButton (bottom bar).
  void setupMainButton({
    required String text,
    required VoidCallback onPressed,
    bool isVisible = true,
  }) {
    if (!_isTelegramContext) return;
    try {
      // TelegramWebApp.instance.mainButton
      //   ..text = text
      //   ..show()
      //   ..onClick(onPressed);
    } catch (_) {}
  }

  void hideMainButton() {
    if (!_isTelegramContext) return;
    try {
      // TelegramWebApp.instance.mainButton.hide();
    } catch (_) {}
  }

  /// Sends form response data back to the bot via sendData.
  void sendData(String jsonPayload) {
    if (!_isTelegramContext) return;
    try {
      // TelegramWebApp.instance.sendData(jsonPayload);
    } catch (_) {}
  }

  void close() {
    if (!_isTelegramContext) return;
    try {
      // TelegramWebApp.instance.close();
    } catch (_) {}
  }

  // ── Theme change listener (live theme switching in Telegram) ────────────────
  void onThemeChanged(void Function(TelegramThemeParams) callback) {
    if (!_isTelegramContext) return;
    try {
      // TelegramWebApp.instance.onThemeChanged(() {
      //   final updated = TelegramThemeParams.fromTelegramMap( ... );
      //   callback(updated);
      // });
    } catch (_) {}
  }
}
