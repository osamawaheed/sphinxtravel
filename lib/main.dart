import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

import './l10n/app_localizations.dart';
import './routes/app_routes.dart';
import './services/localization_service.dart';
import './services/supabase_service.dart';
import './services/firebase_push_service.dart';
import './services/push_device_registration_service.dart';
import './services/theme_service.dart';
import './services/chat/chat_presence_service.dart';
import './theme/app_theme.dart';
import './widgets/custom_error_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool firebaseReady = false;

  // Initialize Firebase without blocking app startup on failure.
  try {
    await Firebase.initializeApp();
    firebaseReady = true;

    debugPrint('[MAIN] Firebase initialized successfully');

    FirebasePushService.instance.initialize().catchError((Object e) {
      debugPrint('[FCM] Push setup failed: ${e.runtimeType}');
    });
  } catch (e) {
    debugPrint('[MAIN] Firebase initialization failed: ${e.runtimeType}');
  }

  // Initialize Supabase.
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize Supabase: ${e.runtimeType}');
  }

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
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (e) {
    debugPrint('[MAIN] orientation lock failed: $e');
  }

  GoRouter.optionURLReflectsImperativeAPIs = true;

  // Initialize services.
  // A failure must never prevent runApp.
  try {
    await LocalizationService.create();
  } catch (e) {
    debugPrint('[MAIN] LocalizationService init failed: $e');
  }

  try {
    await ThemeService.create();
  } catch (e) {
    debugPrint('[MAIN] ThemeService init failed: $e');
  }

  // Pre-load session state so GoRouter redirect is synchronous.
  try {
    await AppRoutes.preloadSessionState();
  } catch (e) {
    debugPrint('[MAIN] Session preload failed: $e');
  }

  runApp(SphinxTravelApp(firebaseReady: firebaseReady));
}

class SphinxTravelApp extends StatefulWidget {
  const SphinxTravelApp({super.key, this.firebaseReady = false});

  final bool firebaseReady;

  @override
  State<SphinxTravelApp> createState() => _SphinxTravelAppState();
}

class _SphinxTravelAppState extends State<SphinxTravelApp>
    with WidgetsBindingObserver {
  final LocalizationService _localizationService = LocalizationService.instance;

  final ThemeService _themeService = ThemeService.instance;

  bool _pushRegistrationStarted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _localizationService.addListener(_onChanged);
    _themeService.addListener(_onChanged);

    // Wait until the first frame has been rendered.
    // This avoids interfering with startup navigation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _registerPushDeviceOnStartup();
    });
  }

  /// Attempts to register the device when the application starts.
  ///
  /// Existing login flows still handle registration after a fresh login.
  /// Registration failures must not interrupt the application.
  Future<void> _registerPushDeviceOnStartup() async {
    if (!widget.firebaseReady) {
      debugPrint('[PUSH] Startup registration skipped: Firebase unavailable.');
      return;
    }

    if (_pushRegistrationStarted) return;

    _pushRegistrationStarted = true;

    try {
      debugPrint('[PUSH] Checking startup device registration...');

      final success = await PushDeviceRegistrationService.instance
          .registerDevice();

      if (success) {
        debugPrint('[PUSH] Startup registration completed.');
      } else {
        debugPrint(
          '[PUSH] Startup registration not completed. '
          'Will retry after login.',
        );
      }
    } catch (e) {
      debugPrint('[PUSH] Startup registration error: ${e.runtimeType}');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    ChatPresenceService.instance.onBackgrounded(force: true);

    _localizationService.removeListener(_onChanged);
    _themeService.removeListener(_onChanged);

    super.dispose();
  }

  /// App-level presence lifecycle:
  /// foreground => online; background / detached => offline.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        ChatPresenceService.instance.onResumed();
        break;

      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        ChatPresenceService.instance.onBackgrounded();
        break;

      case AppLifecycleState.detached:
        ChatPresenceService.instance.onBackgrounded(force: true);
        break;

      case AppLifecycleState.inactive:
        break;
    }
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
            title: 'TourOps',
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
              Locale('az', 'AZ'),
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
