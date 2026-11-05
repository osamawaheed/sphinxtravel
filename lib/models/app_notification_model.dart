/// A single in-app notification.
///
/// Odoo 17 is the source of truth. Instances are only built from payloads
/// returned by Odoo (or from a future FCM data message carrying the same
/// fields). Nothing is generated locally.
class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  /// Optional app route (e.g. "/driver/ratings") opened when tapped.
  final String? targetRoute;

  /// Optional extra payload passed to the target route.
  final Map<String, dynamic>? targetExtra;

  /// Structured fields (set for rows read from public.app_notifications).
  /// When [notificationType] is set, the UI resolves a localized title and
  /// message from it instead of using [title]/[message].
  final String? notificationType;
  final String? category;
  final Map<String, dynamic> params;
  final String? bookingReference;
  final String? bookingId;

  /// Odoo trip/booking id (public.app_notifications.trip_id), if present.
  final String? tripId;

  /// Optional server-rendered text (from the Supabase RPC
  /// `app_notifications_localized`). Only set for customer notifications
  /// when the RPC succeeded. Used only when both are nonempty.
  final String? serverTitle;
  final String? serverBody;

  /// True when both server-rendered title and body are nonempty.
  bool get hasServerText =>
      (serverTitle?.trim().isNotEmpty ?? false) &&
      (serverBody?.trim().isNotEmpty ?? false);

  /// Prefix that distinguishes campaign notification ids from booking ids.
  static const String campaignIdPrefix = 'campaign:';

  /// Notification type marker used for campaign notifications.
  static const String campaignType = 'CAMPAIGN';

  /// True for notifications that come from notification campaigns.
  bool get isCampaign => id.startsWith(campaignIdPrefix);

  /// Returns the raw campaign uuid for a prefixed campaign id, or null when
  /// [id] is not a prefixed campaign id or does not hold a valid uuid.
  static String? campaignUuidFromId(String id) {
    if (!id.startsWith(campaignIdPrefix)) return null;
    final raw = id.substring(campaignIdPrefix.length).trim();
    return isUuid(raw) ? raw : null;
  }

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// True when [value] is a canonical uuid string.
  static bool isUuid(String value) => _uuidRe.hasMatch(value);

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.targetRoute,
    this.targetExtra,
    this.notificationType,
    this.category,
    this.params = const {},
    this.bookingReference,
    this.bookingId,
    this.tripId,
    this.serverTitle,
    this.serverBody,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    message: message,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
    targetRoute: targetRoute,
    targetExtra: targetExtra,
    notificationType: notificationType,
    category: category,
    params: params,
    bookingReference: bookingReference,
    bookingId: bookingId,
    tripId: tripId,
    serverTitle: serverTitle,
    serverBody: serverBody,
  );

  static bool _bool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v == 'true' || v == '1';
    return false;
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  /// Parses a row of public.app_notifications. Returns null when the row has
  /// no id or no notification_type.
  static AppNotification? fromSupabaseRow(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = _str(m['id']);
    final type = _str(m['notification_type']);
    if (id == null || type == null) return null;

    var params = <String, dynamic>{};
    final p = m['params'];
    if (p is Map) {
      params = Map<String, dynamic>.from(p);
    }

    final occurred = _str(m['occurred_at']);
    final parsed = occurred == null ? null : DateTime.tryParse(occurred);

    return AppNotification(
      id: id,
      title: '',
      message: '',
      createdAt: (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal(),
      isRead: _bool(m['is_read']),
      notificationType: type,
      category: _str(m['category']),
      params: params,
      bookingReference: _str(m['booking_reference']),
      bookingId: _str(m['booking_id']),
      tripId: _str(m['trip_id']),
      serverTitle: _str(m['title']),
      serverBody: _str(m['body']),
    );
  }

  /// Parses a row of notification_campaigns_my_inbox(). The id is prefixed
  /// with [campaignIdPrefix]. Campaign notifications carry no booking or trip
  /// reference, so they never navigate. Returns null when the row has no valid
  /// uuid id or no usable text.
  static AppNotification? fromCampaignRow(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = _str(m['id']);
    if (id == null || !isUuid(id.trim())) return null;
    final title = _str(m['title'])?.trim();
    final body = _str(m['body'])?.trim();
    if (title == null || title.isEmpty || body == null || body.isEmpty) {
      return null;
    }
    final created = _str(m['created_at']);
    final parsed = created == null ? null : DateTime.tryParse(created);

    return AppNotification(
      id: '$campaignIdPrefix${id.trim()}',
      title: title,
      message: body,
      createdAt: (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal(),
      isRead: _bool(m['is_read']),
      notificationType: campaignType,
      category: _str(m['campaign_type']),
      serverTitle: title,
      serverBody: body,
    );
  }

  /// Parses an Odoo notification record. Returns null when the payload has no
  /// id or no displayable content.
  static AppNotification? fromMap(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = (m['id'] ?? m['notification_id'] ?? m['event_id'])?.toString();
    if (id == null || id.isEmpty) return null;
    final title = (m['title'] ?? '').toString();
    final message = (m['message'] ?? m['body'] ?? '').toString();
    if (title.isEmpty && message.isEmpty) return null;

    final created = (m['created_at'] ?? m['timestamp'] ?? m['date'])
        ?.toString();
    final parsed = created == null ? null : DateTime.tryParse(created);

    final route = (m['navigation_target'] ?? m['target_route'])?.toString();
    final extra = m['navigation_extra'] ?? m['target_extra'];

    return AppNotification(
      id: id,
      title: title,
      message: message,
      createdAt: (parsed ?? DateTime.fromMillisecondsSinceEpoch(0)).toLocal(),
      isRead: _bool(m['is_read'] ?? m['read']),
      targetRoute: (route == null || route.isEmpty) ? null : route,
      targetExtra: extra is Map ? Map<String, dynamic>.from(extra) : null,
    );
  }
}
