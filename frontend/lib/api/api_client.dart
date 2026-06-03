import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

const String _apiBaseEnv = String.fromEnvironment('API_BASE', defaultValue: '');

String get tgInitData {
  if (!kIsWeb) return '';
  try {
    final tg = (web.window as dynamic).Telegram;
    if (tg == null) return '';
    final w = tg.WebApp;
    if (w == null) return '';
    return (w.initData as String?) ?? '';
  } catch (_) {
    return '';
  }
}

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => 'API $status: $message';
}

class ApiClient {
  String? _token;
  static const _kToken = 'auth_token';

  /// Completes the first time [loadToken] finishes. Every outgoing request
  /// awaits this before composing headers, so a page that fires an API call
  /// during initState (before bootstrap had a chance to read the token from
  /// SharedPreferences) doesn't end up sending an anonymous request and
  /// getting a 401. The completer never resets — once the token store has
  /// been read once, subsequent set/clear operations are synchronous.
  final Completer<void> _ready = Completer<void>();
  Future<void> get ready => _ready.future;

  String get baseUrl {
    // Override через `--dart-define=API_BASE=...` побеждает всё. Нужен,
    // если фронт и API живут на разных доменах, либо в локальной
    // разработке, когда фронт открыт на :5xxx, а бэк отдельно на :8000.
    if (_apiBaseEnv.isNotEmpty) return _apiBaseEnv;
    if (kIsWeb) {
      // В проде фронт и API на одном домене: Caddy режет /api/* и
      // прокидывает на backend:8000. Порт 8000 наружу закрыт, поэтому
      // обращаться к нему напрямую (как было раньше) уже нельзя.
      final loc = web.window.location;
      return '${loc.protocol}//${loc.host}/api';
    }
    return 'http://localhost:8000';
  }

  Future<void> loadToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_kToken);
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> setToken(String? t) async {
    _token = t;
    final prefs = await SharedPreferences.getInstance();
    if (t == null) {
      await prefs.remove(_kToken);
    } else {
      await prefs.setString(_kToken, t);
    }
    // setToken can be called before loadToken on rare hot-reload paths;
    // make sure later requests aren't blocked forever waiting on _ready.
    if (!_ready.isCompleted) _ready.complete();
  }

  String? get token => _token;
  bool get isAuthed => _token != null;

  Map<String, String> _headers() {
    final h = {'Content-Type': 'application/json'};
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Future<dynamic> _handle(http.Response r) async {
    if (r.statusCode == 204) return null;
    final body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final msg = (body is Map && body['detail'] != null) ? body['detail'].toString() : 'Ошибка';
    throw ApiException(r.statusCode, msg);
  }

  Future<dynamic> get(String path) async {
    await _ready.future;
    return _handle(await http.get(Uri.parse('$baseUrl$path'), headers: _headers()));
  }

  Future<dynamic> post(String path, [Object? body]) async {
    await _ready.future;
    return _handle(await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    ));
  }

  Future<dynamic> patch(String path, [Object? body]) async {
    await _ready.future;
    return _handle(await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(),
      body: body == null ? null : jsonEncode(body),
    ));
  }

  Future<dynamic> delete(String path) async {
    await _ready.future;
    return _handle(await http.delete(Uri.parse('$baseUrl$path'), headers: _headers()));
  }
}
