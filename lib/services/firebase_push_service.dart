import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import './push_device_registration_service.dart';
import './token_manager.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint(
    '[FCM] Background message received: ${message.messageId ?? "no-id"}',
  );
}

/// Handles Firebase Cloud Messaging independently
/// from the notification inbox.
class FirebasePushService {
  FirebasePushService._();

  static final FirebasePushService instance = FirebasePushService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM] Firebase is not initialized; skipping push setup.');
      return;
    }

    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // Register background message handler.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages.
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        '[FCM] Foreground message received: '
        '${message.messageId ?? "no-id"}',
      );

      debugPrint('[FCM] Data: ${message.data}');
    });

    // Notification opened while app is in background.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
        '[FCM] Notification opened from background: '
        '${message.messageId ?? "no-id"}',
      );

      debugPrint('[FCM] Data: ${message.data}');
    });

    // Notification opened while app was terminated.
    final initialMessage = await messaging.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('[FCM] App opened from terminated state via notification.');

      debugPrint('[FCM] Data: ${initialMessage.data}');
    }

    // Request notification permissions.
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('[FCM] Permission: ${settings.authorizationStatus.name}');

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied.');
      return;
    }

    // Listen for FCM token changes.
    // This uses the legacy registration-token system because
    // our current Supabase backend stores FCM tokens.
    messaging.onTokenRefresh.listen(
      (newToken) async {
        debugPrint('[FCM] FCM token refreshed.');

        final hasSession = await TokenManager.hasValidSession();

        if (!hasSession) {
          debugPrint('[FCM] No authenticated session; token refresh deferred.');
          return;
        }

        await PushDeviceRegistrationService.instance.registerDevice(
          fcmToken: newToken,
        );
      },
      onError: (Object error) {
        debugPrint('[FCM] Token refresh error: ${error.runtimeType}');
      },
    );

    debugPrint('[FCM] Push service initialized successfully.');
  }
}
