import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  bool _isRegister = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _busy = true; _error = null; });
    try {
      final auth = context.read<AuthState>();
      if (_isRegister) {
        await auth.register(_email.text.trim(), _pass.text, _name.text.trim().isEmpty ? null : _name.text.trim());
      } else {
        await auth.login(_email.text.trim(), _pass.text);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HseColors.surface,
      body: Stack(children: [
        Positioned.fill(
          child: CustomPaint(painter: _BackgroundPainter()),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SoftCard(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 64, width: 64,
                        decoration: BoxDecoration(
                          gradient: HseColors.gradient,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: const Text('HSE',
                            style: TextStyle(color: Colors.white, fontFamily: 'Unbounded', fontWeight: FontWeight.w800, fontSize: 18)),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isRegister ? 'Создаём аккаунт' : 'С возвращением!',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'HSE Forms — конструктор опросов с условной логикой и A/B-экспериментами.',
                        style: TextStyle(color: HseColors.inkSoft, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      if (_isRegister) ...[
                        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Имя', hintText: 'Как вас зовут?')),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', hintText: 'you@hse.ru'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Пароль', hintText: 'Минимум 8 символов'),
                        onSubmitted: (_) => _submit(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x1AE05656),
                            borderRadius: BorderRadius.circular(HseRadius.sm),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: HseColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!, style: const TextStyle(color: HseColors.danger, fontSize: 13))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 22),
                      GradientButton(
                        onPressed: _busy ? null : _submit,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            _busy ? '...' : (_isRegister ? 'Создать аккаунт' : 'Войти'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => _isRegister = !_isRegister),
                        child: Text(_isRegister ? 'Уже есть аккаунт? Войти' : 'Нет аккаунта? Зарегистрироваться'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Soft animated blobs in HSE colors as background.
class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = HseColors.primary.withOpacity(0.08);
    final paint2 = Paint()..color = HseColors.primaryBright.withOpacity(0.06);
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.2), 220, paint1);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.85), 280, paint2);
    canvas.drawCircle(Offset(size.width * 0.9, size.height * 0.15), 120, paint1);
  }
  @override
  bool shouldRepaint(_) => false;
}
