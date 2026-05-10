import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../api/api.dart';

class AuthState extends ChangeNotifier {
  final ApiClient client;
  late final AuthApi _auth = AuthApi(client);
  Map<String, dynamic>? user;
  bool ready = false;

  AuthState(this.client);

  Future<void> bootstrap() async {
    await client.loadToken();
    if (client.isAuthed) {
      try { user = await _auth.me(); } catch (_) { await client.setToken(null); }
    }
    final initData = tgInitData;
    if (!client.isAuthed && initData != null && initData.isNotEmpty) {
      try {
        final tok = await _auth.telegram(initData);
        await client.setToken(tok);
        user = await _auth.me();
      } catch (_) {}
    }
    ready = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final tok = await _auth.login(email, password);
    await client.setToken(tok);
    user = await _auth.me();
    notifyListeners();
  }

  Future<void> register(String email, String password, String? name) async {
    final tok = await _auth.register(email, password, name);
    await client.setToken(tok);
    user = await _auth.me();
    notifyListeners();
  }

  Future<void> logout() async {
    await client.setToken(null);
    user = null;
    notifyListeners();
  }

  bool get isAuthed => client.isAuthed && user != null;
}
