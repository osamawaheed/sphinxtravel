import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification_model.dart';
import './api_client.dart';
import './notification_service.dart';
import './supabase_service.dart';

/// [NotificationSource] backed by public.app_notifications.
///
/// - Requests a short-lived notifications JWT from Odoo
///   (`POST /api/v1/notifications/token`) through [ApiClient], which already
///   handles the Odoo bearer token and refresh-on-401.
/// - Uses a SEPARATE [SupabaseClient] (anon key + `accessToken` callback).
///   The global Supabase client and the chat clients are never touched.
/// - RLS enforces user isolation; no user id is sent or hardcoded.
/// - Never logs or exposes the JWT.
/// - Reads use SELECT only; read state is changed solely through the secure
///   RPC `app_notifications_mark_read` (no direct UPDATE, no service role).
class SupabaseNotificationSource implements NotificationSource {
  SupabaseNotificationSource({
    ApiClient? apiClient,
    this.useLocalizedRpc = false,
  }) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  /// When true (customer only), notifications are loaded through the RPC
  /// `app_notifications_localized`, which also returns server-rendered
  /// `title` and `body`. On any failure the direct SELECT is used instead.
  /// Defaults to false so driver behavior is unchanged.
  final bool useLocalizedRpc;

  SupabaseClient? _client;
  String? _jwt;
  DateTime? _jwtExpiresAt;
  Future<String>? _inFlight;

  /// Refresh the JWT this long before it expires.
  static const Duration _skew = Duration(seconds: 60);
  static const int _defaultTtlSeconds = 300;
  static const int _limit = 200;

  /// Maximum number of ids accepted by app_notifications_mark_read per call.
  static const int _rpcBatchSize = 100;

  @override
  bool get isLocalDemo => false;

  @override
  bool get supportsMarkRead => true;

  bool get _jwtValid {
    final t = _jwt;
    final exp = _jwtExpiresAt;
    return t != null && exp != null && DateTime.now().isBefore(exp);
  }

  Future<String> _token({bool force = false}) {
    if (!force && _jwtValid) return Future.value(_jwt!);
    return _inFlight ??= _requestToken().whenComplete(() => _inFlight = null);
  }

  Future<String> _requestToken() async {
    final response = await _api.post(
      '/api/v1/notifications/token',
      data: <String, dynamic>{},
    );
    final data = response.data;
    final map = data is Map ? data : const {};
    final payload = map['data'] is Map ? map['data'] as Map : map;
    final token = payload['access_token'];
    if (token is! String || token.isEmpty) {
      throw StateError('Notifications token not issued.');
    }
    final exp = payload['expires_in'];
    final seconds =
        (exp is num ? exp.toInt() : int.tryParse('${exp ?? ''}')) ??
        _defaultTtlSeconds;
    final ttl = Duration(seconds: seconds) - _skew;
    _jwt = token;
    _jwtExpiresAt = DateTime.now().add(
      ttl.isNegative ? const Duration(seconds: 1) : ttl,
    );
    return token;
  }

  SupabaseClient _ensureClient() {
    return _client ??= SupabaseClient(
      SupabaseService.supabaseUrl,
      SupabaseService.supabaseAnonKey,
      accessToken: () async => _token(),
    );
  }

  @override
  Future<List<AppNotification>> fetch() async {
    // Make sure a valid token exists (and surface token failures as errors).
    await _token();
    final bookings = await _fetchBookingNotifications();
    // Campaigns are fetched independently; any failure yields an empty list
    // and never affects booking notifications.
    final campaigns = await _fetchCampaignNotifications();
    if (campaigns.isEmpty) return bookings;
    final merged = <AppNotification>[...bookings, ...campaigns]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  /// Loads campaign notifications through
  /// `public.notification_campaigns_my_inbox()` using the notification-specific
  /// client. Draft/cancelled campaigns are filtered by the server. Returns an
  /// empty list on any failure.
  Future<List<AppNotification>> _fetchCampaignNotifications() async {
    try {
      final client = _ensureClient();
      final rows = await client.rpc('notification_campaigns_my_inbox');
      final result = <AppNotification>[];
      if (rows is List) {
        for (final row in rows) {
          final n = AppNotification.fromCampaignRow(row);
          if (n != null) result.add(n);
        }
      }
      return result;
    } catch (_) {
      debugPrint('[NOTIFICATIONS] Failed to load campaign notifications.');
      return const [];
    }
  }

  Future<List<AppNotification>> _fetchBookingNotifications() async {
    final client = _ensureClient();

    if (useLocalizedRpc) {
      try {
        final localized = await client.rpc(
          'app_notifications_localized',
          params: {'p_limit': _limit},
        );
        if (localized is List) {
          final parsed = <AppNotification>[];
          for (final row in localized) {
            final n = AppNotification.fromSupabaseRow(row);
            if (n != null) parsed.add(n);
          }
          // An empty/unparseable result is not trusted; fall back below.
          if (parsed.isNotEmpty) {
            parsed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            return parsed;
          }
        }
      } catch (_) {
        // RPC unavailable or failed: fall back to the direct SELECT.
      }
    }

    final rows = await client
        .from('app_notifications')
        .select(
          'id, notification_type, category, params, booking_reference, '
          'booking_id, trip_id, occurred_at, is_read',
        )
        .order('occurred_at', ascending: false)
        .limit(_limit);

    final result = <AppNotification>[];
    for (final row in rows as List) {
      final n = AppNotification.fromSupabaseRow(row);
      if (n != null) result.add(n);
    }
    return result;
  }

  /// Marks notifications as read. Booking uuids go to the secure RPC
  /// `public.app_notifications_mark_read(p_ids uuid[])`; prefixed campaign ids
  /// are stripped, validated and sent to
  /// `public.notification_campaigns_mark_read(p_ids uuid[])`. Uses the
  /// separate notifications-authenticated client (no service-role key, no
  /// direct table UPDATE). Splits into batches of at most 100 ids. Throws when
  /// any call fails so the caller never marks anything read locally.
  @override
  Future<void> markRead(List<String> ids) async {
    final bookingIds = <String>{};
    final campaignIds = <String>{};
    for (final raw in ids) {
      if (raw.isEmpty) continue;
      if (raw.startsWith(AppNotification.campaignIdPrefix)) {
        final uuid = AppNotification.campaignUuidFromId(raw);
        if (uuid != null) campaignIds.add(uuid);
        continue;
      }
      // Only plain, valid booking uuids may reach the booking RPC.
      if (AppNotification.isUuid(raw)) bookingIds.add(raw);
    }
    if (bookingIds.isEmpty && campaignIds.isEmpty) return;
    // Make sure a valid token exists (and surface token failures as errors).
    await _token();
    final client = _ensureClient();
    await _markBatches(client, 'app_notifications_mark_read', bookingIds);
    await _markBatches(client, 'notification_campaigns_mark_read', campaignIds);
  }

  Future<void> _markBatches(
    SupabaseClient client,
    String rpc,
    Set<String> idSet,
  ) async {
    final unique = idSet.toList();
    for (var i = 0; i < unique.length; i += _rpcBatchSize) {
      final end = (i + _rpcBatchSize < unique.length)
          ? i + _rpcBatchSize
          : unique.length;
      final batch = unique.sublist(i, end);
      await client.rpc(rpc, params: {'p_ids': batch});
    }
  }

  /// Saves the user's language in Supabase through
  /// `public.app_user_preferences_set(p_language text)`.
  ///
  /// Uses ONLY the notification-specific client authenticated with the
  /// Odoo-issued notifications JWT (never the global anonymous client). No
  /// user id or role is sent; Supabase derives identity from the JWT.
  /// Throws on any network/auth failure so the caller can retry later.
  Future<void> setLanguagePreference(String language) async {
    // Make sure a valid token exists (and surface token failures as errors).
    await _token();
    final client = _ensureClient();
    await client.rpc(
      'app_user_preferences_set',
      params: {'p_language': language},
    );
  }

  /// Drops the cached JWT and disposes the separate client.
  @override
  Future<void> dispose() async {
    _jwt = null;
    _jwtExpiresAt = null;
    _inFlight = null;
    final c = _client;
    _client = null;
    try {
      await c?.dispose();
    } catch (e) {
      debugPrint('[NOTIFICATIONS] Client dispose failed.');
    }
  }
}
