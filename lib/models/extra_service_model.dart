class ExtraServiceModel {
  final int id;
  final String name;
  final String serviceType;
  final String? description;
  final int quantity;
  final String? status;
  final String? deliveryDate;
  final String? notes;

  const ExtraServiceModel({
    required this.id,
    required this.name,
    required this.serviceType,
    this.description,
    required this.quantity,
    this.status,
    this.deliveryDate,
    this.notes,
  });

  factory ExtraServiceModel.fromJson(Map<String, dynamic> json) {
    return ExtraServiceModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      serviceType: json['service_type'] as String? ?? '',
      description: json['description'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      status: json['status'] as String?,
      deliveryDate: json['delivery_date'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'service_type': serviceType,
    'description': description,
    'quantity': quantity,
    'status': status,
    'delivery_date': deliveryDate,
    'notes': notes,
  };

  bool get isFlowers => serviceType == 'flowers';

  bool get isSimCard => serviceType == 'sim_card' || isFlowers;
}
