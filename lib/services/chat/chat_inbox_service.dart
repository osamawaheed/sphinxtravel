import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/customer_bootstrap_model.dart';

/// A single driver-side inbox entry: exactly ONE per booking.
class ChatInboxItem {
  final int tripId;

  /// Human-readable booking reference (e.g. RQ.14596).
  final String bookingReference;
  final String customerName;
  final String tripTitle;

  /// Supabase conversation uuid, or null when no conversation row is visible
  /// to the current role for this booking.
  final String? conversationId;

  final String lastMessagePreview;
  final bool lastMessageIsVoice;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isCompleted;

  /// Customer Odoo id / profile photo from /driver/trips (empty when the API
  /// does not return them).
  final int customerId;
  final String customerPhotoUrl;

  const ChatInboxItem({
    required this.tripId,
    required this.bookingReference,
    required this.customerName,
    required this.tripTitle,
    required this.conversationId,
    required this.lastMessagePreview,
    required this.lastMessageIsVoice,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.isCompleted,
    this.customerId = 0,
    this.customerPhotoUrl = '',
  });

  bool get hasConversation => conversationId != null;
}

class ChatInboxResult {
  final List<ChatInboxItem> items;

  /// Exact backend problem (RLS / auth / network), if any. Null when OK.
  final String? backendError;
  const ChatInboxResult({required this.items, this.backendError});
}

/// Builds the Driver chat inbox.
///
/// * The list of bookings that belong to the driver comes from the existing
///   Odoo `/driver/trips` response (Odoo remains the source of truth for
///   assignments, customer names and trip dates).
/// * Conversations are matched by `chat_conversations.booking_reference` and
///   are NEVER created here (no duplicates, no invented `odoo_booking_id`).
/// * Reads go through the normal anon client, so RLS is respected. If RLS or
///   auth blocks the read, the exact error is returned in [backendError].
/// * `chat_messages` has no read-receipt column, so unread counts are tracked
///   per device using a "last seen" timestamp per conversation.
class ChatInboxService {
  ChatInboxService();

  static const String _seenPrefix = 'chat_inbox_last_seen_';

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Trip is completed from the calendar day after departure (Asia/Tbilisi).
  static bool isTripCompleted(DriverTripListItem trip) {
    final raw = trip.departureDate.trim();
    if (raw.isEmpty) return false;
    final m = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(raw);
    if (m == null) return false;
    final nowTbilisi = DateTime.now().toUtc().add(const Duration(hours: 4));
    final today = DateTime.utc(
      nowTbilisi.year,
      nowTbilisi.month,
      nowTbilisi.day,
    );
    final endDay = DateTime.utc(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    ).add(const Duration(days: 1));
    return !today.isBefore(endDay);
  }

  Future<Map<String, DateTime>> _loadSeen(List<String> conversationIds) async {
    final prefs = await SharedPreferences.getInstance();
    final out = <String, DateTime>{};
    for (final id in conversationIds) {
      final raw = prefs.getString('$_seenPrefix$id');
      final dt = raw == null ? null : DateTime.tryParse(raw);
      if (dt != null) out[id] = dt;
    }
    return out;
  }

  /// Marks a conversation as read on this device (call when it is opened).
  Future<void> markSeen(String conversationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_seenPrefix$conversationId',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  String _errorText(Object e) {
    if (e is PostgrestException) {
      final details = (e.details ?? '').toString();
      return '${e.code != null ? '[${e.code}] ' : ''}${e.message}'
          '${details.isNotEmpty ? ' — $details' : ''}';
    }
    return e.toString();
  }

  /// [viewerRole] filters unread to messages sent by the OTHER party.
  Future<ChatInboxResult> load({
    required List<DriverTripListItem> trips,
    String viewerRole = 'driver',
    int? viewerOdooId,
  }) async {
    // One entry per booking reference, even if Odoo returned duplicates.
    final byRef = <String, DriverTripListItem>{};
    for (final t in trips) {
      final ref = t.reference.trim();
      if (ref.isEmpty) continue;
      byRef.putIfAbsent(ref, () => t);
    }

    final client = _client;
    final convByRef = <String, Map<String, dynamic>>{};
    String? error;

    if (client == null) {
      error = 'Supabase is not initialized (SUPABASE_URL / SUPABASE_ANON_KEY).';
    } else if (byRef.isNotEmpty) {
      try {
        final rows = await client
            .from('chat_conversations')
            .select('id, odoo_booking_id, booking_reference, updated_at')
            .inFilter('booking_reference', byRef.keys.toList())
            .order('created_at', ascending: true);
        for (final r in rows) {
          final ref = (r['booking_reference'] as String?) ?? '';
          // Keep the oldest row if (unexpectedly) more than one is visible.
          convByRef.putIfAbsent(ref, () => Map<String, dynamic>.from(r));
        }
      } catch (e) {
        error = _errorText(e);
      }
    }

    // Latest messages per conversation (single query, newest first).
    final convIds = [for (final c in convByRef.values) c['id'] as String];
    final lastByConv = <String, Map<String, dynamic>>{};
    final unreadCandidates = <String, List<DateTime>>{};
    if (client != null && convIds.isNotEmpty && error == null) {
      try {
        final rows = await client
            .from('chat_messages')
            .select(
              'conversation_id, sender_role, message_type, original_text, created_at, read_at',
            )
            .inFilter('conversation_id', convIds)
            .order('created_at', ascending: false)
            .limit(1000);
        for (final raw in rows) {
          final r = Map<String, dynamic>.from(raw);
          final cid = r['conversation_id'] as String;
          lastByConv.putIfAbsent(cid, () => r);
          final at = DateTime.tryParse('${r['created_at']}');
          // Persisted source of truth: incoming (other role) + read_at NULL.
          if (at != null &&
              r['sender_role'] != viewerRole &&
              r['read_at'] == null) {
            unreadCandidates.putIfAbsent(cid, () => []).add(at);
          }
        }
      } catch (e) {
        error = _errorText(e);
      }
    }

    final items = <ChatInboxItem>[];
    // Conversations this user deleted: hidden until a message newer than the
    // deletion cut-off exists (a new incoming message makes it reappear).
    final hiddenAt = await _loadHiddenConversations(viewerRole, viewerOdooId);
    byRef.forEach((ref, trip) {
      final conv = convByRef[ref];
      final cid = conv?['id'] as String?;
      final last = cid == null ? null : lastByConv[cid];
      if (cid != null && hiddenAt.containsKey(cid)) {
        final cutoff = hiddenAt[cid]!;
        final lastCreated = last == null
            ? null
            : DateTime.tryParse('${last['created_at']}');
        if (lastCreated == null || !lastCreated.isAfter(cutoff)) return;
      }
      final isVoice = last?['message_type'] == 'voice';
      final lastAt = last == null
          ? null
          : DateTime.tryParse('${last['created_at']}')?.toLocal();
      items.add(
        ChatInboxItem(
          tripId: trip.id,
          bookingReference: ref,
          customerName: trip.customerName,
          tripTitle: [
            trip.city,
            trip.destination,
          ].where((e) => e.trim().isNotEmpty).join(', '),
          conversationId: cid,
          lastMessagePreview: isVoice
              ? ''
              : ((last?['original_text'] as String?) ?? '').trim(),
          lastMessageIsVoice: isVoice,
          lastMessageAt: lastAt,
          unreadCount: cid == null ? 0 : (unreadCandidates[cid]?.length ?? 0),
          isCompleted: isTripCompleted(trip),
          customerId: trip.customerId,
          customerPhotoUrl: trip.customerPhotoUrl,
        ),
      );
    });

    // Latest activity first; conversations without messages go last.
    items.sort((a, b) {
      final x = a.lastMessageAt;
      final y = b.lastMessageAt;
      if (x == null && y == null) {
        return a.bookingReference.compareTo(b.bookingReference);
      }
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });

    return ChatInboxResult(items: items, backendError: error);
  }

  Future<Map<String, DateTime>> _loadHiddenConversations(
    String viewerRole,
    int? viewerOdooId,
  ) async {
    final client = _client;
    if (client == null || viewerOdooId == null) return const {};
    try {
      final res = await client.rpc(
        'chat_get_hidden_conversations',
        params: {'p_actor_role': viewerRole, 'p_actor_odoo_id': viewerOdooId},
      );
      final out = <String, DateTime>{};
      if (res is List) {
        for (final r in res) {
          if (r is! Map) continue;
          final id = r['conversation_id'];
          final at = DateTime.tryParse('${r['hidden_at']}');
          if (id != null && at != null) out['$id'] = at;
        }
      }
      return out;
    } catch (_) {
      // Migration not applied yet: show everything (existing behaviour).
      return const {};
    }
  }

  /// Deletes a conversation for the current user only.
  Future<void> deleteConversationForMe({
    required String conversationId,
    required String viewerRole,
    required int viewerOdooId,
  }) async {
    final client = _client;
    if (client == null) {
      throw Exception('Supabase is not initialized.');
    }
    final ok = await client.rpc(
      'chat_delete_conversation_for_me',
      params: {
        'p_conversation_id': conversationId,
        'p_actor_role': viewerRole,
        'p_actor_odoo_id': viewerOdooId,
      },
    );
    if (ok != true) {
      throw Exception('The conversation could not be deleted.');
    }
  }

  /// Realtime: calls [onChange] whenever any visible message is inserted.
  /// RLS decides which rows the client actually receives.
  RealtimeChannel? subscribe(void Function() onChange) {
    final client = _client;
    if (client == null) return null;
    return client
        .channel('driver_chat_inbox')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => onChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
