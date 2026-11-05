import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/mock_api_data_source.dart';
import '../routes/app_routes.dart';
import './api_client.dart';
import './chat/chat_presence_service.dart';
import './chat/odoo/odoo_chat_token_manager.dart';
import './customer_language_sync_service.dart';
import './driver_review_notifications.dart';
import './driver_tracking_service.dart';
import './notification_service.dart';
import './token_manager.dart';

/// Handles secure sign-out for both Customer and Driver sessions.
///
/// Language and theme preferences are global settings and are preserved.
class SessionManager {
  SessionManager._();

  static bool _signingOut = false;

  /// True while a sign-out is in progress (blocks duplicate requests).
  static bool get isSigningOut => _signingOut;

  /// Signs the current user out.
  ///
  /// 1. Calls POST /api/v1/auth/logout (best effort, never blocks local cleanup).
  /// 2. Clears tokens, role and all user-specific in-memory state.
  /// 3. Refreshes the router's cached session so protected routes are locked.
  ///
  /// Returns the role that was signed out ('customer' / 'driver'), or
  /// [fallbackRole] when none was stored.
  static Future<String> signOut({required String fallbackRole}) async {
    if (_signingOut) return fallbackRole;
    _signingOut = true;
    String role = fallbackRole;
    try {
      final storedRole = await TokenManager.getUserRole();
      if (storedRole == 'driver' || storedRole == 'customer') {
        role = storedRole!;
      }
      final accessToken = await TokenManager.getAccessToken();
      final refreshToken = await TokenManager.getRefreshToken();

      // Best-effort backend logout. A dedicated Dio is used so a 401 here
      // cannot trigger the shared client's refresh / redirect logic.
      if (!MockApiDataSource.useMock &&
          accessToken != null &&
          accessToken.isNotEmpty) {
        try {
          final dio = Dio(
            BaseOptions(
              baseUrl: ApiClient.baseUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
                'Authorization': 'Bearer $accessToken',
              },
            ),
          );
          await dio.post(
            '/api/v1/auth/logout',
            data: {
              if (refreshToken != null && refreshToken.isNotEmpty)
                'refresh_token': refreshToken,
            },
          );
        } on DioException catch (e) {
          // Never log tokens — only the status / type.
          debugPrint(
            '[SESSION] Logout API failed (${e.response?.statusCode ?? e.type.name}); clearing local session.',
          );
        } catch (_) {
          debugPrint('[SESSION] Logout API failed; clearing local session.');
        }
      }
    } catch (_) {
      debugPrint(
        '[SESSION] Unexpected sign-out error; clearing local session.',
      );
    } finally {
      await _clearLocalSession();
      _signingOut = false;
    }
    return role;
  }

  /// Route of the role-specific login screen.
  static String loginRouteFor(String role) =>
      role == 'driver' ? AppRoutes.driverLogin : AppRoutes.customerLogin;

  static Future<void> _clearLocalSession() async {
    // Go offline immediately: the session no longer exists.
    ChatPresenceService.instance.stop();
    // Drop any in-memory Odoo chat JWTs (no-op while the feature flag is off).
    OdooChatTokenManager.instance.clearAll();
    try {
      await TokenManager.clearTokens();
    } catch (_) {}
    DriverReviewNotifications.reset();
    DriverLocationSharingService.instance.reset();
    CustomerLanguageSyncService.instance.reset();
    DriverLanguageSyncService.instance.reset();
    NotificationService.instance.reset();
    try {
      await AppRoutes.refreshSessionState();
    } catch (_) {}
  }
}
