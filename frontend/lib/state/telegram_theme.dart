/// Чтение и наблюдение за темой Telegram Mini App.
///
/// Telegram WebApp передаёт в страницу набор цветов (`themeParams`)
/// и режим яркости (`colorScheme`), которые должны определять
/// оформление мини-аппа — иначе на тёмном клиенте Telegram светлый
/// Flutter-интерфейс выглядит «оторванным».
///
/// Поток данных:
///   index.html → Telegram.WebApp.onEvent('themeChanged') → syncTgTheme()
///        │
///        ├── раскладывает темy в ПЛОСКИЕ window.tg<...>  свойства
///        │   (window.tgBgColor, window.tgTextColor, window.tgColorScheme …)
///        │
///        └── dispatchEvent(new CustomEvent('tg-theme-changed'))
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
/// Почему именно плоские свойства, а не nested-объект:
///   js_interop_unsafe стабильно читает window.<key> через
///   `globalContext.getProperty('key'.toJS)`. Чтение вложенного объекта
///   (`window.tgThemeParams.bg_color`) в dart2wasm/dart2js даёт
///   неконсистентное поведение — на части браузеров возвращается
///   `JSObject` без удобного доступа к полям, на других — `null`.
///   Плоские строковые window-поля работают везде одинаково.
///
/// Если приложение открыто в обычном браузере (не в Telegram), все
/// геттеры возвращают `null`/`false`, и `buildHseTheme` использует
/// дефолтную HSE-палитру.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class TelegramTheme extends ChangeNotifier {
  TelegramTheme._() {
    _read();
    if (kIsWeb) {
      // Слушаем кастомное событие из index.html. Замыкание через
      // .toJS, иначе addEventListener не примет Dart-функцию.
      web.window.addEventListener('tg-theme-changed', _onEvent.toJS);

      // Подстраховка от гонки загрузки скриптов: Flutter может
      // инстанцировать TelegramTheme.instance ДО того, как
      // telegram-web-app.js загрузится и выставит window.tgThemeReady.
      // Делаем несколько отложенных попыток перечитать — после microtask,
      // через 100/300/800 мс. Как только данные появились, обновляемся
      // и больше не дёргаемся.
      _scheduleRecheck();
    }
  }

  /// Серия отложенных перечитываний темы для лечения race condition
  /// между загрузкой telegram-web-app.js и первым кадром Flutter.
  void _scheduleRecheck() {
    const delays = <Duration>[
      Duration.zero,
      Duration(milliseconds: 100),
      Duration(milliseconds: 300),
      Duration(milliseconds: 800),
    ];
    for (final d in delays) {
      Future.delayed(d, () {
        if (_available) return; // уже успели — больше не трогаем
        _read();
        if (_available) notifyListeners();
      });
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

  /// Достаёт строковое window.<key> через js_interop_unsafe. Возвращает
  /// `null`, если поле отсутствует, не строка или пустая строка.
  ///
  /// Раньше здесь был `dartify()` — формально он умеет снимать JSString,
  /// но на dart2wasm / при включённом tree-shaking иногда отдаёт `null`
  /// либо обёрнутый JSAny без удобной распаковки. Явный `isA<JSString>()
  /// + .toDart` — это документированный, стабильный путь, который
  /// работает одинаково и в dev, и в release-сборке.
  String? _winString(String key) {
    try {
      final raw = globalContext.getProperty(key.toJS);
      if (raw == null) return null;
      if (!raw.isA<JSString>()) return null;
      final s = (raw as JSString).toDart;
      final trimmed = s.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      return null;
    }
  }

  /// Достаёт булевый window.<key>. Используется только для tgThemeReady.
  /// Аналогично: явный JSBoolean-каст вместо dartify() — меньше сюрпризов.
  bool _winBool(String key) {
    try {
      final raw = globalContext.getProperty(key.toJS);
      if (raw == null) return false;
      if (!raw.isA<JSBoolean>()) return false;
      return (raw as JSBoolean).toDart;
    } catch (_) {
      return false;
    }
  }

  void _read() {
    if (!kIsWeb) {
      _available = false;
      return;
    }
    try {
      // window.tgThemeReady выставляется в index.html после успешного
      // syncTgTheme(). Если флага нет — Telegram WebApp недоступен или
      // скрипт ещё не отработал.
      if (!_winBool('tgThemeReady')) {
        _available = false;
        return;
      }
      final bg = _winString('tgBgColor');
      // Базовая валидация: если bg_color не пришёл — считать, что
      // тема не передана (Telegram всегда отдаёт его первым).
      if (bg == null) {
        _available = false;
        return;
      }
      _available = true;
      _isDark = _winString('tgColorScheme') == 'dark';
      _bg          = _parseHex(bg);
      _text        = _parseHex(_winString('tgTextColor'));
      _hint        = _parseHex(_winString('tgHintColor'));
      _link        = _parseHex(_winString('tgLinkColor'));
      _button      = _parseHex(_winString('tgButtonColor'));
      _buttonText  = _parseHex(_winString('tgButtonTextColor'));
      _secondaryBg = _parseHex(_winString('tgSecondaryBgColor'));
      _headerBg    = _parseHex(_winString('tgHeaderBgColor'));
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
