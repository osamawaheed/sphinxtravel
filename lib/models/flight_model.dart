class FlightModel {
  final int id;
  final String flightNumber;
  final String airline;
  final String origin;
  final String destination;
  final String departureTime;
  final String arrivalTime;
  final String departureDate;
  final String? terminal;
  final String? gate;
  final String status;

  const FlightModel({
    required this.id,
    required this.flightNumber,
    required this.airline,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.arrivalTime,
    required this.departureDate,
    this.terminal,
    this.gate,
    required this.status,
  });

  factory FlightModel.fromJson(Map<String, dynamic> json) {
    return FlightModel(
      id: json['id'] as int,
      flightNumber: json['flight_number'] as String? ?? '',
      airline: json['airline'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      departureTime: json['departure_time'] as String? ?? '',
      arrivalTime: json['arrival_time'] as String? ?? '',
      departureDate: json['departure_date'] as String? ?? '',
      terminal: json['terminal'] as String?,
      gate: json['gate'] as String?,
      status: json['status'] as String? ?? 'scheduled',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'flight_number': flightNumber,
    'airline': airline,
    'origin': origin,
    'destination': destination,
    'departure_time': departureTime,
    'arrival_time': arrivalTime,
    'departure_date': departureDate,
    'terminal': terminal,
    'gate': gate,
    'status': status,
  };
}
