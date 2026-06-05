// lib/main.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'providers/creator_provider.dart';
import 'providers/filler_provider.dart';
import 'providers/survey_store.dart';
import 'screens/home_screen.dart';
import 'services/telegram_service.dart';
import 'utils/telegram_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      
      // Динамическая маршрутизация, которая умеет ждать загрузку данных
      onGenerateRoute: (settings) {
        final path = settings.name;
        
        return MaterialPageRoute(
          settings: settings,
          builder: (context) {
            // Слушаем состояние загрузки прямо внутри страницы, не ломая MaterialApp
            final currentStore = context.watch<SurveyStore>();
            
            // 1. Если база данных еще грузится — показываем крутилку, сохраняя путь в памяти
            if (!currentStore.loaded) {
              return const _SplashScreen();
            }
            
            // 2. База загрузилась! Теперь проверяем, куда шел пользователь
            if (path != null && path.startsWith('/s/')) {
              final slug = path.replaceFirst('/s/', '');
              return Scaffold(
                body: Center(
                  child: Text(
                    'БИНГО! Опрос: $slug', 
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }
            
            // 3. Если это не ссылка на опрос — отдаем обычный главный экран
            return const HomeScreen();
          },
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