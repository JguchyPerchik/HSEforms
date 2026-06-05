import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'theme.dart';
import 'api/api_client.dart';
import 'state/auth_state.dart';
import 'screens/login_screen.dart';
import 'screens/surveys_list_screen.dart';
import 'screens/builder_screen.dart';
import 'screens/runner_screen.dart';
import 'screens/analytics_screen.dart';

void main() {
  usePathUrlStrategy();
  runApp(const HseFormsApp());
}

class HseFormsApp extends StatefulWidget {
  const HseFormsApp({super.key});
  @override
  State<HseFormsApp> createState() => _HseFormsAppState();
}

class _HseFormsAppState extends State<HseFormsApp> {
  late final ApiClient client = ApiClient();
  late final AuthState auth = AuthState(client);

  // Делаем роутер late final и инициализируем его сразу
  late final GoRouter router;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();

    // 1. Инициализируем роутер МГНОВЕННО, чтобы Flutter Web зафиксировал URL в браузере
    router = GoRouter(
      refreshListenable: auth,
      redirect: (ctx, st) {
        // Если проверка авторизации еще не завершилась — никуда не редиректим, ждем
        if (!_bootstrapped) return null;

        final path = st.uri.path;
        final isPublic = path.startsWith('/s/');
        final atLogin = path == '/login';

        if (!auth.isAuthed && !isPublic && !atLogin) return '/login';
        if (auth.isAuthed && atLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/', builder: (_, __) => const SurveysListScreen()),
        GoRoute(
          path: '/builder/:id',
          builder: (_, s) =>
              BuilderScreen(surveyId: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/analytics/:id',
          builder: (_, s) =>
              AnalyticsScreen(surveyId: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/s/:slug',
          builder: (_, s) => RunnerScreen(slug: s.pathParameters['slug']!),
        ),
      ],
    );

    // 2. Запускаем асинхронную загрузку токена
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await auth.bootstrap();
    if (!mounted) return;
    setState(() {
      _bootstrapped = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Всегда возвращаем MaterialApp.router, чтобы не ломать веб-ссылки
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: client),
        ChangeNotifierProvider<AuthState>.value(value: auth),
      ],
      child: MaterialApp.router(
        title: 'HSE Forms',
        debugShowCheckedModeBanner: false,
        theme: buildHseTheme(),
        routerConfig: router,

        // Магия перехвата: пока идет bootstrap, этот билдер показывает лоадер.
        // При этом целевой экран (например, RunnerScreen) НЕ монтируется раньше времени,
        // что полностью предотвращает гонку запросов и ошибку 401.
        builder: (context, child) {
          if (!_bootstrapped) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return child!;
        },
      ),
    );
  }
}
