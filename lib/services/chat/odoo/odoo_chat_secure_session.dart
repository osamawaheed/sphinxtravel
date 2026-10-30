import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../supabase_service.dart';
import './odoo_chat_config.dart';
import './odoo_chat_models.dart';
import './odoo_chat_token_manager.dart';

/// A booking-scoped, JWT-authenticated Supabase connection for one chat.
///
/// * Built ONLY when [OdooChatConfig.isEnabled] is true. While the flag is
///   false [open] is never reached and the legacy anon path is untouched.
/// * Uses `SupabaseClient(accessToken: ...)`, so REST, RPC, Storage, Edge
///   Functions and Realtime all send the Odoo-issued booking JWT. The token
///   comes from [OdooChatTokenManager] (cached, refreshed 90s before expiry).
/// * The global anon client (`Supabase.instance.client`) is never modified.
/// * Tokens are never logged or persisted.
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

  /// Supabase `chat_conversations.id` (uuid) resolved server-side by Odoo.
  /// Null when Odoo has not provisioned the conversation yet.
  final String? conversationId;

  /// Odoo's verdict at token time. Sending is refused client-side when false;
  /// the database re-checks on every write regardless.
  bool canSend;

  final OdooChatTokenManager _tokens;

  /// TEMPORARY diagnostic only: the current cached token string (never log).
  String? diagnosticAccessToken() => _tokens.peek(bookingId)?.accessToken;

  /// TEMPORARY diagnostic only: raw conversation_id claim from the Odoo reply.
  String? diagnosticTokenConversationId() =>
      _tokens.peek(bookingId)?.conversationId;

  static final Map<int, ChatSecureSession> _open = {};

  /// Opens (or reuses) the secure session for [bookingId].
  /// Throws [OdooChatException] when Odoo denies access (fail closed).
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
    if (existing != null) {
      existing.canSend = token.permissions.canSend;
      return existing;
    }

    final client = SupabaseClient(
      SupabaseService.supabaseUrl,
      SupabaseService.supabaseAnonKey,
      // Always the freshest valid token; a revoked booking throws here and
      // the request fails closed (no stale token is ever reused).
      accessToken: () async {
        final t = await manager.tokenFor(bookingId);
        return t.accessToken;
      },
    );

    final uuid = _asUuid(token.conversationId);
    final session = ChatSecureSession._(
      bookingId: bookingId,
      client: client,
      conversationId: uuid,
      canSend: token.permissions.canSend,
      tokens: manager,
    );
    _open[bookingId] = session;
    return session;
  }

  /// Re-reads permissions (e.g. before sending) so a replaced driver is
  /// blocked as soon as Odoo says so, without waiting for token expiry.
  Future<bool> refreshCanSend() async {
    try {
      final t = await _tokens.tokenFor(bookingId, forceRefresh: true);
      canSend = t.permissions.canSend;
    } on OdooChatException {
      canSend = false;
    }
    return canSend;
  }

  /// Closes one booking's client and drops its token.
  Future<void> close() async {
    _open.remove(bookingId);
    _tokens.clear(bookingId);
    try {
      await client.dispose();
    } catch (e) {
      debugPrint('[chat] secure session dispose failed');
    }
  }

  /// Sign-out / role switch: drop every secure client and token.
  static Future<void> clearAll({OdooChatTokenManager? tokens}) async {
    final sessions = List<ChatSecureSession>.of(_open.values);
    _open.clear();
    (tokens ?? OdooChatTokenManager.instance).clearAll();
    for (final s in sessions) {
      try {
        await s.client.dispose();
      } catch (_) {}
    }
  }

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Odoo may return a `booking_<id>` key instead of the uuid; only a real
  /// uuid is usable as a conversation id.
  static String? _asUuid(String raw) => _uuidRe.hasMatch(raw) ? raw : null;
}
