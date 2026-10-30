/// Models for the Odoo 17 Smart Chat API (documented contract, Phase 2).
///
/// Parsing is deliberately tolerant: unknown / future fields (for example the
/// not-yet-documented historical read-only cutoff) are preserved in [raw] and
/// are NEVER guessed or interpreted here.
library;

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

String _asString(dynamic v) => v == null ? '' : v.toString();

bool _asBool(dynamic v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return fallback;
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// A person as returned by Odoo (`me`, `customer`, `current_driver`).
class OdooChatUser {
  final int id;
  final String name;

  /// `customer` or `driver`.
  final String role;
  final String language;
  final String photoUrl;
  final Map<String, dynamic> raw;

  const OdooChatUser({
    required this.id,
    required this.name,
    required this.role,
    required this.language,
    required this.photoUrl,
    this.raw = const {},
  });

  bool get isDriver => role == 'driver';
  bool get isCustomer => role == 'customer';

  static OdooChatUser? tryParse(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final id = _asInt(map['id']);
    if (id == null) return null;
    return OdooChatUser(
      id: id,
      name: _asString(map['name']),
      role: _asString(map['role']).toLowerCase(),
      language: _asString(map['language']),
      photoUrl: _asString(map['photo_url']),
      raw: map,
    );
  }
}

/// Result of GET /chat/bookings and GET /chat/bookings/{id}.
class OdooChatBooking {
  final int bookingId;
  final String bookingReference;
  final String status;
  final String startDate;
  final String endDate;
  final OdooChatUser? customer;
  final OdooChatUser? currentDriver;

  /// Only present on GET /chat/bookings/{id}.
  final bool? allowed;
  final String? myRole;
  final OdooChatUser? me;

  /// Full untouched payload (keeps any not-yet-documented historical fields).
  final Map<String, dynamic> raw;

  const OdooChatBooking({
    required this.bookingId,
    required this.bookingReference,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.customer,
    this.currentDriver,
    this.allowed,
    this.myRole,
    this.me,
    this.raw = const {},
  });

  /// Deterministic conversation key used by Odoo: `booking_<id>`.
  String get conversationKey => 'booking_$bookingId';

  static OdooChatBooking? tryParse(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final id = _asInt(map['booking_id']);
    if (id == null) return null;
    return OdooChatBooking(
      bookingId: id,
      bookingReference: _asString(map['booking_reference']),
      status: _asString(map['status']),
      startDate: _asString(map['start_date']),
      endDate: _asString(map['end_date']),
      customer: OdooChatUser.tryParse(map['customer']),
      currentDriver: OdooChatUser.tryParse(map['current_driver']),
      allowed: map.containsKey('allowed') ? _asBool(map['allowed']) : null,
      myRole: map['my_role']?.toString(),
      me: OdooChatUser.tryParse(map['me']),
      raw: map,
    );
  }
}

/// `permissions` block of POST /chat/token.
class OdooChatPermissions {
  final bool canView;
  final bool canSend;
  final Map<String, dynamic> raw;

  const OdooChatPermissions({
    required this.canView,
    required this.canSend,
    this.raw = const {},
  });

  /// Fail-closed default: no access.
  static const OdooChatPermissions none = OdooChatPermissions(
    canView: false,
    canSend: false,
  );

  static OdooChatPermissions parse(dynamic json) {
    if (json is! Map) return none;
    final map = Map<String, dynamic>.from(json);
    return OdooChatPermissions(
      canView: _asBool(map['can_view']),
      canSend: _asBool(map['can_send']),
      raw: map,
    );
  }
}

/// Parsed POST /chat/token response. [accessToken] is a secret: it is never
/// logged and [toString] never prints it.
class OdooChatToken {
  final String conversationId;
  final int bookingId;
  final String accessToken;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final OdooChatPermissions permissions;
  final OdooChatUser? me;
  final Map<String, dynamic> raw;

  const OdooChatToken({
    required this.conversationId,
    required this.bookingId,
    required this.accessToken,
    required this.issuedAt,
    required this.expiresAt,
    required this.permissions,
    this.me,
    this.raw = const {},
  });

  Duration remaining([DateTime? now]) =>
      expiresAt.difference(now ?? DateTime.now());

  bool isUsable({required Duration minRemaining, DateTime? now}) =>
      accessToken.isNotEmpty && remaining(now) > minRemaining;

  static OdooChatToken? tryParse(
    dynamic json, {
    required Duration fallbackTtl,
  }) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final token = _asString(map['access_token']);
    final bookingId = _asInt(map['booking_id']);
    if (token.isEmpty || bookingId == null) return null;
    final ttlSeconds = _asInt(map['expires_in']);
    final ttl = (ttlSeconds != null && ttlSeconds > 0)
        ? Duration(seconds: ttlSeconds)
        : fallbackTtl;
    final now = DateTime.now();
    // The raw payload (which contains the token) is intentionally dropped.
    final safeRaw = Map<String, dynamic>.from(map)..remove('access_token');
    return OdooChatToken(
      conversationId: _asString(map['conversation_id']).isNotEmpty
          ? _asString(map['conversation_id'])
          : 'booking_$bookingId',
      bookingId: bookingId,
      accessToken: token,
      issuedAt: now,
      expiresAt: now.add(ttl),
      permissions: OdooChatPermissions.parse(map['permissions']),
      me: OdooChatUser.tryParse(map['me']),
      raw: safeRaw,
    );
  }

  @override
  String toString() =>
      'OdooChatToken(booking=$bookingId, conv=$conversationId, '
      'canView=${permissions.canView}, canSend=${permissions.canSend}, '
      'expiresAt=$expiresAt)';
}

/// One entry of GET /chat/assignment-events.
class OdooAssignmentEvent {
  final int id;
  final String event;
  final int? tripId;
  final String conversationId;
  final int? oldDriverId;
  final int? newDriverId;
  final DateTime? effectiveAt;
  final Map<String, dynamic> raw;

  const OdooAssignmentEvent({
    required this.id,
    required this.event,
    required this.tripId,
    required this.conversationId,
    required this.oldDriverId,
    required this.newDriverId,
    required this.effectiveAt,
    this.raw = const {},
  });

  static OdooAssignmentEvent? tryParse(dynamic json) {
    if (json is! Map) return null;
    final map = Map<String, dynamic>.from(json);
    final id = _asInt(map['id']);
    if (id == null) return null;
    return OdooAssignmentEvent(
      id: id,
      event: _asString(map['event']),
      tripId: _asInt(map['trip_id']),
      conversationId: _asString(map['conversation_id']),
      oldDriverId: _asInt(map['old_driver_id']),
      newDriverId: _asInt(map['new_driver_id']),
      effectiveAt: DateTime.tryParse(_asString(map['effective_at'])),
      raw: map,
    );
  }
}

/// Typed failure from the chat token / API layer. Never carries a token.
enum OdooChatFailure {
  /// Odoo bearer token invalid and could not be refreshed (401).
  unauthorized,

  /// No access to the booking, or the driver was replaced (403).
  forbidden,

  /// Booking not found (404).
  notFound,

  /// Network / timeout / 5xx.
  network,

  /// Response did not match the documented contract.
  invalidResponse,

  /// Feature flag is off.
  disabled,
}

class OdooChatException implements Exception {
  final OdooChatFailure failure;
  final String message;
  final int? statusCode;

  const OdooChatException(this.failure, [this.message = '', this.statusCode]);

  @override
  String toString() =>
      'OdooChatException(${failure.name}'
      '${statusCode != null ? ', $statusCode' : ''}'
      '${message.isNotEmpty ? ': $message' : ''})';
}
