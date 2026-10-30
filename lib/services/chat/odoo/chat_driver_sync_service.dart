import 'package:dio/dio.dart';

import '../../supabase_service.dart';
import '../../token_manager.dart';
import './odoo_chat_models.dart';

/// Phase 1: asks the `chat-sync-driver` Edge Function to synchronize the
/// authoritative Odoo current driver into Supabase for one booking, and
/// returns the real conversation UUID.
///
/// Security:
/// * Sends ONLY `booking_id` in the body. No driver id is ever supplied.
/// * The Odoo Mobile Access Token travels in the dedicated
///   `X-Odoo-Mobile-Authorization` header (the standard `Authorization`
///   header carries the Supabase anon key for the functions gateway).
/// * A dedicated [Dio] instance is used so no Odoo interceptor can leak the
///   token anywhere else, and so Supabase headers never reach Odoo.
/// * The token is never logged or persisted by this class.
/// * Fails closed: any non-success outcome throws [OdooChatException].
class ChatDriverSyncService {
  ChatDriverSyncService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (_) => true,
            ),
          );

  static const String functionName = 'chat-sync-driver';
  static const String odooTokenHeader = 'X-Odoo-Mobile-Authorization';

  final Dio _dio;

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Synchronizes the driver and returns the conversation UUID.
  /// Must complete BEFORE querying `chat_conversations`.
  Future<String> syncDriver(int bookingId) async {
    final supabaseUrl = SupabaseService.supabaseUrl;
    final anonKey = SupabaseService.supabaseAnonKey;
    if (supabaseUrl.isEmpty || anonKey.isEmpty) {
      throw const OdooChatException(
        OdooChatFailure.network,
        'Supabase is not configured',
      );
    }
    final odooToken = await TokenManager.getAccessToken();
    if (odooToken == null || odooToken.isEmpty) {
      throw const OdooChatException(
        OdooChatFailure.unauthorized,
        'No Odoo session',
        401,
      );
    }

    final base = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;

    Response<dynamic> response;
    try {
      response = await _dio.post(
        '$base/functions/v1/$functionName',
        data: {'booking_id': bookingId},
        options: Options(
          headers: {
            'apikey': anonKey,
            'Authorization': 'Bearer $anonKey',
            odooTokenHeader: 'Bearer $odooToken',
            'Content-Type': 'application/json',
          },
        ),
      );
    } catch (_) {
      throw const OdooChatException(OdooChatFailure.network, 'Request failed');
    }

    final status = response.statusCode ?? 0;
    if (status == 401) {
      throw OdooChatException(
        OdooChatFailure.unauthorized,
        'Unauthorized',
        401,
      );
    }
    if (status == 403) {
      throw OdooChatException(OdooChatFailure.forbidden, 'Forbidden', 403);
    }
    if (status == 404) {
      throw OdooChatException(OdooChatFailure.notFound, 'Not found', 404);
    }
    if (status < 200 || status >= 300) {
      throw OdooChatException(
        OdooChatFailure.network,
        'Driver synchronization failed',
        status,
      );
    }

    final data = response.data;
    final id = data is Map ? data['conversation_id'] : null;
    if (data is! Map ||
        data['ok'] != true ||
        id is! String ||
        !_uuidRe.hasMatch(id)) {
      throw const OdooChatException(
        OdooChatFailure.invalidResponse,
        'Malformed driver synchronization response',
      );
    }
    return id;
  }
}
