
/// Configuration + feature flag for the Odoo-issued Supabase chat JWT path.
///
/// PHASE 2: the service layer exists but is NOT wired into the chat UI or the
/// Supabase client. [isEnabled] defaults to false and nothing in the app reads
/// it yet, so the existing (anon) Smart Chat path is completely unchanged.
class OdooChatConfig {
  OdooChatConfig._();

  /// Master switch. Enable only with --dart-define=ODOO_CHAT_AUTH_ENABLED=true
  /// (or via env.json) once the Supabase backend (RLS / RPCs / Edge Functions /
  /// Storage) verifies the Odoo-issued JWT.
  static const bool isEnabled = bool.fromEnvironment(
    'ODOO_CHAT_AUTH_ENABLED',
    defaultValue: true,
  );

  /// Odoo endpoints (relative to ApiClient.baseUrl, which has no /api/v1).
  static const String sessionPath = '/api/v1/chat/session';
  static const String bookingsPath = '/api/v1/chat/bookings';
  static const String tokenPath = '/api/v1/chat/token';
  static const String assignmentEventsPath = '/api/v1/chat/assignment-events';

  /// Refresh a cached token this long BEFORE it expires (token TTL is 15 min).
  static const Duration refreshSkew = Duration(seconds: 90);

  /// Tokens with less than this remaining are never handed out.
  static const Duration minRemaining = Duration(seconds: 20);

  /// Fallback TTL if the server omits `expires_in`.
  static const Duration defaultTtl = Duration(minutes: 15);
}
