import './driver_assignment_model.dart';
import './customer_bootstrap_model.dart' show HomeDriver;

class TransportationSegmentModel {
  final int id;
  final String segmentType;
  final String pickupLocation;
  final String dropoffLocation;
  final String pickupTime;
  final String date;
  final String? description;
  final String status;
  final DriverAssignment? driverAssignment;
  final HomeDriver? homeDriver;
  final String? notes;
  final String? endTime;
  final String? city;
  final String? title;

  // Extended Odoo fields for Driver Home
  final String? tripReference;
  final String? customerName;
  final String? flightNumber;
  final String? flightAirline;
  final String? vehicleDisplayName;
  final String? vehiclePlate;
  final String? vehicleColor;
  final String? customerPhone;
  final int? passengers;
  final String? flightArrivalTime;
  final String imageUrl;
  final bool driverAssigned;
  final String driverName;

  // Optional fields used by the Driver Home Tomorrow card
  final String? flightAirport;
  final String? flightDate;
  final int? tripId;

  // Optional exact pickup point (Odoo: pickup_address / pickup_lat /
  // pickup_lng / pickup_map_url, or nested pickup.address / latitude /
  // longitude). All may be empty.
  final String? pickupAddress;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupMapUrl;

  const TransportationSegmentModel({
    required this.id,
    required this.segmentType,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.pickupTime,
    required this.date,
    this.description,
    required this.status,
    this.driverAssignment,
    this.homeDriver,
    this.notes,
    this.endTime,
    this.city,
    this.title,
    this.tripReference,
    this.customerName,
    this.flightNumber,
    this.flightAirline,
    this.vehicleDisplayName,
    this.vehiclePlate,
    this.vehicleColor,
    this.customerPhone,
    this.passengers,
    this.flightArrivalTime,
    this.imageUrl = '',
    this.driverAssigned = false,
    this.driverName = '',
    this.flightAirport,
    this.flightDate,
    this.tripId,
    this.pickupAddress,
    this.pickupLat,
    this.pickupLng,
    this.pickupMapUrl,
  });

  static String? _optStr(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  static double? _optDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Google Maps directions URL to the exact pickup point, or null when
  /// no pickup latitude/longitude is available.
  String? get pickupNavigateUrl {
    if (pickupLat == null || pickupLng == null) return null;
    return 'https://www.google.com/maps/dir/?api=1&destination=$pickupLat,$pickupLng';
  }

  static int _int(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  /// Parses both the driver `next_today` / `assigned_segments[]` shape:
  /// {segment_id, trip_reference, date, pickup_time, pickup, destination,
  ///  description, vehicle:{model,color,plate_number}}
  /// and the legacy segment-details shape ({id, pickup_location, ...}).
  factory TransportationSegmentModel.fromJson(Map<String, dynamic> json) {
    final trip = json['trip'] as Map<String, dynamic>?;
    final flight = json['flight'] as Map<String, dynamic>?;
    final vehicle = json['vehicle'] as Map<String, dynamic>?;
    final customer = json['customer'] as Map<String, dynamic>?;
    final pickupObj = json['pickup'] is Map<String, dynamic>
        ? json['pickup'] as Map<String, dynamic>
        : null;

    final vehicleModel = vehicle?['model'] ?? vehicle?['display_name'];

    return TransportationSegmentModel(
      id: _int(json['segment_id'] ?? json['id']),
      segmentType: json['segment_type']?.toString() ?? 'transfer',
      pickupLocation: pickupObj != null
          ? (pickupObj['city'] ??
                    pickupObj['name'] ??
                    json['pickup_location'] ??
                    '')
                .toString()
          : (json['pickup'] ?? json['pickup_location'] ?? '').toString(),
      dropoffLocation: (json['destination'] ?? json['dropoff_location'] ?? '')
          .toString(),
      pickupTime: (json['pickup_time'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      description: _optStr(json['description']),
      status: json['status']?.toString() ?? 'scheduled',
      driverAssignment: json['driver_assignment'] is Map<String, dynamic>
          ? DriverAssignment.fromJson(
              json['driver_assignment'] as Map<String, dynamic>,
            )
          : null,
      notes: _optStr(json['notes']),
      tripReference: _optStr(
        json['trip_reference'] ?? (trip != null ? trip['reference'] : null),
      ),
      customerName: _optStr(
        json['customer_name'] ?? (customer != null ? customer['name'] : null),
      ),
      flightNumber: _optStr(
        json['flight_number'] ??
            (flight != null
                ? (flight['number'] ?? flight['flight_number'])
                : null),
      ),
      flightAirline: _optStr(
        json['flight_airline'] ?? (flight != null ? flight['airline'] : null),
      ),
      vehicleDisplayName: _optStr(json['vehicle_name'] ?? vehicleModel),
      vehiclePlate: _optStr(
        json['vehicle_plate'] ??
            (vehicle != null ? vehicle['plate_number'] : null),
      ),
      vehicleColor: _optStr(vehicle != null ? vehicle['color'] : null),
      customerPhone: _optStr(
        json['customer_phone'] ?? (customer != null ? customer['phone'] : null),
      ),
      passengers: customer != null && customer['passengers'] != null
          ? _int(customer['passengers'])
          : null,
      flightArrivalTime: _optStr(
        flight != null ? flight['arrival_time'] : null,
      ),
      flightAirport: _optStr(
        json['flight_airport'] ??
            (flight != null
                ? (flight['airport'] ?? flight['arrival_airport'])
                : null),
      ),
      flightDate: _optStr(
        json['flight_date'] ??
            (flight != null
                ? (flight['date'] ?? flight['arrival_date'])
                : null),
      ),
      tripId: json['trip_id'] != null
          ? _int(json['trip_id'])
          : (trip != null && trip['id'] != null ? _int(trip['id']) : null),
      pickupAddress: _optStr(
        json['pickup_address'] ??
            (pickupObj != null ? pickupObj['address'] : null),
      ),
      pickupLat: _optDouble(
        json['pickup_lat'] ??
            (pickupObj != null
                ? (pickupObj['latitude'] ?? pickupObj['lat'])
                : null),
      ),
      pickupLng: _optDouble(
        json['pickup_lng'] ??
            (pickupObj != null
                ? (pickupObj['longitude'] ?? pickupObj['lng'])
                : null),
      ),
      pickupMapUrl: _optStr(json['pickup_map_url']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'segment_type': segmentType,
    'pickup_location': pickupLocation,
    'dropoff_location': dropoffLocation,
    'pickup_time': pickupTime,
    'date': date,
    'description': description,
    'status': status,
    'driver_assignment': driverAssignment?.toJson(),
    'notes': notes,
    'trip_reference': tripReference,
    'customer_name': customerName,
    'flight_number': flightNumber,
    'flight_airline': flightAirline,
    'vehicle_name': vehicleDisplayName,
    'vehicle_plate': vehiclePlate,
  };

  bool get hasDriver => driverAssignment != null;

  bool get isCompleted => status == 'completed' || status == 'done';
  bool get isActive => status == 'active' || status == 'in_progress';
  bool get isScheduled =>
      status == 'scheduled' || status == 'confirmed' || status == 'assigned';
}
