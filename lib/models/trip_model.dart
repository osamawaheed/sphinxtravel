import './extra_service_model.dart';
import './flight_model.dart';
import './hotel_model.dart';
import './transportation_segment_model.dart';

class ItineraryItem {
  final String time;
  final String title;
  final String? location;
  final String type;
  final String status;
  final String? description;
  final Map<String, dynamic>? driver;

  const ItineraryItem({
    required this.time,
    required this.title,
    this.location,
    required this.type,
    required this.status,
    this.description,
    this.driver,
  });

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(
      time: json['time']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      location: json['location']?.toString(),
      type: json['type']?.toString() ?? 'activity',
      status: json['status']?.toString() ?? 'upcoming',
      description: json['description']?.toString(),
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isCurrent => status == 'current';
  bool get isUpcoming => status == 'upcoming';
}

class TripModel {
  final int id;
  final String reference;
  final String name;
  final String destination;
  final String startDate;
  final String endDate;
  final int totalDays;
  final int currentDay;
  final String status;
  final String? heroImageUrl;
  final String? description;
  final List<FlightModel> flights;
  final List<HotelModel> hotels;
  final List<TransportationSegmentModel> transportationSegments;
  final List<ExtraServiceModel> extraServices;
  final List<ItineraryItem> todayItinerary;
  final List<ItineraryItem> tomorrowItinerary;
  final String tripState;
  // Customer info
  final String? customerName;
  final String? customerPhone;
  // Arrival info
  final String? arrivalDate;
  final String? arrivalTime;
  final String? arrivalFlightNumber;
  final String? arrivalAirport;
  final String? arrivalAirline;
  // Departure info
  final String? departureDate;
  final String? departureTime;
  final String? departureFlightNumber;
  final String? departureAirport;
  final String? departureAirline;
  // First pickup
  final String? firstPickupLocation;
  final String? firstPickupTime;
  // Vehicle assigned
  final String? vehicleDisplayName;
  // Passenger count
  final int? passengerCount;

  const TripModel({
    required this.id,
    required this.reference,
    required this.name,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.currentDay,
    required this.status,
    this.heroImageUrl,
    this.description,
    required this.flights,
    required this.hotels,
    required this.transportationSegments,
    required this.extraServices,
    required this.todayItinerary,
    required this.tomorrowItinerary,
    required this.tripState,
    this.customerName,
    this.customerPhone,
    this.arrivalDate,
    this.arrivalTime,
    this.arrivalFlightNumber,
    this.arrivalAirport,
    this.arrivalAirline,
    this.departureDate,
    this.departureTime,
    this.departureFlightNumber,
    this.departureAirport,
    this.departureAirline,
    this.firstPickupLocation,
    this.firstPickupTime,
    this.vehicleDisplayName,
    this.passengerCount,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final arrival = json['arrival'] as Map<String, dynamic>?;
    final departure = json['departure'] as Map<String, dynamic>?;
    return TripModel(
      id: json['id'] as int,
      reference: json['reference'] as String? ?? '',
      name: json['name'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      totalDays: json['total_days'] as int? ?? 1,
      currentDay: json['current_day'] as int? ?? 1,
      status: json['status'] as String? ?? 'active',
      heroImageUrl: json['hero_image_url'] as String?,
      description: json['description'] as String?,
      flights:
          (json['flights'] as List<dynamic>?)
              ?.map((e) => FlightModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hotels:
          (json['hotels'] as List<dynamic>?)
              ?.map((e) => HotelModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      transportationSegments:
          (json['transportation_segments'] as List<dynamic>?)
              ?.map(
                (e) => TransportationSegmentModel.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      extraServices:
          (json['extra_services'] as List<dynamic>?)
              ?.map(
                (e) => ExtraServiceModel.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      todayItinerary:
          (json['today_itinerary'] as List<dynamic>?)
              ?.map((e) => ItineraryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tomorrowItinerary:
          (json['tomorrow_itinerary'] as List<dynamic>?)
              ?.map((e) => ItineraryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      tripState: json['trip_state'] as String? ?? 'pre_trip',
      customerName:
          json['customer_name'] as String? ?? customer?['name'] as String?,
      customerPhone:
          json['customer_phone'] as String? ?? customer?['phone'] as String?,
      arrivalDate:
          json['arrival_date'] as String? ?? arrival?['date'] as String?,
      arrivalTime:
          json['arrival_time'] as String? ?? arrival?['time'] as String?,
      arrivalFlightNumber:
          json['arrival_flight_number'] as String? ??
          arrival?['flight_number'] as String?,
      arrivalAirport:
          json['arrival_airport'] as String? ?? arrival?['airport'] as String?,
      arrivalAirline:
          json['arrival_airline'] as String? ?? arrival?['airline'] as String?,
      departureDate:
          json['departure_date'] as String? ?? departure?['date'] as String?,
      departureTime:
          json['departure_time'] as String? ?? departure?['time'] as String?,
      departureFlightNumber:
          json['departure_flight_number'] as String? ??
          departure?['flight_number'] as String?,
      departureAirport:
          json['departure_airport'] as String? ??
          departure?['airport'] as String?,
      departureAirline:
          json['departure_airline'] as String? ??
          departure?['airline'] as String?,
      firstPickupLocation: json['first_pickup_location'] as String?,
      firstPickupTime: json['first_pickup_time'] as String?,
      vehicleDisplayName: json['vehicle_display_name'] as String?,
      passengerCount: json['passenger_count'] as int?,
    );
  }

  bool get isActive => status == 'active';
  bool get isPreTrip => tripState == 'pre_trip';
  bool get isInProgress => tripState == 'in_progress';
  bool get isCompleted => tripState == 'completed';

  TransportationSegmentModel? get nextSegment {
    try {
      return transportationSegments.firstWhere(
        (s) => s.isScheduled || s.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  int get daysUntilStart {
    try {
      final start = DateTime.parse(startDate);
      final now = DateTime.now();
      return start.difference(now).inDays;
    } catch (_) {
      return 0;
    }
  }

  Duration get timeUntilStart {
    try {
      final start = DateTime.parse(startDate);
      final now = DateTime.now();
      final diff = start.difference(now);
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Returns today's hotel based on current date
  HotelModel? hotelForDate(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    for (final hotel in hotels) {
      if (hotel.checkIn.compareTo(dateStr) <= 0 &&
          hotel.checkOut.compareTo(dateStr) > 0) {
        return hotel;
      }
    }
    return null;
  }

  /// Returns transportation segments for a given date
  List<TransportationSegmentModel> segmentsForDate(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return transportationSegments.where((s) => s.date == dateStr).toList()
      ..sort((a, b) => a.pickupTime.compareTo(b.pickupTime));
  }
}
