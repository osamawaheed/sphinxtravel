class HotelModel {
  final int id;
  final String name;
  final String location;
  final String checkIn;
  final String checkOut;
  final int nights;
  final String? roomType;
  final String? photoUrl;
  final double? rating;
  final String? address;
  final String? phone;
  final String? checkInTime;
  final String? checkOutTime;
  final String? guestInfo;

  const HotelModel({
    required this.id,
    required this.name,
    required this.location,
    required this.checkIn,
    required this.checkOut,
    required this.nights,
    this.roomType,
    this.photoUrl,
    this.rating,
    this.address,
    this.phone,
    this.checkInTime,
    this.checkOutTime,
    this.guestInfo,
  });

  factory HotelModel.fromJson(Map<String, dynamic> json) {
    return HotelModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      checkIn: json['check_in'] as String? ?? '',
      checkOut: json['check_out'] as String? ?? '',
      nights: json['nights'] as int? ?? 1,
      roomType: json['room_type'] as String?,
      photoUrl: json['photo_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      guestInfo: json['guest_info'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'location': location,
    'check_in': checkIn,
    'check_out': checkOut,
    'nights': nights,
    'room_type': roomType,
    'photo_url': photoUrl,
    'rating': rating,
    'address': address,
    'phone': phone,
    'check_in_time': checkInTime,
    'check_out_time': checkOutTime,
    'guest_info': guestInfo,
  };

  /// Returns which night of the stay this date is (1-indexed), or null if not staying
  int? nightNumberForDate(DateTime date) {
    try {
      final checkInDate = DateTime.parse(checkIn);
      final checkOutDate = DateTime.parse(checkOut);
      final d = DateTime(date.year, date.month, date.day);
      final ci = DateTime(checkInDate.year, checkInDate.month, checkInDate.day);
      final co = DateTime(
        checkOutDate.year,
        checkOutDate.month,
        checkOutDate.day,
      );
      if (d.isBefore(ci) || !d.isBefore(co)) return null;
      return d.difference(ci).inDays + 1;
    } catch (_) {
      return null;
    }
  }

  bool isCheckInDate(DateTime date) {
    try {
      final ci = DateTime.parse(checkIn);
      return ci.year == date.year &&
          ci.month == date.month &&
          ci.day == date.day;
    } catch (_) {
      return false;
    }
  }

  bool isCheckOutDate(DateTime date) {
    try {
      final co = DateTime.parse(checkOut);
      return co.year == date.year &&
          co.month == date.month &&
          co.day == date.day;
    } catch (_) {
      return false;
    }
  }
}
