import '../../../models/transportation_segment_model.dart';
import '../../../models/extra_service_model.dart';

class SegmentDetail {
  final TransportationSegmentModel segment;
  final List<ExtraServiceModel> extraServices;
  final int? passengerCount;
  final String? arrivalTime;

  const SegmentDetail({
    required this.segment,
    required this.extraServices,
    this.passengerCount,
    this.arrivalTime,
  });

  factory SegmentDetail.fromJson(Map<String, dynamic> json) {
    final seg = TransportationSegmentModel.fromJson(json);
    final rawExtras = json['extra_services'];
    final extras = <ExtraServiceModel>[];
    if (rawExtras is List) {
      for (var i = 0; i < rawExtras.length; i++) {
        final e = rawExtras[i];
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final name = (m['name'] ?? m['title'] ?? '').toString();
        if (name.isEmpty) continue;
        final qty = m['quantity'];
        extras.add(
          ExtraServiceModel(
            id: m['id'] is num ? (m['id'] as num).toInt() : i,
            name: name,
            serviceType: (m['service_type'] ?? m['type'] ?? '').toString(),
            description: (m['description'] ?? m['subtitle'])?.toString(),
            quantity: qty is num ? qty.toInt() : 1,
            status: m['status']?.toString(),
            deliveryDate: m['delivery_date']?.toString(),
            notes: m['notes']?.toString(),
          ),
        );
      }
    }
    final flight = json['flight'];
    final flightArrival = flight is Map ? flight['arrival_time'] : null;
    final arrival =
        (json['arrival_time'] ?? json['flight_arrival_time'] ?? flightArrival)
            ?.toString();
    return SegmentDetail(
      segment: seg,
      extraServices: extras,
      passengerCount: seg.passengers ?? json['passenger_count'] as int?,
      arrivalTime: (arrival == null || arrival.isEmpty) ? null : arrival,
    );
  }
}
