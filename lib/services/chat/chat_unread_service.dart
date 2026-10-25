import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  void track({required String role, required Iterable<String> references}) {
    final next = references
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final prev = _refs[role];
    final changed = prev == null || !setEquals(prev, next);
    _refs[role] = next;
    _ensureChannel();
    if (changed) refresh(role);
  }

  /// Stops tracking [role] (sign-out / screen disposed). Keeps channel shared.
  void untrack(String role) {
    _refs.remove(role);
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
    if (client == null) return;
    _inFlight[role] = true;
    try {
      final n = await _count(client, role, refs);
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
