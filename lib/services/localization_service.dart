import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'sphinx_language';
  static const String _userRoleKey = 'sphinx_role_for_lang';

  String _currentLanguage = 'en';
  String _userRole = 'customer';

  // Singleton instance
  static LocalizationService? _instance;
  static LocalizationService get instance {
    _instance ??= LocalizationService();
    return _instance!;
  }

  String get currentLanguage => _currentLanguage;
  String get userRole => _userRole;
  bool get isArabic => _currentLanguage == 'ar';
  bool get isRTL => _currentLanguage == 'ar';

  Locale get locale {
    switch (_currentLanguage) {
      case 'ar':
        return const Locale('ar', 'AE');
      case 'ru':
        return const Locale('ru', 'RU');
      case 'ka':
        return const Locale('ka', 'GE');
      default:
        return const Locale('en', 'US');
    }
  }

  TextDirection get textDirection =>
      isRTL ? TextDirection.rtl : TextDirection.ltr;

  static Future<LocalizationService> create() async {
    final service = LocalizationService._internal();
    await service._loadSavedLanguage();
    _instance = service;
    return service;
  }

  LocalizationService._internal();
  LocalizationService();

  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? 'en';
    _userRole = prefs.getString(_userRoleKey) ?? 'customer';
  }

  /// Languages available per role (code, native label, English label, flag).
  static const List<Map<String, String>> customerLanguages = [
    {'code': 'ar', 'label': 'العربية', 'sublabel': 'Arabic', 'flag': '🇸🇦'},
    {'code': 'en', 'label': 'English', 'sublabel': 'English', 'flag': '🇬🇧'},
  ];
  static const List<Map<String, String>> driverLanguages = [
    {'code': 'en', 'label': 'English', 'sublabel': 'English', 'flag': '🇬🇧'},
    {'code': 'ru', 'label': 'Русский', 'sublabel': 'Russian', 'flag': '🇷🇺'},
    {'code': 'ka', 'label': 'ქართული', 'sublabel': 'Georgian', 'flag': '🇬🇪'},
  ];

  static List<Map<String, String>> languagesForRole(String role) =>
      role == 'driver' ? driverLanguages : customerLanguages;

  Future<void> setLanguage(String language, {String role = 'customer'}) async {
    if (_currentLanguage == language && _userRole == role) return;
    _currentLanguage = language;
    _userRole = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
    await prefs.setString(_userRoleKey, role);
    notifyListeners();
  }

  /// Translate a key using the built-in map (legacy support).
  String translate(String key) {
    return _translations[_currentLanguage]?[key] ??
        _translations['en']?[key] ??
        key;
  }

  String t(String key) => translate(key);

  // ─── Legacy translations map (kept for backward compatibility) ─────────────
  static const Map<String, Map<String, String>> _translations = {
    'en': {
      'app_name': 'TourOps',
      'welcome': 'Welcome',
      'good_morning': 'Good morning',
      'good_afternoon': 'Good afternoon',
      'good_evening': 'Good evening',
      'today': 'Today',
      'my_trip': 'My Trip',
      'services': 'Services',
      'support': 'Support',
      'profile': 'Profile',
      'driver_pickup': 'DRIVER PICKUP',
      'your_driver_arrives': 'Your driver arrives in',
      'min': 'min',
      'pickup': 'Pickup',
      'destination': 'Destination',
      'call': 'Call',
      'message': 'Message',
      'view_driver': 'View Driver',
      'todays_plan': "Today's Plan",
      'tomorrow': 'Tomorrow',
      'view_tomorrow': 'View Tomorrow',
      'driver_not_assigned': 'Driver will be assigned before your trip.',
      'no_trips': 'No trips assigned yet.',
      'trip_starts_in': 'Your trip starts in',
      'days': 'days',
      'day': 'day',
      'of': 'of',
      'continue_btn': 'Continue',
      'how_to_continue': 'How would you like to continue?',
      'customer': 'Customer',
      'driver': 'Driver',
      'manage_journey': 'Manage your journey and travel experience.',
      'manage_trips': 'View and manage your assigned trips.',
      'select_language': 'Select Your Language',
      'enter_phone': 'Enter your phone number',
      'phone_hint': 'Phone number',
      'request_otp': 'Send OTP via WhatsApp',
      'enter_otp': 'Enter verification code',
      'otp_sent_to': 'We sent a 6-digit code to',
      'verify': 'Verify',
      'resend_code': 'Resend Code',
      'resend_in': 'Resend in',
      'seconds': 's',
      'invalid_code': 'Invalid code. Please try again.',
      'expired_code': 'Code expired. Please request a new one.',
      'too_many_attempts': 'Too many attempts. Please try again later.',
      'username': 'Username',
      'password': 'Password',
      'sign_in': 'Sign In',
      'driver_login': 'Driver Login',
      'customer_login': 'Customer Login',
      'back': 'Back',
      'loading': 'Loading...',
      'error': 'Error',
      'retry': 'Retry',
      'enjoy_evening': 'Enjoy your evening',
      'activities_complete': "Today's activities are complete",
      'currently_on_tour': "You're currently on the",
      'tour': 'Tour',
      'driver_arrived': 'Your driver has arrived',
      'driver_en_route': 'is on the way',
      'day_label': 'Day',
    },
    'ar': {
      'app_name': 'TourOps',
      'welcome': 'مرحباً',
      'good_morning': 'صباح الخير',
      'good_afternoon': 'مساء الخير',
      'good_evening': 'مساء الخير',
      'today': 'اليوم',
      'my_trip': 'رحلتي',
      'services': 'الخدمات',
      'support': 'الدعم',
      'profile': 'الملف الشخصي',
      'driver_pickup': 'استقبال السائق',
      'your_driver_arrives': 'سائقك يصل خلال',
      'min': 'دقيقة',
      'pickup': 'نقطة الانطلاق',
      'destination': 'الوجهة',
      'call': 'اتصال',
      'message': 'رسالة',
      'view_driver': 'عرض السائق',
      'todays_plan': 'خطة اليوم',
      'tomorrow': 'غداً',
      'view_tomorrow': 'عرض الغد',
      'driver_not_assigned': 'سيتم تعيين السائق قبل رحلتك.',
      'no_trips': 'لا توجد رحلات مخصصة بعد.',
      'trip_starts_in': 'رحلتك تبدأ خلال',
      'days': 'أيام',
      'day': 'يوم',
      'of': 'من',
      'continue_btn': 'متابعة',
      'how_to_continue': 'كيف تريد المتابعة؟',
      'customer': 'عميل',
      'driver': 'سائق',
      'manage_journey': 'إدارة رحلتك وتجربة سفرك.',
      'manage_trips': 'عرض وإدارة رحلاتك المخصصة.',
      'select_language': 'اختر لغتك',
      'enter_phone': 'أدخل رقم هاتفك',
      'phone_hint': 'رقم الهاتف',
      'request_otp': 'إرسال رمز عبر واتساب',
      'enter_otp': 'أدخل رمز التحقق',
      'otp_sent_to': 'أرسلنا رمزاً مكوناً من 6 أرقام إلى',
      'verify': 'تحقق',
      'resend_code': 'إعادة إرسال الرمز',
      'resend_in': 'إعادة الإرسال خلال',
      'seconds': 'ث',
      'invalid_code': 'رمز غير صحيح. يرجى المحاولة مرة أخرى.',
      'expired_code': 'انتهت صلاحية الرمز. يرجى طلب رمز جديد.',
      'too_many_attempts': 'محاولات كثيرة جداً. يرجى المحاولة لاحقاً.',
      'username': 'اسم المستخدم',
      'password': 'كلمة المرور',
      'sign_in': 'تسجيل الدخول',
      'driver_login': 'تسجيل دخول السائق',
      'customer_login': 'تسجيل دخول العميل',
      'back': 'رجوع',
      'loading': 'جار التحميل...',
      'error': 'خطأ',
      'retry': 'إعادة المحاولة',
      'enjoy_evening': 'استمتع بمساءك',
      'activities_complete': 'اكتملت أنشطة اليوم',
      'currently_on_tour': 'أنت حالياً في جولة',
      'tour': 'جولة',
      'driver_arrived': 'وصل سائقك',
      'driver_en_route': 'في الطريق',
      'day_label': 'اليوم',
    },
    'ru': {
      'app_name': 'TourOps',
      'welcome': 'Добро пожаловать',
      'good_morning': 'Доброе утро',
      'good_afternoon': 'Добрый день',
      'good_evening': 'Добрый вечер',
      'today': 'Сегодня',
      'my_trip': 'Моя поездка',
      'services': 'Услуги',
      'support': 'Поддержка',
      'profile': 'Профиль',
      'driver_pickup': 'ПОДАЧА АВТОМОБИЛЯ',
      'your_driver_arrives': 'Водитель прибудет через',
      'min': 'мин',
      'pickup': 'Место подачи',
      'destination': 'Назначение',
      'call': 'Позвонить',
      'message': 'Сообщение',
      'view_driver': 'Профиль водителя',
      'todays_plan': 'План на сегодня',
      'tomorrow': 'Завтра',
      'view_tomorrow': 'Посмотреть завтра',
      'driver_not_assigned': 'Водитель будет назначен до поездки.',
      'no_trips': 'Поездок пока нет.',
      'trip_starts_in': 'Поездка начнётся через',
      'days': 'дней',
      'day': 'день',
      'of': 'из',
      'continue_btn': 'Продолжить',
      'how_to_continue': 'Как вы хотите продолжить?',
      'customer': 'Клиент',
      'driver': 'Водитель',
      'manage_journey': 'Управляйте своим путешествием.',
      'manage_trips': 'Просматривайте назначенные поездки.',
      'select_language': 'Выберите язык',
      'enter_phone': 'Введите номер телефона',
      'phone_hint': 'Номер телефона',
      'request_otp': 'Отправить код через WhatsApp',
      'enter_otp': 'Введите код подтверждения',
      'otp_sent_to': 'Мы отправили 6-значный код на',
      'verify': 'Подтвердить',
      'resend_code': 'Отправить код повторно',
      'resend_in': 'Повторная отправка через',
      'seconds': 'с',
      'invalid_code': 'Неверный код. Попробуйте ещё раз.',
      'expired_code': 'Код истёк. Запросите новый.',
      'too_many_attempts': 'Слишком много попыток. Попробуйте позже.',
      'username': 'Имя пользователя',
      'password': 'Пароль',
      'sign_in': 'Войти',
      'driver_login': 'Вход для водителя',
      'customer_login': 'Вход для клиента',
      'back': 'Назад',
      'loading': 'Загрузка...',
      'error': 'Ошибка',
      'retry': 'Повторить',
      'enjoy_evening': 'Приятного вечера',
      'activities_complete': 'Все мероприятия на сегодня завершены',
      'currently_on_tour': 'Вы сейчас на экскурсии',
      'tour': 'Тур',
      'driver_arrived': 'Водитель прибыл',
      'driver_en_route': 'в пути',
      'day_label': 'День',
    },
    'ka': {
      'app_name': 'TourOps',
      'welcome': 'კეთილი იყოს თქვენი მობრძანება',
      'good_morning': 'დილა მშვიდობისა',
      'good_afternoon': 'შუადღე მშვიდობისა',
      'good_evening': 'საღამო მშვიდობისა',
      'today': 'დღეს',
      'my_trip': 'ჩემი მოგზაურობა',
      'services': 'სერვისები',
      'support': 'მხარდაჭერა',
      'profile': 'პროფილი',
      'driver_pickup': 'მძღოლის მიყვანა',
      'your_driver_arrives': 'მძღოლი ჩამოვა',
      'min': 'წთ',
      'pickup': 'გამგზავრების ადგილი',
      'destination': 'დანიშნულება',
      'call': 'დარეკვა',
      'message': 'შეტყობინება',
      'view_driver': 'მძღოლის ნახვა',
      'todays_plan': 'დღის გეგმა',
      'tomorrow': 'ხვალ',
      'view_tomorrow': 'ხვალის ნახვა',
      'driver_not_assigned': 'მძღოლი დაინიშნება მოგზაურობამდე.',
      'no_trips': 'ჯერ მოგზაურობები არ არის.',
      'trip_starts_in': 'მოგზაურობა იწყება',
      'days': 'დღეში',
      'day': 'დღე',
      'of': '-დან',
      'continue_btn': 'გაგრძელება',
      'how_to_continue': 'როგორ გსურთ გაგრძელება?',
      'customer': 'კლიენტი',
      'driver': 'მძღოლი',
      'manage_journey': 'მართეთ თქვენი მოგზაურობა.',
      'manage_trips': 'ნახეთ მინიჭებული მოგზაურობები.',
      'select_language': 'აირჩიეთ ენა',
      'enter_phone': 'შეიყვანეთ ტელეფონის ნომერი',
      'phone_hint': 'ტელეფონის ნომერი',
      'request_otp': 'კოდის გაგზავნა WhatsApp-ით',
      'enter_otp': 'შეიყვანეთ დამადასტურებელი კოდი',
      'otp_sent_to': 'ჩვენ გავაგზავნეთ 6-ნიშნა კოდი',
      'verify': 'დადასტურება',
      'resend_code': 'კოდის ხელახლა გაგზავნა',
      'resend_in': 'ხელახლა გაგზავნა',
      'seconds': 'წმ',
      'invalid_code': 'არასწორი კოდი. სცადეთ ხელახლა.',
      'expired_code': 'კოდის ვადა გავიდა. მოითხოვეთ ახალი.',
      'too_many_attempts': 'ძალიან ბევრი მცდელობა. სცადეთ მოგვიანებით.',
      'username': 'მომხმარებლის სახელი',
      'password': 'პაროლი',
      'sign_in': 'შესვლა',
      'driver_login': 'მძღოლის შესვლა',
      'customer_login': 'კლიენტის შესვლა',
      'back': 'უკან',
      'loading': 'იტვირთება...',
      'error': 'შეცდომა',
      'retry': 'ხელახლა ცდა',
      'enjoy_evening': 'სასიამოვნო საღამო',
      'activities_complete': 'დღის ღონისძიებები დასრულდა',
      'currently_on_tour': 'თქვენ ამჟამად ტურზე ხართ',
      'tour': 'ტური',
      'driver_arrived': 'მძღოლი ჩამოვიდა',
      'driver_en_route': 'გზაშია',
      'day_label': 'დღე',
    },
  };
}
