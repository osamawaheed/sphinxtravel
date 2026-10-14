import './driver_assignment_model.dart';
import './extra_service_model.dart';
import './hotel_model.dart';
import './transportation_segment_model.dart';
import './trip_model.dart';
import './vehicle_model.dart';

String _s(dynamic v) {
  if (v == null) return '';
  return v.toString();
}

String? _sOrNull(dynamic v) {
  final s = _s(v).trim();
  return s.isEmpty ? null : s;
}

int _i(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

Map<String, dynamic>? _map(dynamic v) {
  if (v is Map) return Map<String, dynamic>.from(v);
  return null;
}

List<Map<String, dynamic>> _mapList(dynamic v) {
  if (v is! List) return [];
  return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

class CustomerBootstrapModel {
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? avatarUrl;
  final List<TripModel> trips;
  final String? currentTripId;
  final double? accountBalance;
  final String currency;

  const CustomerBootstrapModel({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.avatarUrl,
    required this.trips,
    this.currentTripId,
    this.accountBalance,
    required this.currency,
  });

  factory CustomerBootstrapModel.fromJson(Map<String, dynamic> json) {
    final customer = _map(json['customer']) ?? <String, dynamic>{};
    final activeTripJson = _map(json['active_trip']);
    final trip = activeTripJson != null
        ? _tripFromActiveTrip(activeTripJson)
        : null;

    return CustomerBootstrapModel(
      customerId: _i(customer['id']),
      customerName: _s(customer['name']),
      customerPhone: _sOrNull(customer['phone']),
      customerEmail: _sOrNull(customer['email']),
      avatarUrl: _sOrNull(customer['avatar_url']),
      trips: trip != null ? [trip] : [],
      currentTripId: trip?.id.toString(),
      accountBalance: null,
      currency: 'USD',
    );
  }

  static ItineraryItem _itemFromJson(Map<String, dynamic> json) {
    final driver = _map(json['driver']);
    return ItineraryItem(
      time: _s(json['time']),
      title: _s(json['title']),
      location: _sOrNull(json['location']),
      type: _sOrNull(json['type']) ?? 'activity',
      status: 'upcoming',
      description: _sOrNull(json['subtitle']),
      driver: driver,
    );
  }

  static DriverAssignment? _driverFromJson(Map<String, dynamic>? d) {
    if (d == null) return null;
    if (d['assigned'] != true) return null;
    final model = _sOrNull(d['vehicle_model']);
    final color = _s(d['vehicle_color']);
    final plate = _s(d['plate_number']);
    VehicleModel? vehicle;
    if (model != null || color.isNotEmpty || plate.isNotEmpty) {
      final parts = (model ?? '').split(' ');
      final make = parts.isNotEmpty ? parts.first : '';
      final rest = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      vehicle = VehicleModel(
        id: 0,
        make: make,
        model: rest,
        color: color,
        plateNumber: plate,
        vehicleType: 'sedan',
      );
    }
    return DriverAssignment(
      driverId: _i(d['id']),
      driverName: _s(d['name']),
      driverPhone: _sOrNull(d['phone']),
      driverPhotoUrl: _sOrNull(d['photo_url']),
      rating: (d['rating'] is num) ? (d['rating'] as num).toDouble() : null,
      totalTrips: d['trip_count'] is num
          ? (d['trip_count'] as num).toInt()
          : null,
      vehicle: vehicle,
    );
  }

  static TripModel _tripFromActiveTrip(Map<String, dynamic> t) {
    final totalDays = _i(t['total_days'], _i(t['days'], 1));
    final dayOfTour = _i(t['day_of_tour'], 1);

    // Next pickup -> single transportation segment
    final nextPickup = _map(t['next_pickup']);
    final segments = <TransportationSegmentModel>[];
    if (nextPickup != null) {
      segments.add(
        TransportationSegmentModel(
          id: _i(nextPickup['segment_id']),
          segmentType: 'transfer',
          pickupLocation: _s(nextPickup['pickup']),
          dropoffLocation: _s(nextPickup['destination']),
          pickupTime: _s(nextPickup['time']),
          date: _s(nextPickup['date']),
          description: _sOrNull(nextPickup['eta_text']),
          status: 'scheduled',
          driverAssignment: _driverFromJson(_map(nextPickup['driver'])),
          notes: _sOrNull(nextPickup['title']),
        ),
      );
    }

    final todayPlan = _mapList(t['today_plan']).map(_itemFromJson).toList();
    final tomorrowJson = _map(t['tomorrow']);
    final tomorrow = tomorrowJson != null
        ? <ItineraryItem>[_itemFromJson(tomorrowJson)]
        : <ItineraryItem>[];

    final hotels = _mapList(t['hotels'])
        .map(
          (h) => HotelModel(
            id: _i(h['id']),
            name: _s(h['title']),
            location: _s(h['location']),
            checkIn: '',
            checkOut: '',
            nights: 0,
          ),
        )
        .toList();

    final extraServices = _mapList(t['extra_services'])
        .map(
          (e) => ExtraServiceModel(
            id: _i(e['id']),
            name: _s(e['title']),
            serviceType: _sOrNull(e['type']) ?? 'service',
            description: _sOrNull(e['subtitle']),
            quantity: 1,
            status: 'active',
          ),
        )
        .toList();

    final destination = _s(t['destination']);
    final status = _s(t['status']);

    return TripModel(
      id: _i(t['id']),
      reference: _s(t['reference']),
      name: destination,
      destination: destination,
      startDate: _s(t['arrival_date']),
      endDate: _s(t['departure_date']),
      totalDays: totalDays <= 0 ? 1 : totalDays,
      currentDay: dayOfTour,
      status: 'active',
      heroImageUrl: null,
      description: _sOrNull(t['notes']),
      flights: const [],
      hotels: hotels,
      transportationSegments: segments,
      extraServices: extraServices,
      todayItinerary: todayPlan,
      tomorrowItinerary: tomorrow,
      tripState: status == 'completed' ? 'completed' : 'in_progress',
      arrivalDate: _sOrNull(t['arrival_date']),
      departureDate: _sOrNull(t['departure_date']),
      passengerCount: t['passengers'] is num
          ? (t['passengers'] as num).toInt()
          : null,
    );
  }

  TripModel? get activeTrip => trips.isNotEmpty ? trips.first : null;

  String get firstName {
    final trimmed = customerName.trim();
    if (trimmed.isEmpty) return trimmed;
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts[0] : trimmed;
  }
}
