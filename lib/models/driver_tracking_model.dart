/// Tracking models for the Live Driver Tracking feature.
///
/// Odoo 17 is the source of truth. None of these values are invented: a
/// location exists only when the backend returns real coordinates.
library;

enum TrackingState {
  /// Tracking not available yet (outside the pickup window or no driver).
  notEligible,

  /// Window is open, but the driver has not started sharing GPS.
  waitingForDriver,

  /// Driver is sharing and a real location was received.
  live,

  /// Window is open, but GPS is inactive / no location is available.
  unavailable,

  /// Pickup completed or session stopped.
  ended,
}

/// A real GPS fix reported by the assigned driver.
class DriverLiveLocation {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? headingDegrees;
  final double? speedMps;
  final DateTime updatedAt;

  const DriverLiveLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
    this.accuracyMeters,
    this.headingDegrees,
    this.speedMps,
  });

  static double? _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '');
  }

  /// Returns null unless valid, non-zero coordinates are present.
  static DriverLiveLocation? fromJsonOrNull(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final lat = _d(m['latitude'] ?? m['lat']);
    final lng = _d(m['longitude'] ?? m['lng'] ?? m['lon']);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    if (lat == 0 && lng == 0) return null;
    final ts = DateTime.tryParse(
      (m['updated_at'] ?? m['timestamp'] ?? m['recorded_at'] ?? '').toString(),
    );
    if (ts == null) return null;
    return DriverLiveLocation(
      latitude: lat,
      longitude: lng,
      accuracyMeters: _d(m['accuracy']),
      headingDegrees: _d(m['heading']),
      speedMps: _d(m['speed']),
      updatedAt: ts.toLocal(),
    );
  }
}

/// Snapshot returned by the customer tracking endpoint.
class DriverTrackingSnapshot {
  /// Backend session status: pending | active | stopped | completed.
  final String sessionStatus;
  final int driverId;
  final DriverLiveLocation? location;
  final int? etaMinutes;

  /// Odoo-controlled visibility flag (`location_visible`). Defaults to true
  /// only when the key is missing from the response.
  final bool locationVisible;

  const DriverTrackingSnapshot({
    required this.sessionStatus,
    required this.driverId,
    this.location,
    this.etaMinutes,
    this.locationVisible = true,
  });

  bool get isActive => sessionStatus == 'active';
  bool get isEnded =>
      sessionStatus == 'stopped' || sessionStatus == 'completed';

  static bool _parseVisible(Map<String, dynamic> j) {
    if (!j.containsKey('location_visible')) return true;
    final v = j['location_visible'];
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().trim().toLowerCase() ?? '';
    return s == 'true' || s == '1' || s == 'yes';
  }

  factory DriverTrackingSnapshot.fromJson(Map<String, dynamic> j) {
    final eta = j['eta_minutes'];
    return DriverTrackingSnapshot(
      sessionStatus: (j['status'] ?? j['session_status'] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase(),
      driverId: j['driver_id'] is num
          ? (j['driver_id'] as num).toInt()
          : int.tryParse(j['driver_id']?.toString() ?? '') ?? 0,
      location: DriverLiveLocation.fromJsonOrNull(
        j['location'] ??
            ((j['driver_lat'] != null && j['driver_lng'] != null)
                ? {
                    'lat': j['driver_lat'],
                    'lng': j['driver_lng'],
                    'updated_at': j['last_updated_at'],
                    'accuracy': j['accuracy'],
                    'heading': j['heading'],
                    'speed': j['speed'],
                  }
                : null),
      ),
      etaMinutes: eta is num ? eta.toInt() : int.tryParse('${eta ?? ''}'),
      locationVisible: _parseVisible(j),
    );
  }
}

/// Pickup scheduling info needed to decide tracking eligibility.
class PickupTrackingWindow {
  /// Odoo segment id the session belongs to.
  final int segmentId;

  /// Assigned driver id (changes => previous tracking is dropped).
  final int driverId;

  /// Scheduled pickup date-time from Odoo (null when it can't be resolved).
  final DateTime? pickupAt;

  /// Optional explicit eligibility flags sent by Odoo.
  final bool? backendEligible;
  final DateTime? windowStart;

  /// True when the pickup is already completed.
  final bool completed;

  const PickupTrackingWindow({
    required this.segmentId,
    required this.driverId,
    required this.pickupAt,
    required this.completed,
    this.backendEligible,
    this.windowStart,
  });

  static const Duration leadTime = Duration(minutes: 30);

  /// Tracking is eligible from 30 minutes before the Odoo pickup time until
  /// the pickup is completed. Never eligible without a driver / segment.
  bool isEligibleAt(DateTime now) {
    if (completed || segmentId <= 0 || driverId <= 0) return false;
    if (backendEligible != null) return backendEligible!;
    final start = windowStart ?? pickupAt?.subtract(leadTime);
    if (start == null) return false;
    return !now.isBefore(start);
  }
}
