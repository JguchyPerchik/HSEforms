// lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'providers/creator_provider.dart';
import 'providers/filler_provider.dart';
import 'providers/survey_store.dart';
import 'screens/home_screen.dart';
import 'services/telegram_service.dart';
import 'utils/telegram_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Убираем /#/ из ссылок в браузере
  usePathUrlStrategy();
  
  await TelegramService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SurveyStore()
            ..setTelegramTheme(
              TelegramService.instance.themeParams,
              isTelegram: TelegramService.instance.isTelegramContext,
            ),
        ),
        ChangeNotifierProvider(create: (_) => CreatorProvider()),
        ChangeNotifierProxyProvider<SurveyStore, FillerProvider>(
          create: (ctx) => FillerProvider(ctx.read<SurveyStore>()),
          update: (ctx, store, prev) => prev ?? FillerProvider(store),
        ),
      ],
      child: const _AppLoader(),
    ),
  );
}

// ── Loads persistence before showing UI ──────────────────────────────────────

class _AppLoader extends StatefulWidget {
  const _AppLoader();
  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  @override
  void initState() {
    super.initState();
    context.read<SurveyStore>().init();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SurveyStore>();
    final tgTheme = store.tgTheme;
    final themeData = _buildTheme(tgTheme);

    return MaterialApp(
      title: 'Forms',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      darkTheme: _buildTheme(TelegramThemeParams.dark),
      themeMode: tgTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      
      // 1. Говорим Flutter, что по умолчанию мы стартуем с корня
      initialRoute: '/',
      
      // 2. ПОЛНОСТЬЮ берем маршрутизацию под свой контроль
      onGenerateRoute: (settings) {
        final path = settings.name;
        
        // СЦЕНАРИЙ А: Кто-то пришел по ссылке на опрос
        if (path != null && path.startsWith('/s/')) {
          final slug = path.replaceFirst('/s/', '');
          
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Center(
                child: Text('Ура! Ссылка работает. Опрос: $slug', style: const TextStyle(fontSize: 24)),
              ),
            ),
          );
        }
        
        // СЦЕНАРИЙ Б: Обычный запуск сайта (открываем домашний экран)
        return MaterialPageRoute(
          builder: (context) => store.loaded ? const HomeScreen() : const _SplashScreen(),
        );
      },
    );
  }

  ThemeData _buildTheme(TelegramThemeParams tgTheme) {
    final base = tgTheme.toThemeData();
    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}