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
  SupabaseNotificationSource({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();

  final ApiClient _api;

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
    final client = _ensureClient();
    final rows = await client
        .from('app_notifications')
        .select(
          'id, notification_type, category, params, booking_reference, '
          'booking_id, occurred_at, is_read',
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

  /// Marks notifications as read through the secure RPC
  /// `public.app_notifications_mark_read(p_ids uuid[])`. Uses the separate
  /// notifications-authenticated client (no service-role key, no direct
  /// table UPDATE). Splits into batches of at most 100 ids. Throws when any
  /// call fails so the caller never marks anything read locally.
  @override
  Future<void> markRead(List<String> ids) async {
    final unique = ids.where((e) => e.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return;
    // Make sure a valid token exists (and surface token failures as errors).
    await _token();
    final client = _ensureClient();
    for (var i = 0; i < unique.length; i += _rpcBatchSize) {
      final end = (i + _rpcBatchSize < unique.length)
          ? i + _rpcBatchSize
          : unique.length;
      final batch = unique.sublist(i, end);
      await client.rpc('app_notifications_mark_read', params: {'p_ids': batch});
    }
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
