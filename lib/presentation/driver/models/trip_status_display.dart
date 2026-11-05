/// Display-only formatting for raw trip/segment status values.
/// The raw value (Odoo / API / database) is never modified; only the text
/// shown to the user changes.
///
/// - underscores / hyphens become spaces
/// - every word is capitalised (Title Case)
/// - `assigned` is shown as `Ready`
///
/// When [localize] is provided and returns a translation that differs from the
/// raw value (i.e. the status is a known one), that translation is used.
String formatTripStatusDisplay(
  String? raw, {
  String Function(String raw)? localize,
}) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '';
  final key = value.toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
  if (localize != null) {
    final localized = localize(value);
    final unchanged = localized == value.replaceAll('_', ' ');
    if (!unchanged && localized.isNotEmpty) return localized;
  }
  if (key == 'assigned') return 'Ready';
  final words = value
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  return words
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
