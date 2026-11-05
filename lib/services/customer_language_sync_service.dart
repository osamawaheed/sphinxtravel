import 'package:flutter/foundation.dart';

import './localization_service.dart';
import './notification_service.dart';
import './supabase_notification_source.dart';

/// Keeps the CUSTOMER's saved language in Supabase
/// (`app_user_preferences_set`) so server-rendered notifications use it.
///
/// - Customer only: DRIVER languages are never synchronized here.
/// - Goes through the notification-specific Supabase client (Odoo-issued
///   notifications JWT) via [SupabaseNotificationSource]; the global
///   anonymous client is never used.
/// - Remembers the last successfully synced language so repeated calls with
///   the same language make no network request.
/// - Never throws: on failure the local language is untouched and the next
///   call (app start or language change) retries.
class CustomerLanguageSyncService {
  CustomerLanguageSyncService._();

  static final CustomerLanguageSyncService instance =
      CustomerLanguageSyncService._();

  static const Set<String> _supported = {'ar', 'en'};

  /// Last language confirmed saved in Supabase for the current account.
  String? _lastSynced;

  /// Language currently being sent (blocks duplicate in-flight calls).
  String? _inFlightLanguage;

  /// Set when the language changed while a request was running.
  bool _rerun = false;

  /// Synchronizes the customer's current language. Safe to call repeatedly.
  Future<void> sync() async {
    final locService = LocalizationService.instance;
    // Never sync driver language preferences.
    if (locService.userRole != 'customer') return;

    final language = locService.currentLanguage;
    if (!_supported.contains(language)) return;
    if (_lastSynced == language) return;

    if (_inFlightLanguage != null) {
      if (_inFlightLanguage != language) _rerun = true;
      return;
    }

    final source = NotificationService.instance.source;
    if (source is! SupabaseNotificationSource) return;

    _inFlightLanguage = language;
    var succeeded = false;
    try {
      await source.setLanguagePreference(language);
      succeeded = true;
      _lastSynced = language;
    } catch (_) {
      debugPrint('[LANG_SYNC] Language sync failed; will retry later.');
    } finally {
      _inFlightLanguage = null;
    }

    // Only act if this account/source is still the active one.
    if (!identical(NotificationService.instance.source, source)) return;

    if (_rerun) {
      _rerun = false;
      await sync();
      return;
    }

    if (succeeded) {
      // Re-render server-side titles/bodies in the newly selected language.
      await _refreshNotifications();
    }
  }

  /// refresh() is a no-op while a load is running (that load may have been
  /// rendered in the previous language), so wait briefly for it to finish.
  Future<void> _refreshNotifications() async {
    final service = NotificationService.instance;
    for (var i = 0; i < 20 && service.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await service.refresh();
  }

  /// Forgets the synced state (sign-out / account switch).
  void reset() {
    _lastSynced = null;
    _inFlightLanguage = null;
    _rerun = false;
  }
}

/// Keeps the DRIVER's saved language in Supabase
/// (`app_user_preferences_set`) so server-rendered notifications use it.
///
/// Mirrors [CustomerLanguageSyncService] with independent state. Driver
/// languages: en, ru, ka, az. Customer sync is never touched by this class.
class DriverLanguageSyncService {
  DriverLanguageSyncService._();

  static final DriverLanguageSyncService instance =
      DriverLanguageSyncService._();

  static const Set<String> _supported = {'en', 'ru', 'ka', 'az'};

  /// Last language confirmed saved in Supabase for the current account.
  String? _lastSynced;

  /// Language currently being sent (blocks duplicate in-flight calls).
  String? _inFlightLanguage;

  /// Set when the language changed while a request was running.
  bool _rerun = false;

  /// Synchronizes the driver's current language. Safe to call repeatedly.
  Future<void> sync() async {
    final locService = LocalizationService.instance;
    // Drivers only; customer language is handled by its own service.
    if (locService.userRole != 'driver') return;

    final language = locService.currentLanguage;
    if (!_supported.contains(language)) return;
    if (_lastSynced == language) return;

    if (_inFlightLanguage != null) {
      if (_inFlightLanguage != language) _rerun = true;
      return;
    }

    final source = NotificationService.instance.source;
    if (source is! SupabaseNotificationSource) return;

    _inFlightLanguage = language;
    var succeeded = false;
    try {
      await source.setLanguagePreference(language);
      succeeded = true;
      _lastSynced = language;
    } catch (_) {
      debugPrint('[LANG_SYNC] Driver language sync failed; will retry later.');
    } finally {
      _inFlightLanguage = null;
    }

    // Only act if this account/source is still the active one.
    if (!identical(NotificationService.instance.source, source)) return;

    if (_rerun) {
      _rerun = false;
      await sync();
      return;
    }

    if (succeeded) {
      // Re-render server-side titles/bodies in the newly selected language.
      await _refreshNotifications();
    }
  }

  /// refresh() is a no-op while a load is running (that load may have been
  /// rendered in the previous language), so wait briefly for it to finish.
  Future<void> _refreshNotifications() async {
    final service = NotificationService.instance;
    for (var i = 0; i < 20 && service.isLoading; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await service.refresh();
  }

  /// Forgets the synced state (sign-out / account switch).
  void reset() {
    _lastSynced = null;
    _inFlightLanguage = null;
    _rerun = false;
  }
}
