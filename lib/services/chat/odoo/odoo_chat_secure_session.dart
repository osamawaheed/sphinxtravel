import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase_service.dart';
import './odoo_chat_config.dart';
import './odoo_chat_models.dart';
import './odoo_chat_token_manager.dart';

/// A booking-scoped, JWT-authenticated Supabase connection for one chat.
///
/// The Odoo-issued JWT is used for REST, RPC, Storage and Realtime.
/// Realtime authentication is refreshed periodically while the session
/// remains open, without changing the global Supabase client.
class ChatSecureSession {
  ChatSecureSession._({
    required this.bookingId,
    required this.client,
    required this.conversationId,
    required this.canSend,
    required OdooChatTokenManager tokens,
  }) : _tokens = tokens;

  final int bookingId;
  final SupabaseClient client;

  final String? conversationId;

  bool canSend;

  final OdooChatTokenManager _tokens;

  Timer? _realtimeAuthTimer;
  bool _refreshingRealtimeAuth = false;
  bool _closed = false;

  String? diagnosticAccessToken() => _tokens.peek(bookingId)?.accessToken;

  String? diagnosticTokenConversationId() =>
      _tokens.peek(bookingId)?.conversationId;

  static final Map<int, ChatSecureSession> _open = {};

  static Future<ChatSecureSession> open(
    int bookingId, {
    OdooChatTokenManager? tokens,
  }) async {
    if (!OdooChatConfig.isEnabled) {
      throw const OdooChatException(
        OdooChatFailure.disabled,
        'Odoo chat authentication is disabled',
      );
    }

    final manager = tokens ?? OdooChatTokenManager.instance;
    final token = await manager.tokenFor(bookingId);

    final existing = _open[bookingId];

    if (existing != null && !existing._closed) {
      existing.canSend = token.permissions.canSend;
      await existing.refreshRealtimeAuth();
      return existing;
    }

    final client = SupabaseClient(
      SupabaseService.supabaseUrl,
      SupabaseService.supabaseAnonKey,
      accessToken: () async {
        final t = await manager.tokenFor(bookingId);
        return t.accessToken;
      },
    );

    final session = ChatSecureSession._(
      bookingId: bookingId,
      client: client,
      conversationId: _asUuid(token.conversationId),
      canSend: token.permissions.canSend,
      tokens: manager,
    );

    _open[bookingId] = session;

    try {
      await session.refreshRealtimeAuth();
      session._startRealtimeAuthRefresh();
      return session;
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  /// Supplies the current booking JWT to the Realtime connection.
  ///
  /// The token manager is responsible for refreshing the Odoo token
  /// before expiry. Authentication failures are never bypassed.
  Future<void> refreshRealtimeAuth() async {
    if (_closed || _refreshingRealtimeAuth) return;

    _refreshingRealtimeAuth = true;

    try {
      final token = await _tokens.tokenFor(bookingId);

      if (_closed) return;

      canSend = token.permissions.canSend;

      client.realtime.setAuth(token.accessToken);

      debugPrint('[chat] realtime auth refreshed for booking=$bookingId');
    } finally {
      _refreshingRealtimeAuth = false;
    }
  }

  void _startRealtimeAuthRefresh() {
    _realtimeAuthTimer?.cancel();

    // Refresh regularly so an open chat does not keep using an
    // expired booking JWT on its Realtime connection.
    _realtimeAuthTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_closed || _refreshingRealtimeAuth) return;

      try {
        await refreshRealtimeAuth();
      } catch (e) {
        debugPrint(
          '[chat] realtime auth refresh failed '
          'for booking=$bookingId: ${e.runtimeType}',
        );
      }
    });
  }

  /// Re-checks sending permissions directly with Odoo.
  Future<bool> refreshCanSend() async {
    try {
      final token = await _tokens.tokenFor(bookingId, forceRefresh: true);

      canSend = token.permissions.canSend;

      if (!_closed) {
        client.realtime.setAuth(token.accessToken);
      }
    } on OdooChatException {
      canSend = false;
    }

    return canSend;
  }

  /// Closes the booking-scoped Supabase client and clears its token.
  Future<void> close() async {
    if (_closed) return;

    _closed = true;
    _realtimeAuthTimer?.cancel();
    _realtimeAuthTimer = null;

    if (identical(_open[bookingId], this)) {
      _open.remove(bookingId);
    }

    _tokens.clear(bookingId);

    try {
      await client.dispose();
    } catch (e) {
      debugPrint('[chat] secure session dispose failed');
    }
  }

  /// Sign-out / role switch: close every secure client and clear tokens.
  static Future<void> clearAll({OdooChatTokenManager? tokens}) async {
    final sessions = List<ChatSecureSession>.of(_open.values);

    _open.clear();

    for (final session in sessions) {
      session._closed = true;
      session._realtimeAuthTimer?.cancel();
      session._realtimeAuthTimer = null;
    }

    (tokens ?? OdooChatTokenManager.instance).clearAll();

    for (final session in sessions) {
      try {
        await session.client.dispose();
      } catch (_) {
        debugPrint('[chat] secure session dispose failed');
      }
    }
  }

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static String? _asUuid(String raw) => _uuidRe.hasMatch(raw) ? raw : null;
}
