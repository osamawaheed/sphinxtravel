import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// App/session-level online presence using Supabase Realtime Presence.
///
/// * ONE shared channel (`tourops_presence`) for the whole app session.
/// * The signed-in user is tracked under a unique key `<role>:<userId>`
///   (e.g. `customer:123`, `driver:45`), so accounts/roles never collide and
///   re-tracking after a reconnect REPLACES the entry (no duplicates).
/// * Booking identity is consistent on both sides: every user publishes the
///   numeric Odoo booking ids AND the normalized references of their bookings.
///   A booking matches when EITHER the numeric id OR the normalized reference
///   is shared (`RQ.13509`, `rq 13509` and `13509` all normalize to `13509`).
/// * Presence follows the app lifecycle. On Flutter Web an unfocused / hidden
///   tab is NOT offline (the page is still connected); only a real
///   disconnect (heartbeat timeout / page close) or sign-out is offline.
///   On mobile, background / detached => offline.
/// * Opening or closing the chat screen never changes presence.
class ChatPresenceService {
  ChatPresenceService._();
  static final ChatPresenceService instance = ChatPresenceService._();

  static const String _topic = 'tourops_presence';

  /// TEST-only diagnostics. Never logs tokens, keys or secrets.
  static const bool _debugLogs = !kReleaseMode;

  RealtimeChannel? _channel;
  String? _role; // 'customer' | 'driver'
  int? _userId;
  final Set<String> _bookings = <String>{}; // normalized reference keys
  final Set<int> _bookingIds = <int>{}; // numeric Odoo booking ids
  bool _foreground = true;
  bool _subscribed = false;
  Timer? _reconnect;
  int _reconnectAttempt = 0;
  String _lastStatus = 'idle';

  /// App-level heartbeat: re-publishes `last_seen` so a half-open socket
  /// (phone lost network without a clean close) stops looking online.
  static const Duration _heartbeatEvery = Duration(seconds: 15);

  /// A presence entry whose `last_seen` is older than this is treated as
  /// offline even if the Realtime server has not yet dropped it.
  static const Duration _staleAfter = Duration(seconds: 45);
  Timer? _heartbeat;
  Timer? _expiry;
  String _lastSig = '';

  /// Bumped on every presence change; listeners re-evaluate [isOnline].
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// presence key -> entry for every currently online user.
  final Map<String, _PresenceEntry> _online = {};

  static void _log(String m) {
    if (_debugLogs) debugPrint('[presence] $m');
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _key =>
      (_role == null || _userId == null) ? null : '$_role:$_userId';

  /// Canonical booking identity from a reference: lowercase alphanumerics with
  /// a leading `rq` prefix removed, e.g. `RQ.13509` -> `13509`.
  static String normalizeReference(String? ref) {
    var s = (ref ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (s.startsWith('rq')) s = s.substring(2);
    return s;
  }

  /// Starts presence for the signed-in user. Safe to call repeatedly
  /// (same identity => no-op; new identity => previous one is replaced).
  void start({
    required String role,
    required int userId,
    Iterable<String> bookings = const [],
    Iterable<int> bookingIds = const [],
  }) {
    if (userId <= 0 || (role != 'customer' && role != 'driver')) {
      _log('start skipped: invalid identity role=$role id=$userId');
      return;
    }
    final changedIdentity = _role != role || _userId != userId;
    if (changedIdentity && _channel != null) {
      _teardown();
    }
    _role = role;
    _userId = userId;
    final beforeRefs = Set<String>.of(_bookings);
    final beforeIds = Set<int>.of(_bookingIds);
    _bookings
      ..clear()
      ..addAll(bookings.map(normalizeReference).where((e) => e.isNotEmpty));
    _bookingIds
      ..clear()
      ..addAll(bookingIds.where((e) => e > 0));
    _log(
      'start role=$role odooId=$userId key=$_key refs=$_bookings '
      'bookingIds=$_bookingIds foreground=$_foreground',
    );
    if (_foreground) {
      _ensureChannel();
      if (_subscribed &&
          (!setEquals(beforeRefs, _bookings) ||
              !setEquals(beforeIds, _bookingIds))) {
        _track();
      }
    }
  }

  /// Adds a booking (the one the open chat shows) to this user's presence
  /// payload WITHOUT dropping the bookings published by the home screens.
  /// If presence has not been started yet (deep link / app restore) it is
  /// started from the chat's own identity, so both participants are always
  /// trackable while a chat is open.
  void ensureBooking({
    required String role,
    required int userId,
    required String reference,
    int? bookingId,
  }) {
    if (userId <= 0 || (role != 'customer' && role != 'driver')) return;
    final ref = normalizeReference(reference);
    final id = (bookingId ?? 0) > 0 ? bookingId! : null;
    if (_key == null || _role != role || _userId != userId) {
      start(
        role: role,
        userId: userId,
        bookings: ref.isEmpty ? const [] : [ref],
        bookingIds: id == null ? const [] : [id],
      );
      return;
    }
    final newRef = ref.isNotEmpty && !_bookings.contains(ref);
    final newId = id != null && !_bookingIds.contains(id);
    if (!newRef && !newId) {
      // Make sure the channel is alive even when nothing changed.
      if (_foreground && _channel == null) _ensureChannel();
      return;
    }
    if (newRef) _bookings.add(ref);
    if (newId) _bookingIds.add(id);
    if (_foreground && _channel == null) _ensureChannel();
    if (_subscribed) _track();
  }

  /// Updates the bookings carried in this user's presence payload.
  void updateBookings(
    Iterable<String> bookings, {
    Iterable<int> bookingIds = const [],
  }) {
    if (_key == null) return;
    final nextRefs = bookings
        .map(normalizeReference)
        .where((e) => e.isNotEmpty)
        .toSet();
    final nextIds = bookingIds.where((e) => e > 0).toSet();
    if (setEquals(nextRefs, _bookings) && setEquals(nextIds, _bookingIds)) {
      return;
    }
    _bookings
      ..clear()
      ..addAll(nextRefs);
    _bookingIds
      ..clear()
      ..addAll(nextIds);
    if (_subscribed) _track();
  }

  /// App returned to the foreground: reconnect and go online.
  void onResumed() {
    _foreground = true;
    _log('lifecycle resumed');
    if (_key == null) return;
    // A socket that died while backgrounded is never trusted: if the channel
    // is not currently subscribed, rebuild it; otherwise re-track.
    if (_channel == null || !_subscribed) {
      final old = _channel;
      _channel = null;
      _subscribed = false;
      if (old != null) {
        () async {
          try {
            await old.unsubscribe();
          } catch (_) {}
        }();
      }
      _ensureChannel();
    } else {
      _track();
    }
  }

  /// App moved to background / is closing: go offline immediately.
  ///
  /// On Flutter Web, `hidden`/`paused` only mean the tab lost focus or
  /// visibility: the page is still connected, so presence is kept. A real
  /// close/disconnect is cleaned up by the Supabase heartbeat timeout.
  /// Pass [force] for sign-out / real detach.
  void onBackgrounded({bool force = false}) {
    if (kIsWeb && !force) {
      _log('lifecycle background ignored on web (tab unfocused/hidden)');
      return;
    }
    _log('lifecycle background -> offline (force=$force)');
    _foreground = false;
    _teardown();
  }

  /// Sign-out / session expiry: go offline and forget the identity.
  void stop() {
    _log('stop (sign-out)');
    _teardown();
    _role = null;
    _userId = null;
    _bookings.clear();
    _bookingIds.clear();
    _foreground = true;
  }

  void _teardown() {
    _reconnect?.cancel();
    _reconnect = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    _expiry?.cancel();
    _expiry = null;
    _reconnectAttempt = 0;
    final ch = _channel;
    _channel = null;
    _subscribed = false;
    _lastStatus = 'closed';
    if (ch != null) {
      () async {
        try {
          await ch.untrack();
        } catch (_) {}
        try {
          await ch.unsubscribe();
        } catch (_) {}
      }();
    }
    if (_online.isNotEmpty) {
      _online.clear();
      _lastSig = '';
      changes.value++;
    }
  }

  void _ensureChannel() {
    if (_channel != null) return;
    final client = _client;
    final key = _key;
    if (client == null || key == null) {
      _log('ensureChannel skipped: client=${client != null} key=$key');
      return;
    }
    _log('subscribing topic=$_topic key=$key');
    final ch = client.channel(_topic, opts: RealtimeChannelConfig(key: key));
    ch
        .onPresenceSync((_) => _syncFrom(ch, 'sync'))
        .onPresenceJoin((_) => _syncFrom(ch, 'join'))
        .onPresenceLeave((_) => _syncFrom(ch, 'leave'))
        .subscribe((status, [error]) {
          if (!identical(_channel, ch)) return;
          _lastStatus = status.name;
          _log(
            'subscription status=${status.name}'
            '${error != null ? ' error=$error' : ''}',
          );
          if (status == RealtimeSubscribeStatus.subscribed) {
            _subscribed = true;
            _reconnectAttempt = 0;
            _track(); // same key => replaces, never duplicates
            _syncFrom(ch, 'subscribed');
            _startTimers();
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut ||
              status == RealtimeSubscribeStatus.closed) {
            _subscribed = false;
            _scheduleReconnect();
          }
        });
    _channel = ch;
  }

  void _startTimers() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatEvery, (_) {
      if (_subscribed && _foreground) _track();
    });
    _expiry?.cancel();
    // Re-evaluate staleness without needing a server event.
    _expiry = Timer.periodic(const Duration(seconds: 10), (_) {
      final ch = _channel;
      if (ch != null && _subscribed) _syncFrom(ch, 'expiry');
    });
  }

  Future<void> _track() async {
    final ch = _channel;
    final role = _role;
    final id = _userId;
    if (ch == null || role == null || id == null || !_foreground) return;
    final payload = {
      'role': role,
      'user_id': id,
      'bookings': _bookings.toList(),
      'booking_ids': _bookingIds.toList(),
      'online_at': DateTime.now().toUtc().toIso8601String(),
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      final res = await ch.track(payload);
      _log(
        'track result=$res key=$_key refs=${payload['bookings']} '
        'bookingIds=${payload['booking_ids']}',
      );
    } catch (e) {
      _log('track failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_foreground || _key == null) return;
    if (_reconnect?.isActive == true) return;
    _reconnectAttempt++;
    final secs = (_reconnectAttempt * 3).clamp(3, 30);
    _log('reconnect in ${secs}s (attempt $_reconnectAttempt)');
    _reconnect = Timer(Duration(seconds: secs), () {
      _reconnect = null;
      if (!_foreground || _key == null) return;
      final old = _channel;
      _channel = null;
      _subscribed = false;
      if (old != null) {
        () async {
          try {
            await old.unsubscribe();
          } catch (_) {}
        }();
      }
      _ensureChannel();
    });
  }

  void _syncFrom(RealtimeChannel ch, String reason) {
    if (!identical(_channel, ch)) return;
    final next = <String, _PresenceEntry>{};
    try {
      for (final state in ch.presenceState()) {
        for (final p in state.presences) {
          final data = p.payload;
          final role = data['role'];
          final uid = data['user_id'];
          if (role is! String || uid == null) continue;
          // Expire entries that stopped heart-beating (lost network, killed
          // app without a clean leave). Own entry is always considered fresh.
          final seenRaw = data['last_seen'] ?? data['online_at'];
          final seen = seenRaw == null
              ? null
              : DateTime.tryParse('$seenRaw')?.toUtc();
          final isMe = '$role:$uid' == _key;
          if (!isMe &&
              seen != null &&
              DateTime.now().toUtc().difference(seen) > _staleAfter) {
            continue;
          }
          final refs = <String>{
            for (final b in (data['bookings'] as List? ?? const []))
              normalizeReference('$b'),
          }..remove('');
          final ids = <int>{
            for (final b in (data['booking_ids'] as List? ?? const []))
              if (int.tryParse('$b') != null && int.parse('$b') > 0)
                int.parse('$b'),
          };
          // Keyed by `<role>:<id>` => several tabs/devices of the SAME user
          // collapse into one entry (no duplicates).
          next['$role:$uid'] = _PresenceEntry(role, refs, ids);
        }
      }
    } catch (e) {
      _log('sync failed: $e');
      return;
    }
    _online
      ..clear()
      ..addAll(next);
    // Only notify when the set of online keys actually changed.
    final sig = (next.keys.toList()..sort()).join('|');
    final changed = sig != _lastSig;
    _lastSig = sig;
    _log(
      'received ($reason) keys=${_online.keys.toList()} '
      'me=$_key subscribed=$_subscribed',
    );
    if (changed || reason != 'expiry') changes.value++;
  }

  /// True when a user of [counterpartRole] who shares the booking with the
  /// viewer is currently connected. The booking matches by numeric Odoo id
  /// ([bookingId]) OR by normalized reference. Never guesses.
  bool isCounterpartOnline({
    required String counterpartRole,
    required String bookingReference,
    int? bookingId,
  }) {
    final ref = normalizeReference(bookingReference);
    final id = (bookingId ?? 0) > 0 ? bookingId : null;
    if (ref.isEmpty && id == null) {
      _log('offline reason: no booking identity on this conversation');
      return false;
    }
    var sameRole = 0;
    for (final e in _online.values) {
      if (e.role != counterpartRole) continue;
      sameRole++;
      if ((ref.isNotEmpty && e.bookings.contains(ref)) ||
          (id != null && e.bookingIds.contains(id))) {
        return true;
      }
    }
    if (_debugLogs) {
      final why = !_subscribed
          ? 'my channel not subscribed (status=$_lastStatus)'
          : _online.isEmpty
          ? 'no presence entries received'
          : sameRole == 0
          ? 'no "$counterpartRole" entry among ${_online.keys.toList()}'
          : 'a "$counterpartRole" is online but shares no booking '
                '(want ref=$ref id=$id; have '
                '${_online.entries.where((e) => e.value.role == counterpartRole).map((e) => '${e.key}:refs=${e.value.bookings},ids=${e.value.bookingIds}').toList()})';
      _log('counterpart $counterpartRole considered OFFLINE: $why');
    }
    return false;
  }
}

class _PresenceEntry {
  final String role;
  final Set<String> bookings;
  final Set<int> bookingIds;
  const _PresenceEntry(this.role, this.bookings, this.bookingIds);
}
