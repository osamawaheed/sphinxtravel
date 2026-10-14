import './vehicle_model.dart';

class DriverAssignment {
  final int driverId;
  final String driverName;
  final String? driverPhone;
  final String? driverPhotoUrl;
  final double? rating;
  final int? totalTrips;
  final VehicleModel? vehicle;

  const DriverAssignment({
    required this.driverId,
    required this.driverName,
    this.driverPhone,
    this.driverPhotoUrl,
    this.rating,
    this.totalTrips,
    this.vehicle,
  });

  factory DriverAssignment.fromJson(Map<String, dynamic> json) {
    return DriverAssignment(
      driverId: json['driver_id'] as int,
      driverName: json['driver_name'] as String? ?? '',
      driverPhone: json['driver_phone'] as String?,
      driverPhotoUrl: json['driver_photo_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      totalTrips: json['total_trips'] as int?,
      vehicle: json['vehicle'] != null
          ? VehicleModel.fromJson(json['vehicle'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'driver_id': driverId,
    'driver_name': driverName,
    'driver_phone': driverPhone,
    'driver_photo_url': driverPhotoUrl,
    'rating': rating,
    'total_trips': totalTrips,
    'vehicle': vehicle?.toJson(),
  };

  String get displayName {
    final parts = driverName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0]} ${parts[1][0]}.';
    }
    return driverName;
  }
}
