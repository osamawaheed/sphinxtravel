/// Display-only formatting for raw trip/segment status values.
/// The raw value (Odoo / API / database) is never modified; only the text
/// shown to the user changes.
///
/// - underscores / hyphens become spaces
/// - every word is capitalised (Title Case)
/// - `assigned` is shown as `Ready`
String formatTripStatusDisplay(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty) return '';
  final key = value.toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
  if (key == 'assigned') return 'Ready';
  final words = value
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty);
  return words
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
