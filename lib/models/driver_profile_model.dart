/// Driver as returned by POST /api/v1/auth/driver/login (`user`) and
/// GET /api/v1/driver/bootstrap (`driver`).
///
/// {
///   "id": 2871, "role": "driver", "name": "Giorgi", "phone": "+995555000111",
///   "email": "...", "profile_completed": false, "rating": 5.0,
///   "rating_count": 3, "trip_count": 1,
///   "vehicle_model": "Toyota Camry", "vehicle_year": "2020",
///   "vehicle_color": "Black", "photo_url": "",
///   "personal_photos": ["", "", ""], "vehicle_photos": ["", "", "", "", ""],
///   "location_required": true   // login only
/// }
class DriverProfile {
  final int id;
  final String role;
  final String name;
  final String phone;
  final String email;
  final bool profileCompleted;
  final double rating;
  final double rating10;
  final int ratingCount;
  final int tripCount;
  final String vehicleModel;
  final String vehicleYear;
  final String vehicleColor;

  /// Relative path (e.g. "/web/image/...") or empty string.
  final String photoUrl;

  /// Image URLs (empty strings allowed — skipped when rendering).
  final List<String> personalPhotos;
  final List<String> vehiclePhotos;

  /// Only present in the login response; false when absent.
  final bool locationRequired;

  const DriverProfile({
    this.id = 0,
    this.role = 'driver',
    this.name = '',
    this.phone = '',
    this.email = '',
    this.profileCompleted = false,
    this.rating = 0.0,
    this.rating10 = 0.0,
    this.ratingCount = 0,
    this.tripCount = 0,
    this.vehicleModel = '',
    this.vehicleYear = '',
    this.vehicleColor = '',
    this.photoUrl = '',
    this.personalPhotos = const [],
    this.vehiclePhotos = const [],
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

  static List<String> _strList(dynamic v) {
    if (v is! List) return const [];
    return v.map(_str).toList();
  }

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: _int(json['id']),
      role: _str(json['role']).isEmpty ? 'driver' : _str(json['role']),
      name: _str(json['name']),
      phone: _str(json['phone']),
      email: _str(json['email']),
      profileCompleted: _bool(json['profile_completed']),
      rating: _double(json['rating']),
      rating10: _double(json['rating_10']),
      ratingCount: _int(json['rating_count']),
      tripCount: _int(json['trip_count']),
      vehicleModel: _str(json['vehicle_model']),
      vehicleYear: _str(json['vehicle_year']),
      vehicleColor: _str(json['vehicle_color']),
      photoUrl: _str(json['photo_url']),
      personalPhotos: _strList(json['personal_photos']),
      vehiclePhotos: _strList(json['vehicle_photos']),
      locationRequired: _bool(json['location_required']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'name': name,
      'phone': phone,
      'email': email,
      'profile_completed': profileCompleted,
      'rating': rating,
      'rating_10': rating10,
      'rating_count': ratingCount,
      'trip_count': tripCount,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'photo_url': photoUrl,
      'personal_photos': personalPhotos,
      'vehicle_photos': vehiclePhotos,
      'location_required': locationRequired,
    };
  }

  DriverProfile copyWith({
    String? name,
    bool? profileCompleted,
    String? vehicleModel,
    String? vehicleYear,
    String? vehicleColor,
    String? photoUrl,
    bool? locationRequired,
  }) {
    return DriverProfile(
      id: id,
      role: role,
      name: name ?? this.name,
      phone: phone,
      email: email,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      rating: rating,
      rating10: rating10,
      ratingCount: ratingCount,
      tripCount: tripCount,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      photoUrl: photoUrl ?? this.photoUrl,
      personalPhotos: personalPhotos,
      vehiclePhotos: vehiclePhotos,
      locationRequired: locationRequired ?? this.locationRequired,
    );
  }

  String get firstName {
    final parts = name.trim().split(' ');
    return parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : name;
  }

  /// "{vehicle_model} · {vehicle_year}" (skips empty parts).
  String get vehicleLine {
    final parts = <String>[
      if (vehicleModel.trim().isNotEmpty) vehicleModel.trim(),
      if (vehicleYear.trim().isNotEmpty) vehicleYear.trim(),
    ];
    return parts.join(' · ');
  }
}
