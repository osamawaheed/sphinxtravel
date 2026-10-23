import './customer_bootstrap_model.dart' show CustomerHomeTrip;
import './driver_profile_model.dart';
import './transportation_segment_model.dart';
import './vehicle_model.dart';
import './trip_model.dart';

/// GET /api/v1/driver/bootstrap
/// {
///   "driver": { ...DriverProfile... },
///   "location_required": true,
///   "next_today": { segment } | null,
///   "assigned_segments": [ segment, ... ]
/// }
class DriverBootstrapModel {
  final DriverProfile driver;
  final bool locationRequired;
  final TransportationSegmentModel? nextToday;
  final List<TransportationSegmentModel> assignedSegments;

  /// `active_trip` from the bootstrap (customer trip shape + `customer` and
  /// `my_segment_ids`). Null when no trip is assigned.
  final CustomerHomeTrip? homeTrip;

  /// Not part of the bootstrap response; kept for screens that still render
  /// full trip data (empty for the real API).
  final List<TripModel> assignedTrips;

  const DriverBootstrapModel({
    required this.driver,
    required this.locationRequired,
    this.nextToday,
    this.assignedSegments = const [],
    this.homeTrip,
    this.assignedTrips = const [],
  });

  factory DriverBootstrapModel.fromJson(Map<String, dynamic> json) {
    final driverJson = json['driver'];
    final nextTodayJson = json['next_today'];
    final segmentsJson = json['assigned_segments'];
    final activeTripJson = json['active_trip'];

    return DriverBootstrapModel(
      driver: driverJson is Map<String, dynamic>
          ? DriverProfile.fromJson(driverJson)
          : const DriverProfile(),
      locationRequired: json['location_required'] is bool
          ? json['location_required'] as bool
          : true,
      nextToday: nextTodayJson is Map<String, dynamic>
          ? TransportationSegmentModel.fromJson(nextTodayJson)
          : null,
      assignedSegments: segmentsJson is List
          ? segmentsJson
                .whereType<Map<String, dynamic>>()
                .map(TransportationSegmentModel.fromJson)
                .toList()
          : const [],
      homeTrip: activeTripJson is Map
          ? CustomerHomeTrip.fromJson(Map<String, dynamic>.from(activeTripJson))
          : null,
    );
  }

  // ─── Convenience accessors (derived from `driver`) ────────────────────────

  int get driverId => driver.id;
  String get driverName => driver.name;
  String? get driverPhone => driver.phone.isEmpty ? null : driver.phone;
  String? get driverUsername => null;
  String? get driverPhotoUrl =>
      driver.photoUrl.isEmpty ? null : driver.photoUrl;
  double? get rating => driver.rating;
  int? get totalTrips => driver.tripCount;
  bool get profileCompleted => driver.profileCompleted;
  String get vehicleLine => driver.vehicleLine;

  VehicleModel? get vehicle {
    if (driver.vehicleModel.isEmpty && driver.vehicleYear.isEmpty) return null;
    return VehicleModel(
      id: 0,
      make: '',
      model: driver.vehicleModel,
      color: driver.vehicleColor,
      plateNumber: '',
      vehicleType: '',
      manufacturingYear: driver.vehicleYear,
    );
  }

  String get firstName => driver.firstName;

  TransportationSegmentModel? get currentSegment {
    try {
      return assignedSegments.firstWhere((s) => s.isActive);
    } catch (_) {
      return null;
    }
  }

  List<TransportationSegmentModel> get todaySegments {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return assignedSegments
        .where((s) => s.date == todayStr && !s.isCompleted)
        .toList();
  }

  /// Returns the active trip (in_progress or pre_trip with today/future start)
  TripModel? get activeTrip {
    try {
      return assignedTrips.firstWhere(
        (t) => t.isInProgress || (t.isPreTrip && !t.isCompleted),
      );
    } catch (_) {
      return assignedTrips.isNotEmpty ? assignedTrips.first : null;
    }
  }
}
