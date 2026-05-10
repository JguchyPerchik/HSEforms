// lib/services/telegram_service.dart

import 'package:flutter/foundation.dart';
import '../../../utils/telegram_theme.dart';

class TelegramService {
  TelegramService._();
  static final TelegramService instance = TelegramService._();

  bool _initialized = false;
  bool _isTelegramContext = false;
  TelegramThemeParams _themeParams = TelegramThemeParams.light;
  String? _initData;
  int? _telegramUserId;

  bool get isTelegramContext => _isTelegramContext;
  TelegramThemeParams get themeParams => _themeParams;
  String? get initData => _initData;
  int? get telegramUserId => _telegramUserId;
  int? get chatId => _telegramUserId;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!kIsWeb) return;
    try {
      final params = await _tryGetTelegramParams();
      if (params != null) {
        _isTelegramContext = true;
        _themeParams = TelegramThemeParams.fromTelegramMap(
            params['theme'] as Map<String, dynamic>? ?? {});
        _initData = params['initData'] as String?;
        _telegramUserId = params['userId'] as int?;
        await _tryExpand();
        debugPrint('[TelegramService] In Telegram uid=$_telegramUserId');
      }
    } catch (e) {
      debugPrint('[TelegramService] init error: $e');
    }
  }

  // ── REAL IMPLEMENTATION ───────────────────────────────────────────────────
  // Uncomment and replace _tryGetTelegramParams with:
  //
  // import 'dart:convert';
  // import 'package:telegram_web_app/telegram_web_app.dart';
  //
  // Future<Map<String,dynamic>?> _tryGetTelegramParams() async {
  //   final twa = TelegramWebApp.instance;
  //   if (!twa.isAvailable) return null;
  //   int? userId;
  //   try {
  //     final p = Uri.splitQueryString(twa.initData);
  //     final u = p['user'];
  //     if (u != null) userId = (jsonDecode(Uri.decodeComponent(u))['id'] as num).toInt();
  //   } catch (_) {}
  //   return {
  //     'initData': twa.initData,
  //     'userId': userId,
  //     'theme': {
  //       'bg_color':                twa.themeParams.bgColor,
  //       'text_color':              twa.themeParams.textColor,
  //       'hint_color':              twa.themeParams.hintColor,
  //       'link_color':              twa.themeParams.linkColor,
  //       'button_color':            twa.themeParams.buttonColor,
  //       'button_text_color':       twa.themeParams.buttonTextColor,
  //       'secondary_bg_color':      twa.themeParams.secondaryBgColor,
  //       'accent_text_color':       twa.themeParams.accentTextColor,
  //       'destructive_text_color':  twa.themeParams.destructiveTextColor,
  //       'header_bg_color':         twa.themeParams.headerBgColor,
  //       'section_bg_color':        twa.themeParams.sectionBgColor,
  //       'section_separator_color': twa.themeParams.sectionSeparatorColor,
  //     },
  //   };
  // }

  Future<Map<String, dynamic>?> _tryGetTelegramParams() async => null;
  Future<void> _tryExpand() async {}

  void sendData(String payload) {}
  void close() {}
}
