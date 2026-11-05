import '../services/localization_service.dart';

/// Locale-aware case conversion. Dart's default `toUpperCase()` / `toLowerCase()`
/// are locale-insensitive, so for Azerbaijani they map `i` -> `I` and `I` -> `i`
/// instead of `i` -> `İ` and `I` -> `ı`. These helpers fix that only when the
/// active language is Azerbaijani; every other language is unchanged.
class AzCase {
  AzCase._();

  static bool get _isAz => LocalizationService.instance.currentLanguage == 'az';

  static String upper(String s) {
    if (!_isAz) return s.toUpperCase();
    return s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }

  static String lower(String s) {
    if (!_isAz) return s.toLowerCase();
    return s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  }
}
