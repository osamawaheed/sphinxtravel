import '../../api_client.dart';
import './odoo_chat_config.dart';
import './odoo_chat_models.dart';
import './odoo_chat_token_manager.dart';

/// Thin client for the Odoo 17 Smart Chat API.
///
/// Reuses the existing [ApiClient], so the Odoo bearer token (1h) injection,
/// `Accept-Language`, and one-shot `/auth/refresh` retry are inherited.
///
/// PHASE 2: not called from any screen. All methods throw
/// [OdooChatFailure.disabled] while [OdooChatConfig.isEnabled] is false, unless
/// [allowWhenDisabled] is set (used only by explicit diagnostics/tests).
class OdooChatApiService {
  OdooChatApiService({ApiClient? client, this.allowWhenDisabled = false})
    : _client = client ?? ApiClient();

  final ApiClient _client;
  final bool allowWhenDisabled;

  void _ensureEnabled() {
    if (!OdooChatConfig.isEnabled && !allowWhenDisabled) {
      throw const OdooChatException(
        OdooChatFailure.disabled,
        'Odoo chat authentication is disabled',
      );
    }
  }

  /// GET /chat/session — who is calling (id, role, language).
  Future<OdooChatUser> getSession() async {
    _ensureEnabled();
    final data = await _guard(() => _client.get(OdooChatConfig.sessionPath));
    final user = OdooChatUser.tryParse(data);
    if (user == null) {
      throw const OdooChatException(
        OdooChatFailure.invalidResponse,
        'Malformed /chat/session response',
      );
    }
    return user;
  }

  /// GET /chat/bookings — conversations the caller may open.
  Future<List<OdooChatBooking>> listBookings() async {
    _ensureEnabled();
    final data = await _guard(() => _client.get(OdooChatConfig.bookingsPath));
    final list = data is Map ? data['bookings'] : null;
    if (list is! List) {
      throw const OdooChatException(
        OdooChatFailure.invalidResponse,
        'Malformed /chat/bookings response',
      );
    }
    return list
        .map(OdooChatBooking.tryParse)
        .whereType<OdooChatBooking>()
        .toList(growable: false);
  }

  /// GET /chat/bookings/{id} — access check + booking details.
  Future<OdooChatBooking> getBooking(int bookingId) async {
    _ensureEnabled();
    final data = await _guard(
      () => _client.get('${OdooChatConfig.bookingsPath}/$bookingId'),
    );
    final booking = OdooChatBooking.tryParse(data);
    if (booking == null) {
      throw const OdooChatException(
        OdooChatFailure.invalidResponse,
        'Malformed /chat/bookings/{id} response',
      );
    }
    return booking;
  }

  /// POST /chat/token — mints a booking-scoped, 15-minute Supabase JWT.
  /// Prefer [OdooChatTokenManager.tokenFor], which caches and refreshes.
  Future<OdooChatToken> requestToken(int bookingId) async {
    _ensureEnabled();
    final data = await _guard(
      () => _client.post(
        OdooChatConfig.tokenPath,
        data: {'booking_id': bookingId},
      ),
    );
    final token = OdooChatToken.tryParse(
      data,
      fallbackTtl: OdooChatConfig.defaultTtl,
    );
    if (token == null || token.bookingId != bookingId) {
      throw const OdooChatException(
        OdooChatFailure.invalidResponse,
        'Malformed /chat/token response',
      );
    }
    return token;
  }

  /// GET /chat/assignment-events?booking_id= — driver change log (read-only).
  Future<List<OdooAssignmentEvent>> getAssignmentEvents(int bookingId) async {
    _ensureEnabled();
    final data = await _guard(
      () => _client.get(
        OdooChatConfig.assignmentEventsPath,
        queryParams: {'booking_id': bookingId},
      ),
    );
    final list = data is Map ? data['events'] : null;
    if (list is! List) {
      throw const OdooChatException(
        OdooChatFailure.invalidResponse,
        'Malformed /chat/assignment-events response',
      );
    }
    return list
        .map(OdooAssignmentEvent.tryParse)
        .whereType<OdooAssignmentEvent>()
        .toList(growable: false);
  }

  /// Runs a request and maps [ApiException] to a typed [OdooChatException].
  /// Response bodies are returned as-is; nothing is logged.
  Future<dynamic> _guard(Future<dynamic> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on ApiException catch (e) {
      throw OdooChatException(_failureFor(e), e.message, e.statusCode);
    } on OdooChatException {
      rethrow;
    } catch (_) {
      throw const OdooChatException(OdooChatFailure.network, 'Request failed');
    }
  }

  static OdooChatFailure _failureFor(ApiException e) {
    switch (e.statusCode) {
      case 401:
        return OdooChatFailure.unauthorized;
      case 403:
        return OdooChatFailure.forbidden;
      case 404:
        return OdooChatFailure.notFound;
      default:
        return OdooChatFailure.network;
    }
  }
}
