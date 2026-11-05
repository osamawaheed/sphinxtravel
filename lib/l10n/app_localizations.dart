import 'package:flutter/material.dart';

import '../services/localization_service.dart';
import './az_app_translations.dart';

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

  String get appName =>
      _t({'en': 'TourOps', 'ar': 'TourOps', 'ru': 'TourOps', 'ka': 'TourOps'});
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
  String get enableBiometricLogin => _t({
    'en': 'Enable Biometric Login',
    'ar': 'تفعيل تسجيل الدخول بالبصمة',
    'ru': 'Включить биометрический вход',
    'ka': 'ბიომეტრიული შესვლის ჩართვა',
  });
  String get enableBiometricLoginMessage => _t({
    'en':
        'Sign in faster next time with a Passkey using your fingerprint, face or device screen lock. Your password stays as a fallback.',
    'ar':
        'سجّل الدخول بشكل أسرع في المرة القادمة باستخدام مفتاح المرور عبر البصمة أو الوجه أو قفل الشاشة. تبقى كلمة المرور خيارًا بديلًا.',
    'ru':
        'В следующий раз входите быстрее с помощью Passkey: отпечаток пальца, лицо или блокировка экрана. Пароль остаётся запасным вариантом.',
    'ka':
        'შემდეგ ჯერზე უფრო სწრაფად შედით Passkey-ით თითის ანაბეჭდით, სახით ან ეკრანის დაბლოკვით. პაროლი რჩება სარეზერვო ვარიანტად.',
  });
  String get notNow => _t({
    'en': 'Not now',
    'ar': 'ليس الآن',
    'ru': 'Не сейчас',
    'ka': 'ახლა არა',
  });
  String get signInWithPasskey => _t({
    'en': 'Sign in with Passkey',
    'ar': 'تسجيل الدخول بمفتاح المرور',
    'ru': 'Войти с помощью Passkey',
    'ka': 'შესვლა Passkey-ით',
  });
  String get securitySectionTitle => _t({
    'en': 'Security',
    'ar': 'الأمان',
    'ru': 'Безопасность',
    'ka': 'უსაფრთხოება',
  });
  String get customerPhoneUnavailable => _t({
    'en': 'Customer phone number is not available.',
    'ar': 'رقم هاتف العميل غير متوفر.',
    'ru': 'Номер телефона клиента недоступен.',
    'ka': 'მომხმარებლის ტელეფონის ნომერი მიუწვდომელია.',
  });
  String get callFailed => _t({
    'en': 'Could not open the phone dialer.',
    'ar': 'تعذر فتح تطبيق الاتصال.',
    'ru': 'Не удалось открыть набор номера.',
    'ka': 'ტელეფონის აპლიკაციის გახსნა ვერ მოხერხდა.',
  });
  String get passkeyLogin => _t({
    'en': 'Passkey Login',
    'ar': 'تسجيل الدخول بمفتاح المرور',
    'ru': 'Вход по Passkey',
    'ka': 'Passkey-ით შესვლა',
  });
  String get passkeyUnavailableYet => _t({
    'en': 'Passkey login is not available yet. Please use your password.',
    'ar': 'تسجيل الدخول بمفتاح المرور غير متاح بعد. يرجى استخدام كلمة المرور.',
    'ru': 'Вход по Passkey пока недоступен. Используйте пароль.',
    'ka': 'Passkey-ით შესვლა ჯერ მიუწვდომელია. გამოიყენეთ პაროლი.',
  });
  String get passkeyComingSoon =>
      _t({'en': 'Coming soon', 'ar': 'قريبًا', 'ru': 'Скоро', 'ka': 'მალე'});
  String get passkeyDisabledMessage => _t({
    'en': 'Passkey login disabled on this device.',
    'ar': 'تم تعطيل تسجيل الدخول بمفتاح المرور على هذا الجهاز.',
    'ru': 'Вход по Passkey отключён на этом устройстве.',
    'ka': 'Passkey-ით შესვლა გამორთულია ამ მოწყობილობაზე.',
  });
  String get passkeyFailed => _t({
    'en': 'Passkey sign-in failed. Please use your password.',
    'ar': 'فشل تسجيل الدخول بمفتاح المرور. يرجى استخدام كلمة المرور.',
    'ru': 'Не удалось войти с Passkey. Используйте пароль.',
    'ka': 'Passkey-ით შესვლა ვერ მოხერხდა. გამოიყენეთ პაროლი.',
  });
  String get passkeySubtitle => _t({
    'en': 'Use fingerprint, face or screen lock to sign in',
    'ar': 'استخدم البصمة أو الوجه أو قفل الشاشة لتسجيل الدخول',
    'ru': 'Входите по отпечатку, лицу или блокировке экрана',
    'ka': 'შედით თითის ანაბეჭდით, სახით ან ეკრანის დაბლოკვით',
  });
  String get signOutMessage => _t({
    'en': 'Are you sure you want to sign out?',
    'ar': 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
    'ru': 'Вы уверены, что хотите выйти?',
    'ka': 'დარწმუნებული ხართ, რომ გსურთ გასვლა?',
  });
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
    'en': '© 2026 Sphinx Travel LLC. All rights reserved.',
    'ar': '© 2026 Sphinx Travel LLC. جميع الحقوق محفوظة.',
    'ru': '© 2026 Sphinx Travel LLC. Все права защищены.',
    'ka': '© 2026 Sphinx Travel LLC. ყველა უფლება დაცულია.',
  });

  // ─── Language Selection ────────────────────────────────────────────────────

  String get selectLanguage => _t({
    'en': 'Select Your\nLanguage',
    'ar': 'اختر\nلغتك',
    'ru': 'Выберите\nязык',
    'ka': 'აირჩიეთ\nენა',
  });
  String get chooseYourLanguage => _t({
    'en': 'Choose Your Language',
    'ar': 'اختر لغتك',
    'ru': 'Выберите язык',
    'ka': 'აირჩიეთ ენა',
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
    'en':
        "We'll send a verification code to the phone number registered with your booking.",
    'ar': 'سنرسل رمز التحقق إلى رقم الهاتف المسجل في حجزك.',
    'ru':
        'Мы отправим код подтверждения на номер телефона, указанный в вашем бронировании.',
    'ka':
        'ჩვენ გამოგიგზავნით დამადასტურებელ კოდს თქვენს ჯავშანზე რეგისტრირებულ ტელეფონის ნომერზე.',
  });
  String get phoneHint => _t({
    'en': 'Phone number',
    'ar': 'رقم الهاتف',
    'ru': 'Номер телефона',
    'ka': 'ტელეფონის ნომერი',
  });
  String get sendOtpWhatsapp => _t({
    'en': 'Send Verification Code',
    'ar': 'إرسال رمز التحقق',
    'ru': 'Отправить код подтверждения',
    'ka': 'დამადასტურებელი კოდის გაგზავნა',
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
    'en': 'Use your Tour Operations driver account',
    'ar': 'استخدم حساب سائق Tour Operations',
    'ru': 'Используйте аккаунт водителя Tour Operations',
    'ka': 'გამოიყენეთ Tour Operations-ის მძღოლის ანგარიში',
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

  String get driverLoginFailedMessage => _t({
    'en': 'Incorrect username or password. Please try again.',
    'ar': 'اسم المستخدم أو كلمة المرور غير صحيحة. يُرجى المحاولة مرة أخرى.',
    'ru': 'Неверное имя пользователя или пароль. Попробуйте ещё раз.',
    'ka': 'არასწორი მომხმარებლის სახელი ან პაროლი. სცადეთ ხელახლა.',
  });
  String get driverLoginFailedMultiple => _t({
    'en':
        'Login failed multiple times. Please contact the Operations Team to verify your username and password.',
    'ar':
        'فشلت محاولات تسجيل الدخول عدة مرات. يُرجى التواصل مع فريق العمليات للتأكد من صحة اسم المستخدم وكلمة المرور.',
    'ru':
        'Не удалось войти несколько раз. Обратитесь в операционную службу, чтобы проверить имя пользователя и пароль.',
    'ka':
        'შესვლა რამდენჯერმე ვერ მოხერხდა. დაუკავშირდით ოპერაციების გუნდს მომხმარებლის სახელისა და პაროლის შესამოწმებლად.',
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
  String get esimDeliveryQuestion => _t({
    'en': 'Have you delivered the eSIM cards to the customer?',
    'ar': 'هل قمت بتسليم شرائح eSIM إلى العميل؟',
    'ru': 'Вы передали eSIM-карты клиенту?',
    'ka': 'მიაწოდეთ თუ არა eSIM ბარათები მომხმარებელს?',
  });
  String get cancelAction =>
      _t({'en': 'Cancel', 'ar': 'إلغاء', 'ru': 'Отмена', 'ka': 'გაუქმება'});
  String get confirmDelivery => _t({
    'en': 'Confirm Delivery',
    'ar': 'تأكيد التسليم',
    'ru': 'Подтвердить доставку',
    'ka': 'მიწოდების დადასტურება',
  });
  String get deliveredLabel => _t({
    'en': 'Delivered',
    'ar': 'تم التسليم',
    'ru': 'Доставлено',
    'ka': 'მიწოდებულია',
  });
  String get tapToConfirmDelivery => _t({
    'en': 'Tap to confirm delivery',
    'ar': 'اضغط لتأكيد التسليم',
    'ru': 'Нажмите для подтверждения',
    'ka': 'დააჭირეთ დასადასტურებლად',
  });
  String get esimDeliveredSuccess => _t({
    'en': 'eSIM delivery confirmed',
    'ar': 'تم تأكيد تسليم eSIM',
    'ru': 'Доставка eSIM подтверждена',
    'ka': 'eSIM-ის მიწოდება დადასტურდა',
  });
  String get esimDeliveryFailed => _t({
    'en': 'Could not confirm delivery. Please try again.',
    'ar': 'تعذر تأكيد التسليم. يرجى المحاولة مرة أخرى.',
    'ru': 'Не удалось подтвердить доставку. Попробуйте снова.',
    'ka': 'მიწოდების დადასტურება ვერ მოხერხდა. სცადეთ ხელახლა.',
  });
  String get wallet =>
      _t({'en': 'Wallet', 'ar': 'المحفظة', 'ru': 'Кошелёк', 'ka': 'საფულე'});
  String get walletBalance =>
      _t({'en': 'Balance', 'ar': 'الرصيد', 'ru': 'Баланс', 'ka': 'ბალანსი'});
  String get transactions => _t({
    'en': 'Transactions',
    'ar': 'المعاملات',
    'ru': 'Транзакции',
    'ka': 'ტრანზაქციები',
  });
  String get noTransactionsYet => _t({
    'en': 'No transactions yet',
    'ar': 'لا توجد معاملات بعد',
    'ru': 'Транзакций пока нет',
    'ka': 'ტრანზაქციები ჯერ არ არის',
  });
  String get viewUpdateStatus => _t({
    'en': 'View / Update status',
    'ar': 'عرض / تحديث الحالة',
    'ru': 'Просмотр / обновление статуса',
    'ka': 'სტატუსის ნახვა / განახლება',
  });
  String get driverNoColon =>
      _t({'en': 'Driver', 'ar': 'السائق', 'ru': 'Водитель', 'ka': 'მძღოლი'});
  String get noDriverAssigned => _t({
    'en': 'No driver assigned',
    'ar': 'لم يتم تعيين سائق',
    'ru': 'Водитель не назначен',
    'ka': 'მძღოლი არ არის მინიჭებული',
  });
  String get myTripsTitle => _t({
    'en': 'My Trips',
    'ar': 'رحلاتي',
    'ru': 'Мои поездки',
    'ka': 'ჩემი მოგზაურობები',
  });
  String get tripEndedRibbon => _t({
    'en': 'Ended',
    'ar': 'Ended',
    'ru': 'Завершено',
    'ka': 'დასრულებულია',
  });
  String get tripDetails => _t({
    'en': 'Trip Details',
    'ar': 'تفاصيل الرحلة',
    'ru': 'Детали поездки',
    'ka': 'მოგზაურობის დეტალები',
  });
  String get driverTaskTitle => _t({
    'en': 'Driver Task',
    'ar': 'مهمة السائق',
    'ru': 'Задача водителя',
    'ka': 'მძღოლის დავალება',
  });
  String get statusReadyToGo => _t({
    'en': 'Ready to Go',
    'ar': 'جاهز للانطلاق',
    'ru': 'Готов к выезду',
    'ka': 'მზადაა გასასვლელად',
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
  String get driverWillBeAssignedSoon => _t({
    'en': 'Your driver will be assigned soon',
    'ar': 'سيتم تعيين سائقك قريباً',
    'ru': 'Водитель скоро будет назначен',
    'ka': 'თქვენი მძღოლი მალე დაინიშნება',
  });
  String get driverIsOnTheWay => _t({
    'en': 'Driver is on the way',
    'ar': 'السائق في الطريق إليك',
    'ru': 'Водитель в пути',
    'ka': 'მძღოლი გზაშია',
  });
  String driverArrivesInMin(int min) => _t({
    'en': 'Your driver arrives in $min min',
    'ar': 'سائقك يصل خلال $min دقيقة',
    'ru': 'Водитель прибудет через $min мин',
    'ka': 'მძღოლი ჩამოვა $min წუთში',
    'az': 'Sürücünüz $min dəq. ərzində çatacaq',
  });
  String get tripStatusAssigned => _t({
    'en': 'Ready',
    'ar': 'تم التعيين',
    'ru': 'Назначен',
    'ka': 'დანიშნულია',
  });
  String get tripStatusOnTheWay => _t({
    'en': 'On The Way',
    'ar': 'في الطريق',
    'ru': 'В пути',
    'ka': 'გზაშია',
  });
  String get tripStatusPickedUp => _t({
    'en': 'Picked Up',
    'ar': 'تم الاستقبال',
    'ru': 'Пассажир забран',
    'ka': 'აყვანილია',
  });
  String get tripStatusInTour =>
      _t({'en': 'In Tour', 'ar': 'في الجولة', 'ru': 'В туре', 'ka': 'ტურშია'});
  String get tripStatusCompleted => _t({
    'en': 'Completed',
    'ar': 'مكتمل',
    'ru': 'Завершено',
    'ka': 'დასრულებულია',
  });
  String get whatsapp => _t({
    'en': 'WhatsApp',
    'ar': 'واتساب',
    'ru': 'WhatsApp',
    'ka': 'WhatsApp',
  });
  String get driverAndVehiclePhotos => _t({
    'en': 'Driver & Vehicle',
    'ar': 'السائق والمركبة',
    'ru': 'Водитель и автомобиль',
    'ka': 'მძღოლი და ავტომობილი',
  });
  String get driverPhotoLabel =>
      _t({'en': 'Driver', 'ar': 'السائق', 'ru': 'Водитель', 'ka': 'მძღოლი'});
  String get vehiclePhotoLabel => _t({
    'en': 'Vehicle',
    'ar': 'المركبة',
    'ru': 'Автомобиль',
    'ka': 'ავტომობილი',
  });
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
  String get transportDateLabel =>
      _t({'en': 'Date', 'ar': 'التاريخ', 'ru': 'Дата', 'ka': 'თარიღი'});
  String get transportTimeLabel =>
      _t({'en': 'Time', 'ar': 'الوقت', 'ru': 'Время', 'ka': 'დრო'});
  String get transportCityLabel =>
      _t({'en': 'City', 'ar': 'المدينة', 'ru': 'Город', 'ka': 'ქალაქი'});
  String get transportStatusLabel =>
      _t({'en': 'Status', 'ar': 'الحالة', 'ru': 'Статус', 'ka': 'სტატუსი'});
  String get rateDriverTitle => _t({
    'en': 'Rate your driver',
    'ar': 'قيّم السائق',
    'ru': 'Оцените водителя',
    'ka': 'შეაფასეთ მძღოლი',
  });
  String get rateDriverButton => _t({
    'en': 'Rate Driver',
    'ar': 'قيّم السائق',
    'ru': 'Оценить водителя',
    'ka': 'მძღოლის შეფასება',
  });
  String get submitReview =>
      _t({'en': 'Submit', 'ar': 'إرسال', 'ru': 'Отправить', 'ka': 'გაგზავნა'});
  String get rateHotelTitle => _t({
    'en': 'Rate your hotel',
    'ar': 'قيّم الفندق',
    'ru': 'Оцените отель',
    'ka': 'შეაფასეთ სასტუმრო',
  });
  String get submitRating => _t({
    'en': 'Submit rating',
    'ar': 'إرسال التقييم',
    'ru': 'Отправить оценку',
    'ka': 'შეფასების გაგზავნა',
  });
  String get updateRating => _t({
    'en': 'Update rating',
    'ar': 'تحديث التقييم',
    'ru': 'Обновить оценку',
    'ka': 'შეფასების განახლება',
  });
  String get ratingCommentHint => _t({
    'en': 'Add a comment (optional)',
    'ar': 'أضف تعليقاً (اختياري)',
    'ru': 'Добавьте комментарий (необязательно)',
    'ka': 'დაამატეთ კომენტარი (არასავალდებულო)',
  });
  String get ratingRequired => _t({
    'en': 'Please select a rating from 1 to 5',
    'ar': 'يرجى اختيار تقييم من 1 إلى 5',
    'ru': 'Выберите оценку от 1 до 5',
    'ka': 'აირჩიეთ შეფასება 1-დან 5-მდე',
  });
  String get driverRatingRequired => _t({
    'en': 'Please select a rating from 1 to 10',
    'ar': 'يرجى اختيار تقييم من 1 إلى 10',
    'ru': 'Выберите оценку от 1 до 10',
    'ka': 'აირჩიეთ შეფასება 1-დან 10-მდე',
  });
  String get thanksForRating => _t({
    'en': 'Thanks for your rating',
    'ar': 'شكراً على تقييمك',
    'ru': 'Спасибо за вашу оценку',
    'ka': 'გმადლობთ შეფასებისთვის',
  });
  String get destination => _t({
    'en': 'Destination',
    'ar': 'الوجهة',
    'ru': 'Назначение',
    'ka': 'დანიშნულება',
  });
  String get call =>
      _t({'en': 'Call', 'ar': 'اتصال', 'ru': 'Позвонить', 'ka': 'დარეკვა'});
  String get printCustomerName => _t({
    'en': 'Print Customer Name',
    'ar': 'طباعة اسم العميل',
    'ru': 'Печать имени клиента',
    'ka': 'მომხმარებლის სახელის ბეჭდვა',
  });
  String get customerNameReport => _t({
    'en': 'Customer Name Report',
    'ar': 'تقرير اسم العميل',
    'ru': 'Отчёт с именем клиента',
    'ka': 'მომხმარებლის სახელის ანგარიში',
  });
  String get shareViaWhatsapp => _t({
    'en': 'Share via WhatsApp',
    'ar': 'مشاركة عبر واتساب',
    'ru': 'Поделиться в WhatsApp',
    'ka': 'გაზიარება WhatsApp-ით',
  });
  String get downloadPdf => _t({
    'en': 'Download',
    'ar': 'تنزيل',
    'ru': 'Скачать',
    'ka': 'ჩამოტვირთვა',
  });
  String get printPdf =>
      _t({'en': 'Print', 'ar': 'طباعة', 'ru': 'Печать', 'ka': 'ბეჭდვა'});
  String get openPdf => _t({
    'en': 'Open PDF',
    'ar': 'فتح PDF',
    'ru': 'Открыть PDF',
    'ka': 'PDF-ის გახსნა',
  });
  String get reportNotAvailable => _t({
    'en': 'The report is not available yet. Please try again later.',
    'ar': 'التقرير غير متاح حاليًا. يرجى المحاولة لاحقًا.',
    'ru': 'Отчёт пока недоступен. Попробуйте позже.',
    'ka': 'ანგარიში ჯერ მიუწვდომელია. სცადეთ მოგვიანებით.',
  });
  String get reportAccessDenied => _t({
    'en': 'Only the assigned driver can access this report.',
    'ar': 'يمكن للسائق المعيّن فقط الوصول إلى هذا التقرير.',
    'ru': 'Доступ к отчёту есть только у назначенного водителя.',
    'ka': 'ანგარიშზე წვდომა მხოლოდ დანიშნულ მძღოლს აქვს.',
  });
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
  String get planViewMore => _t({
    'en': 'View More',
    'ar': 'عرض المزيد',
    'ru': 'Показать больше',
    'ka': 'მეტის ნახვა',
  });
  String get planViewLess => _t({
    'en': 'View Less',
    'ar': 'عرض أقل',
    'ru': 'Показать меньше',
    'ka': 'ნაკლების ნახვა',
  });
  String get planNoActivities => _t({
    'en': 'No activities scheduled for today',
    'ar': 'لا توجد أنشطة مجدولة لهذا اليوم',
    'ru': 'На сегодня нет запланированных мероприятий',
    'ka': 'დღეისთვის აქტივობები დაგეგმილი არ არის',
  });
  String get planStayingTonight => _t({
    'en': 'Staying tonight',
    'ar': 'إقامتك الليلة',
    'ru': 'Проживание сегодня',
    'ka': 'დღეს ღამით',
  });
  String get planMoreActivities => _t({
    'en': 'more activities',
    'ar': 'أنشطة أخرى',
    'ru': 'ещё мероприятий',
    'ka': 'კიდევ აქტივობა',
  });
  String get simCardTitle => _t({
    'en': 'SIM Card',
    'ar': 'شريحة SIM',
    'ru': 'SIM-карта',
    'ka': 'SIM ბარათი',
  });
  String get eSimCardTitle => _t({
    'en': 'eSIM Card',
    'ar': 'شريحة eSIM',
    'ru': 'eSIM-карта',
    'ka': 'eSIM ბარათი',
  });
  String get simCardsCount => _t({
    'en': 'SIM cards',
    'ar': 'شرائح',
    'ru': 'SIM-карт',
    'ka': 'SIM ბარათი',
  });
  String get simStatusPending => _t({
    'en': 'Awaiting delivery',
    'ar': 'بانتظار التسليم',
    'ru': 'Ожидает доставки',
    'ka': 'მიწოდების მოლოდინში',
  });
  String get simStatusDelivered => _t({
    'en': 'Delivered by driver',
    'ar': 'تم التسليم من السائق',
    'ru': 'Доставлено водителем',
    'ka': 'მძღოლმა მიაწოდა',
  });
  String get simAwaitingDeliveryStatus => _t({
    'en': 'Awaiting Delivery',
    'ar': 'بانتظار التسليم',
    'ru': 'Ожидает доставки',
    'ka': 'მიწოდების მოლოდინში',
  });
  String get simDeliveryConfirmedStatus => _t({
    'en': 'Delivery Confirmed',
    'ar': 'تم تأكيد التسليم',
    'ru': 'Доставка подтверждена',
    'ka': 'მიწოდება დადასტურებულია',
  });
  String get simConfirmedByLabel => _t({
    'en': 'Confirmed by',
    'ar': 'تم التأكيد بواسطة',
    'ru': 'Подтвердил',
    'ka': 'დაადასტურა',
  });
  String get simConfirmedByCustomer => _t({
    'en': 'Customer',
    'ar': 'العميل',
    'ru': 'Клиент',
    'ka': 'მომხმარებელი',
  });
  String get simConfirmedByDriver =>
      _t({'en': 'Driver', 'ar': 'السائق', 'ru': 'Водитель', 'ka': 'მძღოლი'});
  String get simConfirmedAtLabel => _t({
    'en': 'Confirmed on',
    'ar': 'تاريخ التأكيد',
    'ru': 'Дата подтверждения',
    'ka': 'დადასტურების დრო',
  });
  String get simQuantityLabel => _t({
    'en': 'SIM quantity',
    'ar': 'عدد الشرائح',
    'ru': 'Количество SIM',
    'ka': 'SIM-ების რაოდენობა',
  });
  String get simReceivedLabel => _t({
    'en': 'SIM Received',
    'ar': 'تم استلام الشريحة',
    'ru': 'SIM получена',
    'ka': 'SIM მიღებულია',
  });
  String get simNotReceivedReported => _t({
    'en': 'Not Received — Reported',
    'ar': 'لم تُستلم — تم الإبلاغ',
    'ru': 'Не получена — сообщено',
    'ka': 'არ მიღებულა — გაგზავნილია',
  });
  String get confirmSimReceived => _t({
    'en': 'Confirm SIM Received',
    'ar': 'تأكيد استلام الشريحة',
    'ru': 'Подтвердить получение SIM',
    'ka': 'SIM-ის მიღების დადასტურება',
  });
  String get simNotReceivedYet => _t({
    'en': 'SIM Not Received Yet',
    'ar': 'لم أستلم الشريحة بعد',
    'ru': 'SIM ещё не получена',
    'ka': 'SIM ჯერ არ მიმიღია',
  });
  String get simReceivedQuestion => _t({
    'en': 'Have you received your SIM cards?',
    'ar': 'هل استلمت شرائح SIM الخاصة بك؟',
    'ru': 'Вы получили свои SIM-карты?',
    'ka': 'მიიღეთ თქვენი SIM ბარათები?',
  });
  String get simNotReceivedQuestion => _t({
    'en': 'Have you not received your SIM cards yet?',
    'ar': 'هل لم تستلم شرائح SIM الخاصة بك بعد؟',
    'ru': 'Вы ещё не получили свои SIM-карты?',
    'ka': 'ჯერ არ მიგიღიათ თქვენი SIM ბარათები?',
  });
  String get confirmReceipt => _t({
    'en': 'Confirm Receipt',
    'ar': 'تأكيد الاستلام',
    'ru': 'Подтвердить получение',
    'ka': 'მიღების დადასტურება',
  });
  String get reportNotReceived => _t({
    'en': 'Report Not Received',
    'ar': 'الإبلاغ عن عدم الاستلام',
    'ru': 'Сообщить о неполучении',
    'ka': 'არმიღების შეტყობინება',
  });
  String get simReceiptSaved => _t({
    'en': 'SIM receipt confirmed',
    'ar': 'تم تأكيد استلام الشريحة',
    'ru': 'Получение SIM подтверждено',
    'ka': 'SIM-ის მიღება დადასტურებულია',
  });
  String get simReportSaved => _t({
    'en': 'Your report was sent. We will follow up shortly.',
    'ar': 'تم إرسال بلاغك. سنتابع الأمر قريباً.',
    'ru': 'Ваше сообщение отправлено. Мы скоро свяжемся с вами.',
    'ka': 'თქვენი შეტყობინება გაიგზავნა. მალე დაგიკავშირდებით.',
  });
  String get simActionFailed => _t({
    'en': 'Could not update SIM status. Please try again.',
    'ar': 'تعذر تحديث حالة الشريحة. يرجى المحاولة مرة أخرى.',
    'ru': 'Не удалось обновить статус SIM. Попробуйте снова.',
    'ka': 'SIM-ის სტატუსის განახლება ვერ მოხერხდა. სცადეთ ხელახლა.',
  });
  String get flowersTitle =>
      _t({'en': 'Flowers', 'ar': 'الزهور', 'ru': 'Цветы', 'ka': 'ყვავილები'});
  String get flowersCount => _t({
    'en': 'flowers',
    'ar': 'باقات زهور',
    'ru': 'цветов',
    'ka': 'ყვავილი',
  });
  String get flowersQuantityLabel => _t({
    'en': 'Flowers quantity',
    'ar': 'عدد الزهور',
    'ru': 'Количество цветов',
    'ka': 'ყვავილების რაოდენობა',
  });
  String get flowersReceivedLabel => _t({
    'en': 'Flowers Received',
    'ar': 'تم استلام الزهور',
    'ru': 'Цветы получены',
    'ka': 'ყვავილები მიღებულია',
  });
  String get confirmFlowersReceived => _t({
    'en': 'Confirm Flowers Received',
    'ar': 'تأكيد استلام الزهور',
    'ru': 'Подтвердить получение цветов',
    'ka': 'ყვავილების მიღების დადასტურება',
  });
  String get flowersNotReceivedYet => _t({
    'en': 'Flowers Not Received Yet',
    'ar': 'لم أستلم الزهور بعد',
    'ru': 'Цветы ещё не получены',
    'ka': 'ყვავილები ჯერ არ მიმიღია',
  });
  String get flowersReceivedQuestion => _t({
    'en': 'Have you received your flowers?',
    'ar': 'هل استلمت الزهور الخاصة بك؟',
    'ru': 'Вы получили свои цветы?',
    'ka': 'მიიღეთ თქვენი ყვავილები?',
  });
  String get flowersNotReceivedQuestion => _t({
    'en': 'Have you not received your flowers yet?',
    'ar': 'هل لم تستلم الزهور الخاصة بك بعد؟',
    'ru': 'Вы ещё не получили свои цветы?',
    'ka': 'ჯერ არ მიგიღიათ თქვენი ყვავილები?',
  });
  String get flowersReceiptSaved => _t({
    'en': 'Flowers receipt confirmed',
    'ar': 'تم تأكيد استلام الزهور',
    'ru': 'Получение цветов подтверждено',
    'ka': 'ყვავილების მიღება დადასტურებულია',
  });
  String get flowersActionFailed => _t({
    'en': 'Could not update flowers status. Please try again.',
    'ar': 'تعذر تحديث حالة الزهور. يرجى المحاولة مرة أخرى.',
    'ru': 'Не удалось обновить статус цветов. Попробуйте снова.',
    'ka': 'ყვავილების სტატუსის განახლება ვერ მოხერხდა. სცადეთ ხელახლა.',
  });
  String get flowersDeliveryQuestion => _t({
    'en': 'Have you delivered the flowers to the customer?',
    'ar': 'هل قمت بتسليم الزهور إلى العميل؟',
    'ru': 'Вы передали цветы клиенту?',
    'ka': 'მიაწოდეთ თუ არა ყვავილები მომხმარებელს?',
  });
  String get flowersDeliveredSuccess => _t({
    'en': 'Flowers delivery confirmed',
    'ar': 'تم تأكيد تسليم الزهور',
    'ru': 'Доставка цветов подтверждена',
    'ka': 'ყვავილების მიწოდება დადასტურდა',
  });
  String get confirmFlowersDeliveredTitle => _t({
    'en': 'Confirm Flowers Delivered?',
    'ar': 'تأكيد تسليم الزهور؟',
    'ru': 'Подтвердить доставку цветов?',
    'ka': 'დაადასტურეთ ყვავილების მიწოდება?',
  });
  String get flowersMarkedDelivered => _t({
    'en': 'Flowers marked as Delivered',
    'ar': 'تم تحديد الزهور كمُسلَّمة',
    'ru': 'Цветы отмечены как доставленные',
    'ka': 'ყვავილები მონიშნულია როგორც მიწოდებული',
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
  String get hotelDetailsTitle => _t({
    'en': 'Hotel Details',
    'ar': 'تفاصيل الفندق',
    'ru': 'Информация об отеле',
    'ka': 'სასტუმროს დეტალები',
  });
  String get hotelPhoneLabel => _t({
    'en': 'Hotel Phone',
    'ar': 'هاتف الفندق',
    'ru': 'Телефон отеля',
    'ka': 'სასტუმროს ტელეფონი',
  });
  String get closeAction =>
      _t({'en': 'Close', 'ar': 'إغلاق', 'ru': 'Закрыть', 'ka': 'დახურვა'});
  String get getDirections => _t({
    'en': 'Get Directions',
    'ar': 'احصل على الاتجاهات',
    'ru': 'Проложить маршрут',
    'ka': 'მარშრუტის მიღება',
  });
  String get callHotel => _t({
    'en': 'Call Hotel',
    'ar': 'اتصل بالفندق',
    'ru': 'Позвонить в отель',
    'ka': 'სასტუმროში დარეკვა',
  });
  String get hotelMapsShort =>
      _t({'en': 'Maps', 'ar': 'الخرائط', 'ru': 'Карты', 'ka': 'რუკა'});
  String get hotelPhoneUnavailable => _t({
    'en': 'Phone number not available',
    'ar': 'رقم الهاتف غير متوفر',
    'ru': 'Номер телефона недоступен',
    'ka': 'ტელეფონის ნომერი მიუწვდომელია',
  });
  String get hotelMapUnavailable => _t({
    'en': 'Map location not available',
    'ar': 'موقع الخريطة غير متوفر',
    'ru': 'Местоположение на карте недоступно',
    'ka': 'რუკის მდებარეობა მიუწვდომელია',
  });
  String get hotelActionFailed => _t({
    'en': 'Unable to open. Please try again.',
    'ar': 'تعذر الفتح. حاول مرة أخرى.',
    'ru': 'Не удалось открыть. Повторите попытку.',
    'ka': 'გახსნა ვერ მოხერხდა. სცადეთ ხელახლა.',
  });
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
  String get arrivedAction =>
      _t({'en': 'Arrived', 'ar': 'وصلت', 'ru': 'Прибыл', 'ka': 'მოვედი'});
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
  String get ratings => _t({
    'en': 'Ratings',
    'ar': 'التقييمات',
    'ru': 'Оценки',
    'ka': 'შეფასებები',
  });
  String get noRatingsYet => _t({
    'en': 'No ratings yet',
    'ar': 'لا توجد تقييمات بعد',
    'ru': 'Оценок пока нет',
    'ka': 'შეფასებები ჯერ არ არის',
  });
  String get modelYear => _t({
    'en': 'Model Year',
    'ar': 'سنة الصنع',
    'ru': 'Год выпуска',
    'ka': 'გამოშვების წელი',
  });
  String get personalPhotosLabel => _t({
    'en': 'Personal photos',
    'ar': 'الصور الشخصية',
    'ru': 'Личные фото',
    'ka': 'პირადი ფოტოები',
  });
  String get vehiclePhotosLabel => _t({
    'en': 'Vehicle photos',
    'ar': 'صور المركبة',
    'ru': 'Фото автомобиля',
    'ka': 'მანქანის ფოტოები',
  });
  String ratingsCountLabel(int n) => _t({
    'en': '$n ${n == 1 ? 'rating' : 'ratings'}',
    'ar': '$n تقييم',
    'ru': '$n оценок',
    'ka': '$n შეფასება',
    'az': '$n qiymət',
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

  // ─── Greeting header (localized) ───────────────────────────────────────────

  /// Right-to-left only for Arabic. English, Russian and Georgian are LTR.
  bool get isRtlLocale => locale == 'ar';

  String get helloLabel => _t({
    'en': 'Hello',
    'ar': 'مرحباً',
    'ru': 'Здравствуйте',
    'ka': 'გამარჯობა',
  });

  String helloWithName(String name) {
    final sep = locale == 'ar' ? '،' : ',';
    return '$helloLabel$sep $name';
  }

  String headerSubtitle({required bool isDriver}) {
    if (isDriver) {
      return _t({
        'en': 'Every Trip Your Excellence.',
        'ru': 'Каждая поездка Ваше мастерство.',
        'ka': 'ყოველი მგზავრობა თქვენი პროფესიონალიზმი.',
        'az': 'Hər səfər sizin peşəkarlığınızdır.',
      });
    }
    return _t({'en': 'Your Journey Our Care.', 'ar': 'رحلتك تهمنا'});
  }

  String formattedHeaderDate(DateTime now) {
    const weekdays = {
      'en': [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ],
      'ar': [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ],
      'ru': [
        'Понедельник',
        'Вторник',
        'Среда',
        'Четверг',
        'Пятница',
        'Суббота',
        'Воскресенье',
      ],
      'ka': [
        'ორშაბათი',
        'სამშაბათი',
        'ოთხშაბათი',
        'ხუთშაბათი',
        'პარასკევი',
        'შაბათი',
        'კვირა',
      ],
    };
    const months = {
      'en': [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ],
      'ar': [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ],
      // Genitive forms (used after the day number)
      'ru': [
        'января',
        'февраля',
        'марта',
        'апреля',
        'мая',
        'июня',
        'июля',
        'августа',
        'сентября',
        'октября',
        'ноября',
        'декабря',
      ],
      'ka': [
        'იანვარი',
        'თებერვალი',
        'მარტი',
        'აპრილი',
        'მაისი',
        'ივნისი',
        'ივლისი',
        'აგვისტო',
        'სექტემბერი',
        'ოქტომბერი',
        'ნოემბერი',
        'დეკემბერი',
      ],
    };
    final lang = weekdays.containsKey(locale) ? locale : 'en';
    if (locale == 'az') {
      return '${weekdayName(now.weekday)}, ${now.day} ${monthName(now.month)}';
    }
    final day = weekdays[lang]![now.weekday - 1];
    final month = months[lang]![now.month - 1];
    final sep = lang == 'ar' ? '،' : ',';
    return '$day$sep ${now.day} $month';
  }

  // ─── Customer Home (new design) ────────────────────────────────────────────

  String get guestsLabel =>
      _t({'en': 'guests', 'ar': 'ضيوف', 'ru': 'гостей', 'ka': 'სტუმარი'});

  String get departureFlightTitle => _t({
    'en': 'DEPARTURE FLIGHT',
    'ar': 'رحلة المغادرة',
    'ru': 'РЕЙС ВЫЛЕТА',
    'ka': 'გამგზავრების ფრენა',
  });

  String get arrivalLabel =>
      _t({'en': 'Arrival', 'ar': 'الوصول', 'ru': 'Прибытие', 'ka': 'ჩამოსვლა'});

  String get departureLabel => _t({
    'en': 'Departure',
    'ar': 'المغادرة',
    'ru': 'Отправление',
    'ka': 'გამგზავრება',
  });

  // ─── Driver Tomorrow card ──────────────────────────────────────────────────

  String get newTripLabel => _t({
    'en': 'NEW TRIP',
    'ar': 'رحلة جديدة',
    'ru': 'НОВАЯ ПОЕЗДКА',
    'ka': 'ახალი მოგზაურობა',
  });

  String get airportPickupLabel => _t({
    'en': 'AIRPORT PICKUP',
    'ar': 'الاستقبال من المطار',
    'ru': 'ВСТРЕЧА В АЭРОПОРТУ',
    'ka': 'აეროპორტიდან მიყვანა',
  });

  String get tomorrowAirportPickupMessage => _t({
    'en': 'You have an airport pickup scheduled tomorrow for a new trip.',
    'ar': 'لديك استقبال من المطار غداً لرحلة جديدة.',
    'ru': 'У вас завтра запланирована встреча в аэропорту для новой поездки.',
    'ka': 'ხვალ დაგეგმილი გაქვთ აეროპორტიდან მიყვანა ახალი მოგზაურობისთვის.',
  });

  String get tomorrowNewTripMessage => _t({
    'en': 'You have an assignment tomorrow for a new trip.',
    'ar': 'لديك مهمة غداً لرحلة جديدة.',
    'ru': 'У вас завтра задание для новой поездки.',
    'ka': 'ხვალ გაქვთ დავალება ახალი მოგზაურობისთვის.',
  });

  String get bookingLabel => _t({
    'en': 'Booking',
    'ar': 'الحجز',
    'ru': 'Бронирование',
    'ka': 'დაჯავშნა',
  });

  String get arrivalTimeLabel => _t({
    'en': 'Arrival Time',
    'ar': 'وقت الوصول',
    'ru': 'Время прибытия',
    'ka': 'ჩამოსვლის დრო',
  });

  // ─── Localized date helpers ────────────────────────────────────────────────

  static const Map<String, List<String>> _weekdayNames = {
    'en': [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ],
    'ar': [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ],
    'ru': [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье',
    ],
    'ka': [
      'ორშაბათი',
      'სამშაბათი',
      'ოთხშაბათი',
      'ხუთშაბათი',
      'პარასკევი',
      'შაბათი',
      'კვირა',
    ],
    'az': [
      'Bazar ertəsi',
      'Çərşənbə axşamı',
      'Çərşənbə',
      'Cümə axşamı',
      'Cümə',
      'Şənbə',
      'Bazar',
    ],
  };

  static const Map<String, List<String>> _monthNames = {
    'en': [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ],
    'ar': [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ],
    // Genitive forms (used after the day number)
    'ru': [
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ],
    'ka': [
      'იანვარი',
      'თებერვალი',
      'მარტი',
      'აპრილი',
      'მაისი',
      'ივნისი',
      'ივლისი',
      'აგვისტო',
      'სექტემბერი',
      'ოქტომბერი',
      'ნოემბერი',
      'დეკემბერი',
    ],
    'az': [
      'Yanvar',
      'Fevral',
      'Mart',
      'Aprel',
      'May',
      'İyun',
      'İyul',
      'Avqust',
      'Sentyabr',
      'Oktyabr',
      'Noyabr',
      'Dekabr',
    ],
  };

  static const Map<String, List<String>> _shortMonthNames = {
    'en': [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    'ar': [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ],
    'ru': [
      'янв.',
      'февр.',
      'мар.',
      'апр.',
      'мая',
      'июн.',
      'июл.',
      'авг.',
      'сент.',
      'окт.',
      'нояб.',
      'дек.',
    ],
    'ka': [
      'იან',
      'თებ',
      'მარ',
      'აპრ',
      'მაი',
      'ივნ',
      'ივლ',
      'აგვ',
      'სექ',
      'ოქტ',
      'ნოე',
      'დეკ',
    ],
    'az': [
      'Yan',
      'Fev',
      'Mar',
      'Apr',
      'May',
      'İyn',
      'İyl',
      'Avq',
      'Sen',
      'Okt',
      'Noy',
      'Dek',
    ],
  };

  String get _dateLang => _monthNames.containsKey(locale) ? locale : 'en';

  /// Localized weekday name (1 = Monday ... 7 = Sunday).
  String weekdayName(int weekday) => _weekdayNames[_dateLang]![weekday - 1];

  /// Localized month name (1..12). Russian uses the genitive form.
  String monthName(int month) => _monthNames[_dateLang]![month - 1];

  /// Localized abbreviated month name (1..12).
  String shortMonthName(int month) => _shortMonthNames[_dateLang]![month - 1];

  /// e.g. "Monday, 5 June" in the selected language.
  String weekdayDayMonth(DateTime d) {
    final sep = _dateLang == 'ar' ? '،' : ',';
    return '${weekdayName(d.weekday)}$sep ${d.day} ${monthName(d.month)}';
  }

  /// e.g. "5 June" in the selected language.
  String dayMonth(DateTime d) => '${d.day} ${monthName(d.month)}';

  /// e.g. "5 June 2026" in the selected language.
  String dayMonthYear(DateTime d) => '${d.day} ${monthName(d.month)} ${d.year}';

  /// e.g. "Jun 5" in the selected language.
  String shortMonthDay(DateTime d) => '${shortMonthName(d.month)} ${d.day}';

  // ─── Driver bottom navigation & tabs ───────────────────────────────────────

  String get navToday =>
      _t({'en': 'Today', 'ar': 'اليوم', 'ru': 'Сегодня', 'ka': 'დღეს'});
  String get navMyTrips => _t({
    'en': 'My Trips',
    'ar': 'رحلاتي',
    'ru': 'Мои поездки',
    'ka': 'ჩემი მოგზაურობები',
  });
  String get supportComingSoon => _t({
    'en': 'Support coming soon',
    'ar': 'الدعم قريباً',
    'ru': 'Поддержка скоро появится',
    'ka': 'მხარდაჭერა მალე იქნება ხელმისაწვდომი',
  });
  String get appearance => _t({
    'en': 'Appearance',
    'ar': 'المظهر',
    'ru': 'Оформление',
    'ka': 'გარეგნობა',
  });
  String get themeSystem => _t({
    'en': 'System',
    'ar': 'النظام',
    'ru': 'Системная',
    'ka': 'სისტემური',
  });
  String get themeLight =>
      _t({'en': 'Light', 'ar': 'فاتح', 'ru': 'Светлая', 'ka': 'ნათელი'});
  String get themeDark =>
      _t({'en': 'Dark', 'ar': 'داكن', 'ru': 'Тёмная', 'ka': 'მუქი'});

  // ─── Driver trip / hotel details ───────────────────────────────────────────

  String get hotelName => _t({
    'en': 'Hotel Name',
    'ar': 'اسم الفندق',
    'ru': 'Название отеля',
    'ka': 'სასტუმროს სახელი',
  });
  String get fullAddress => _t({
    'en': 'Full Address',
    'ar': 'العنوان الكامل',
    'ru': 'Полный адрес',
    'ka': 'სრული მისამართი',
  });
  String get addressNotAvailable => _t({
    'en': 'Address not available',
    'ar': 'العنوان غير متوفر',
    'ru': 'Адрес недоступен',
    'ka': 'მისამართი მიუწვდომელია',
  });
  String get phoneNumber => _t({
    'en': 'Phone Number',
    'ar': 'رقم الهاتف',
    'ru': 'Номер телефона',
    'ka': 'ტელეფონის ნომერი',
  });
  String get phoneLabel =>
      _t({'en': 'Phone', 'ar': 'الهاتف', 'ru': 'Телефон', 'ka': 'ტელეფონი'});
  String get notAvailable => _t({
    'en': 'Not available',
    'ar': 'غير متوفر',
    'ru': 'Недоступно',
    'ka': 'მიუწვდომელია',
  });
  String get openInGoogleMaps => _t({
    'en': 'Open in Google Maps',
    'ar': 'فتح في خرائط جوجل',
    'ru': 'Открыть в Google Картах',
    'ka': 'Google Maps-ში გახსნა',
  });
  String get tripDuration => _t({
    'en': 'Trip Duration',
    'ar': 'مدة الرحلة',
    'ru': 'Длительность поездки',
    'ka': 'მოგზაურობის ხანგრძლივობა',
  });
  String get passengersLabel => _t({
    'en': 'Passengers',
    'ar': 'الركاب',
    'ru': 'Пассажиры',
    'ka': 'მგზავრები',
  });
  String guestCount(int n) => _t({
    'en': '$n ${n == 1 ? 'Guest' : 'Guests'}',
    'ar': '$n ${n == 1 ? 'ضيف' : 'ضيوف'}',
    'ru': '$n ${n == 1 ? 'гость' : (n >= 2 && n <= 4 ? 'гостя' : 'гостей')}',
    'ka': '$n ${n == 1 ? 'სტუმარი' : 'სტუმარი'}',
    'az': '$n qonaq',
  });
  String get arrivalFlightUnavailable => _t({
    'en': 'Arrival flight details not available',
    'ar': 'تفاصيل رحلة الوصول غير متوفرة',
    'ru': 'Данные рейса прибытия недоступны',
    'ka': 'ჩამოსვლის ფრენის დეტალები მიუწვდომელია',
  });
  String get checkInLabel => _t({
    'en': 'Check-in',
    'ar': 'تسجيل الوصول',
    'ru': 'Заезд',
    'ka': 'ჩასვლა',
  });
  String get checkOutLabel => _t({
    'en': 'Check-out',
    'ar': 'تسجيل المغادرة',
    'ru': 'Выезд',
    'ka': 'გასვლა',
  });
  String checkInWithName(String name) => '$checkInLabel: $name';
  String get viewDetailsAction => viewDetails;
  String get tripInformation => _t({
    'en': 'Trip Information',
    'ar': 'معلومات الرحلة',
    'ru': 'Информация о поездке',
    'ka': 'მოგზაურობის ინფორმაცია',
  });
  String get flightInfo => _t({
    'en': 'Flight Info',
    'ar': 'معلومات الرحلة الجوية',
    'ru': 'Информация о рейсе',
    'ka': 'ფრენის ინფორმაცია',
  });
  String get flightNumber => _t({
    'en': 'Flight Number',
    'ar': 'رقم الرحلة الجوية',
    'ru': 'Номер рейса',
    'ka': 'ფრენის ნომერი',
  });
  String get notes => _t({
    'en': 'Notes',
    'ar': 'ملاحظات',
    'ru': 'Примечания',
    'ka': 'შენიშვნები',
  });
  String get dateLabel =>
      _t({'en': 'Date', 'ar': 'التاريخ', 'ru': 'Дата', 'ka': 'თარიღი'});
  String get tripProgress => _t({
    'en': 'Trip Progress',
    'ar': 'تقدم الرحلة',
    'ru': 'Ход поездки',
    'ka': 'მოგზაურობის პროგრესი',
  });
  String get tripCompleted => _t({
    'en': 'Trip Completed!',
    'ar': 'اكتملت الرحلة!',
    'ru': 'Поездка завершена!',
    'ka': 'მოგზაურობა დასრულდა!',
  });
  String get tripReference => _t({
    'en': 'Trip Reference',
    'ar': 'مرجع الرحلة',
    'ru': 'Номер поездки',
    'ka': 'მოგზაურობის ნომერი',
  });
  String get customerName => _t({
    'en': 'Customer Name',
    'ar': 'اسم العميل',
    'ru': 'Имя клиента',
    'ka': 'კლიენტის სახელი',
  });
  String get simQuantity => _t({
    'en': 'SIM Quantity',
    'ar': 'عدد شرائح SIM',
    'ru': 'Количество SIM-карт',
    'ka': 'SIM ბარათების რაოდენობა',
  });
  String get currentStatus => _t({
    'en': 'Current Status',
    'ar': 'الحالة الحالية',
    'ru': 'Текущий статус',
    'ka': 'მიმდინარე სტატუსი',
  });
  String get confirmSimDeliveredTitle => _t({
    'en': 'Confirm SIM Cards Delivered?',
    'ar': 'تأكيد تسليم شرائح SIM؟',
    'ru': 'Подтвердить доставку SIM-карт?',
    'ka': 'დაადასტურეთ SIM ბარათების მიწოდება?',
  });
  String get simMarkedDelivered => _t({
    'en': 'SIM cards marked as Delivered',
    'ar': 'تم تحديد شرائح SIM كمُسلَّمة',
    'ru': 'SIM-карты отмечены как доставленные',
    'ka': 'SIM ბარათები მონიშნულია როგორც მიწოდებული',
  });
  String get confirmDeliveryFailed => _t({
    'en': 'Failed to confirm delivery. Please try again.',
    'ar': 'فشل تأكيد التسليم. يرجى المحاولة مرة أخرى.',
    'ru': 'Не удалось подтвердить доставку. Попробуйте ещё раз.',
    'ka': 'მიწოდების დადასტურება ვერ მოხერხდა. სცადეთ ხელახლა.',
  });
  String get tripDetailsTitle => tripDetails;

  // ─── Driver profile completion extras ──────────────────────────────────────

  String get usernameLabel => username;
  String get driverNameLabel => _t({
    'en': 'Driver Name',
    'ar': 'اسم السائق',
    'ru': 'Имя водителя',
    'ka': 'მძღოლის სახელი',
  });
  String get driverNameHint => _t({
    'en': 'e.g. John Smith',
    'ar': 'مثال: أحمد محمد',
    'ru': 'напр. Иван Иванов',
    'ka': 'მაგ. გიორგი გიორგაძე',
  });
  String get vehicleModelHintLong => _t({
    'en': 'e.g. Toyota Camry 2020',
    'ar': 'مثال: تويوتا كامري 2020',
    'ru': 'напр. Toyota Camry 2020',
    'ka': 'მაგ. Toyota Camry 2020',
  });
  String get vehicleColorLabel => _t({
    'en': 'Vehicle Color',
    'ar': 'لون المركبة',
    'ru': 'Цвет автомобиля',
    'ka': 'მანქანის ფერი',
  });
  String get vehicleColorHint => _t({
    'en': 'e.g. Black',
    'ar': 'مثال: أسود',
    'ru': 'напр. Чёрный',
    'ka': 'მაგ. შავი',
  });
  String get driverNameFromOdoo => _t({
    'en': 'From Odoo',
    'ar': 'من أودو',
    'ru': 'Из Odoo',
    'ka': 'Odoo-დან',
  });
  String get vehicleType => _t({
    'en': 'Vehicle Type',
    'ar': 'نوع المركبة',
    'ru': 'Тип автомобиля',
    'ka': 'მანქანის ტიპი',
  });
  String get selectVehicleType => _t({
    'en': 'Select vehicle type',
    'ar': 'اختر نوع المركبة',
    'ru': 'Выберите тип автомобиля',
    'ka': 'აირჩიეთ მანქანის ტიპი',
  });
  String vehicleTypeName(String type) {
    switch (type) {
      case 'Sedan':
        return _t({
          'en': 'Sedan',
          'ar': 'سيدان',
          'ru': 'Седан',
          'ka': 'სედანი',
        });
      case 'Minivan':
        return _t({
          'en': 'Minivan',
          'ar': 'ميني فان',
          'ru': 'Минивэн',
          'ka': 'მინივენი',
        });
      case 'Sprinter':
        return _t({
          'en': 'Sprinter',
          'ar': 'سبرينتر',
          'ru': 'Спринтер',
          'ka': 'სპრინტერი',
        });
      case 'Minibus':
        return _t({
          'en': 'Minibus',
          'ar': 'ميني باص',
          'ru': 'Микроавтобус',
          'ka': 'მიკროავტობუსი',
        });
      default:
        return type;
    }
  }

  // ─── Generic UI ────────────────────────────────────────────────────────────

  String get errorOccurredTitle => _t({
    'en': 'Something went wrong',
    'ar': 'حدث خطأ ما',
    'ru': 'Что-то пошло не так',
    'ka': 'რაღაც შეცდომა მოხდა',
  });
  String get errorOccurredBody => _t({
    'en': 'We encountered an unexpected error while processing your request.',
    'ar': 'واجهنا خطأ غير متوقع أثناء معالجة طلبك.',
    'ru': 'При обработке запроса произошла непредвиденная ошибка.',
    'ka': 'თქვენი მოთხოვნის დამუშავებისას მოხდა გაუთვალისწინებელი შეცდომა.',
  });
  String get travelOperations => _t({
    'en': 'Travel Operations',
    'ar': 'عمليات السفر',
    'ru': 'Туристические операции',
    'ka': 'ტურისტული ოპერაციები',
  });
  String get testMode => _t({
    'en': 'TEST MODE',
    'ar': 'وضع الاختبار',
    'ru': 'ТЕСТОВЫЙ РЕЖИМ',
    'ka': 'სატესტო რეჟიმი',
  });
  String get accountLinkedToBooking => _t({
    'en':
        'Your account is linked to your booking. Use the phone number provided during booking.',
    'ar': 'حسابك مرتبط بحجزك. استخدم رقم الهاتف المقدم أثناء الحجز.',
    'ru':
        'Ваш аккаунт связан с бронированием. Используйте номер телефона, указанный при бронировании.',
    'ka':
        'თქვენი ანგარიში დაკავშირებულია დაჯავშნასთან. გამოიყენეთ დაჯავშნისას მითითებული ტელეფონის ნომერი.',
  });
  String get splashButton1 => _t({
    'en': 'Explore Your Journey',
    'ar': 'استكشف رحلتك',
    'ru': 'Исследуйте путешествие',
    'ka': 'აღმოაჩინეთ თქვენი მოგზაურობა',
  });
  String get splashButton2 => _t({
    'en': 'Start Driving',
    'ar': 'ابدأ القيادة',
    'ru': 'Начать работу',
    'ka': 'მართვის დაწყება',
  });
  String get splashButton3 => _t({
    'en': 'Get Started',
    'ar': 'ابدأ الآن',
    'ru': 'Начать',
    'ka': 'დაწყება',
  });
  String get splashHeadline1 => _t({
    'en': 'Your Journey\nStarts Here',
    'ar': 'رحلتك\nتبدأ هنا',
    'ru': 'Ваше путешествие\nначинается здесь',
    'ka': 'თქვენი მოგზაურობა\nიწყება აქ',
  });
  String get splashHeadline2 => _t({
    'en': 'Every Trip.\nPerfectly Managed.',
    'ar': 'كل رحلة.\nبإدارة مثالية.',
    'ru': 'Каждая поездка.\nИдеально организована.',
    'ka': 'ყოველი მგზავრობა.\nიდეალურად მართული.',
  });
  String get splashHeadline3 => _t({
    'en': 'Run Travel\nSmarter',
    'ar': 'أدر السفر\nبذكاء أكبر',
    'ru': 'Управляйте\nпутешествиями умнее',
    'ka': 'მართეთ მოგზაურობა\nუფრო ჭკვიანურად',
  });
  String get splashBody1 => _t({
    'en':
        'Everything you need for a seamless travel experience, all in one place.',
    'ar': 'كل ما تحتاجه لتجربة سفر سلسة، في مكان واحد.',
    'ru': 'Всё необходимое для комфортного путешествия в одном месте.',
    'ka': 'ყველაფერი, რაც გჭირდებათ შეუფერხებელი მოგზაურობისთვის, ერთ ადგილას.',
  });
  String get splashBody2 => _t({
    'en':
        'Stay connected, follow your schedule, and deliver every journey with confidence.',
    'ar': 'ابقَ على اتصال، وتابع جدولك، وأنجز كل رحلة بثقة.',
    'ru':
        'Оставайтесь на связи, следуйте расписанию и выполняйте каждую поездку уверенно.',
    'ka':
        'დარჩით კავშირზე, მიჰყევით გრაფიკს და შეასრულეთ ყოველი მგზაურობა თავდაჯერებით.',
  });
  String get splashBody3 => _t({
    'en':
        'Customers, drivers, trips and operations — connected in one powerful platform.',
    'ar': 'العملاء والسائقون والرحلات والعمليات — متصلة في منصة واحدة قوية.',
    'ru': 'Клиенты, водители, поездки и операции — в одной мощной платформе.',
    'ka':
        'კლიენტები, მძღოლები, მოგზაურობები და ოპერაციები — ერთ მძლავრ პლატფორმაში.',
  });

  // ─── Driver trip status labels ─────────────────────────────────────────────

  String get statusAssigned => _t({
    'en': 'Ready',
    'ar': 'مُعيَّنة',
    'ru': 'Назначена',
    'ka': 'მინიჭებულია',
  });
  String get statusOnTheWay => _t({
    'en': 'On The Way',
    'ar': 'في الطريق',
    'ru': 'В пути',
    'ka': 'გზაში',
  });
  String get statusArrived =>
      _t({'en': 'Arrived', 'ar': 'وصل', 'ru': 'Прибыл', 'ka': 'მივიდა'});
  String get statusPassengerPickedUp => _t({
    'en': 'Passenger Picked Up',
    'ar': 'تم استقبال الراكب',
    'ru': 'Пассажир забран',
    'ka': 'მგზავრი აყვანილია',
  });
  String get statusPickedUpShort => _t({
    'en': 'Picked Up',
    'ar': 'تم الاستقبال',
    'ru': 'Забран',
    'ka': 'აყვანილია',
  });
  String get statusInTour =>
      _t({'en': 'In Tour', 'ar': 'في الجولة', 'ru': 'В туре', 'ka': 'ტურზე'});
  String get statusCompleted => _t({
    'en': 'Completed',
    'ar': 'مكتملة',
    'ru': 'Завершена',
    'ka': 'დასრულებულია',
  });
  String get startDriving => _t({
    'en': 'Start Driving',
    'ar': 'ابدأ القيادة',
    'ru': 'Начать движение',
    'ka': 'მართვის დაწყება',
  });
  String get completeTrip => _t({
    'en': 'Complete Trip',
    'ar': 'إنهاء الرحلة',
    'ru': 'Завершить поездку',
    'ka': 'მოგზაურობის დასრულება',
  });

  /// Localizes a raw backend status code (e.g. "in_progress", "delivered").
  /// Unknown values are returned as-is (backend data is never invented).
  String backendStatus(String raw) {
    final key = raw.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    switch (key) {
      case 'pending':
        return pending;
      case 'active':
        return active;
      case 'assigned':
        return statusAssigned;
      case 'on_the_way':
        return statusOnTheWay;
      case 'arrived':
        return statusArrived;
      case 'passenger_picked_up':
      case 'picked_up':
        return statusPassengerPickedUp;
      case 'in_progress':
      case 'in_tour':
        return statusInTour;
      case 'completed':
      case 'done':
        return statusCompleted;
      case 'delivered':
        return deliveredLabel;
      case 'scheduled':
        return _t({
          'en': 'Scheduled',
          'ar': 'مجدولة',
          'ru': 'Запланирована',
          'ka': 'დაგეგმილია',
        });
      case 'confirmed':
        return _t({
          'en': 'Confirmed',
          'ar': 'مؤكدة',
          'ru': 'Подтверждена',
          'ka': 'დადასტურებულია',
        });
      case 'cancelled':
      case 'canceled':
        return _t({
          'en': 'Cancelled',
          'ar': 'ملغاة',
          'ru': 'Отменена',
          'ka': 'გაუქმებულია',
        });
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  String get exampleAbbrev =>
      _t({'en': 'e.g.', 'ar': 'مثال:', 'ru': 'напр.', 'ka': 'მაგ.'});
  String get traveler => _t({
    'en': 'Traveler',
    'ar': 'مسافر',
    'ru': 'Путешественник',
    'ka': 'მოგზაური',
  });

  /// e.g. "Jun 5, 2026" in the selected language.
  String shortDateWithYear(DateTime d) =>
      '${shortMonthName(d.month)} ${d.day}, ${d.year}';

  // ─── Notifications ─────────────────────────────────────────────────────────

  String get notificationsTitle => _t({
    'en': 'Notifications',
    'ar': 'الإشعارات',
    'ru': 'Уведомления',
    'ka': 'შეტყობინებები',
  });
  String get notificationsEmptyTitle => _t({
    'en': 'No notifications yet',
    'ar': 'لا توجد إشعارات بعد',
    'ru': 'Уведомлений пока нет',
    'ka': 'შეტყობინებები ჯერ არ არის',
  });
  String get notificationsEmptyMessage => _t({
    'en': 'New updates about your trips will appear here.',
    'ar': 'ستظهر هنا التحديثات الجديدة حول رحلاتك.',
    'ru': 'Здесь появятся новые обновления по вашим поездкам.',
    'ka': 'აქ გამოჩნდება ახალი განახლებები თქვენი მოგზაურობების შესახებ.',
  });
  String get notificationsDemoLabel => _t({
    'en': 'Demo mode: notifications are not connected to the server yet.',
    'ar': 'وضع تجريبي: الإشعارات غير متصلة بالخادم بعد.',
    'ru': 'Демо-режим: уведомления ещё не подключены к серверу.',
    'ka': 'დემო რეჟიმი: შეტყობინებები სერვერთან ჯერ არ არის დაკავშირებული.',
  });
  String get notificationsLoadError => _t({
    'en': 'Could not load notifications.',
    'ar': 'تعذر تحميل الإشعارات.',
    'ru': 'Не удалось загрузить уведомления.',
    'ka': 'შეტყობინებების ჩატვირთვა ვერ მოხერხდა.',
  });
  String get markAllAsRead => _t({
    'en': 'Mark all as read',
    'ar': 'تحديد الكل كمقروء',
    'ru': 'Отметить все как прочитанные',
    'ka': 'ყველას წაკითხულად მონიშვნა',
  });
  String get markAsRead => _t({
    'en': 'Mark as read',
    'ar': 'تحديد كمقروء',
    'ru': 'Отметить как прочитанное',
    'ka': 'წაკითხულად მონიშვნა',
  });
  String get notificationBookingUpdatedTitle => _t({
    'en': 'Booking updated',
    'ar': 'تم تحديث الحجز',
    'ru': 'Бронирование обновлено',
    'ka': 'ჯავშანი განახლდა',
  });
  String notificationBookingUpdatedMessage(String? ref) {
    final hasRef = ref != null && ref.isNotEmpty;
    return _t({
      'en': hasRef
          ? 'There is an update to your booking $ref.'
          : 'There is an update to your booking.',
      'ar': hasRef ? 'يوجد تحديث على حجزك $ref.' : 'يوجد تحديث على حجزك.',
      'ru': hasRef
          ? 'Есть обновление по вашему бронированию $ref.'
          : 'Есть обновление по вашему бронированию.',
      'ka': hasRef
          ? 'თქვენს ჯავშანზე $ref არის განახლება.'
          : 'თქვენს ჯავშანზე არის განახლება.',
      'az': hasRef
          ? '$ref rezervasiyası üzrə yenilik var.'
          : 'Rezervasiyanız üzrə yenilik var.',
    });
  }

  String get notificationTripAssignedTitle => _t({
    'en': 'Trip assigned',
    'ar': 'تم تعيين رحلة',
    'ru': 'Поездка назначена',
    'ka': 'მგზავრობა მინიჭებულია',
  });
  String notificationTripAssignedMessage(String? ref) {
    final hasRef = ref != null && ref.isNotEmpty;
    return _t({
      'en': hasRef
          ? 'You have been assigned to trip $ref.'
          : 'You have been assigned to a trip.',
      'ar': hasRef ? 'تم تعيينك للرحلة $ref.' : 'تم تعيينك لرحلة.',
      'ru': hasRef ? 'Вам назначена поездка $ref.' : 'Вам назначена поездка.',
      'ka': hasRef
          ? 'თქვენ მოგენიშნათ მგზავრობა $ref.'
          : 'თქვენ მოგენიშნათ მგზავრობა.',
      'az': hasRef
          ? 'Sizə $ref səfəri təyin edildi.'
          : 'Sizə səfər təyin edildi.',
    });
  }

  String get notificationTripUnassignedTitle => _t({
    'en': 'Trip unassigned',
    'ar': 'تم إلغاء تعيين الرحلة',
    'ru': 'Назначение отменено',
    'ka': 'მგზავრობა მოგეხსნათ',
  });
  String notificationTripUnassignedMessage(String? ref) {
    final hasRef = ref != null && ref.isNotEmpty;
    return _t({
      'en': hasRef
          ? 'You are no longer assigned to trip $ref.'
          : 'You are no longer assigned to a trip.',
      'ar': hasRef ? 'لم تعد معينًا للرحلة $ref.' : 'لم تعد معينًا لرحلة.',
      'ru': hasRef
          ? 'Вы больше не назначены на поездку $ref.'
          : 'Вы больше не назначены на поездку.',
      'ka': hasRef
          ? 'თქვენ აღარ ხართ მინიჭებული მგზავრობაზე $ref.'
          : 'თქვენ აღარ ხართ მინიჭებული მგზავრობაზე.',
      'az': hasRef
          ? 'Siz artıq $ref səfərinə təyin edilməmisiniz.'
          : 'Siz artıq səfərə təyin edilməmisiniz.',
    });
  }

  String get notificationTripUnavailable => _t({
    'en': 'This trip is no longer available to you.',
    'ar': 'لم تعد هذه الرحلة متاحة لك.',
    'ru': 'Эта поездка вам больше недоступна.',
    'ka': 'ეს მგზავრობა თქვენთვის აღარ არის ხელმისაწვდომი.',
  });

  String get notificationGenericTitle => _t({
    'en': 'New notification',
    'ar': 'إشعار جديد',
    'ru': 'Новое уведомление',
    'ka': 'ახალი შეტყობინება',
  });
  String notificationGenericMessage(String? ref) {
    final hasRef = ref != null && ref.isNotEmpty;
    return _t({
      'en': hasRef ? 'Booking $ref' : 'You have a new notification.',
      'ar': hasRef ? 'الحجز $ref' : 'لديك إشعار جديد.',
      'ru': hasRef ? 'Бронирование $ref' : 'У вас новое уведомление.',
      'ka': hasRef ? 'ჯავშანი $ref' : 'თქვენ გაქვთ ახალი შეტყობინება.',
      'az': hasRef ? 'Rezervasiya $ref' : 'Sizin yeni bildirişiniz var.',
    });
  }

  String get notificationsReadOnlyMessage => _t({
    'en': 'Marking notifications as read is not available yet.',
    'ar': 'تحديد الإشعارات كمقروءة غير متاح بعد.',
    'ru': 'Отметка уведомлений как прочитанных пока недоступна.',
    'ka': 'შეტყობინებების წაკითხულად მონიშვნა ჯერ ხელმისაწვდომი არ არის.',
  });

  String get notificationsMarkReadFailed => _t({
    'en': 'Could not update notifications. Please try again.',
    'ar': 'تعذر تحديث الإشعارات. يرجى المحاولة مرة أخرى.',
    'ru': 'Не удалось обновить уведомления. Попробуйте ещё раз.',
    'ka': 'შეტყობინებების განახლება ვერ მოხერხდა. სცადეთ ხელახლა.',
  });

  String get unreadLabel =>
      _t({'en': 'Unread', 'ar': 'غير مقروء', 'ru': 'Новое', 'ka': 'ახალი'});
  String get readLabel =>
      _t({'en': 'Read', 'ar': 'مقروء', 'ru': 'Прочитано', 'ka': 'წაკითხული'});
  String get yesterday =>
      _t({'en': 'Yesterday', 'ar': 'أمس', 'ru': 'Вчера', 'ka': 'გუშინ'});

  /// "Today, 14:05" / "Yesterday, 14:05" / "Jun 5, 2026, 14:05".
  String notificationDateTime(DateTime d) {
    final now = DateTime.now();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    final time = '$hh:$mm';
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    if (sameDay(d, now)) return '$today, $time';
    if (sameDay(d, now.subtract(const Duration(days: 1)))) {
      return '$yesterday, $time';
    }
    return '${shortDateWithYear(d)}, $time';
  }

  // ─── Internal ──────────────────────────────────────────────────────────────

  // ─── Live Driver Tracking ─────────────────────────────────────────────────
  String get trackYourDriver => _t({
    'en': 'Track Your Driver',
    'ar': 'تتبع سائقك',
    'ru': 'Отследить водителя',
    'ka': 'მძღოლის თვალყურის დევნება',
  });
  String get trackingAirportPickup => _t({
    'en': 'Airport pickup',
    'ar': 'الاستقبال من المطار',
    'ru': 'Встреча в аэропорту',
    'ka': 'აეროპორტში შეხვედრა',
  });
  String get trackingHotelPickup => _t({
    'en': 'Hotel pickup',
    'ar': 'الاستقبال من الفندق',
    'ru': 'Трансфер из отеля',
    'ka': 'სასტუმროდან აყვანა',
  });
  String get trackingStatusNotStarted => _t({
    'en': 'Tracking opens 30 minutes before pickup',
    'ar': 'يبدأ التتبع قبل 30 دقيقة من موعد الاستقبال',
    'ru': 'Отслеживание откроется за 30 минут до встречи',
    'ka': 'თვალყურის დევნება იწყება აყვანამდე 30 წუთით ადრე',
  });
  String get trackingStatusWaiting => _t({
    'en': 'Waiting for your driver to share location',
    'ar': 'بانتظار مشاركة السائق لموقعه',
    'ru': 'Ожидаем, пока водитель включит геолокацию',
    'ka': 'ველოდებით მძღოლის მდებარეობის გაზიარებას',
  });
  String get trackingStatusLive => _t({
    'en': 'Live tracking active',
    'ar': 'التتبع المباشر مفعّل',
    'ru': 'Отслеживание активно',
    'ka': 'პირდაპირი თვალყურის დევნება აქტიურია',
  });
  String get trackingStatusEnded => _t({
    'en': 'Tracking ended',
    'ar': 'انتهى التتبع',
    'ru': 'Отслеживание завершено',
    'ka': 'თვალყურის დევნება დასრულდა',
  });
  String get locationUnavailable => _t({
    'en': 'Location Unavailable',
    'ar': 'الموقع غير متاح',
    'ru': 'Местоположение недоступно',
    'ka': 'მდებარეობა მიუწვდომელია',
  });
  String get trackingOpenInMaps => _t({
    'en': 'Open in Google Maps',
    'ar': 'فتح في خرائط جوجل',
    'ru': 'Открыть в Google Maps',
    'ka': 'გახსნა Google Maps-ში',
  });
  String get pickupOpenInMaps => _t({
    'en': 'Open in Maps',
    'ar': 'فتح في الخرائط',
    'ru': 'Открыть на карте',
    'ka': 'რუკაზე გახსნა',
  });
  String get pickupNavigate => _t({
    'en': 'Navigate',
    'ar': 'ابدأ التنقل',
    'ru': 'Навигация',
    'ka': 'ნავიგაცია',
  });
  String get trackingLastUpdate => _t({
    'en': 'Last update',
    'ar': 'آخر تحديث',
    'ru': 'Последнее обновление',
    'ka': 'ბოლო განახლება',
  });
  String get trackingEta => _t({
    'en': 'Estimated arrival',
    'ar': 'الوصول المتوقع',
    'ru': 'Ориентировочное прибытие',
    'ka': 'სავარაუდო ჩამოსვლა',
  });
  String trackingEtaMinutes(int m) => _t({
    'en': '$m min',
    'ar': '$m دقيقة',
    'ru': '$m мин',
    'ka': '$m წთ',
    'az': '$m dəq.',
  });
  String get trackingJustNow =>
      _t({'en': 'Just now', 'ar': 'الآن', 'ru': 'Только что', 'ka': 'ახლახან'});
  String trackingSecondsAgo(int s) => _t({
    'en': '$s sec ago',
    'ar': 'منذ $s ثانية',
    'ru': '$s сек назад',
    'ka': '$s წმ-ის წინ',
    'az': '$s san. əvvəl',
  });
  String trackingMinutesAgo(int m) => _t({
    'en': '$m min ago',
    'ar': 'منذ $m دقيقة',
    'ru': '$m мин назад',
    'ka': '$m წთ-ის წინ',
    'az': '$m dəq. əvvəl',
  });
  String get trackingNoDriverYet => _t({
    'en': 'Your driver will be assigned soon',
    'ar': 'سيتم تعيين السائق قريباً',
    'ru': 'Водитель будет назначен в ближайшее время',
    'ka': 'მძღოლი მალე დაინიშნება',
  });
  String get trackingDriverChanged => _t({
    'en': 'Your driver was updated. Tracking now follows the new driver.',
    'ar': 'تم تغيير السائق. يتم الآن تتبع السائق الجديد.',
    'ru': 'Водитель изменён. Отслеживание переключено на нового водителя.',
    'ka': 'მძღოლი შეიცვალა. თვალყურის დევნება ახალ მძღოლზეა გადართული.',
  });

  // Driver side
  String get shareLocationTitle => _t({
    'en': 'Share Live Location',
    'ar': 'مشاركة الموقع المباشر',
    'ru': 'Передача местоположения',
    'ka': 'მდებარეობის გაზიარება',
  });
  String get shareLocationSubtitle => _t({
    'en': 'Let your passenger follow you during pickup',
    'ar': 'اسمح للمسافر بمتابعتك أثناء الاستقبال',
    'ru': 'Пассажир сможет видеть вас во время встречи',
    'ka': 'მგზავრს შეეძლება თვალყური გიდევნოთ აყვანისას',
  });
  String get startLocationSharing => _t({
    'en': 'Start Location Sharing',
    'ar': 'بدء مشاركة الموقع',
    'ru': 'Начать передачу',
    'ka': 'გაზიარების დაწყება',
  });
  String get stopLocationSharing => _t({
    'en': 'Stop Location Sharing',
    'ar': 'إيقاف مشاركة الموقع',
    'ru': 'Остановить передачу',
    'ka': 'გაზიარების შეჩერება',
  });
  String get sharingActive => _t({
    'en': 'Sharing your location',
    'ar': 'جارٍ مشاركة موقعك',
    'ru': 'Местоположение передаётся',
    'ka': 'თქვენი მდებარეობა გაზიარებულია',
  });
  String get sharingStopped => _t({
    'en': 'Location sharing is off',
    'ar': 'مشاركة الموقع متوقفة',
    'ru': 'Передача отключена',
    'ka': 'გაზიარება გამორთულია',
  });
  String get sharingNotYetAvailable => _t({
    'en': 'Available 30 minutes before pickup',
    'ar': 'متاح قبل 30 دقيقة من موعد الاستقبال',
    'ru': 'Доступно за 30 минут до встречи',
    'ka': 'ხელმისაწვდომია აყვანამდე 30 წუთით ადრე',
  });
  String get sharingPermissionDenied => _t({
    'en': 'Location permission is required to share your location.',
    'ar': 'يلزم إذن الموقع لمشاركة موقعك.',
    'ru': 'Для передачи местоположения нужно разрешение на геолокацию.',
    'ka': 'მდებარეობის გასაზიარებლად საჭიროა ნებართვა.',
  });
  String get sharingServiceDisabled => _t({
    'en': 'Please turn on location services on your device.',
    'ar': 'يرجى تفعيل خدمات الموقع على جهازك.',
    'ru': 'Включите службы геолокации на устройстве.',
    'ka': 'ჩართეთ მდებარეობის სერვისები თქვენს მოწყობილობაზე.',
  });
  String get sharingBackendUnavailable => _t({
    'en': 'Live tracking is not available yet. Please try again later.',
    'ar': 'التتبع المباشر غير متاح بعد. يرجى المحاولة لاحقاً.',
    'ru': 'Отслеживание пока недоступно. Повторите позже.',
    'ka':
        'პირდაპირი თვალყურის დევნება ჯერ არ არის ხელმისაწვდომი. სცადეთ მოგვიანებით.',
  });
  String get sharingRejected => _t({
    'en': 'Sharing is only available during the pickup period.',
    'ar': 'المشاركة متاحة فقط خلال فترة الاستقبال.',
    'ru': 'Передача доступна только в период встречи.',
    'ka': 'გაზიარება ხელმისაწვდომია მხოლოდ აყვანის პერიოდში.',
  });
  String get sharingFailed => _t({
    'en': 'Could not start sharing. Please try again.',
    'ar': 'تعذر بدء المشاركة. يرجى المحاولة مرة أخرى.',
    'ru': 'Не удалось начать передачу. Повторите попытку.',
    'ka': 'გაზიარების დაწყება ვერ მოხერხდა. სცადეთ ხელახლა.',
  });
  String get sharingBackgroundTitle => _t({
    'en': 'TourOps — sharing location',
    'ar': 'TourOps — مشاركة الموقع',
    'ru': 'TourOps — передача геолокации',
    'ka': 'TourOps — მდებარეობის გაზიარება',
  });
  String get sharingBackgroundText => _t({
    'en': 'Your location is shared with your passenger during pickup.',
    'ar': 'يتم مشاركة موقعك مع المسافر أثناء الاستقبال.',
    'ru': 'Ваше местоположение доступно пассажиру во время встречи.',
    'ka': 'თქვენი მდებარეობა მგზავრს აყვანისას უზიარდება.',
  });

  // ─── Internal ──────────────────────────────────────────────────────────────

  String _t(Map<String, String> map) {
    if (locale == 'az') {
      final inline = map['az'];
      if (inline != null) return inline;
      final en = map['en'];
      if (en != null) {
        final az = AzAppTranslations.lookup(en);
        if (az != null) return az;
      }
    }
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
