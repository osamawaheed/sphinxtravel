import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import './l10n/app_localizations.dart';
import './routes/app_routes.dart';
import './services/localization_service.dart';
import './services/theme_service.dart';
import './theme/app_theme.dart';
import './widgets/custom_error_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;
      Future.delayed(const Duration(seconds: 5), () {
        hasShownError = false;
      });
      return CustomErrorWidget(errorDetails: details);
    }
    return const SizedBox.shrink();
  };

  // 🚨 CRITICAL: Device orientation lock - DO NOT REMOVE
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // Initialize LocalizationService (loads persisted language)
  await LocalizationService.create();

  // Initialize ThemeService (loads persisted theme)
  await ThemeService.create();

  // Pre-load session state so GoRouter redirect is synchronous (prevents blank screen)
  await AppRoutes.preloadSessionState();

  runApp(const SphinxTravelApp());
}

class SphinxTravelApp extends StatefulWidget {
  const SphinxTravelApp({super.key});

  @override
  State<SphinxTravelApp> createState() => _SphinxTravelAppState();
}

class _SphinxTravelAppState extends State<SphinxTravelApp> {
  final LocalizationService _localizationService = LocalizationService.instance;
  final ThemeService _themeService = ThemeService.instance;

  @override
  void initState() {
    super.initState();
    _localizationService.addListener(_onChanged);
    _themeService.addListener(_onChanged);
  }

  @override
  void dispose() {
    _localizationService.removeListener(_onChanged);
    _themeService.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final locale = _localizationService.locale;
    final isArabic = locale.languageCode == 'ar';
    return SphinxLocalizationProvider(
      service: _localizationService,
      child: Sizer(
        builder: (context, orientation, screenType) {
          return MaterialApp.router(
            title: 'Travel Operations',
            theme: isArabic
                ? AppTheme.lightThemeForLocale(locale)
                : AppTheme.lightTheme,
            darkTheme: isArabic
                ? AppTheme.darkThemeForLocale(locale)
                : AppTheme.darkTheme,
            themeMode: _themeService.flutterThemeMode,
            locale: locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('ar', 'AE'),
              Locale('ru', 'RU'),
              Locale('ka', 'GE'),
            ],
            // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.0)),
                child: Directionality(
                  textDirection: isArabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: child!,
                ),
              );
            },
            // 🚨 END CRITICAL SECTION
            debugShowCheckedModeBanner: false,
            routerConfig: appRouter,
          );
        },
      ),
    );
  }
}
