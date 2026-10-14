import 'package:flutter/material.dart';
import '../services/localization_service.dart';

/// AppLocalizations provides all translated UI strings.
/// Customer screens use: en, ar
/// Driver screens use: en, ru, ka
class AppLocalizations {
  final String locale;

  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    final service = context
        .dependOnInheritedWidgetOfExactType<_LocalizationInheritedWidget>()
        ?.service;
    return AppLocalizations(service?.currentLanguage ?? 'en');
  }

  static AppLocalizations fromService(LocalizationService service) {
    return AppLocalizations(service.currentLanguage);
  }

  // ─── Generic ───────────────────────────────────────────────────────────────

  String get appName => _t({
    'en': 'Travel Operations',
    'ar': 'Travel Operations',
    'ru': 'Travel Operations',
    'ka': 'Travel Operations',
  });
  String get loading => _t({
    'en': 'Loading...',
    'ar': 'جار التحميل...',
    'ru': 'Загрузка...',
    'ka': 'იტვირთება...',
  });
  String get error =>
      _t({'en': 'Error', 'ar': 'خطأ', 'ru': 'Ошибка', 'ka': 'შეცდომა'});
  String get retry => _t({
    'en': 'Retry',
    'ar': 'إعادة المحاولة',
    'ru': 'Повторить',
    'ka': 'ხელახლა ცდა',
  });
  String get back =>
      _t({'en': 'Back', 'ar': 'رجوع', 'ru': 'Назад', 'ka': 'უკან'});
  String get continueBtn => _t({
    'en': 'Continue',
    'ar': 'متابعة',
    'ru': 'Продолжить',
    'ka': 'გაგრძელება',
  });
  String get skip =>
      _t({'en': 'Skip', 'ar': 'تخطي', 'ru': 'Пропустить', 'ka': 'გამოტოვება'});
  String get logout => _t({
    'en': 'Sign Out',
    'ar': 'تسجيل الخروج',
    'ru': 'Выйти',
    'ka': 'გასვლა',
  });
  String get signOut => logout;
  String get noTrips => _t({
    'en': 'No trips assigned yet.',
    'ar': 'لا توجد رحلات مخصصة بعد.',
    'ru': 'Поездок пока нет.',
    'ka': 'ჯერ მოგზაურობები არ არის.',
  });

  // ─── Splash ────────────────────────────────────────────────────────────────

  String get splashTitle1 => _t({
    'en': 'Georgia Awaits',
    'ar': 'جورجيا تنتظرك',
    'ru': 'Грузия ждёт',
    'ka': 'საქართველო გელოდება',
  });
  String get splashSubtitle1 => _t({
    'en': 'Ancient monasteries, mountain peaks,\nand timeless hospitality.',
    'ar': 'أديرة عريقة، قمم جبلية،\nوضيافة لا تُنسى.',
    'ru': 'Древние монастыри, горные вершины\nи гостеприимство на все времена.',
    'ka':
        'უძველესი მონასტრები, მთის მწვერვალები\nდა დაუვიწყარი სტუმართმოყვარეობა.',
  });
  String get splashTag1 => _t({
    'en': 'TBILISI · KAZBEGI · BATUMI',
    'ar': 'تبليسي · كازبيغي · باتومي',
    'ru': 'ТБИЛИСИ · КАЗБЕГИ · БАТУМИ',
    'ka': 'თბილისი · ყაზბეგი · ბათუმი',
  });

  String get splashTitle2 => _t({
    'en': 'Stay in Luxury',
    'ar': 'أقامة فاخرة',
    'ru': 'Роскошное проживание',
    'ka': 'ფუფუნებაში დარჩენა',
  });
  String get splashSubtitle2 => _t({
    'en': 'Curated hotels and resorts\nselected for your comfort.',
    'ar': 'فنادق ومنتجعات مختارة بعناية\nلراحتك التامة.',
    'ru': 'Тщательно отобранные отели и курорты\nдля вашего комфорта.',
    'ka': 'სპეციალურად შერჩეული სასტუმროები\nთქვენი კომფორტისთვის.',
  });
  String get splashTag2 => _t({
    'en': 'PREMIUM ACCOMMODATIONS',
    'ar': 'إقامة فاخرة',
    'ru': 'ПРЕМИУМ РАЗМЕЩЕНИЕ',
    'ka': 'პრემიუმ განთავსება',
  });

  String get splashTitle3 => _t({
    'en': 'Your Journey,\nPersonalized',
    'ar': 'رحلتك،\nبأسلوبك',
    'ru': 'Ваше путешествие,\nперсонализированное',
    'ka': 'თქვენი მოგზაურობა,\nინდივიდუალური',
  });
  String get splashSubtitle3 => _t({
    'en':
        'Private transfers and expert drivers\nwith you every step of the way.',
    'ar': 'نقل خاص وسائقون محترفون\nمعك في كل خطوة.',
    'ru': 'Частные трансферы и опытные водители\nрядом с вами на каждом шагу.',
    'ka': 'კერძო ტრანსფერები და გამოცდილი მძღოლები\nყოველ ნაბიჯზე თქვენთან.',
  });
  String get splashTag3 => _t({
    'en': 'PRIVATE TRANSPORTATION',
    'ar': 'نقل خاص',
    'ru': 'ЧАСТНЫЙ ТРАНСПОРТ',
    'ka': 'კერძო ტრანსპორტი',
  });

  // ─── User Type Selection ───────────────────────────────────────────────────

  String get howToContinue => _t({
    'en': 'How would you like\nto continue?',
    'ar': 'كيف تريد\nالمتابعة؟',
    'ru': 'Как вы хотите\nпродолжить?',
    'ka': 'როგორ გსურთ\nგაგრძელება?',
  });
  String get selectRoleSubtitle => _t({
    'en': 'Select your role to get started',
    'ar': 'اختر دورك للبدء',
    'ru': 'Выберите роль для начала',
    'ka': 'აირჩიეთ თქვენი როლი დასაწყებად',
  });
  String get customer =>
      _t({'en': 'Customer', 'ar': 'عميل', 'ru': 'Клиент', 'ka': 'კლიენტი'});
  String get driver =>
      _t({'en': 'Driver', 'ar': 'سائق', 'ru': 'Водитель', 'ka': 'მძღოლი'});
  String get manageJourney => _t({
    'en': 'Manage your journey and\ntravel experience.',
    'ar': 'إدارة رحلتك وتجربة\nسفرك.',
    'ru': 'Управляйте своим путешествием\nи впечатлениями.',
    'ka': 'მართეთ თქვენი მოგზაურობა\nდა სამგზავრო გამოცდილება.',
  });
  String get manageTrips => _t({
    'en': 'View and manage your\nassigned trips.',
    'ar': 'عرض وإدارة\nرحلاتك المخصصة.',
    'ru': 'Просматривайте и управляйте\nназначенными поездками.',
    'ka': 'ნახეთ და მართეთ\nმინიჭებული მოგზაურობები.',
  });
  String get copyright => _t({
    'en': '© 2026 Sphinx Travel. جميع الحقوق محفوظة.',
    'ar': '© 2026 Sphinx Travel. جميع الحقوق محفوظة.',
    'ru': '© 2026 Sphinx Travel. جميع الحقوق محفوظة.',
    'ka': '© 2026 Sphinx Travel. جميع الحقوق محفوظة.',
  });

  // ─── Language Selection ────────────────────────────────────────────────────

  String get selectLanguage => _t({
    'en': 'Select Your\nLanguage',
    'ar': 'اختر\nلغتك',
    'ru': 'Выберите\nязык',
    'ka': 'აირჩიეთ\nენა',
  });
  String get selectLanguageSubtitle => _t({
    'en': 'Choose your preferred language to continue',
    'ar': 'اختر لغتك المفضلة للمتابعة',
    'ru': 'Выберите предпочитаемый язык для продолжения',
    'ka': 'გასაგრძელებლად აირჩიეთ სასურველი ენა',
  });

  // ─── Customer Login ────────────────────────────────────────────────────────

  String get welcomeBack => _t({
    'en': 'Welcome Back',
    'ar': 'مرحباً بعودتك',
    'ru': 'С возвращением',
    'ka': 'კეთილი იყოს თქვენი დაბრუნება',
  });
  String get signInToAccess => _t({
    'en': 'Sign in to access your journey',
    'ar': 'سجّل الدخول للوصول إلى رحلتك',
    'ru': 'Войдите, чтобы получить доступ к поездке',
    'ka': 'შედით თქვენი მოგზაურობის სანახავად',
  });
  String get yourPhoneNumber => _t({
    'en': 'Your Phone Number',
    'ar': 'رقم هاتفك',
    'ru': 'Ваш номер телефона',
    'ka': 'თქვენი ტელეფონის ნომერი',
  });
  String get phoneSubtitle => _t({
    'en': "We'll send a verification code via WhatsApp",
    'ar': 'سنرسل رمز التحقق عبر واتساب',
    'ru': 'Мы отправим код подтверждения через WhatsApp',
    'ka': 'ჩვენ გავაგზავნით დამადასტურებელ კოდს WhatsApp-ით',
  });
  String get phoneHint => _t({
    'en': 'Phone number',
    'ar': 'رقم الهاتف',
    'ru': 'Номер телефона',
    'ka': 'ტელეფონის ნომერი',
  });
  String get sendOtpWhatsapp => _t({
    'en': 'Send OTP via WhatsApp',
    'ar': 'إرسال رمز عبر واتساب',
    'ru': 'Отправить код через WhatsApp',
    'ka': 'კოდის გაგზავნა WhatsApp-ით',
  });
  String get enterPhone => _t({
    'en': 'Please enter your phone number',
    'ar': 'يرجى إدخال رقم هاتفك',
    'ru': 'Пожалуйста, введите номер телефона',
    'ka': 'გთხოვთ შეიყვანოთ ტელეფონის ნომერი',
  });
  String get failedToSendOtp => _t({
    'en': 'Failed to send OTP. Please try again.',
    'ar': 'فشل إرسال الرمز. يرجى المحاولة مرة أخرى.',
    'ru': 'Не удалось отправить код. Попробуйте ещё раз.',
    'ka': 'კოდის გაგზავნა ვერ მოხერხდა. სცადეთ ხელახლა.',
  });
  String get searchCountry => _t({
    'en': 'Search country...',
    'ar': 'البحث عن دولة...',
    'ru': 'Поиск страны...',
    'ka': 'ქვეყნის ძიება...',
  });
  String get selectCountry => _t({
    'en': 'Select Country',
    'ar': 'اختر الدولة',
    'ru': 'Выберите страну',
    'ka': 'აირჩიეთ ქვეყანა',
  });

  // ─── OTP Screen ────────────────────────────────────────────────────────────

  String get verifyPhoneNumber => _t({
    'en': 'Verify Your\nPhone Number',
    'ar': 'تحقق من\nرقم هاتفك',
    'ru': 'Подтвердите\nномер телефона',
    'ka': 'დაადასტურეთ\nტელეფონის ნომერი',
  });
  String get otpSentTo => _t({
    'en': 'We sent a 6-digit code to',
    'ar': 'أرسلنا رمزاً مكوناً من 6 أرقام إلى',
    'ru': 'Мы отправили 6-значный код на',
    'ka': 'ჩვენ გავაგზავნეთ 6-ნიშნა კოდი',
  });
  String get viaWhatsapp => _t({
    'en': 'via WhatsApp',
    'ar': 'عبر واتساب',
    'ru': 'через WhatsApp',
    'ka': 'WhatsApp-ით',
  });
  String get verify => _t({
    'en': 'Verify',
    'ar': 'تحقق',
    'ru': 'Подтвердить',
    'ka': 'დადასტურება',
  });
  String get resendCode => _t({
    'en': 'Resend Code',
    'ar': 'إعادة إرسال الرمز',
    'ru': 'Отправить повторно',
    'ka': 'კოდის ხელახლა გაგზავნა',
  });
  String get resendIn => _t({
    'en': 'Resend in',
    'ar': 'إعادة الإرسال خلال',
    'ru': 'Повторная отправка через',
    'ka': 'ხელახლა გაგზავნა',
  });
  String get seconds => _t({'en': 's', 'ar': 'ث', 'ru': 'с', 'ka': 'წმ'});
  String get invalidCode => _t({
    'en': 'Invalid code. Please try again.',
    'ar': 'رمز غير صحيح. يرجى المحاولة مرة أخرى.',
    'ru': 'Неверный код. Попробуйте ещё раз.',
    'ka': 'არასწორი კოდი. სცადეთ ხელახლა.',
  });
  String get expiredCode => _t({
    'en': 'Code expired. Please request a new one.',
    'ar': 'انتهت صلاحية الرمز. يرجى طلب رمز جديد.',
    'ru': 'Код истёк. Запросите новый.',
    'ka': 'კოდის ვადა გავიდა. მოითხოვეთ ახალი.',
  });
  String get tooManyAttempts => _t({
    'en': 'Too many attempts. Please try again later.',
    'ar': 'محاولات كثيرة جداً. يرجى المحاولة لاحقاً.',
    'ru': 'Слишком много попыток. Попробуйте позже.',
    'ka': 'ძალიან ბევრი მცდელობა. სცადეთ მოგვიანებით.',
  });

  // ─── Driver Login ──────────────────────────────────────────────────────────

  String get driverPortal => _t({
    'en': 'Driver Portal',
    'ar': 'بوابة السائق',
    'ru': 'Портал водителя',
    'ka': 'მძღოლის პორტალი',
  });
  String get signInOdoo => _t({
    'en': 'Sign in with your Odoo credentials',
    'ar': 'سجّل الدخول ببيانات أودو',
    'ru': 'Войдите с учётными данными Odoo',
    'ka': 'შედით Odoo-ს სერთიფიკატებით',
  });
  String get signIn => _t({
    'en': 'Sign In',
    'ar': 'تسجيل الدخول',
    'ru': 'Войти',
    'ka': 'შესვლა',
  });
  String get driverAccountSubtitle => _t({
    'en': 'Use your Travel Operations driver account',
    'ar': 'استخدم حساب سائق Travel Operations',
    'ru': 'Используйте аккаунт водителя Travel Operations',
    'ka': 'გამოიყენეთ Travel Operations-ის მძღოლის ანგარიში',
  });
  String get username => _t({
    'en': 'Username',
    'ar': 'اسم المستخدم',
    'ru': 'Имя пользователя',
    'ka': 'მომხმარებლის სახელი',
  });
  String get password => _t({
    'en': 'Password',
    'ar': 'كلمة المرور',
    'ru': 'Пароль',
    'ka': 'პაროლი',
  });
  String get enterUsername => _t({
    'en': 'Enter your username',
    'ar': 'أدخل اسم المستخدم',
    'ru': 'Введите имя пользователя',
    'ka': 'შეიყვანეთ მომხმარებლის სახელი',
  });
  String get enterPassword => _t({
    'en': 'Enter your password',
    'ar': 'أدخل كلمة المرور',
    'ru': 'Введите пароль',
    'ka': 'შეიყვანეთ პაროლი',
  });
  String get enterUsernameAndPassword => _t({
    'en': 'Please enter your username and password',
    'ar': 'يرجى إدخال اسم المستخدم وكلمة المرور',
    'ru': 'Пожалуйста, введите имя пользователя и пароль',
    'ka': 'გთხოვთ შეიყვანოთ მომხმარებლის სახელი და პაროლი',
  });
  String get invalidCredentials => _t({
    'en': 'Invalid username or password. Please try again.',
    'ar': 'اسم المستخدم أو كلمة المرور غير صحيحة. يرجى المحاولة مرة أخرى.',
    'ru': 'Неверное имя пользователя или пароль. Попробуйте ещё раз.',
    'ka': 'არასწორი მომხმარებლის სახელი ან პაროლი. სცადეთ ხელახლა.',
  });

  // ─── Customer Home ─────────────────────────────────────────────────────────

  String get goodMorning => _t({
    'en': 'Good morning',
    'ar': 'صباح الخير',
    'ru': 'Доброе утро',
    'ka': 'დილა მშვიდობისა',
  });
  String get goodAfternoon => _t({
    'en': 'Good afternoon',
    'ar': 'مساء الخير',
    'ru': 'Добрый день',
    'ka': 'შუადღე მშვიდობისა',
  });
  String get goodEvening => _t({
    'en': 'Good evening',
    'ar': 'مساء الخير',
    'ru': 'Добрый вечер',
    'ka': 'საღამო მშვიდობისა',
  });

  String get today =>
      _t({'en': 'Today', 'ar': 'اليوم', 'ru': 'Сегодня', 'ka': 'დღეს'});
  String get myTrip => _t({
    'en': 'My Trip',
    'ar': 'رحلتي',
    'ru': 'Моя поездка',
    'ka': 'ჩემი მოგზაურობა',
  });
  String get services => _t({
    'en': 'Services',
    'ar': 'الخدمات',
    'ru': 'Услуги',
    'ka': 'სერვისები',
  });
  String get support => _t({
    'en': 'Support',
    'ar': 'الدعم',
    'ru': 'Поддержка',
    'ka': 'მხარდაჭერა',
  });
  String get profile => _t({
    'en': 'Profile',
    'ar': 'الملف الشخصي',
    'ru': 'Профиль',
    'ka': 'პროფილი',
  });

  String get noActiveTrips => _t({
    'en': 'No active trip',
    'ar': 'لا توجد رحلات نشطة',
    'ru': 'Нет активных поездок',
    'ka': 'აქტიური მოგზაურობები არ არის',
  });
  String get upcomingTripsHere => _t({
    'en': 'Your upcoming trips will appear here',
    'ar': 'ستظهر رحلاتك القادمة هنا',
    'ru': 'Здесь появятся ваши предстоящие поездки',
    'ka': 'თქვენი მომავალი მოგზაურობები გამოჩნდება აქ',
  });

  String get driverPickup => _t({
    'en': 'DRIVER PICKUP',
    'ar': 'استقبال السائق',
    'ru': 'ПОДАЧА АВТОМОБИЛЯ',
    'ka': 'მძღოლის მიყვანა',
  });
  String get nextUp =>
      _t({'en': 'NEXT UP', 'ar': 'التالي', 'ru': 'СЛЕДУЮЩЕЕ', 'ka': 'შემდეგი'});
  String get yourDriverArrives => _t({
    'en': 'Your driver arrives in 25 min',
    'ar': 'سائقك يصل خلال 25 دقيقة',
    'ru': 'Водитель прибудет через 25 мин',
    'ka': 'მძღოლი ჩამოვა 25 წუთში',
  });
  String get pickup => _t({
    'en': 'Pickup',
    'ar': 'نقطة الانطلاق',
    'ru': 'Место подачи',
    'ka': 'გამგზავრების ადგილი',
  });
  String get destination => _t({
    'en': 'Destination',
    'ar': 'الوجهة',
    'ru': 'Назначение',
    'ka': 'დანიშნულება',
  });
  String get call =>
      _t({'en': 'Call', 'ar': 'اتصال', 'ru': 'Позвонить', 'ka': 'დარეკვა'});
  String get message => _t({
    'en': 'Message',
    'ar': 'رسالة',
    'ru': 'Сообщение',
    'ka': 'შეტყობინება',
  });
  String get viewDriver => _t({
    'en': 'View Driver',
    'ar': 'عرض السائق',
    'ru': 'Профиль водителя',
    'ka': 'მძღოლის ნახვა',
  });
  String get trips =>
      _t({'en': 'trips', 'ar': 'رحلة', 'ru': 'поездок', 'ka': 'მოგზ.'});

  String get driverNotAssigned => _t({
    'en': 'Driver will be assigned before your trip.',
    'ar': 'سيتم تعيين السائق قبل رحلتك.',
    'ru': 'Водитель будет назначен до поездки.',
    'ka': 'მძღოლი დაინიშნება მოგზაურობამდე.',
  });
  String get driverArrived => _t({
    'en': 'Your driver has arrived',
    'ar': 'وصل سائقك',
    'ru': 'Водитель прибыл',
    'ka': 'მძღოლი ჩამოვიდა',
  });
  String get driverEnRoute => _t({
    'en': 'is on the way',
    'ar': 'في الطريق',
    'ru': 'в пути',
    'ka': 'გზაშია',
  });
  String get activitiesComplete => _t({
    'en': "Today's activities are complete",
    'ar': 'اكتملت أنشطة اليوم',
    'ru': 'Все мероприятия на сегодня завершены',
    'ka': 'დღის ღონისძიებები დასრულდა',
  });
  String get enjoyEvening => _t({
    'en': 'Enjoy your evening',
    'ar': 'استمتع بمساءك',
    'ru': 'Приятного вечера',
    'ka': 'სასიამოვნო საღამო',
  });
  String get noUpcomingActivities => _t({
    'en': 'No upcoming activities',
    'ar': 'لا توجد أنشطة قادمة',
    'ru': 'Нет предстоящих мероприятий',
    'ka': 'მომავალი ღონისძიებები არ არის',
  });

  String get todaysPlan => _t({
    'en': "Today's Plan",
    'ar': 'خطة اليوم',
    'ru': 'План на сегодня',
    'ka': 'დღის გეგმა',
  });
  String get tomorrow =>
      _t({'en': 'Tomorrow', 'ar': 'غداً', 'ru': 'Завтра', 'ka': 'ხვალ'});
  String get viewTomorrow => _t({
    'en': 'View Tomorrow',
    'ar': 'عرض الغد',
    'ru': 'Посмотреть завтра',
    'ka': 'ხვალის ნახვა',
  });

  String get dayLabel =>
      _t({'en': 'Day', 'ar': 'اليوم', 'ru': 'День', 'ka': 'დღე'});
  String get ofLabel => _t({'en': 'of', 'ar': 'من', 'ru': 'из', 'ka': '-დან'});
  String get yourJourney =>
      _t({'en': 'Your', 'ar': 'رحلة', 'ru': 'Ваш', 'ka': 'თქვენი'});

  String get tripStartsIn => _t({
    'en': 'Your trip starts in',
    'ar': 'رحلتك تبدأ خلال',
    'ru': 'Поездка начнётся через',
    'ka': 'მოგზაურობა იწყება',
  });
  String get days =>
      _t({'en': 'days', 'ar': 'أيام', 'ru': 'дней', 'ka': 'დღეში'});
  String get day => _t({'en': 'day', 'ar': 'يوم', 'ru': 'день', 'ka': 'დღე'});

  // ─── My Trip Tab ───────────────────────────────────────────────────────────

  String get tripOverview => _t({
    'en': 'Trip Overview',
    'ar': 'نظرة عامة على الرحلة',
    'ru': 'Обзор поездки',
    'ka': 'მოგზაურობის მიმოხილვა',
  });
  String get reference => _t({
    'en': 'Reference',
    'ar': 'المرجع',
    'ru': 'Референс',
    'ka': 'მითითება',
  });
  String get destinationLabel => _t({
    'en': 'Destination',
    'ar': 'الوجهة',
    'ru': 'Назначение',
    'ka': 'დანიშნულება',
  });
  String get checkIn => _t({
    'en': 'Check-in',
    'ar': 'تسجيل الوصول',
    'ru': 'Заезд',
    'ka': 'ჩასვლა',
  });
  String get checkOut => _t({
    'en': 'Check-out',
    'ar': 'تسجيل المغادرة',
    'ru': 'Выезд',
    'ka': 'გასვლა',
  });
  String get duration => _t({
    'en': 'Duration',
    'ar': 'المدة',
    'ru': 'Продолжительность',
    'ka': 'ხანგრძლივობა',
  });
  String get daysLabel =>
      _t({'en': 'days', 'ar': 'أيام', 'ru': 'дней', 'ka': 'დღე'});
  String get flightsLabel => _t({
    'en': 'Flights',
    'ar': 'الرحلات الجوية',
    'ru': 'Рейсы',
    'ka': 'ფრენები',
  });
  String get hotelsLabel =>
      _t({'en': 'Hotels', 'ar': 'الفنادق', 'ru': 'Отели', 'ka': 'სასტუმროები'});
  String get flightLabel =>
      _t({'en': 'Flight', 'ar': 'رحلة جوية', 'ru': 'Рейс', 'ka': 'ფრენა'});
  String get airline => _t({
    'en': 'Airline',
    'ar': 'شركة الطيران',
    'ru': 'Авиакомпания',
    'ka': 'ავიაკომპანია',
  });
  String get route =>
      _t({'en': 'Route', 'ar': 'المسار', 'ru': 'Маршрут', 'ka': 'მარშრუტი'});
  String get departure => _t({
    'en': 'Departure',
    'ar': 'المغادرة',
    'ru': 'Отправление',
    'ka': 'გამგზავრება',
  });
  String get arrival =>
      _t({'en': 'Arrival', 'ar': 'الوصول', 'ru': 'Прибытие', 'ka': 'ჩამოსვლა'});
  String get hotel =>
      _t({'en': 'Hotel', 'ar': 'الفندق', 'ru': 'Отель', 'ka': 'სასტუმრო'});
  String get location => _t({
    'en': 'Location',
    'ar': 'الموقع',
    'ru': 'Местоположение',
    'ka': 'მდებარეობა',
  });
  String get nights =>
      _t({'en': 'Nights', 'ar': 'الليالي', 'ru': 'Ночей', 'ka': 'ღამე'});
  String get room =>
      _t({'en': 'Room', 'ar': 'الغرفة', 'ru': 'Номер', 'ka': 'ოთახი'});

  // ─── Services Tab ──────────────────────────────────────────────────────────

  String get extraServices => _t({
    'en': 'Extra Services',
    'ar': 'الخدمات الإضافية',
    'ru': 'Дополнительные услуги',
    'ka': 'დამატებითი სერვისები',
  });
  String get noExtraServices => _t({
    'en': 'No extra services',
    'ar': 'لا توجد خدمات إضافية',
    'ru': 'Нет дополнительных услуг',
    'ka': 'დამატებითი სერვისები არ არის',
  });
  String get pending => _t({
    'en': 'pending',
    'ar': 'قيد الانتظار',
    'ru': 'ожидание',
    'ka': 'მოლოდინი',
  });
  String get active =>
      _t({'en': 'active', 'ar': 'نشط', 'ru': 'активно', 'ka': 'აქტიური'});

  // ─── Support Tab ───────────────────────────────────────────────────────────

  String get supportTitle => _t({
    'en': 'Support',
    'ar': 'الدعم',
    'ru': 'Поддержка',
    'ka': 'მხარდაჭერა',
  });
  String get callUs => _t({
    'en': 'Call Us',
    'ar': 'اتصل بنا',
    'ru': 'Позвонить нам',
    'ka': 'დაგვიკავშირდით',
  });
  String get whatsapp => _t({
    'en': 'WhatsApp',
    'ar': 'واتساب',
    'ru': 'WhatsApp',
    'ka': 'WhatsApp',
  });
  String get chatWithTeam => _t({
    'en': 'Chat with our team',
    'ar': 'تحدث مع فريقنا',
    'ru': 'Чат с нашей командой',
    'ka': 'ჩვენს გუნდთან ჩატი',
  });
  String get email => _t({
    'en': 'Email',
    'ar': 'البريد الإلكتروني',
    'ru': 'Электронная почта',
    'ka': 'ელ. ფოსტა',
  });
  String get faq => _t({
    'en': 'FAQ',
    'ar': 'الأسئلة الشائعة',
    'ru': 'Часто задаваемые вопросы',
    'ka': 'ხშირად დასმული კითხვები',
  });
  String get faqSubtitle => _t({
    'en': 'Frequently asked questions',
    'ar': 'الأسئلة الأكثر شيوعاً',
    'ru': 'Часто задаваемые вопросы',
    'ka': 'ხშირად დასმული კითხვები',
  });

  // ─── Profile Tab ───────────────────────────────────────────────────────────

  String get currency =>
      _t({'en': 'Currency', 'ar': 'العملة', 'ru': 'Валюта', 'ka': 'ვალუტა'});
  String get emailLabel => _t({
    'en': 'Email',
    'ar': 'البريد الإلكتروني',
    'ru': 'Электронная почта',
    'ka': 'ელ. ფოსტა',
  });
  String get failedToLoad => _t({
    'en': 'Failed to load trip data',
    'ar': 'فشل تحميل بيانات الرحلة',
    'ru': 'Не удалось загрузить данные поездки',
    'ka': 'მოგზაურობის მონაცემების ჩატვირთვა ვერ მოხერხდა',
  });
  String get somethingWentWrong => _t({
    'en': 'Something went wrong',
    'ar': 'حدث خطأ ما',
    'ru': 'Что-то пошло не так',
    'ka': 'რაღაც შეცდომა მოხდა',
  });

  // ─── Driver Home ───────────────────────────────────────────────────────────

  String get currentTrip => _t({
    'en': 'CURRENT TRIP',
    'ar': 'الرحلة الحالية',
    'ru': 'ТЕКУЩАЯ ПОЕЗДКА',
    'ka': 'მიმდინარე მოგზაურობა',
  });
  String get nextToday => _t({
    'en': 'NEXT TODAY',
    'ar': 'التالي اليوم',
    'ru': 'СЛЕДУЮЩЕЕ СЕГОДНЯ',
    'ka': 'შემდეგი დღეს',
  });
  String get tomorrowLabel =>
      _t({'en': 'TOMORROW', 'ar': 'غداً', 'ru': 'ЗАВТРА', 'ka': 'ხვალ'});
  String get todayLabel =>
      _t({'en': 'TODAY', 'ar': 'اليوم', 'ru': 'СЕГОДНЯ', 'ka': 'დღეს'});
  String get upcomingLabel => _t({
    'en': 'UPCOMING',
    'ar': 'القادمة',
    'ru': 'ПРЕДСТОЯЩИЕ',
    'ka': 'მომავალი',
  });
  String get completedLabel => _t({
    'en': 'COMPLETED',
    'ar': 'مكتملة',
    'ru': 'ЗАВЕРШЁННЫЕ',
    'ka': 'დასრულებული',
  });
  String get noTripsAssigned => _t({
    'en': 'No trips assigned yet.',
    'ar': 'لا توجد رحلات مخصصة بعد.',
    'ru': 'Поездок пока нет.',
    'ka': 'ჯერ მოგზაურობები არ არის.',
  });
  String get assignedTripsHere => _t({
    'en': 'Your assigned trips will appear here',
    'ar': 'ستظهر رحلاتك المخصصة هنا',
    'ru': 'Здесь появятся назначенные поездки',
    'ka': 'თქვენი მინიჭებული მოგზაურობები გამოჩნდება აქ',
  });
  String get viewDetails => _t({
    'en': 'View Details',
    'ar': 'عرض التفاصيل',
    'ru': 'Подробнее',
    'ka': 'დეტალების ნახვა',
  });
  String get startTrip => _t({
    'en': 'Start Trip',
    'ar': 'بدء الرحلة',
    'ru': 'Начать поездку',
    'ka': 'მოგზაურობის დაწყება',
  });
  String get nextAssignedTrip => _t({
    'en': 'Next Assigned Trip',
    'ar': 'الرحلة المخصصة التالية',
    'ru': 'Следующая назначенная поездка',
    'ka': 'შემდეგი მინიჭებული მოგზაურობა',
  });
  String get vehicle => _t({
    'en': 'Vehicle',
    'ar': 'المركبة',
    'ru': 'Автомобиль',
    'ka': 'მანქანა',
  });
  String get color =>
      _t({'en': 'Color', 'ar': 'اللون', 'ru': 'Цвет', 'ka': 'ფერი'});
  String get plate =>
      _t({'en': 'Plate', 'ar': 'لوحة الترخيص', 'ru': 'Номер', 'ka': 'ნომერი'});
  String get tripsLabel => _t({
    'en': 'Trips',
    'ar': 'الرحلات',
    'ru': 'Поездки',
    'ka': 'მოგზაურობები',
  });
  // New Driver Home strings
  String get upcomingTrip => _t({
    'en': 'UPCOMING TRIP',
    'ar': 'الرحلة القادمة',
    'ru': 'ПРЕДСТОЯЩАЯ ПОЕЗДКА',
    'ka': 'მომავალი მოგზაურობა',
  });
  String get activeTrip =>
      _t({'en': 'ACTIVE', 'ar': 'نشطة', 'ru': 'АКТИВНАЯ', 'ka': 'აქტიური'});
  String get activeLabel =>
      _t({'en': 'NOW', 'ar': 'الآن', 'ru': 'СЕЙЧАС', 'ka': 'ახლა'});
  String get viewTrip => _t({
    'en': 'View Trip',
    'ar': 'عرض الرحلة',
    'ru': 'Посмотреть поездку',
    'ka': 'მოგზაურობის ნახვა',
  });
  String get viewFullTrip => _t({
    'en': 'View Full Trip',
    'ar': 'عرض الرحلة الكاملة',
    'ru': 'Полная информация о поездке',
    'ka': 'სრული მოგზაურობის ნახვა',
  });
  String get hotelCheckIn => _t({
    'en': 'HOTEL CHECK-IN',
    'ar': 'تسجيل الوصول للفندق',
    'ru': 'ЗАЕЗД В ОТЕЛЬ',
    'ka': 'სასტუმროში ჩასვლა',
  });
  String get hotelCheckOut => _t({
    'en': 'HOTEL CHECK-OUT',
    'ar': 'تسجيل المغادرة من الفندق',
    'ru': 'ВЫЕЗД ИЗ ОТЕЛЯ',
    'ka': 'სასტუმროდან გასვლა',
  });
  String get currentHotel => _t({
    'en': 'CURRENT HOTEL',
    'ar': 'الفندق الحالي',
    'ru': 'ТЕКУЩИЙ ОТЕЛЬ',
    'ka': 'მიმდინარე სასტუმრო',
  });
  String get finalNight => _t({
    'en': 'FINAL NIGHT',
    'ar': 'الليلة الأخيرة',
    'ru': 'ПОСЛЕДНЯЯ НОЧЬ',
    'ka': 'ბოლო ღამე',
  });
  String get night =>
      _t({'en': 'Night', 'ar': 'ليلة', 'ru': 'Ночь', 'ka': 'ღამე'});
  String get moreSegments => _t({
    'en': 'more segments',
    'ar': 'مقاطع أخرى',
    'ru': 'ещё сегментов',
    'ka': 'მეტი სეგმენტი',
  });
  // Full Trip Details strings
  String get fullTripDetails => _t({
    'en': 'Full Trip Details',
    'ar': 'تفاصيل الرحلة الكاملة',
    'ru': 'Полные данные поездки',
    'ka': 'სრული მოგზაურობის დეტალები',
  });
  String get arrivalInfo =>
      _t({'en': 'ARRIVAL', 'ar': 'الوصول', 'ru': 'ПРИБЫТИЕ', 'ka': 'ჩამოსვლა'});
  String get arrivalFlight => _t({
    'en': 'ARRIVAL FLIGHT',
    'ar': 'رحلة الوصول',
    'ru': 'РЕЙС ПРИБЫТИЯ',
    'ka': 'ჩამოსვლის ფრენა',
  });
  String get departureInfo => _t({
    'en': 'DEPARTURE',
    'ar': 'المغادرة',
    'ru': 'ОТПРАВЛЕНИЕ',
    'ka': 'გამგზავრება',
  });
  String get transportationLabel => _t({
    'en': 'TRANSPORTATION',
    'ar': 'النقل',
    'ru': 'ТРАНСПОРТ',
    'ka': 'ტრანსპორტი',
  });
  String get airport => _t({
    'en': 'Airport',
    'ar': 'المطار',
    'ru': 'Аэропорт',
    'ka': 'აეროპორტი',
  });
  String get firstPickup => _t({
    'en': 'First Pickup',
    'ar': 'أول استقبال',
    'ru': 'Первая подача',
    'ka': 'პირველი მიყვანა',
  });
  String get passengers => _t({
    'en': 'Passengers',
    'ar': 'الركاب',
    'ru': 'Пассажиры',
    'ka': 'მგზავრები',
  });
  String get arrivalTime => _t({
    'en': 'Arrival Time',
    'ar': 'وقت الوصول',
    'ru': 'Время прибытия',
    'ka': 'ჩამოსვლის დრო',
  });
  String get departureTime => _t({
    'en': 'Departure Time',
    'ar': 'وقت المغادرة',
    'ru': 'Время отправления',
    'ka': 'გამგზავრების დრო',
  });
  String get terminal => _t({
    'en': 'Terminal',
    'ar': 'الصالة',
    'ru': 'Терминал',
    'ka': 'ტერმინალი',
  });
  String get gate =>
      _t({'en': 'Gate', 'ar': 'البوابة', 'ru': 'Выход', 'ka': 'გეითი'});
  String get guestInfo =>
      _t({'en': 'Guest', 'ar': 'الضيف', 'ru': 'Гость', 'ka': 'სტუმარი'});

  // ─── Driver Onboarding — Location Permission ───────────────────────────────

  String get locationRequired => _t({
    'en': 'Location Required',
    'ar': 'الموقع مطلوب',
    'ru': 'Требуется геолокация',
    'ka': 'საჭიროა მდებარეობა',
  });
  String get locationRequiredSubtitle => _t({
    'en': 'To operate as a driver, we need access to your location.',
    'ar': 'للعمل كسائق، نحتاج إلى الوصول إلى موقعك.',
    'ru': 'Для работы водителем нам необходим доступ к вашему местоположению.',
    'ka': 'მძღოლად მუშაობისთვის გვჭირდება თქვენი მდებარეობის წვდომა.',
  });
  String get locationFeature1 => _t({
    'en': 'Assigned trip navigation',
    'ar': 'التنقل في الرحلات المخصصة',
    'ru': 'Навигация по назначенным поездкам',
    'ka': 'მინიჭებული მოგზაურობის ნავიგაცია',
  });
  String get locationFeature2 => _t({
    'en': 'Live driver location sharing',
    'ar': 'مشاركة موقع السائق المباشر',
    'ru': 'Трансляция местоположения водителя',
    'ka': 'მძღოლის ცოცხალი მდებარეობის გაზიარება',
  });
  String get locationFeature3 => _t({
    'en': 'Pickup point tracking',
    'ar': 'تتبع نقطة الاستقبال',
    'ru': 'Отслеживание точки подачи',
    'ka': 'გამგზავრების წერტილის თვალყურის დევნება',
  });
  String get locationFeature4 => _t({
    'en': 'Customer driver tracking',
    'ar': 'تتبع السائق من قِبل العميل',
    'ru': 'Отслеживание водителя клиентом',
    'ka': 'კლიენტის მიერ მძღოლის თვალყურის დევნება',
  });
  String get locationFeature5 => _t({
    'en': 'Trip operations and routing',
    'ar': 'عمليات الرحلة والتوجيه',
    'ru': 'Операции поездки и маршрутизация',
    'ka': 'მოგზაურობის ოპერაციები და მარშრუტი',
  });
  String get enableLocation => _t({
    'en': 'Enable Location',
    'ar': 'تفعيل الموقع',
    'ru': 'Включить геолокацию',
    'ka': 'მდებარეობის ჩართვა',
  });
  String get openSettings => _t({
    'en': 'Open Settings',
    'ar': 'فتح الإعدادات',
    'ru': 'Открыть настройки',
    'ka': 'პარამეტრების გახსნა',
  });
  String get locationDeniedTitle => _t({
    'en': 'Location Access Denied',
    'ar': 'تم رفض الوصول إلى الموقع',
    'ru': 'Доступ к геолокации запрещён',
    'ka': 'მდებარეობის წვდომა უარყოფილია',
  });
  String get locationDeniedMessage => _t({
    'en': 'Location permission was denied. Please enable it to continue.',
    'ar': 'تم رفض إذن الموقع. يرجى تفعيله للمتابعة.',
    'ru': 'Разрешение на геолокацию отклонено. Включите его для продолжения.',
    'ka': 'მდებარეობის ნებართვა უარყოფილია. გასაგრძელებლად ჩართეთ.',
  });
  String get locationPermanentlyDenied => _t({
    'en':
        'Location permission is permanently denied. Please open Settings to enable it.',
    'ar': 'تم رفض إذن الموقع بشكل دائم. يرجى فتح الإعدادات لتفعيله.',
    'ru':
        'Разрешение на геолокацию заблокировано навсегда. Откройте Настройки для включения.',
    'ka':
        'მდებარეობის ნებართვა სამუდამოდ უარყოფილია. გახსენით პარამეტრები ჩასართავად.',
  });
  String get locationServicesDisabled => _t({
    'en':
        'Location services are disabled on your device. Please enable them in Settings.',
    'ar': 'خدمات الموقع معطّلة على جهازك. يرجى تفعيلها في الإعدادات.',
    'ru':
        'Службы геолокации отключены на устройстве. Включите их в Настройках.',
    'ka':
        'მდებარეობის სერვისები გამორთულია მოწყობილობაზე. ჩართეთ პარამეტრებში.',
  });
  String get locationPermissionBody => _t({
    'en':
        'Location access is required for assigned trips, navigation, pickup tracking and live trip operations.',
    'ar':
        'يُعدّ الوصول إلى الموقع ضروريًا للرحلات المخصصة والتنقل وتتبع نقاط الاستقبال وعمليات الرحلة المباشرة.',
    'ru':
        'Доступ к геолокации необходим для назначенных поездок, навигации, отслеживания точки подачи и операций в реальном времени.',
    'ka':
        'მდებარეობის წვდომა საჭიროა მინიჭებული მოგზაურობებისთვის, ნავიგაციისთვის, გამგზავრების თვალყურის დევნებისა და ცოცხალი ოპერაციებისთვის.',
  });
  String get openLocationSettings => _t({
    'en': 'Open Location Settings',
    'ar': 'فتح إعدادات الموقع',
    'ru': 'Открыть настройки геолокации',
    'ka': 'მდებარეობის პარამეტრების გახსნა',
  });
  String get locationFeatureTrips => _t({
    'en': 'Assigned trips',
    'ar': 'الرحلات المخصصة',
    'ru': 'Назначенные поездки',
    'ka': 'მინიჭებული მოგზაურობები',
  });
  String get locationFeatureNavigation => _t({
    'en': 'Navigation',
    'ar': 'التنقل والملاحة',
    'ru': 'Навигация',
    'ka': 'ნავიგაცია',
  });
  String get locationFeaturePickup => _t({
    'en': 'Pickup tracking',
    'ar': 'تتبع نقطة الاستقبال',
    'ru': 'Отслеживание точки подачи',
    'ka': 'გამგზავრების თვალყურის დევნება',
  });
  String get locationFeatureTracking => _t({
    'en': 'Live trip tracking',
    'ar': 'تتبع الرحلة المباشر',
    'ru': 'Отслеживание поездки в реальном времени',
    'ka': 'ცოცხალი მოგზაურობის თვალყურის დევნება',
  });
  String get locationFeatureLiveOps => _t({
    'en': 'Live trip operations',
    'ar': 'عمليات الرحلة المباشرة',
    'ru': 'Операции поездки в реальном времени',
    'ka': 'ცოცხალი მოგზაურობის ოპერაციები',
  });

  // ─── Driver Onboarding — Profile Completion ────────────────────────────────

  String get completeYourProfile => _t({
    'en': 'Complete Your Profile',
    'ar': 'أكمل ملفك الشخصي',
    'ru': 'Заполните профиль',
    'ka': 'შეავსეთ თქვენი პროფილი',
  });
  String get profileCompletionSubtitle => _t({
    'en': 'Required before you can start accepting trips.',
    'ar': 'مطلوب قبل أن تتمكن من قبول الرحلات.',
    'ru': 'Необходимо заполнить перед началом работы.',
    'ka': 'საჭიროა მოგზაურობების მიღების დაწყებამდე.',
  });
  String get personalPhotos => _t({
    'en': 'Personal Photos',
    'ar': 'الصور الشخصية',
    'ru': 'Личные фотографии',
    'ka': 'პირადი ფოტოები',
  });
  String get personalPhotosSubtitle => _t({
    'en': 'Clear photos of yourself for customer identification.',
    'ar': 'صور واضحة لك لتعريف العملاء.',
    'ru': 'Чёткие фотографии для идентификации клиентами.',
    'ka': 'მკაფიო ფოტოები კლიენტების მიერ იდენტიფიკაციისთვის.',
  });
  String get vehiclePhotos => _t({
    'en': 'Vehicle Photos',
    'ar': 'صور المركبة',
    'ru': 'Фотографии автомобиля',
    'ka': 'მანქანის ფოტოები',
  });
  String get vehiclePhotosSubtitle => _t({
    'en': 'Photos of your vehicle from multiple angles.',
    'ar': 'صور مركبتك من زوايا متعددة.',
    'ru': 'Фотографии автомобиля с разных ракурсов.',
    'ka': 'მანქანის ფოტოები სხვადასხვა კუთხიდან.',
  });
  String get vehicleInformation => _t({
    'en': 'Vehicle Information',
    'ar': 'معلومات المركبة',
    'ru': 'Информация об автомобиле',
    'ka': 'მანქანის ინფორმაცია',
  });
  String get plateNumber => _t({
    'en': 'Plate Number',
    'ar': 'رقم اللوحة',
    'ru': 'Номерной знак',
    'ka': 'სანომრე ნიშანი',
  });
  String get plateNumberHint => _t({
    'en': 'e.g. GG-123-AB',
    'ar': 'مثال: GG-123-AB',
    'ru': 'напр. GG-123-AB',
    'ka': 'მაგ. GG-123-AB',
  });
  String get vehicleModelLabel => _t({
    'en': 'Vehicle Model',
    'ar': 'موديل المركبة',
    'ru': 'Модель автомобиля',
    'ka': 'მანქანის მოდელი',
  });
  String get vehicleModelHint => _t({
    'en': 'e.g. Toyota Camry',
    'ar': 'مثال: تويوتا كامري',
    'ru': 'напр. Toyota Camry',
    'ka': 'მაგ. Toyota Camry',
  });
  String get submitProfile => _t({
    'en': 'Submit Profile',
    'ar': 'إرسال الملف الشخصي',
    'ru': 'Отправить профиль',
    'ka': 'პროფილის გაგზავნა',
  });
  String get uploadedOf => _t({
    'en': 'uploaded',
    'ar': 'تم الرفع',
    'ru': 'загружено',
    'ka': 'ატვირთულია',
  });
  String get addPhoto => _t({
    'en': 'Add Photo',
    'ar': 'إضافة صورة',
    'ru': 'Добавить фото',
    'ka': 'ფოტოს დამატება',
  });
  String get takePhoto => _t({
    'en': 'Take Photo',
    'ar': 'التقاط صورة',
    'ru': 'Сделать фото',
    'ka': 'ფოტოს გადაღება',
  });
  String get chooseFromGallery => _t({
    'en': 'Choose from Gallery',
    'ar': 'اختيار من المعرض',
    'ru': 'Выбрать из галереи',
    'ka': 'გალერიიდან არჩევა',
  });
  String get replacePhoto => _t({
    'en': 'Replace Photo',
    'ar': 'استبدال الصورة',
    'ru': 'Заменить фото',
    'ka': 'ფოტოს შეცვლა',
  });
  String get removePhoto => _t({
    'en': 'Remove Photo',
    'ar': 'حذف الصورة',
    'ru': 'Удалить фото',
    'ka': 'ფოტოს წაშლა',
  });
  String get profileSubmitting => _t({
    'en': 'Submitting your profile...',
    'ar': 'جارٍ إرسال ملفك الشخصي...',
    'ru': 'Отправка профиля...',
    'ka': 'პროფილი იგზავნება...',
  });

  String get verifyingProfile => _t({
    'en': 'Verifying with Odoo...',
    'ar': 'جارٍ التحقق مع أودو...',
    'ru': 'Проверка в Odoo...',
    'ka': 'Odoo-ში შემოწმება...',
  });

  String get profileSubmitSuccess => _t({
    'en': 'Profile submitted successfully!',
    'ar': 'تم إرسال الملف الشخصي بنجاح!',
    'ru': 'Профиль успешно отправлен!',
    'ka': 'პროფილი წარმატებით გაიგზავნა!',
  });
  String get profileSubmitError => _t({
    'en': 'Failed to submit profile. Please try again.',
    'ar': 'فشل إرسال الملف الشخصي. يرجى المحاولة مرة أخرى.',
    'ru': 'Не удалось отправить профиль. Попробуйте ещё раз.',
    'ka': 'პროფილის გაგზავნა ვერ მოხერხდა. სცადეთ ხელახლა.',
  });
  String get fillAllFields => _t({
    'en': 'Please fill in all required fields and upload all photos.',
    'ar': 'يرجى ملء جميع الحقول المطلوبة ورفع جميع الصور.',
    'ru':
        'Пожалуйста, заполните все обязательные поля и загрузите все фотографии.',
    'ka': 'გთხოვთ შეავსოთ ყველა სავალდებულო ველი და ატვირთოთ ყველა ფოტო.',
  });
  String get uploadingPhotos => _t({
    'en': 'Uploading photos...',
    'ar': 'جارٍ رفع الصور...',
    'ru': 'Загрузка фотографий...',
    'ka': 'ფოტოები იტვირთება...',
  });
  String get photoUploadError => _t({
    'en': 'Failed to upload photo. Tap to retry.',
    'ar': 'فشل رفع الصورة. اضغط للمحاولة مرة أخرى.',
    'ru': 'Не удалось загрузить фото. Нажмите для повтора.',
    'ka': 'ფოტოს ატვირთვა ვერ მოხერხდა. შეეხეთ ხელახლა სცადეთ.',
  });
  String get required3PersonalPhotos => _t({
    'en': 'Exactly 3 personal photos required',
    'ar': 'مطلوب 3 صور شخصية بالضبط',
    'ru': 'Требуется ровно 3 личных фотографии',
    'ka': 'საჭიროა ზუსტად 3 პირადი ფოტო',
  });
  String get required5VehiclePhotos => _t({
    'en': 'Exactly 5 vehicle photos required',
    'ar': 'مطلوب 5 صور للمركبة بالضبط',
    'ru': 'Требуется ровно 5 фотографий автомобиля',
    'ka': 'საჭიროა ზუსტად 5 მანქანის ფოტო',
  });

  // ─── Greeting helper ───────────────────────────────────────────────────────

  String greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return goodMorning;
    if (hour < 17) return goodAfternoon;
    return goodEvening;
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  String _t(Map<String, String> map) {
    return map[locale] ?? map['en'] ?? '';
  }
}

/// InheritedWidget that provides AppLocalizations down the tree.
class _LocalizationInheritedWidget extends InheritedWidget {
  final LocalizationService service;

  const _LocalizationInheritedWidget({
    required this.service,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LocalizationInheritedWidget old) =>
      old.service.currentLanguage != service.currentLanguage;
}

/// Wrap your app (or subtree) with this to provide AppLocalizations.
class SphinxLocalizationProvider extends StatefulWidget {
  final LocalizationService service;
  final Widget child;

  const SphinxLocalizationProvider({
    super.key,
    required this.service,
    required this.child,
  });

  @override
  State<SphinxLocalizationProvider> createState() =>
      _SphinxLocalizationProviderState();
}

class _SphinxLocalizationProviderState
    extends State<SphinxLocalizationProvider> {
  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    widget.service.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return _LocalizationInheritedWidget(
      service: widget.service,
      child: widget.child,
    );
  }
}
