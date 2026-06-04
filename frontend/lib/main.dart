import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'theme.dart';
import 'api/api_client.dart';
import 'state/auth_state.dart';
import 'screens/login_screen.dart';
import 'screens/surveys_list_screen.dart';
import 'screens/builder_screen.dart';
import 'screens/runner_screen.dart';
import 'screens/analytics_screen.dart';

void main() {
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
  GoRouter? router;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Resolve auth BEFORE building the router. Otherwise on hard refresh the
    // protected screen would mount, fire its first API request, and race the
    // token load — yielding a spurious 401. Waiting here is a few hundred
    // milliseconds of "Loading…" instead.
    await auth.bootstrap();
    if (!mounted) return;
    setState(() {
      router = GoRouter(
        refreshListenable: auth,
        redirect: (ctx, st) {
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
            builder: (_, s) => BuilderScreen(surveyId: int.parse(s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/analytics/:id',
            builder: (_, s) => AnalyticsScreen(surveyId: int.parse(s.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/s/:slug',
            builder: (_, s) => RunnerScreen(slug: s.pathParameters['slug']!),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = router;
    if (r == null) {
      // Splash while bootstrap is resolving the auth token. Themed minimally
      // so it doesn't depend on providers that aren't installed yet.
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildHseTheme(),
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: client),
        ChangeNotifierProvider<AuthState>.value(value: auth),
      ],
      child: MaterialApp.router(
        title: 'HSE Forms',
        debugShowCheckedModeBanner: false,
        theme: buildHseTheme(),
        routerConfig: r,
      ),
    );
  }
}
