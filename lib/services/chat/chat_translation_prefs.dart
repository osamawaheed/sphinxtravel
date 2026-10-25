import 'package:shared_preferences/shared_preferences.dart';

import '../../models/chat_models.dart';

/// Languages supported by Smart Chat translation.
class ChatTranslationLanguages {
  ChatTranslationLanguages._();

  static const List<String> supported = ['ar', 'en', 'ru', 'ka', 'az'];

  /// Native display names shown in the selector.
  static const Map<String, String> nativeNames = {
    'ar': 'العربية',
    'en': 'English',
    'ru': 'Русский',
    'ka': 'ქართული',
    'az': 'Azərbaycanca',
  };

  static bool isSupported(String? code) => supported.contains(code);

  static bool isRtl(String code) => code == 'ar';
}

/// Local, per logged-in user AND role persistence of the chat translation
/// language. Independent from the app interface language.
class ChatTranslationPrefs {
  ChatTranslationPrefs._();

  static const String _prefix = 'chat_translation_lang';

  static String _key(ChatRole role, int? userId) =>
      '${_prefix}_${role.name}_${userId ?? 'anon'}';

  /// Saved choice, or null when the user never picked one.
  static Future<String?> load(ChatRole role, int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_key(role, userId));
      return ChatTranslationLanguages.isSupported(v) ? v : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(ChatRole role, int? userId, String language) async {
    if (!ChatTranslationLanguages.isSupported(language)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(role, userId), language);
    } catch (_) {
      // Preference persistence must never disturb the chat.
    }
  }

  /// Saved choice, falling back to the current app language (or English when
  /// the app language is not a supported translation language).
  static Future<String> resolve(
    ChatRole role,
    int? userId,
    String appLanguage,
  ) async {
    final saved = await load(role, userId);
    if (saved != null) return saved;
    return ChatTranslationLanguages.isSupported(appLanguage)
        ? appLanguage
        : 'en';
  }
}
