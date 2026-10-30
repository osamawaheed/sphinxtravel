import 'dart:async';

import 'package:flutter/foundation.dart';

import './odoo_chat_api_service.dart';
import './odoo_chat_config.dart';
import './odoo_chat_models.dart';

/// JWT lifecycle for the booking-scoped Supabase chat token.
///
/// - One token per booking (the Odoo token is scoped to a single booking).
/// - In-memory only: tokens are NEVER persisted to SharedPreferences or logged.
/// - Concurrent callers for the same booking share one in-flight request.
/// - A cached token is refreshed [OdooChatConfig.refreshSkew] before expiry.
/// - 401/403/404 clear the cached token (fail closed: no stale token is reused
///   after Odoo denies access, e.g. a replaced driver).
/// - [clearAll] must be called on sign-out / role switch.
///
/// PHASE 2: nothing in the app calls this yet and the Supabase client is NOT
/// switched to these tokens. The legacy anon path is unchanged.
class OdooChatTokenManager {
  OdooChatTokenManager._({OdooChatApiService? api})
    : _api = api ?? OdooChatApiService();

  static final OdooChatTokenManager instance = OdooChatTokenManager._();

  /// Test seam: build an isolated manager with a custom API implementation.
  @visibleForTesting
  factory OdooChatTokenManager.forTesting(OdooChatApiService api) =>
      OdooChatTokenManager._(api: api);

  final OdooChatApiService _api;
  final Map<int, OdooChatToken> _tokens = {};
  final Map<int, Future<OdooChatToken>> _inFlight = {};
  final Map<int, Timer> _timers = {};
  final StreamController<OdooChatTokenEvent> _events =
      StreamController<OdooChatTokenEvent>.broadcast();

  /// Emits whenever a token is refreshed or revoked for a booking, so a future
  /// Supabase/Realtime layer can re-authenticate without polling.
  Stream<OdooChatTokenEvent> get events => _events.stream;

  /// Returns a usable token for [bookingId], fetching/refreshing if needed.
  /// Throws [OdooChatException] (never returns an expired/denied token).
  Future<OdooChatToken> tokenFor(
    int bookingId, {
    bool forceRefresh = false,
  }) async {
    if (!OdooChatConfig.isEnabled) {
      throw const OdooChatException(
        OdooChatFailure.disabled,
        'Odoo chat authentication is disabled',
      );
    }

    if (!forceRefresh) {
      final cached = _tokens[bookingId];
      if (cached != null &&
          cached.isUsable(minRemaining: OdooChatConfig.refreshSkew)) {
        return cached;
      }
    }

    final pending = _inFlight[bookingId];
    if (pending != null) return pending;

    final future = _fetch(bookingId);
    _inFlight[bookingId] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(bookingId);
    }
  }

  /// Cached token if still comfortably valid, without any network call.
  OdooChatToken? peek(int bookingId) {
    final cached = _tokens[bookingId];
    if (cached == null) return null;
    return cached.isUsable(minRemaining: OdooChatConfig.minRemaining)
        ? cached
        : null;
  }

  Future<OdooChatToken> _fetch(int bookingId) async {
    try {
      final token = await _api.requestToken(bookingId);
      if (!token.permissions.canView) {
        // Server says no view permission: treat as denied, never cache.
        _revoke(bookingId, OdooChatFailure.forbidden);
        throw const OdooChatException(
          OdooChatFailure.forbidden,
          'No view permission for this conversation',
          403,
        );
      }
      _tokens[bookingId] = token;
      _scheduleRefresh(bookingId, token);
      _events.add(OdooChatTokenEvent.refreshed(bookingId, token));
      return token;
    } on OdooChatException catch (e) {
      if (e.failure == OdooChatFailure.unauthorized ||
          e.failure == OdooChatFailure.forbidden ||
          e.failure == OdooChatFailure.notFound) {
        _revoke(bookingId, e.failure);
      }
      rethrow;
    }
  }

  void _scheduleRefresh(int bookingId, OdooChatToken token) {
    _timers.remove(bookingId)?.cancel();
    var delay = token.remaining() - OdooChatConfig.refreshSkew;
    if (delay < const Duration(seconds: 5)) {
      delay = const Duration(seconds: 5);
    }
    _timers[bookingId] = Timer(delay, () async {
      _timers.remove(bookingId);
      // Only refresh proactively while the manager is still tracking it.
      if (!_tokens.containsKey(bookingId)) return;
      try {
        await tokenFor(bookingId, forceRefresh: true);
      } catch (_) {
        // Failure already handled (revoked / left to the next explicit call).
      }
    });
  }

  void _revoke(int bookingId, OdooChatFailure reason) {
    _timers.remove(bookingId)?.cancel();
    final had = _tokens.remove(bookingId) != null;
    if (had) {
      _events.add(OdooChatTokenEvent.revoked(bookingId, reason));
    }
  }

  /// Drops one booking's token (e.g. leaving a conversation).
  void clear(int bookingId) => _revoke(bookingId, OdooChatFailure.disabled);

  /// Drops every token and cancels all timers. Call on sign-out / role switch.
  void clearAll() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _tokens.clear();
    _inFlight.clear();
  }
}

/// Token lifecycle notification (no secret material is exposed here except
/// via the [OdooChatToken] on refresh, which callers must not log).
class OdooChatTokenEvent {
  final int bookingId;
  final OdooChatToken? token;
  final OdooChatFailure? revokedReason;

  const OdooChatTokenEvent._(this.bookingId, this.token, this.revokedReason);

  factory OdooChatTokenEvent.refreshed(int bookingId, OdooChatToken token) =>
      OdooChatTokenEvent._(bookingId, token, null);

  factory OdooChatTokenEvent.revoked(int bookingId, OdooChatFailure reason) =>
      OdooChatTokenEvent._(bookingId, null, reason);

  bool get isRevoked => revokedReason != null;
}
