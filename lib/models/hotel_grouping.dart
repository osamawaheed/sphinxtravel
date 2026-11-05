import './customer_bootstrap_model.dart';
import './hotel_model.dart';

/// Shared presentation-layer hotel de-duplication used by every customer and
/// driver screen (Home / Today's Plan, Trip Details, Full Trip).
///
/// Rule: same normalized hotel name + same check-in + same check-out
/// = ONE displayed hotel. Record ids are intentionally NOT part of the key,
/// because Odoo gives each room/accommodation record its own id.
/// Source lists are never mutated; first-seen order is preserved.
class HotelGrouping {
  HotelGrouping._();

  /// Trim, collapse repeated whitespace, case-insensitive.
  static String normName(String? v) =>
      (v ?? '').replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();

  /// Normalizes a date so "2026-10-30", "2026-10-30 14:00:00" and
  /// " 2026-10-30 " compare equal. Unparseable values are compared trimmed.
  static String normDate(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '';
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s);
    if (iso != null) {
      return '${iso.group(1)}-${iso.group(2)!.padLeft(2, '0')}-'
          '${iso.group(3)!.padLeft(2, '0')}';
    }
    return s.toLowerCase();
  }

  static String stayKey(String? name, String? checkIn, String? checkOut) =>
      '${normName(name)}|${normDate(checkIn)}|${normDate(checkOut)}';

  /// Groups [HomeStayHotel] records of the same hotel stay into one.
  static List<HomeStayHotel> groupStays(Iterable<HomeStayHotel> source) {
    final order = <String>[];
    final firsts = <String, HomeStayHotel>{};
    final counts = <String, Map<String, int>>{};
    final roomOrder = <String, List<String>>{};

    for (final h in source) {
      if (normName(h.name).isEmpty) continue;
      final key = stayKey(h.name, h.checkIn, h.checkOut);
      if (!firsts.containsKey(key)) {
        firsts[key] = h;
        order.add(key);
        counts[key] = <String, int>{};
        roomOrder[key] = <String>[];
      } else {
        // Keep the first record, but fill blanks from later duplicates.
        final f = firsts[key]!;
        if (f.phone.isEmpty && h.phone.isNotEmpty ||
            f.googleMapUrl.isEmpty && h.googleMapUrl.isNotEmpty ||
            f.city.isEmpty && h.city.isNotEmpty ||
            f.address.isEmpty && h.address.isNotEmpty) {
          firsts[key] = HomeStayHotel(
            id: f.id,
            name: f.name,
            city: f.city.isNotEmpty ? f.city : h.city,
            checkIn: f.checkIn,
            checkOut: f.checkOut,
            phone: f.phone.isNotEmpty ? f.phone : h.phone,
            googleMapUrl: f.googleMapUrl.isNotEmpty
                ? f.googleMapUrl
                : h.googleMapUrl,
            address: f.address.isNotEmpty ? f.address : h.address,
            roomType: f.roomType,
          );
        }
      }
      final type = h.roomType.trim();
      if (type.isNotEmpty) {
        final m = counts[key]!;
        if (!m.containsKey(type)) roomOrder[key]!.add(type);
        m[type] = (m[type] ?? 0) + 1;
      }
    }

    return [
      for (final key in order)
        HomeStayHotel(
          id: firsts[key]!.id,
          name: firsts[key]!.name,
          city: firsts[key]!.city,
          checkIn: firsts[key]!.checkIn,
          checkOut: firsts[key]!.checkOut,
          phone: firsts[key]!.phone,
          googleMapUrl: firsts[key]!.googleMapUrl,
          address: firsts[key]!.address,
          roomType: firsts[key]!.roomType,
          rooms: [
            for (final t in roomOrder[key]!)
              HomeStayRoom(type: t, quantity: counts[key]![t]!),
          ],
        ),
    ];
  }

  /// Groups [HotelModel] records (driver trip model) of the same stay.
  /// Returns one representative [HotelModel] per stay (first occurrence) and,
  /// separately, the room lines per stay via [roomsOf].
  static List<HotelModel> groupHotelModels(Iterable<HotelModel> source) {
    final order = <String>[];
    final firsts = <String, HotelModel>{};
    for (final h in source) {
      if (normName(h.name).isEmpty) continue;
      final key = stayKey(h.name, h.checkIn, h.checkOut);
      if (!firsts.containsKey(key)) {
        firsts[key] = h;
        order.add(key);
      }
    }
    return [for (final k in order) firsts[k]!];
  }

  /// Room lines (type + quantity) for the stay of [hotel] within [all].
  /// Only uses room types actually present in the data.
  static List<HomeStayRoom> roomsOf(
    HotelModel hotel,
    Iterable<HotelModel> all,
  ) {
    final key = stayKey(hotel.name, hotel.checkIn, hotel.checkOut);
    final counts = <String, int>{};
    final order = <String>[];
    for (final h in all) {
      if (stayKey(h.name, h.checkIn, h.checkOut) != key) continue;
      final t = (h.roomType ?? '').trim();
      if (t.isEmpty) continue;
      if (!counts.containsKey(t)) order.add(t);
      counts[t] = (counts[t] ?? 0) + 1;
    }
    return [for (final t in order) HomeStayRoom(type: t, quantity: counts[t]!)];
  }

  static bool isHotelItem(HomePlanItem i) =>
      i.type.trim().toLowerCase() == 'hotel';

  /// Removes duplicate hotel entries (and therefore duplicate hotel images)
  /// from a list of plan items. Hotel items with the same normalized title and
  /// the same date are one entry; the first occurrence (and its image) wins.
  /// Non-hotel items are untouched. Order is preserved.
  static List<HomePlanItem> dedupeHotelPlanItems(Iterable<HomePlanItem> src) {
    final seen = <String>{};
    final out = <HomePlanItem>[];
    for (final i in src) {
      if (isHotelItem(i)) {
        final key = '${normName(i.title)}|${normDate(i.date)}';
        if (!seen.add(key)) continue;
      }
      out.add(i);
    }
    return out;
  }

  /// Same hotel shown both as a plan item and as the "current hotel" card:
  /// drop hotel plan items whose title matches [currentHotelName].
  static List<HomePlanItem> withoutHotelNamed(
    Iterable<HomePlanItem> src,
    String? currentHotelName,
  ) {
    final n = normName(currentHotelName);
    if (n.isEmpty) return src.toList();
    return [
      for (final i in src)
        if (!(isHotelItem(i) && normName(i.title) == n)) i,
    ];
  }
}
