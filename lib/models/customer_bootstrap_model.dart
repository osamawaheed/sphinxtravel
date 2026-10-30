import './driver_assignment_model.dart';
import './extra_service_model.dart';
import './flight_model.dart';
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

/// Reads the first non-empty value among [keys] (exact values from Odoo).
String _firstOf(Map<String, dynamic> j, List<String> keys) {
  for (final k in keys) {
    final v = _s(j[k]).trim();
    if (v.isNotEmpty) return v;
  }
  return '';
}

const List<String> _hotelPhoneKeys = [
  'phone',
  'hotel_phone',
  'mobile',
  'hotel_mobile',
];
const List<String> _hotelMapKeys = [
  'hotel_location_gps',
  'hotel_location',
  'location_gps',
  'gps_url',
  'google_map_url',
  'google_map',
  'google_maps_url',
  'map_url',
  'google_map_link',
  'map_link',
];

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
  final CustomerHomeTrip? homeTrip;

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
    this.homeTrip,
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
      homeTrip: activeTripJson != null
          ? CustomerHomeTrip.fromJson(activeTripJson)
          : null,
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

    // Transportation list -> one segment per movement
    final segments = <TransportationSegmentModel>[];
    final transportList = t['transportation'];
    if (transportList is List) {
      for (final m in _mapList(transportList)) {
        final drv = _map(m['driver']);
        segments.add(
          TransportationSegmentModel(
            id: _i(m['id']),
            segmentType: 'transfer',
            pickupLocation: '',
            dropoffLocation: '',
            pickupTime: _s(m['time']),
            date: _s(m['date']),
            description: _sOrNull(m['description']),
            status: _s(m['status']),
            driverAssignment: _driverFromJson(drv),
            homeDriver: _homeDriverFrom(drv),
            notes: _sOrNull(m['title']),
            endTime: _sOrNull(m['end_time']),
            city: _sOrNull(m['subtitle']),
            title: _sOrNull(m['title']),
          ),
        );
      }
    } else {
      final nextPickup = _map(t['next_pickup']);
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
            homeDriver: _homeDriverFrom(_map(nextPickup['driver'])),
            notes: _sOrNull(nextPickup['title']),
            title: _sOrNull(nextPickup['title']),
          ),
        );
      }
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
            name: _s(h['title']).isNotEmpty ? _s(h['title']) : _s(h['name']),
            location: _s(h['location']).isNotEmpty
                ? _s(h['location'])
                : _s(h['city']),
            checkIn: _s(h['check_in']),
            checkOut: _s(h['check_out']),
            nights: _i(h['nights']),
            phone: _sOrNull(_firstOf(h, _hotelPhoneKeys)),
            googleMapUrl: _sOrNull(_firstOf(h, _hotelMapKeys)),
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
            quantity: e['qty'] == null ? 0 : _i(e['qty']),
            status: 'active',
            deliveryDate: _sOrNull(e['date']),
          ),
        )
        .toList();

    final flights = _mapList(t['flights']).map((f) {
      return FlightModel(
        id: _i(f['id']),
        flightNumber: _s(f['flight_no']).isNotEmpty
            ? _s(f['flight_no'])
            : _s(f['flight_number']),
        airline: _s(f['airline']),
        origin: '',
        destination: '',
        departureTime: _s(f['time']),
        arrivalTime: '',
        departureDate: _s(f['date']),
        status: 'scheduled',
        direction: _sOrNull(f['direction']),
        date: _sOrNull(f['date']),
        time: _sOrNull(f['time']),
        airport: _sOrNull(f['airport']),
      );
    }).toList();

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
      flights: flights,
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

// ─── Customer Home (active_trip) data ────────────────────────────────────────

double? _d(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

class HomeMyRating {
  final int rating;
  final int rating10;
  final String comment;

  const HomeMyRating({
    required this.rating,
    this.rating10 = 0,
    required this.comment,
  });

  static HomeMyRating? fromJsonOrNull(dynamic v) {
    final m = _map(v);
    if (m == null) return null;
    final r = _i(m['rating']);
    final r10 = _i(m['rating_10']);
    if (r <= 0 && r10 <= 0) return null;
    return HomeMyRating(
      rating: r.clamp(0, 5),
      rating10: r10.clamp(0, 10),
      comment: _s(m['comment']),
    );
  }
}

class HomeDriver {
  final int id;
  final String photoUrl;
  final String name;
  final double? rating;
  final double? rating10;
  final int? ratingCount;
  final int? tripCount;
  final String vehicleModel;
  final String vehicleYear;
  final String vehicleColor;
  final String plateNumber;
  final String phone;
  final bool hasAppAccount;
  final HomeMyRating? myRating;
  final List<String> vehiclePhotos;
  final List<String> driverPhotos;
  final double? latitude;
  final double? longitude;

  const HomeDriver({
    this.id = 0,
    required this.photoUrl,
    required this.name,
    this.rating,
    this.rating10,
    this.ratingCount,
    this.tripCount,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleColor,
    this.plateNumber = '',
    required this.phone,
    this.hasAppAccount = true,
    this.myRating,
    this.vehiclePhotos = const [],
    this.driverPhotos = const [],
    this.latitude,
    this.longitude,
  });

  static List<String> _driverPhotoList(Map<String, dynamic> j) {
    final out = <String>[];
    void add(dynamic v) {
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty && !out.contains(s)) out.add(s);
      } else if (v is Map) {
        add(v['url'] ?? v['photo_url'] ?? v['image_url']);
      } else if (v is List) {
        for (final e in v) {
          add(e);
        }
      }
    }

    // Driver-specific gallery keys only (never vehicle data).
    for (final k in const [
      'personal_photos',
      'driver_photos',
      'driver_photo_urls',
      'driver_images',
    ]) {
      add(j[k]);
    }
    // Single profile photo is used only when no gallery is provided.
    if (out.isEmpty) add(j['photo_url']);
    return out.take(3).toList();
  }

  static List<String> _photoList(Map<String, dynamic> j) {
    final out = <String>[];
    void add(dynamic v) {
      if (v is String) {
        final s = v.trim();
        if (s.isNotEmpty && !out.contains(s)) out.add(s);
      } else if (v is Map) {
        add(v['url'] ?? v['photo_url'] ?? v['image_url']);
      } else if (v is List) {
        for (final e in v) {
          add(e);
        }
      }
    }

    // Vehicle-specific keys only (assigned vehicle record).
    for (final k in const [
      'vehicle_photos',
      'vehicle_photo_urls',
      'vehicle_images',
      'vehicle_image_urls',
      'vehicle_photo_url',
      'vehicle_image_url',
      'vehicle_image',
      'vehicle_photo',
    ]) {
      add(j[k]);
    }
    final vehicle = _map(j['vehicle']);
    if (vehicle != null) {
      for (final k in const [
        'photos',
        'photo_urls',
        'images',
        'image_urls',
        'photo_url',
        'image_url',
        'image',
        'photo',
      ]) {
        add(vehicle[k]);
      }
    }
    return out.take(5).toList();
  }

  static double? _coord(Map<String, dynamic> j, List<String> keys) {
    for (final k in keys) {
      final v = _d(j[k]);
      if (v != null) return v;
    }
    final loc = _map(j['location'] ?? j['current_location'] ?? j['gps']);
    if (loc != null) {
      for (final k in keys) {
        final v = _d(loc[k]);
        if (v != null) return v;
      }
    }
    return null;
  }

  factory HomeDriver.fromJson(Map<String, dynamic> j) => HomeDriver(
    id: _i(j['id']),
    photoUrl: _s(j['photo_url']),
    name: _s(j['name']),
    rating: _d(j['rating']),
    rating10: _d(j['rating_10']),
    ratingCount: j['rating_count'] == null ? null : _i(j['rating_count']),
    tripCount: j['trip_count'] == null ? null : _i(j['trip_count']),
    vehicleModel: _s(j['vehicle_model']),
    vehicleYear: _s(j['vehicle_year']) == '0' ? '' : _s(j['vehicle_year']),
    vehicleColor: _s(j['vehicle_color']),
    plateNumber: _s(
      j['plate_number'] ?? j['license_plate'] ?? j['vehicle_plate'],
    ),
    phone: _s(j['phone']),
    hasAppAccount: j['has_app_account'] != false,
    myRating: HomeMyRating.fromJsonOrNull(j['my_rating']),
    vehiclePhotos: _photoList(j),
    driverPhotos: _driverPhotoList(j),
    latitude: _coord(j, const ['latitude', 'lat', 'current_lat']),
    longitude: _coord(j, const ['longitude', 'lng', 'lon', 'current_lng']),
  );
}

HomeDriver? _homeDriverFrom(Map<String, dynamic>? d) {
  if (!_hasAssignedDriver(d)) return null;
  return HomeDriver.fromJson(d!);
}

/// A driver counts as assigned when Odoo sends a name, or an id with
/// `assigned != false`. `assigned: false` always means unassigned.
bool _hasAssignedDriver(Map<String, dynamic>? d) {
  if (d == null) return false;
  if (d['assigned'] == false) return false;
  if (_s(d['name']).trim().isNotEmpty) return true;
  if (_s(d['driver_name']).trim().isNotEmpty) return true;
  return d['assigned'] == true && _i(d['id']) > 0;
}

/// Picks the driver map of a transportation service, tolerating alternate keys.
Map<String, dynamic>? _driverMapOf(Map<String, dynamic> j) {
  final d = _map(j['driver']) ?? _map(j['assigned_driver']);
  if (d == null) return null;
  if (_s(d['name']).trim().isEmpty && _s(d['driver_name']).trim().isNotEmpty) {
    return {...d, 'name': d['driver_name']};
  }
  return d;
}

class HomeNextPickup {
  final String time;
  final String title;
  final String etaText;
  final String pickup;
  final String destination;
  final HomeDriver? driver;
  final String progressStatus;
  final double? pickupLat;
  final double? pickupLng;
  final int transportationId;
  final bool? canRate;

  /// Optional live-tracking scheduling data. Only values Odoo actually sends
  /// are stored; nothing is assumed.
  final HomePickupTrackingInfo trackingInfo;

  const HomeNextPickup({
    required this.time,
    required this.title,
    required this.etaText,
    required this.pickup,
    required this.destination,
    this.driver,
    this.progressStatus = '',
    this.pickupLat,
    this.pickupLng,
    this.transportationId = 0,
    this.canRate,
    this.trackingInfo = const HomePickupTrackingInfo(),
  });

  factory HomeNextPickup.fromJson(Map<String, dynamic> j) {
    final d = _driverMapOf(j);
    final hasDriver = _hasAssignedDriver(d);
    final pl = _map(j['pickup_location'] ?? j['pickup_coords']);
    return HomeNextPickup(
      transportationId: _i(j['segment_id'] ?? j['id']),
      canRate: _canRateOf(j),
      trackingInfo: HomePickupTrackingInfo.fromJson(j),
      time: _firstOf(j, _pickupTimeKeys),
      title: _s(j['title']),
      etaText: _s(j['eta_text']),
      pickup: _s(j['pickup']),
      destination: _resolveDestination(j),
      driver: hasDriver ? HomeDriver.fromJson(d!) : null,
      progressStatus: _firstOf(j, const [
        'trip_progress',
        'progress_status',
        'trip_status',
        'progress',
        'status',
      ]),
      pickupLat:
          _d(j['pickup_lat'] ?? j['pickup_latitude']) ??
          (pl != null ? _d(pl['latitude'] ?? pl['lat']) : null),
      pickupLng:
          _d(j['pickup_lng'] ?? j['pickup_longitude']) ??
          (pl != null ? _d(pl['longitude'] ?? pl['lng'] ?? pl['lon']) : null),
    );
  }

  /// Builds the Driver Pickup card data from an upcoming transportation
  /// service of `transportation[]` (used when `next_pickup` is absent or has
  /// no driver although the service has one).
  factory HomeNextPickup.fromTransportation(Map<String, dynamic> m) {
    final d = _driverMapOf(m);
    final hasDriver = _hasAssignedDriver(d);
    final pl = _map(m['pickup_location'] ?? m['pickup_coords']);
    return HomeNextPickup(
      transportationId: _i(m['segment_id'] ?? m['id']),
      canRate: _canRateOf(m),
      trackingInfo: HomePickupTrackingInfo.fromJson(m),
      time: _firstOf(m, _pickupTimeKeys),
      title: _s(m['title']),
      etaText: _s(m['eta_text']),
      pickup: _firstOf(m, const ['pickup', 'pickup_location']),
      destination: _resolveDestination(m),
      driver: hasDriver ? HomeDriver.fromJson(d!) : null,
      progressStatus: _firstOf(m, const [
        'trip_progress',
        'progress_status',
        'trip_status',
        'progress',
        'status',
      ]),
      pickupLat:
          _d(m['pickup_lat'] ?? m['pickup_latitude']) ??
          (pl != null ? _d(pl['latitude'] ?? pl['lat']) : null),
      pickupLng:
          _d(m['pickup_lng'] ?? m['pickup_longitude']) ??
          (pl != null ? _d(pl['longitude'] ?? pl['lng'] ?? pl['lon']) : null),
    );
  }

  HomeNextPickup copyWith({String? time, String? destination}) =>
      HomeNextPickup(
        time: time ?? this.time,
        title: title,
        etaText: etaText,
        pickup: pickup,
        destination: destination ?? this.destination,
        driver: driver,
        progressStatus: progressStatus,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        transportationId: transportationId,
        canRate: canRate,
        trackingInfo: trackingInfo,
      );

  /// Merges a driver found on the matching transportation service.
  HomeNextPickup withDriver(HomeDriver? d) => HomeNextPickup(
    time: time,
    title: title,
    etaText: etaText,
    pickup: pickup,
    destination: destination,
    driver: d,
    progressStatus: progressStatus,
    pickupLat: pickupLat,
    pickupLng: pickupLng,
    transportationId: transportationId,
    canRate: canRate,
    trackingInfo: trackingInfo,
  );
}

/// Optional tracking scheduling fields of a pickup, read only when Odoo sends
/// them (`pickup_datetime`, `tracking_eligible`, `tracking_window_start`,
/// `segment_type`, `date`). See the backend requirements for the Odoo
/// developer.
class HomePickupTrackingInfo {
  final String date;
  final String pickupDatetime;
  final String segmentType;
  final bool? trackingEligible;
  final String trackingWindowStart;

  const HomePickupTrackingInfo({
    this.date = '',
    this.pickupDatetime = '',
    this.segmentType = '',
    this.trackingEligible,
    this.trackingWindowStart = '',
  });

  factory HomePickupTrackingInfo.fromJson(Map<String, dynamic> j) {
    final e = j['tracking_eligible'];
    return HomePickupTrackingInfo(
      date: _firstOf(j, const ['date', 'pickup_date']),
      pickupDatetime: _firstOf(j, const ['pickup_datetime', 'scheduled_at']),
      segmentType: _firstOf(j, const ['segment_type', 'type']),
      trackingEligible: e is bool ? e : null,
      trackingWindowStart: _firstOf(j, const ['tracking_window_start']),
    );
  }
}

/// Reads an explicit review-eligibility flag only when Odoo sends one.
/// Returns null when no such flag exists (eligibility is then decided by Odoo
/// when the review is submitted).
bool? _canRateOf(Map<String, dynamic> j) {
  for (final k in const ['can_rate', 'can_review', 'can_rate_driver']) {
    final v = j[k];
    if (v is bool) return v;
  }
  return null;
}

/// Keys under which Odoo may send the pickup time of a transportation service.
const List<String> _pickupTimeKeys = [
  'time',
  'pickup_time',
  'start_time',
  'scheduled_time',
];

/// Resolves the destination of a transportation service from the Odoo data of
/// that service: the destination city for the day (tour / hotel transfer /
/// arrival airport / departure airport) when Odoo sends it, otherwise the
/// service's own destination. Returns '' when Odoo sends nothing, so no wrong
/// city is ever shown.
String _resolveDestination(Map<String, dynamic> j) {
  final hotel = _map(j['destination_hotel'] ?? j['dropoff_hotel']);
  final airport = _map(j['destination_airport'] ?? j['dropoff_airport']);
  final candidates = <String>[
    _firstOf(j, const [
      'destination_city',
      'dropoff_city',
      'to_city',
      'day_destination',
      'destination',
      'dropoff_location',
    ]),
    if (hotel != null) _firstOf(hotel, const ['city', 'location', 'name']),
    if (airport != null) _firstOf(airport, const ['city', 'name']),
    _firstOf(j, const [
      'destination_hotel_city',
      'hotel_city',
      'airport_city',
      'arrival_airport_city',
      'departure_airport_city',
    ]),
  ];
  for (final c in candidates) {
    if (c.trim().isNotEmpty) return c.trim();
  }
  return '';
}

/// Resolves the Driver Pickup card data. Odoo's `next_pickup` is used when
/// present; the assigned driver is read from the matching transportation
/// service (by segment id) when `next_pickup.driver` is empty. When
/// `next_pickup` is missing, the earliest non-completed transportation
/// service is used so the card is shown whenever a service is upcoming.
HomeNextPickup? _resolveNextPickup(
  Map<String, dynamic>? pickup,
  List<Map<String, dynamic>> transportation,
) {
  bool isOpen(Map<String, dynamic> m) {
    final s = _s(m['status']).toLowerCase();
    return s != 'completed' && s != 'done' && s != 'cancelled';
  }

  if (pickup != null) {
    var result = HomeNextPickup.fromJson(pickup);
    if (result.driver == null) {
      final segId = _i(pickup['segment_id'] ?? pickup['id'], -1);
      Map<String, dynamic>? match;
      if (segId >= 0) {
        for (final m in transportation) {
          if (_i(m['id'], -2) == segId) {
            match = m;
            break;
          }
        }
      }
      if (match != null) {
        result = result.withDriver(
          _hasAssignedDriver(_driverMapOf(match))
              ? HomeDriver.fromJson(_driverMapOf(match)!)
              : null,
        );
      }
    }
    // Prefer the matching transportation service's own day-specific
    // destination and time over trip-wide values.
    final segId = _i(pickup['segment_id'] ?? pickup['id'], -1);
    if (segId >= 0) {
      for (final m in transportation) {
        if (_i(m['id'], -2) == segId) {
          final dest = _resolveDestination(m);
          final time = _firstOf(m, _pickupTimeKeys);
          result = result
              .withDriver(result.driver)
              .copyWith(
                destination: dest.isNotEmpty ? dest : null,
                time: result.time.isEmpty && time.isNotEmpty ? time : null,
              );
          break;
        }
      }
    }
    return result;
  }

  for (final m in transportation) {
    if (isOpen(m)) return HomeNextPickup.fromTransportation(m);
  }
  return null;
}

class HomeFlight {
  final String airline;
  final String flightNo;
  final String date;
  final String time;
  final String airport;

  const HomeFlight({
    required this.airline,
    required this.flightNo,
    required this.date,
    required this.time,
    required this.airport,
  });

  factory HomeFlight.fromJson(Map<String, dynamic> j) => HomeFlight(
    airline: _s(j['airline']),
    flightNo: _s(j['flight_no']),
    date: _s(j['date']),
    time: _s(j['time']),
    airport: _s(j['airport']),
  );
}

class HomeHotel {
  final int id;
  final String imageUrl;
  final String name;
  final String city;
  final String country;
  final int night;
  final int totalNights;
  final String checkIn;
  final String checkOut;
  final String phone;
  final String googleMapUrl;
  final String address;
  final HomeMyRating? myRating;

  const HomeHotel({
    this.id = 0,
    required this.imageUrl,
    required this.name,
    required this.city,
    required this.country,
    required this.night,
    required this.totalNights,
    this.checkIn = '',
    required this.checkOut,
    this.phone = '',
    this.googleMapUrl = '',
    this.address = '',
    this.myRating,
  });

  factory HomeHotel.fromJson(Map<String, dynamic> j) => HomeHotel(
    id: _i(j['id']),
    imageUrl: _s(j['image_url']),
    name: _s(j['name']),
    city: _s(j['city']),
    country: _s(j['country']),
    night: _i(j['night']),
    totalNights: _i(j['total_nights']),
    checkIn: _s(j['check_in'] ?? j['checkin'] ?? j['check_in_date']).trim(),
    checkOut: _s(j['check_out']),
    phone: _firstOf(j, _hotelPhoneKeys),
    googleMapUrl: _firstOf(j, _hotelMapKeys),
    address: _s(j['address']).trim(),
    myRating: HomeMyRating.fromJsonOrNull(j['my_rating']),
  );
}

class HomePlanItem {
  final int id;
  final String time;
  final String endTime;
  final String title;
  final String subtitle;
  final String imageUrl;
  final HomeDriver? driver;
  final String type;
  final String status;
  final bool driverAssigned;
  final String driverName;
  final String date;

  const HomePlanItem({
    this.id = 0,
    required this.time,
    required this.endTime,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.driver,
    this.type = '',
    this.status = '',
    this.driverAssigned = false,
    this.driverName = '',
    this.date = '',
  });

  factory HomePlanItem.fromJson(Map<String, dynamic> j) {
    final drv = _map(j['driver']);
    return HomePlanItem(
      id: _i(j['id']),
      time: _s(j['time']),
      endTime: _s(j['end_time']),
      title: _s(j['title']),
      subtitle: _s(j['subtitle']),
      imageUrl: _s(j['image_url']),
      driver: _homeDriverFrom(drv),
      type: _s(j['type']),
      status: _s(j['status']),
      driverAssigned: drv != null && drv['assigned'] != false,
      driverName: drv == null ? '' : _s(drv['name']).trim(),
    );
  }
}

/// One hotel stay of a booking (name + check-in / check-out dates).
class HomeStayHotel {
  final int id;
  final String name;
  final String city;
  final String checkIn;
  final String checkOut;
  final String phone;
  final String googleMapUrl;
  final String address;

  const HomeStayHotel({
    this.id = 0,
    required this.name,
    this.city = '',
    this.checkIn = '',
    this.checkOut = '',
    this.phone = '',
    this.googleMapUrl = '',
    this.address = '',
  });

  factory HomeStayHotel.fromJson(Map<String, dynamic> j) {
    final title = _s(j['title']).trim();
    return HomeStayHotel(
      id: _i(j['id']),
      name: _s(j['name']).trim().isNotEmpty ? _s(j['name']).trim() : title,
      city: _s(j['city']).trim().isNotEmpty
          ? _s(j['city']).trim()
          : _s(j['location']).trim(),
      checkIn: _s(j['check_in'] ?? j['checkin'] ?? j['check_in_date']).trim(),
      checkOut: _s(
        j['check_out'] ?? j['checkout'] ?? j['check_out_date'],
      ).trim(),
      phone: _firstOf(j, _hotelPhoneKeys),
      googleMapUrl: _firstOf(j, _hotelMapKeys),
      address: _s(j['address']).trim(),
    );
  }
}

class HomeCustomer {
  final String name;
  final String phone;
  final String whatsapp;

  /// Odoo customer id and profile photo, only when the API returns them.
  final int id;
  final String photoUrl;

  const HomeCustomer({
    required this.name,
    required this.phone,
    required this.whatsapp,
    this.id = 0,
    this.photoUrl = '',
  });

  factory HomeCustomer.fromJson(Map<String, dynamic> j) => HomeCustomer(
    name: _s(j['name']),
    phone: _s(j['phone']),
    whatsapp: _s(j['whatsapp']),
    id: _i(j['id']),
    photoUrl: _s(j['avatar_url']).isNotEmpty
        ? _s(j['avatar_url'])
        : (_s(j['photo_url']).isNotEmpty
              ? _s(j['photo_url'])
              : _s(j['image_url'])),
  );
}

class HomeExtraService {
  final int id;
  final String title;
  final String date;
  final int qty;
  final String type;
  final String status;

  /// Customer receipt state from Odoo, kept separate from the driver's
  /// delivery [status]: `none` | `received` | `not_received_reported`.
  final String customerReceiptStatus;
  final String customerReceivedAt;
  final String customerReportedAt;
  final int activeIssueId;

  /// Delivery confirmation details exactly as stored in Odoo 17.
  /// [deliveryConfirmedBy] is `customer` | `driver` | ''.
  final String deliveryConfirmedBy;
  final String deliveryConfirmedAt;
  final int deliveryConfirmedQty;

  const HomeExtraService({
    this.id = 0,
    required this.title,
    required this.date,
    required this.qty,
    this.type = '',
    this.status = '',
    this.customerReceiptStatus = '',
    this.customerReceivedAt = '',
    this.customerReportedAt = '',
    this.activeIssueId = 0,
    this.deliveryConfirmedBy = '',
    this.deliveryConfirmedAt = '',
    this.deliveryConfirmedQty = 0,
  });

  bool get isSimCard {
    final t = type.toLowerCase();
    if (t == 'sim_card' || t == 'esim' || t == 'sim' || t == 'flowers') {
      return true;
    }
    final n = title.toLowerCase();
    return n.contains('esim') || n.contains('e-sim') || n.contains('sim card');
  }

  bool get isESim {
    final t = type.toLowerCase();
    final n = title.toLowerCase();
    return t == 'esim' || n.contains('esim') || n.contains('e-sim');
  }

  bool get isFlowers => type.toLowerCase() == 'flowers';

  bool get isDelivered => status.toLowerCase() == 'delivered';

  /// Customer confirmed receipt (Odoo record, not the driver's delivery).
  bool get isCustomerReceived =>
      customerReceiptStatus.toLowerCase() == 'received' ||
      customerReceivedAt.isNotEmpty;

  /// An active "not received" report exists in Odoo.
  bool get isNotReceivedReported =>
      !isCustomerReceived &&
      (customerReceiptStatus.toLowerCase() == 'not_received_reported' ||
          activeIssueId > 0);

  /// True only for a real confirmation stored in Odoo: the customer confirmed
  /// receipt or the driver confirmed delivery. "Not received" never counts.
  bool get isSimConfirmed => isCustomerReceived || isDelivered;

  /// Who confirmed: `customer` or `driver` ('' when not confirmed).
  String get confirmedByRole {
    if (!isSimConfirmed) return '';
    final by = deliveryConfirmedBy.toLowerCase();
    if (by.contains('customer')) return 'customer';
    if (by.contains('driver')) return 'driver';
    if (isCustomerReceived) return 'customer';
    return 'driver';
  }

  /// Confirmation timestamp from Odoo ('' when Odoo did not provide one).
  String get confirmedAtText {
    if (!isSimConfirmed) return '';
    if (deliveryConfirmedAt.isNotEmpty) return deliveryConfirmedAt;
    if (confirmedByRole == 'customer') return customerReceivedAt;
    return '';
  }

  /// Confirmed SIM quantity from Odoo (falls back to the service quantity).
  int get confirmedQty => deliveryConfirmedQty > 0 ? deliveryConfirmedQty : qty;

  factory HomeExtraService.fromJson(Map<String, dynamic> j) => HomeExtraService(
    id: _i(j['id']),
    title: _s(j['title']),
    date: _s(j['date']),
    qty: j['qty'] == null ? 0 : _i(j['qty']),
    type: _s(j['type']),
    status: _s(j['status'] ?? j['delivery_status']),
    customerReceiptStatus: _s(j['customer_receipt_status']).trim(),
    customerReceivedAt: _s(j['customer_received_at']).trim(),
    customerReportedAt: _s(j['customer_reported_at']).trim(),
    activeIssueId: _i(j['active_issue_id']),
    deliveryConfirmedBy: _firstOf(j, [
      'confirmed_by',
      'delivery_confirmed_by',
      'sim_confirmed_by',
    ]),
    deliveryConfirmedAt: _firstOf(j, [
      'confirmed_at',
      'delivery_confirmed_at',
      'delivered_at',
      'sim_confirmed_at',
    ]),
    deliveryConfirmedQty: _i(
      j['confirmed_quantity'] ??
          j['delivered_quantity'] ??
          j['delivery_confirmed_qty'],
    ),
  );
}

/// One row of GET /api/v1/driver/trips
class DriverTripListItem {
  final int id;
  final String reference;
  final String city;
  final String destination;
  final String imageUrl;
  final String arrivalDate;
  final String departureDate;
  final String customerName;

  /// Customer Odoo id and profile photo from the same `customer` object
  /// (same keys as [HomeCustomer]); 0 / '' when the API does not return them.
  final int customerId;
  final String customerPhotoUrl;

  /// Customer phone from the same `customer.phone` key [HomeCustomer] reads
  /// (empty when the list endpoint does not return it).
  final String customerPhone;

  const DriverTripListItem({
    required this.id,
    required this.reference,
    required this.city,
    required this.destination,
    required this.imageUrl,
    required this.arrivalDate,
    required this.departureDate,
    required this.customerName,
    this.customerId = 0,
    this.customerPhotoUrl = '',
    this.customerPhone = '',
  });

  factory DriverTripListItem.fromJson(Map<String, dynamic> j) {
    final cust = _map(j['customer']);
    final avatar = cust == null ? '' : _s(cust['avatar_url']);
    final photo = cust == null ? '' : _s(cust['photo_url']);
    final image = cust == null ? '' : _s(cust['image_url']);
    return DriverTripListItem(
      id: _i(j['id']),
      reference: _s(j['reference']),
      city: _s(j['city']),
      destination: _s(j['destination']),
      imageUrl: _s(j['image_url']),
      arrivalDate: _s(j['arrival_date']),
      departureDate: _s(j['departure_date']),
      customerName: cust != null ? _s(cust['name']) : '',
      customerId: cust != null ? _i(cust['id']) : 0,
      customerPhone: cust != null ? _s(cust['phone']) : '',
      customerPhotoUrl: avatar.isNotEmpty
          ? avatar
          : (photo.isNotEmpty ? photo : image),
    );
  }

  /// GET /api/v1/driver/trips -> {"trips": [...]}
  static List<DriverTripListItem> listFromResponse(dynamic data) {
    final raw = data is Map ? data['trips'] : null;
    return _mapList(raw).map(DriverTripListItem.fromJson).toList();
  }
}

/// One entry of GET /api/v1/driver/ratings -> `ratings[]`
class DriverRatingItem {
  final String tripReference;
  final String customer;
  final double rating;
  final double rating10;
  final String comment;
  final String date;

  const DriverRatingItem({
    required this.tripReference,
    required this.customer,
    required this.rating,
    this.rating10 = 0,
    required this.comment,
    required this.date,
  });

  factory DriverRatingItem.fromJson(Map<String, dynamic> j) => DriverRatingItem(
    tripReference: _s(j['trip_reference']),
    customer: _s(j['customer']),
    rating: _d(j['rating']) ?? 0,
    rating10: _d(j['rating_10']) ?? 0,
    comment: _s(j['comment']),
    date: _s(j['date']),
  );
}

/// GET /api/v1/driver/ratings
/// {rating, rating_count, ratings:[{trip_reference, customer, rating, comment, date}]}
class DriverRatingsResult {
  final double rating;
  final double rating10;
  final int ratingCount;
  final List<DriverRatingItem> ratings;

  const DriverRatingsResult({
    required this.rating,
    this.rating10 = 0,
    required this.ratingCount,
    required this.ratings,
  });

  factory DriverRatingsResult.fromJson(Map<String, dynamic> j) {
    final items = _mapList(
      j['ratings'],
    ).map(DriverRatingItem.fromJson).toList();
    return DriverRatingsResult(
      rating: _d(j['rating']) ?? 0,
      rating10: _d(j['rating_10']) ?? 0,
      ratingCount: j['rating_count'] == null
          ? items.length
          : _i(j['rating_count']),
      ratings: items,
    );
  }
}

class CustomerHomeTrip {
  final int id;
  final String reference;
  final String city;
  final String destination;
  final String imageUrl;
  final int dayOfTour;
  final int totalDays;
  final String arrivalDate;
  final String departureDate;
  final int passengers;
  final String today;
  final String tomorrowDate;
  final HomeNextPickup? nextPickup;
  final HomeFlight? arrivalFlight;
  final HomeFlight? departureFlight;
  final HomeHotel? currentHotel;
  final List<HomePlanItem> todayPlan;
  final List<HomePlanItem> tomorrow;
  final HomeCustomer? customer;
  final List<int> mySegmentIds;
  final List<TransportationSegmentModel> transportation;
  final List<HomeExtraService> extraServices;
  final List<HomeStayHotel> hotels;
  final List<HomePlanItem> activities;

  /// Trip status exactly as returned by Odoo (empty when not provided).
  final String tripStatus;

  const CustomerHomeTrip({
    this.id = 0,
    required this.reference,
    required this.city,
    required this.destination,
    required this.imageUrl,
    required this.dayOfTour,
    required this.totalDays,
    required this.arrivalDate,
    required this.departureDate,
    required this.passengers,
    required this.today,
    required this.tomorrowDate,
    this.nextPickup,
    this.arrivalFlight,
    this.departureFlight,
    this.currentHotel,
    required this.todayPlan,
    required this.tomorrow,
    this.customer,
    this.mySegmentIds = const [],
    this.transportation = const [],
    this.extraServices = const [],
    this.hotels = const [],
    this.activities = const [],
    this.tripStatus = '',
  });

  factory CustomerHomeTrip.fromJson(Map<String, dynamic> t) {
    final pickup = _map(t['next_pickup']);
    final arr = _map(t['arrival_flight']);
    final dep = _map(t['departure_flight']);
    final hotel = _map(t['current_hotel']);
    final cust = _map(t['customer']);
    final segIds = t['my_segment_ids'];
    final total = _i(t['total_days'], _i(t['days'], 1));
    // `tomorrow` is a list; tolerate a legacy single object.
    final tomorrowRaw = t['tomorrow'];
    final tomorrowList = tomorrowRaw is Map
        ? <Map<String, dynamic>>[Map<String, dynamic>.from(tomorrowRaw)]
        : _mapList(tomorrowRaw);

    final hotelStays = _mapList(
      t['hotels'],
    ).map(HomeStayHotel.fromJson).where((h) => h.name.isNotEmpty).toList();
    if (hotelStays.isEmpty && hotel != null) {
      final h = HomeStayHotel.fromJson(hotel);
      if (h.name.isNotEmpty) hotelStays.add(h);
    }

    return CustomerHomeTrip(
      id: _i(t['id']),
      reference: _s(t['reference']),
      city: _s(t['city']),
      destination: _s(t['destination']),
      imageUrl: _s(t['image_url']),
      dayOfTour: _i(t['day_of_tour'], 1),
      totalDays: total <= 0 ? 1 : total,
      arrivalDate: _s(t['arrival_date']),
      departureDate: _s(t['departure_date']),
      passengers: _i(t['passengers']),
      today: _s(t['today']),
      tomorrowDate: _s(t['tomorrow_date']),
      nextPickup: _resolveNextPickup(pickup, _mapList(t['transportation'])),
      arrivalFlight: arr != null ? HomeFlight.fromJson(arr) : null,
      departureFlight: dep != null ? HomeFlight.fromJson(dep) : null,
      currentHotel: hotel != null ? HomeHotel.fromJson(hotel) : null,
      todayPlan: _mapList(t['today_plan']).map(HomePlanItem.fromJson).toList(),
      tomorrow: tomorrowList.map(HomePlanItem.fromJson).toList(),
      customer: cust != null ? HomeCustomer.fromJson(cust) : null,
      mySegmentIds: segIds is List
          ? segIds.map((e) => _i(e, -1)).where((e) => e >= 0).toList()
          : const [],
      transportation: _mapList(t['transportation']).map((m) {
        final drv = _map(m['driver']);
        return TransportationSegmentModel(
          id: _i(m['id']),
          segmentType: 'transfer',
          pickupLocation: '',
          dropoffLocation: '',
          pickupTime: _s(m['time']),
          date: _s(m['date']),
          description: _sOrNull(m['description']),
          status: _s(m['status']),
          homeDriver: _homeDriverFrom(drv),
          notes: _sOrNull(m['title']),
          endTime: _sOrNull(m['end_time']),
          city: _sOrNull(m['subtitle']),
          title: _sOrNull(m['title']),
          imageUrl: _s(m['image_url']),
          driverAssigned: drv != null && drv['assigned'] != false,
          driverName: drv == null ? '' : _s(drv['name']).trim(),
        );
      }).toList(),
      activities: _mapList(t['activities']).map((a) {
        return HomePlanItem(
          id: _i(a['id']),
          time: _s(a['time']),
          endTime: _s(a['end_time']),
          title: _s(a['title']),
          subtitle: _s(a['subtitle']),
          imageUrl: _s(a['image_url']),
          type: _sOrNull(a['type']) ?? 'activity',
          status: _s(a['status']),
          date: _s(a['date']),
        );
      }).toList(),
      extraServices: _mapList(
        t['extra_services'],
      ).map(HomeExtraService.fromJson).toList(),
      hotels: hotelStays,
      tripStatus: _s(t['status'] ?? t['trip_status'] ?? t['trip_state']),
    );
  }
}
