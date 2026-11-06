import 'dart:async';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './api_client.dart';
import './supabase_service.dart';

/// Registers the current app installation for Firebase push notifications.
///
/// Authentication:
/// 1. Uses the existing Odoo access token through ApiClient.
/// 2. Requests a short-lived Notifications JWT from Odoo.
/// 3. Sends the Firebase Installation ID (FID) to Supabase.
/// 4. Supabase derives the recipient identity from the verified JWT.
class PushDeviceRegistrationService {
  PushDeviceRegistrationService._();

  static final PushDeviceRegistrationService instance =
      PushDeviceRegistrationService._();

  static const String _deviceIdKey = 'sphinx_push_device_id';

  final ApiClient _apiClient = ApiClient();

  bool _registering = false;

  String? _firebaseInstallationId;

  StreamSubscription<String>? _registrationSubscription;

  /// Register the current device after successful customer/driver login.
  Future<bool> registerAfterLogin() async {
    return registerDevice();
  }

  /// Register or update the current Firebase installation.
  ///
  /// [fcmToken] is retained for compatibility with existing callers.
  /// With Firebase Messaging 17, the value is a Firebase Installation ID.
  Future<bool> registerDevice({String? fcmToken}) async {
    if (_registering) {
      debugPrint('[PUSH] Registration already in progress.');
      return false;
    }

    _registering = true;

    String stage = 'initialization';

    try {
      // 1. Detect platform.
      stage = 'platform_detection';

      final platform = _getPlatform();

      if (platform == null) {
        debugPrint('[PUSH] Unsupported platform; registration skipped.');
        return false;
      }

      debugPrint('[PUSH] Platform: $platform');

      // 2. Register with Firebase and obtain the installation ID.
      stage = 'firebase_registration';

      String? installationId = fcmToken;

      if (installationId == null || installationId.trim().isEmpty) {
        installationId = await _getFirebaseInstallationId();
      }

      if (installationId == null || installationId.trim().isEmpty) {
        debugPrint('[PUSH] Firebase Installation ID is unavailable.');
        return false;
      }

      debugPrint('[PUSH] Firebase Installation ID received.');

      // 3. Get persistent device ID.
      stage = 'device_id';

      final deviceId = await _getOrCreateDeviceId();

      // 4. Request notification JWT from Odoo.
      stage = 'odoo_notification_jwt';

      debugPrint('[PUSH] Requesting notification JWT from Odoo...');

      final jwtResponse = await _apiClient.post(
        '/api/v1/notifications/token',
        data: <String, dynamic>{},
      );

      final responseData = jwtResponse.data;

      if (responseData is! Map) {
        debugPrint('[PUSH] Invalid Odoo notification response.');
        return false;
      }

      final notificationJwt = responseData['access_token']?.toString() ?? '';

      if (notificationJwt.isEmpty) {
        debugPrint('[PUSH] Odoo notification JWT is missing.');
        return false;
      }

      debugPrint('[PUSH] Odoo notification JWT received.');

      // 5. Register device in Supabase.
      stage = 'supabase_registration';

      debugPrint('[PUSH] Registering device in Supabase...');

      final result = await SupabaseService.instance.client.functions.invoke(
        'chat-push-device',
        headers: {'Authorization': 'Bearer $notificationJwt'},
        body: {
          'device_id': deviceId,
          'platform': platform,
          'token': installationId.trim(),
        },
      );

      if (result.status != 200) {
        debugPrint(
          '[PUSH] Supabase registration failed: HTTP ${result.status}',
        );
        debugPrint('[PUSH] Response: ${result.data}');
        return false;
      }

      debugPrint('[PUSH] Device registration successful.');

      return true;
    } catch (e, stackTrace) {
      debugPrint('========================================');
      debugPrint('[PUSH] DEVICE REGISTRATION FAILED');
      debugPrint('[PUSH] Stage: $stage');
      debugPrint('[PUSH] Error: $e');
      debugPrint('[PUSH] Error type: ${e.runtimeType}');
      debugPrint('[PUSH] StackTrace: $stackTrace');
      debugPrint('========================================');

      // Push registration must never prevent normal app authentication.
      return false;
    } finally {
      _registering = false;
    }
  }

  /// Registers with Firebase Messaging 17 and waits for the FID.
  Future<String?> _getFirebaseInstallationId() async {
    if (_firebaseInstallationId != null &&
        _firebaseInstallationId!.isNotEmpty) {
      return _firebaseInstallationId;
    }

    debugPrint('[PUSH] Registering Firebase installation...');

    final messaging = FirebaseMessaging.instance;

    final completer = Completer<String>();

    // Listen before calling register() so we do not miss the event.
    _registrationSubscription ??= messaging.onRegistered.listen(
      (installationId) {
        if (installationId.trim().isEmpty) return;

        _firebaseInstallationId = installationId.trim();

        debugPrint('[PUSH] Firebase installation registered.');

        if (!completer.isCompleted) {
          completer.complete(_firebaseInstallationId!);
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    await messaging.register();

    if (_firebaseInstallationId != null &&
        _firebaseInstallationId!.isNotEmpty) {
      return _firebaseInstallationId;
    }

    try {
      return await completer.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      debugPrint('[PUSH] Timed out waiting for Firebase registration.');
      return null;
    }
  }

  /// Returns the current installation ID or creates a persistent one.
  Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    final existing = prefs.getString(_deviceIdKey);

    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();

    final deviceId = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    await prefs.setString(_deviceIdKey, deviceId);

    return deviceId;
  }

  /// Maps Flutter platforms to the database-supported values.
  String? _getPlatform() {
    if (kIsWeb) return null;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';

      case TargetPlatform.iOS:
        return 'ios';

      default:
        return null;
    }
  }
}
