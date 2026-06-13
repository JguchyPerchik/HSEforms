// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'theme.dart';
import 'api/api_client.dart';
import 'state/auth_state.dart';
import 'state/telegram_theme.dart';
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

  // 1. Делаем роутер non-nullable и инициализируем его мгновенно
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

        // Если пользователь идет на публичный опрос — пускаем ВСЕГДА и без задержек
        if (isPublic) return null;

        // Если проверка токена админа еще идет, а страница приватная — ждем bootstrap
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
          // ValueKey по id критичен для переключения между вариантами опроса.
          // Без ключа Flutter видит, что GoRouter возвращает BuilderScreen
          // того же типа, и переиспользует существующий Element — initState
          // не вызывается, _load() не дёргается, состояние остаётся от
          // прошлого варианта (старый survey, старый _parent, старый
          // currentSurveyId). Симптомы: подсветка «открыт» висит на прежней
          // строке, удалённые варианты не исчезают из списка, поля заголовка/
          // описания не перезаполняются. С ValueKey каждый id — новый виджет,
          // state дисается и пересоздаётся.
          builder: (_, s) {
            final id = int.parse(s.pathParameters['id']!);
            return BuilderScreen(key: ValueKey('builder-$id'), surveyId: id);
          },
        ),
        GoRoute(
          path: '/analytics/:id',
          // Та же история: экран аналитики тоже имеет :id-параметр и тоже
          // не перезагружается при переходе между опросами без ключа.
          builder: (_, s) {
            final id = int.parse(s.pathParameters['id']!);
            return AnalyticsScreen(key: ValueKey('analytics-$id'), surveyId: id);
          },
        ),
        GoRoute(
          path: '/s/:slug',
          builder: (_, s) => RunnerScreen(
            slug: s.pathParameters['slug']!,
            isCreatorPreview: s.uri.queryParameters['preview'] == 'true',
          ),
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
      // Подписываемся на TelegramTheme: когда внутри Mini App пользователь
      // переключит тёмную/светлую тему клиента — Telegram стрельнёт
      // событием themeChanged, наш JS-listener в index.html обновит
      // window.tgThemeParams и dispatchEvent'нет 'tg-theme-changed',
      // TelegramTheme.instance это получит и вызовет notifyListeners() —
      // что заставит ListenableBuilder перестроить весь MaterialApp с
      // новой темой. Снаружи Telegram объект тоже создаётся, но
      // available=false, и buildHseTheme(tg) откатывается на HSE-палитру.
      child: ListenableBuilder(
        listenable: TelegramTheme.instance,
        builder: (context, _) => MaterialApp.router(
        title: 'HSE Forms',
        debugShowCheckedModeBanner: false,
        theme: buildHseTheme(TelegramTheme.instance),
        routerConfig: router,
        
        // 2. Вместо подмены MaterialApp используем билдер. 
        // Он показывает лоадер поверх страниц, сохраняя целостность роутера.
        builder: (context, child) {
          final currentPath = router.routerDelegate.currentConfiguration.uri.path;
          final isPublic = currentPath.startsWith('/s/');

          // Показываем крутилку, только если мы еще не загрузились И страница ПРИВАТНАЯ.
          // Публичные опросы рендерятся мгновенно.
          if (!_bootstrapped && !isPublic) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return child!;
        },
      ),
      ),  // close ListenableBuilder
    );
  }
}