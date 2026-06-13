/// Чтение и наблюдение за темой Telegram Mini App.
///
/// Telegram WebApp передаёт в страницу набор цветов
/// (`themeParams`) и режим яркости (`colorScheme`), которые должны
/// определять оформление мини-аппа — иначе на тёмном клиенте Telegram
/// светлый Flutter-интерфейс выглядит «оторванным».
///
/// Поток данных:
///   index.html → onEvent('themeChanged') → window.tgThemeParams +
///                CustomEvent('tg-theme-changed')
///                                            │
///                                            ▼
///                             TelegramTheme.instance ←— addEventListener
///                                            │
///                                            ▼
///                              ChangeNotifier → notifyListeners()
///                                            │
///                                            ▼
///                              ListenableBuilder в main.dart → rebuild
///
/// Если приложение открыто в обычном браузере (не в Telegram), все
/// геттеры возвращают `null`/`false`, и `buildHseTheme` использует
/// дефолтную HSE-палитру.
library;

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class TelegramTheme extends ChangeNotifier {
  TelegramTheme._() {
    _read();
    if (kIsWeb) {
      // Слушаем кастомное событие из index.html. Замыкание через
      // .toJS, иначе аддон 'addEventListener' не примет Dart-функцию.
      web.window.addEventListener('tg-theme-changed', _onEvent.toJS);
    }
  }

  /// Один экземпляр на всё приложение — тема глобальна по определению.
  static final TelegramTheme instance = TelegramTheme._();

  bool _available = false;
  bool _isDark = false;
  Color? _bg;
  Color? _text;
  Color? _hint;
  Color? _link;
  Color? _button;
  Color? _buttonText;
  Color? _secondaryBg;
  Color? _headerBg;

  /// true если приложение реально открыто внутри Telegram Mini App
  /// (то есть скрипт telegram-web-app.js загрузился и отдал themeParams).
  /// Используется как «выключатель» Telegram-стилизации: вне Telegram
  /// — рендерим как обычный сайт с HSE-палитрой.
  bool get available => _available;

  bool get isDark => _isDark;
  Color? get bg => _bg;
  Color? get text => _text;
  Color? get hint => _hint;
  Color? get link => _link;
  Color? get button => _button;
  Color? get buttonText => _buttonText;
  Color? get secondaryBg => _secondaryBg;
  Color? get headerBg => _headerBg;

  void _onEvent(web.Event _) {
    _read();
    notifyListeners();
  }

  void _read() {
    if (!kIsWeb) {
      _available = false;
      return;
    }
    try {
      // `window.tgThemeParams` — простой JS-объект, выставленный в
      // index.html. Тянем через `as dynamic`, чтобы не описывать
      // JSInterop-обёртку — поля стабильны и редко меняются.
      final raw = (web.window as dynamic).tgThemeParams;
      if (raw == null) {
        _available = false;
        return;
      }
      _available = true;
      _isDark = (raw.color_scheme as String?) == 'dark';
      _bg = _parseHex(raw.bg_color as String?);
      _text = _parseHex(raw.text_color as String?);
      _hint = _parseHex(raw.hint_color as String?);
      _link = _parseHex(raw.link_color as String?);
      _button = _parseHex(raw.button_color as String?);
      _buttonText = _parseHex(raw.button_text_color as String?);
      _secondaryBg = _parseHex(raw.secondary_bg_color as String?);
      _headerBg = _parseHex(raw.header_bg_color as String?);
    } catch (_) {
      // Любой сбой JS-interop — откатываемся на дефолтную тему.
      _available = false;
    }
  }

  /// Telegram отдаёт цвета в формате `#RRGGBB`. Парсим в opaque-Color
  /// (альфа 0xFF — Telegram прозрачность не поддерживает).
  Color? _parseHex(String? hex) {
    if (hex == null) return null;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return null;
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return null;
    }
  }
}
