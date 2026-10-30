import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../api_client.dart';
import '../../supabase_service.dart';
import './odoo_chat_config.dart';

/// TEMPORARY, READ-ONLY runtime diagnostic for the Odoo chat JWT path.
///
/// * Decodes ONLY the JWT payload (middle segment) locally.
/// * Never returns, logs or displays the full token, the signature, any JWT
///   secret or a service-role key.
/// * Performs a single read-only GET on `chat_conversations` using the same
///   Odoo bearer token the secure Supabase client attaches.
/// * Changes no state: no RLS, no permissions, no records, no auth logic.
class OdooChatDiagnostics {
  OdooChatDiagnostics._();

  /// Builds a redacted multi-line report and prints it with `debugPrint`.
  static Future<String> run({
    required int bookingId,
    required String? accessToken,
    required String? tokenConversationId,
    required String? supabaseClientError,
    required int? supabaseClientRowCount,
  }) async {
    final b = StringBuffer()..writeln('[JWT-DIAG] booking_id=$bookingId');

    // 4. Project / endpoint.
    final sbUri = Uri.tryParse(SupabaseService.supabaseUrl);
    final sbHost = sbUri?.host ?? '';
    final sbRef = sbHost.contains('.') ? sbHost.split('.').first : sbHost;
    b.writeln(
      '[JWT-DIAG] flag ODOO_CHAT_AUTH_ENABLED=${OdooChatConfig.isEnabled}',
    );
    b.writeln('[JWT-DIAG] supabase_project_ref=$sbRef host=$sbHost');
    b.writeln(
      '[JWT-DIAG] odoo_endpoint=${ApiClient.baseUrl}'
      '${OdooChatConfig.tokenPath} '
      'is_test_env=${ApiClient.isTestEnvironment}',
    );
    b.writeln('[JWT-DIAG] token_conversation_id=${tokenConversationId ?? '-'}');

    // 1. Received / attached?
    final token = accessToken ?? '';
    final received = token.isNotEmpty;
    b.writeln('[JWT-DIAG] odoo_jwt_received=$received');
    b.writeln(
      '[JWT-DIAG] odoo_jwt_attached_to_supabase_request=$received '
      '(Authorization: Bearer <redacted len=${token.length}>)',
    );

    // 2. Decoded payload (selected claims only).
    final payload = received ? _decodePayload(token) : null;
    if (received && payload == null) {
      b.writeln('[JWT-DIAG] payload=UNDECODABLE (not a 3-part JWT)');
    }
    if (payload != null) {
      String f(String k) =>
          payload.containsKey(k) ? '${payload[k]}' : '<absent>';
      b.writeln('[JWT-DIAG] role=${f('role')}');
      b.writeln('[JWT-DIAG] odoo_role=${f('odoo_role')}');
      b.writeln('[JWT-DIAG] odoo_user_id=${f('odoo_user_id')}');
      b.writeln('[JWT-DIAG] booking_id_claim=${f('booking_id')}');
      b.writeln('[JWT-DIAG] can_view=${f('can_view')}');
      b.writeln('[JWT-DIAG] aud=${f('aud')}');
      b.writeln('[JWT-DIAG] iss=${f('iss')}');
      b.writeln('[JWT-DIAG] ${_expiry(payload['exp'])}');
    }

    // 3a. supabase_flutter client query result (already executed by caller).
    b.writeln(
      '[JWT-DIAG] client_query rows=${supabaseClientRowCount ?? '-'} '
      'error=${supabaseClientError ?? 'none'}',
    );

    // 3b. Raw REST probe for the real HTTP status (read-only GET).
    if (received && SupabaseService.supabaseUrl.isNotEmpty) {
      b.writeln(await _restProbe(bookingId, token));
    } else {
      b.writeln('[JWT-DIAG] rest_probe=SKIPPED (no token or no SUPABASE_URL)');
    }

    final report = b.toString().trimRight();
    for (final line in report.split('\n')) {
      debugPrint(line);
    }
    return report;
  }

  static Future<String> _restProbe(int bookingId, String token) async {
    try {
      final base = SupabaseService.supabaseUrl.endsWith('/')
          ? SupabaseService.supabaseUrl.substring(
              0,
              SupabaseService.supabaseUrl.length - 1,
            )
          : SupabaseService.supabaseUrl;
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          validateStatus: (_) => true,
        ),
      );
      final res = await dio.get(
        '$base/rest/v1/chat_conversations',
        queryParameters: {'select': 'id', 'odoo_booking_id': 'eq.$bookingId'},
        options: Options(
          headers: {
            'apikey': SupabaseService.supabaseAnonKey,
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      final status = res.statusCode;
      final data = res.data;
      if (status != null && status >= 200 && status < 300) {
        final count = data is List ? data.length : -1;
        return '[JWT-DIAG] rest_probe http_status=$status rows=$count '
            'error=none';
      }
      String code = '-';
      String msg = '-';
      if (data is Map) {
        code = '${data['code'] ?? '-'}';
        msg = _clip('${data['message'] ?? data['error'] ?? '-'}');
      } else if (data != null) {
        msg = _clip('$data');
      }
      return '[JWT-DIAG] rest_probe http_status=$status rows=- '
          'error_code=$code error_message=$msg';
    } catch (e) {
      return '[JWT-DIAG] rest_probe FAILED: ${_clip(_scrub('$e'))}';
    }
  }

  static Map<String, dynamic>? _decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final decoded = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final json = jsonDecode(decoded);
      return json is Map ? Map<String, dynamic>.from(json) : null;
    } catch (_) {
      return null;
    }
  }

  static String _expiry(dynamic exp) {
    final secs = exp is num ? exp.toInt() : int.tryParse('$exp');
    if (secs == null) return 'exp=<absent> expired=unknown';
    final at = DateTime.fromMillisecondsSinceEpoch(secs * 1000, isUtc: true);
    final left = at.difference(DateTime.now().toUtc());
    return 'exp=${at.toIso8601String()} '
        'expired=${left.isNegative} '
        'seconds_remaining=${left.inSeconds}';
  }

  static String _clip(String s) =>
      s.length > 300 ? '${s.substring(0, 300)}…' : s;

  /// Removes anything that looks like a JWT from free text.
  static String _scrub(String s) => s.replaceAll(
    RegExp(r'eyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*'),
    '<jwt-redacted>',
  );
}
