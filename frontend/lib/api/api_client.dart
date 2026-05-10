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

  String get baseUrl {
    if (_apiBaseEnv.isNotEmpty) return _apiBaseEnv;
    if (kIsWeb) {
      final loc = web.window.location;
      return '${loc.protocol}//${loc.hostname}:8000';
    }
    return 'http://localhost:8000';
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_kToken);
  }

  Future<void> setToken(String? t) async {
    _token = t;
    final prefs = await SharedPreferences.getInstance();
    if (t == null) {
      await prefs.remove(_kToken);
    } else {
      await prefs.setString(_kToken, t);
    }
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

  Future<dynamic> get(String path) async =>
      _handle(await http.get(Uri.parse('$baseUrl$path'), headers: _headers()));

  Future<dynamic> post(String path, [Object? body]) async =>
      _handle(await http.post(Uri.parse('$baseUrl$path'), headers: _headers(), body: body == null ? null : jsonEncode(body)));

  Future<dynamic> patch(String path, [Object? body]) async =>
      _handle(await http.patch(Uri.parse('$baseUrl$path'), headers: _headers(), body: body == null ? null : jsonEncode(body)));

  Future<dynamic> delete(String path) async =>
      _handle(await http.delete(Uri.parse('$baseUrl$path'), headers: _headers()));
}
