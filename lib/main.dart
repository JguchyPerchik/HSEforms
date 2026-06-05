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
    // 1. ИСПОЛЬЗУЕМ SELECT! Слушаем только смену темы.
    // Теперь при изменении store.loaded сам MaterialApp НЕ будет перерисовываться!
    final tgTheme = context.select<SurveyStore, TelegramThemeParams>((s) => s.tgTheme);
    final themeData = _buildTheme(tgTheme);

    return MaterialApp(
      title: 'Forms',
      debugShowCheckedModeBanner: false,
      theme: themeData,
      darkTheme: _buildTheme(TelegramThemeParams.dark),
      themeMode: tgTheme.isDark ? ThemeMode.dark : ThemeMode.light,
      
      // 2. Навигатор спокойно съедает URL /s/... и строит нужный экран
      onGenerateRoute: (settings) {
        final path = settings.name;
        
        if (path != null && path.startsWith('/s/')) {
          final slug = path.replaceFirst('/s/', '');
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => Scaffold(
              body: Center(
                child: Text(
                  'БИНГО! Опрос: $slug', 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        }
        
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const HomeScreen(),
        );
      },

      // 3. МАГИЯ ЗДЕСЬ: перехватываем отрисовку всего, что под навигатором.
      // Navigator уже зафиксировал URL в браузере, мы просто вешаем шторку-лоадер.
      builder: (context, child) {
        final isLoaded = context.select<SurveyStore, bool>((s) => s.loaded);
        
        if (!isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return child!;
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