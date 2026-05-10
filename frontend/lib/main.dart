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
  late final GoRouter router;

  @override
  void initState() {
    super.initState();
    auth.bootstrap();
    router = GoRouter(
      refreshListenable: auth,
      redirect: (ctx, st) {
        if (!auth.ready) return null;
        final isPublic = st.matchedLocation.startsWith('/s/');
        final atLogin = st.matchedLocation == '/login';
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
      ),
    );
  }
}
