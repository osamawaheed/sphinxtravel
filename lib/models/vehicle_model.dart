class VehicleModel {
  final int id;
  final String make;
  final String model;
  final String color;
  final String plateNumber;
  final String? photoUrl;
  final String vehicleType;
  final String manufacturingYear;

  const VehicleModel({
    required this.id,
    required this.make,
    required this.model,
    required this.color,
    required this.plateNumber,
    this.photoUrl,
    required this.vehicleType,
    this.manufacturingYear = '',
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as int,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      color: json['color'] as String? ?? '',
      plateNumber: json['plate_number'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      vehicleType: json['vehicle_type'] as String? ?? 'sedan',
      manufacturingYear: json['manufacturing_year'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'make': make,
    'model': model,
    'color': color,
    'plate_number': plateNumber,
    'photo_url': photoUrl,
    'vehicle_type': vehicleType,
    'manufacturing_year': manufacturingYear,
  };

  String get displayName => '$make $model'.trim();
}
