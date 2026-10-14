/// Driver as returned by POST /api/v1/auth/driver/login (`user`) and
/// GET /api/v1/driver/bootstrap (`driver`).
///
/// {
///   "id": 2871, "role": "driver", "name": "Giorgi", "phone": "+995555000111",
///   "profile_completed": false, "rating": 5.0, "trip_count": 1,
///   "vehicle_model": "Toyota Camry", "vehicle_color": "Black",
///   "plate_number": "GG-123-AB", "photo_url": "",
///   "location_required": true   // login only
/// }
class DriverProfile {
  final int id;
  final String role;
  final String name;
  final String phone;
  final bool profileCompleted;
  final double rating;
  final int tripCount;
  final String vehicleModel;
  final String vehicleColor;
  final String plateNumber;

  /// Relative path (e.g. "/web/image/...") or empty string.
  final String photoUrl;

  /// Only present in the login response; false when absent.
  final bool locationRequired;

  const DriverProfile({
    this.id = 0,
    this.role = 'driver',
    this.name = '',
    this.phone = '',
    this.profileCompleted = false,
    this.rating = 0.0,
    this.tripCount = 0,
    this.vehicleModel = '',
    this.vehicleColor = '',
    this.plateNumber = '',
    this.photoUrl = '',
    this.locationRequired = false,
  });

  static String _str(dynamic v) => v == null ? '' : v.toString();

  static int _int(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse(_str(v)) ?? 0;
  }

  static double _double(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(_str(v)) ?? 0.0;
  }

  static bool _bool(dynamic v, {bool fallback = false}) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) return v.toLowerCase() == 'true';
    return fallback;
  }

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: _int(json['id']),
      role: _str(json['role']).isEmpty ? 'driver' : _str(json['role']),
      name: _str(json['name']),
      phone: _str(json['phone']),
      profileCompleted: _bool(json['profile_completed']),
      rating: _double(json['rating']),
      tripCount: _int(json['trip_count']),
      vehicleModel: _str(json['vehicle_model']),
      vehicleColor: _str(json['vehicle_color']),
      plateNumber: _str(json['plate_number']),
      photoUrl: _str(json['photo_url']),
      locationRequired: _bool(json['location_required']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'name': name,
      'phone': phone,
      'profile_completed': profileCompleted,
      'rating': rating,
      'trip_count': tripCount,
      'vehicle_model': vehicleModel,
      'vehicle_color': vehicleColor,
      'plate_number': plateNumber,
      'photo_url': photoUrl,
      'location_required': locationRequired,
    };
  }

  DriverProfile copyWith({
    String? name,
    bool? profileCompleted,
    String? plateNumber,
    String? vehicleModel,
    String? vehicleColor,
    String? photoUrl,
    bool? locationRequired,
  }) {
    return DriverProfile(
      id: id,
      role: role,
      name: name ?? this.name,
      phone: phone,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      rating: rating,
      tripCount: tripCount,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      plateNumber: plateNumber ?? this.plateNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      locationRequired: locationRequired ?? this.locationRequired,
    );
  }

  String get firstName {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : name;
  }

  /// "{vehicle_model} · {plate_number}" (skips empty parts).
  String get vehicleLine {
    final parts = <String>[
      if (vehicleModel.trim().isNotEmpty) vehicleModel.trim(),
      if (plateNumber.trim().isNotEmpty) plateNumber.trim(),
    ];
    return parts.join(' · ');
  }
}
