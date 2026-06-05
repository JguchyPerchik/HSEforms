// lib/main.dart

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

  late final GoRouter router;
  bool _bootstrapped = false;

  @override
  void initState() {
    super.initState();

    router = GoRouter(
      refreshListenable: auth,
      redirect: (ctx, st) {
        final path = st.uri.path;
        final isPublic = path.startsWith('/s/');
        
        // ПРАВИЛО 1: Если это ссылка на опрос — пускаем всегда и без задержек!
        if (isPublic) return null;

        // Если это закрытая страница и проверка авторизации еще идет — ждем
        if (!_bootstrapped) return null;

        final atLogin = path == '/login';

        if (!auth.isAuthed && !atLogin) return '/login';
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

        // Умный билдер: лоадер показывается ТОЛЬКО для приватных страниц.
        // Публичные опросы рендерятся мгновенно, не ломая историю переходов браузера.
        builder: (context, child) {
          final currentPath = router.routerDelegate.currentConfiguration.uri.path;
          final isPublic = currentPath.startsWith('/s/');

          if (!_bootstrapped && !isPublic) {
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