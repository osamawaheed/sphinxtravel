import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import './odoo/odoo_chat_config.dart';
import './odoo/odoo_chat_secure_session.dart';

/// Real unread-message counts for the Today-screen badges.
///
/// Source of truth: `chat_messages` where `read_at IS NULL`, the conversation
/// belongs to the tracked booking(s) and `sender_role` differs from the viewer
/// role (the user's own messages are never counted).
///
/// * ONE shared Realtime channel (`chat_unread_badges`) for the whole app
///   session - it only triggers a debounced re-count (no polling).
/// * A failed request keeps the last CONFIRMED count (never fakes zero) and a
///   retry is scheduled with back-off; foreground / navigation refreshes also
///   retry.
class ChatUnreadService {
  ChatUnreadService._();
  static final ChatUnreadService instance = ChatUnreadService._();

  /// Tracked scope per viewer role: booking references currently assigned.
  final Map<String, Set<String>> _refs = {};

  /// Booking id per tracked reference (needed for the booking-scoped secure
  /// session). Never shared between bookings.
  final Map<String, Map<String, int>> _bookingIds = {};

  /// Last confirmed count per viewer role ('customer' | 'driver').
  final Map<String, ValueNotifier<int>> _counts = {};

  final Map<String, bool> _inFlight = {};
  final Map<String, bool> _again = {};
  final Map<String, Timer?> _retry = {};
  final Map<String, int> _retryAttempt = {};

  RealtimeChannel? _channel;
  Timer? _debounce;

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Listenable count for [role] ('customer' or 'driver'). 0 => hide badge.
  ValueNotifier<int> countFor(String role) =>
      _counts.putIfAbsent(role, () => ValueNotifier<int>(0));

  /// Sets the booking references this viewer should count and refreshes.
  /// Customer: the displayed driver-pickup booking. Driver: currently
  /// assigned (non-completed) bookings only.
  void track({
    required String role,
    required Iterable<String> references,
    Map<String, int> bookingIds = const {},
  }) {
    final next = references
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final prev = _refs[role];
    final prevIds = _bookingIds[role];
    final nextIds = <String, int>{
      for (final e in bookingIds.entries)
        if (next.contains(e.key.trim()) && e.value > 0) e.key.trim(): e.value,
    };
    final changed =
        prev == null ||
        !setEquals(prev, next) ||
        !mapEquals(prevIds ?? const <String, int>{}, nextIds);
    _refs[role] = next;
    _bookingIds[role] = nextIds;
    _ensureChannel();
    if (changed) refresh(role);
  }

  /// Stops tracking [role] (sign-out / screen disposed). Keeps channel shared.
  void untrack(String role) {
    _refs.remove(role);
    _bookingIds.remove(role);
    _retry[role]?.cancel();
    _retry[role] = null;
    _retryAttempt[role] = 0;
    _counts[role]?.value = 0;
    if (_refs.isEmpty) {
      _debounce?.cancel();
      _channel?.unsubscribe();
      _channel = null;
    }
  }

  void _ensureChannel() {
    if (_channel != null) return;
    final client = _client;
    if (client == null) return;
    _channel = client
        .channel('chat_unread_badges')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => _scheduleRefreshAll(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => _scheduleRefreshAll(),
        )
        .subscribe((status, [error]) {
          // Events in between a drop and a reconnect are lost: re-count.
          if (status == RealtimeSubscribeStatus.subscribed) {
            _scheduleRefreshAll();
          }
        });
  }

  void _scheduleRefreshAll() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refreshAll);
  }

  /// Re-counts every tracked role (foreground, back to Today, realtime).
  void refreshAll() {
    for (final role in _refs.keys.toList()) {
      refresh(role);
    }
  }

  /// Re-counts [role] from the database. Safe to call repeatedly.
  Future<void> refresh(String role) async {
    if (_inFlight[role] == true) {
      _again[role] = true;
      return;
    }
    final refs = _refs[role];
    if (refs == null) return;
    final client = _client;
    if (client == null && !OdooChatConfig.isEnabled) return;
    _inFlight[role] = true;
    try {
      final n = OdooChatConfig.isEnabled
          ? await _countSecure(role, refs, _bookingIds[role] ?? const {})
          : await _count(client!, role, refs);
      countFor(role).value = n;
      _retry[role]?.cancel();
      _retry[role] = null;
      _retryAttempt[role] = 0;
    } catch (e) {
      // Preserve the last confirmed count; retry when connectivity returns.
      debugPrint('[chat-unread] count failed for $role (kept last): $e');
      _scheduleRetry(role);
    } finally {
      _inFlight[role] = false;
      if (_again[role] == true) {
        _again[role] = false;
        refresh(role);
      }
    }
  }

  /// JWT path: each booking is counted through ITS OWN secure client. A
  /// missing/expired/denied session throws (last confirmed count is kept);
  /// the anonymous client is never used for protected chat reads.
  Future<int> _countSecure(
    String role,
    Set<String> refs,
    Map<String, int> ids,
  ) async {
    if (refs.isEmpty) return 0;
    var total = 0;
    Object? firstError;
    for (final ref in refs) {
      final bookingId = ids[ref];
      if (bookingId == null || bookingId <= 0) {
        firstError ??= StateError('missing booking id for tracked reference');
        continue;
      }
      try {
        final session = await ChatSecureSession.open(bookingId);
        final convRows = await session.client
            .from('chat_conversations')
            .select('id')
            .eq('odoo_booking_id', bookingId)
            .eq('booking_reference', ref);
        final convIds = [for (final r in convRows) r['id'] as String];
        if (convIds.isEmpty) continue;
        final rows = await session.client
            .from('chat_messages')
            .select('id')
            .inFilter('conversation_id', convIds)
            .neq('sender_role', role)
            .isFilter('read_at', null);
        total += rows.length;
      } catch (e) {
        firstError ??= e;
      }
    }
    if (firstError != null) throw firstError;
    return total;
  }

  Future<int> _count(
    SupabaseClient client,
    String role,
    Set<String> refs,
  ) async {
    if (refs.isEmpty) return 0;
    // Only conversations of the currently tracked bookings. Conversations of
    // previous driver assignments / completed trips are not in [refs].
    final convRows = await client
        .from('chat_conversations')
        .select('id')
        .inFilter('booking_reference', refs.toList());
    final convIds = [for (final r in convRows) r['id'] as String];
    if (convIds.isEmpty) return 0;
    final rows = await client
        .from('chat_messages')
        .select('id')
        .inFilter('conversation_id', convIds)
        .neq('sender_role', role)
        .isFilter('read_at', null);
    return rows.length;
  }

  void _scheduleRetry(String role) {
    if (_refs[role] == null) return;
    if (_retry[role]?.isActive == true) return;
    final attempt = (_retryAttempt[role] ?? 0) + 1;
    _retryAttempt[role] = attempt;
    final secs = (attempt * 5).clamp(5, 60);
    _retry[role] = Timer(Duration(seconds: secs), () {
      _retry[role] = null;
      refresh(role);
    });
  }
}
