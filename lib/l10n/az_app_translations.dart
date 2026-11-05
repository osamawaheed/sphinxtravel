/// Azerbaijani (Latin, az-AZ) translations for [AppLocalizations].
///
/// Keyed by the exact English source string used in the `'en'` entry of each
/// `_t({...})` map. This overlay is only consulted when the locale is `az`, so
/// English, Arabic, Russian and Georgian translations are never affected.
class AzAppTranslations {
  AzAppTranslations._();

  static String? lookup(String english) => _map[english];

  static const Map<String, String> _map = {
    // ─── Generic ───────────────────────────────────────────────────────────
    'Loading...': 'Yüklənir...',
    'Error': 'Xəta',
    'Retry': 'Yenidən cəhd et',
    'Back': 'Geri',
    'Continue': 'Davam et',
    'Skip': 'Keç',
    'Sign Out': 'Çıxış',
    'Enable Biometric Login': 'Biometrik girişi aktiv et',
    'Sign in faster next time with a Passkey using your fingerprint, face or device screen lock. Your password stays as a fallback.':
        'Növbəti dəfə barmaq izi, üz və ya ekran kilidi ilə Passkey vasitəsilə daha sürətli daxil olun. Parolunuz ehtiyat variant kimi qalır.',
    'Not now': 'İndi yox',
    'Sign in with Passkey': 'Passkey ilə daxil ol',
    'Security': 'Təhlükəsizlik',
    'Customer phone number is not available.':
        'Müştərinin telefon nömrəsi əlçatan deyil.',
    'Could not open the phone dialer.': 'Zəng tətbiqini açmaq mümkün olmadı.',
    'Passkey Login': 'Passkey ilə giriş',
    'Passkey login is not available yet. Please use your password.':
        'Passkey ilə giriş hələ əlçatan deyil. Zəhmət olmasa, parolunuzdan istifadə edin.',
    'Coming soon': 'Tezliklə',
    'Passkey login disabled on this device.':
        'Passkey ilə giriş bu cihazda deaktivdir.',
    'Passkey sign-in failed. Please use your password.':
        'Passkey ilə giriş alınmadı. Zəhmət olmasa, parolunuzdan istifadə edin.',
    'Use fingerprint, face or screen lock to sign in':
        'Daxil olmaq üçün barmaq izi, üz və ya ekran kilidindən istifadə edin',
    'Are you sure you want to sign out?': 'Çıxış etmək istədiyinizə əminsiniz?',
    'No trips assigned yet.': 'Hələ ki, təyin olunmuş səfər yoxdur.',

    // ─── Splash ────────────────────────────────────────────────────────────
    'Georgia Awaits': 'Gürcüstan sizi gözləyir',
    'Ancient monasteries, mountain peaks,\nand timeless hospitality.':
        'Qədim monastırlar, dağ zirvələri\nvə zamansız qonaqpərvərlik.',
    'TBILISI · KAZBEGI · BATUMI': 'TBİLİSİ · QAZBEQİ · BATUMİ',
    'Stay in Luxury': 'Lüks şəraitdə qalın',
    'Curated hotels and resorts\nselected for your comfort.':
        'Rahatlığınız üçün seçilmiş\notellər və kurortlar.',
    'PREMIUM ACCOMMODATIONS': 'PREMİUM YERLƏŞDİRMƏ',
    'Your Journey,\nPersonalized': 'Səyahətiniz,\nsizə özəl',
    'Private transfers and expert drivers\nwith you every step of the way.':
        'Fərdi transferlər və təcrübəli sürücülər\nhər addımda sizinlə.',
    'PRIVATE TRANSPORTATION': 'FƏRDİ NƏQLİYYAT',
    'Explore Your Journey': 'Səyahətinizi kəşf edin',
    'Start Driving': 'Sürməyə başla',
    'Get Started': 'Başlayın',
    'Your Journey\nStarts Here': 'Səyahətiniz\nburadan başlayır',
    'Every Trip.\nPerfectly Managed.': 'Hər səfər.\nMükəmməl idarə olunur.',
    'Run Travel\nSmarter': 'Səyahəti\ndaha ağıllı idarə edin',
    'Everything you need for a seamless travel experience, all in one place.':
        'Problemsiz səyahət təcrübəsi üçün lazım olan hər şey bir yerdə.',
    'Stay connected, follow your schedule, and deliver every journey with confidence.':
        'Əlaqədə qalın, cədvəlinizə əməl edin və hər səfəri əminliklə yerinə yetirin.',
    'Customers, drivers, trips and operations — connected in one powerful platform.':
        'Müştərilər, sürücülər, səfərlər və əməliyyatlar — bir güclü platformada birləşib.',

    // ─── User type & language ──────────────────────────────────────────────
    'How would you like\nto continue?': 'Necə davam etmək\nistərdiniz?',
    'Select your role to get started': 'Başlamaq üçün rolunuzu seçin',
    'Customer': 'Müştəri',
    'Driver': 'Sürücü',
    'Manage your journey and\ntravel experience.':
        'Səyahətinizi və səyahət\ntəcrübənizi idarə edin.',
    'View and manage your\nassigned trips.':
        'Sizə təyin olunmuş\nsəfərlərə baxın və idarə edin.',
    '© 2026 Sphinx Travel LLC. All rights reserved.':
        '© 2026 Sphinx Travel LLC. Bütün hüquqlar qorunur.',
    'Select Your\nLanguage': 'Dilinizi\nseçin',
    'Choose Your Language': 'Dilinizi seçin',
    'Choose your preferred language to continue':
        'Davam etmək üçün üstünlük verdiyiniz dili seçin',

    // ─── Customer login / OTP (shared auth strings) ────────────────────────
    'Welcome Back': 'Yenidən xoş gəldiniz',
    'Sign in to access your journey':
        'Səyahətinizə daxil olmaq üçün giriş edin',
    'Your Phone Number': 'Telefon nömrəniz',
    "We'll send a verification code to the phone number registered with your booking.":
        'Rezervasiyanız üçün qeydiyyatdan keçmiş telefon nömrəsinə təsdiq kodu göndərəcəyik.',
    'Phone number': 'Telefon nömrəsi',
    'Send Verification Code': 'Təsdiq kodunu göndər',
    'Please enter your phone number':
        'Zəhmət olmasa, telefon nömrənizi daxil edin',
    'Failed to send OTP. Please try again.':
        'Kodu göndərmək mümkün olmadı. Yenidən cəhd edin.',
    'Search country...': 'Ölkə axtar...',
    'Select Country': 'Ölkə seçin',
    'Verify Your\nPhone Number': 'Telefon nömrənizi\ntəsdiqləyin',
    'We sent a 6-digit code to': '6 rəqəmli kodu göndərdik:',
    'via WhatsApp': 'WhatsApp vasitəsilə',
    'Verify': 'Təsdiqlə',
    'Resend Code': 'Kodu yenidən göndər',
    'Resend in': 'Yenidən göndərmək üçün',
    's': 'san',
    'Invalid code. Please try again.': 'Yanlış kod. Yenidən cəhd edin.',
    'Code expired. Please request a new one.':
        'Kodun vaxtı bitib. Yeni kod tələb edin.',
    'Too many attempts. Please try again later.':
        'Çox sayda cəhd. Bir az sonra yenidən cəhd edin.',

    // ─── Driver login ──────────────────────────────────────────────────────
    'Driver Portal': 'Sürücü portalı',
    'Sign in with your Odoo credentials':
        'Odoo giriş məlumatlarınızla daxil olun',
    'Sign In': 'Daxil ol',
    'Use your Tour Operations driver account':
        'Tour Operations sürücü hesabınızdan istifadə edin',
    'Username': 'İstifadəçi adı',
    'Password': 'Parol',
    'Enter your username': 'İstifadəçi adınızı daxil edin',
    'Enter your password': 'Parolunuzu daxil edin',
    'Please enter your username and password':
        'Zəhmət olmasa, istifadəçi adı və parolu daxil edin',
    'Invalid username or password. Please try again.':
        'İstifadəçi adı və ya parol yanlışdır. Yenidən cəhd edin.',
    'Incorrect username or password. Please try again.':
        'İstifadəçi adı və ya parol yanlışdır. Yenidən cəhd edin.',
    'Login failed multiple times. Please contact the Operations Team to verify your username and password.':
        'Giriş bir neçə dəfə uğursuz oldu. İstifadəçi adı və parolu yoxlamaq üçün Əməliyyat komandası ilə əlaqə saxlayın.',

    // ─── Greetings & home ──────────────────────────────────────────────────
    'Good morning': 'Sabahınız xeyir',
    'Good afternoon': 'Günortanız xeyir',
    'Good evening': 'Axşamınız xeyir',
    'Today': 'Bu gün',
    'My Trip': 'Mənim səfərim',
    'Services': 'Xidmətlər',
    'Have you delivered the eSIM cards to the customer?':
        'eSIM kartlarını müştəriyə təhvil verdiniz?',
    'Cancel': 'Ləğv et',
    'Confirm Delivery': 'Təhvili təsdiqlə',
    'Delivered': 'Təhvil verildi',
    'Tap to confirm delivery': 'Təhvili təsdiqləmək üçün toxunun',
    'eSIM delivery confirmed': 'eSIM təhvili təsdiqləndi',
    'Could not confirm delivery. Please try again.':
        'Təhvili təsdiqləmək mümkün olmadı. Yenidən cəhd edin.',
    'Wallet': 'Pul kisəsi',
    'Balance': 'Balans',
    'Transactions': 'Əməliyyatlar',
    'No transactions yet': 'Hələ ki, əməliyyat yoxdur',
    'View / Update status': 'Statusa bax / yenilə',
    'No driver assigned': 'Sürücü təyin edilməyib',
    'My Trips': 'Səfərlərim',
    'Ended': 'Bitdi',
    'Trip Details': 'Səfər təfərrüatları',
    'Driver Task': 'Sürücü tapşırığı',
    'Ready to Go': 'Yola hazırdır',
    'Support': 'Dəstək',
    'Profile': 'Profil',
    'No active trip': 'Aktiv səfər yoxdur',
    'Your upcoming trips will appear here':
        'Gələcək səfərləriniz burada görünəcək',
    'DRIVER PICKUP': 'SÜRÜCÜ QARŞILAMASI',
    'NEXT UP': 'NÖVBƏTİ',
    'Your driver will be assigned soon': 'Sürücünüz tezliklə təyin olunacaq',
    'Driver is on the way': 'Sürücü yoldadır',
    'Ready': 'Hazırdır',
    'On The Way': 'Yolda',
    'Picked Up': 'Götürüldü',
    'In Tour': 'Turda',
    'Completed': 'Tamamlandı',
    'WhatsApp': 'WhatsApp',
    'Driver & Vehicle': 'Sürücü və nəqliyyat vasitəsi',
    'Vehicle': 'Nəqliyyat vasitəsi',
    'Your driver arrives in 25 min': 'Sürücünüz 25 dəqiqəyə çatacaq',
    'Pickup': 'Götürülmə yeri',
    'Date': 'Tarix',
    'Time': 'Vaxt',
    'City': 'Şəhər',
    'Status': 'Status',
    'Rate your driver': 'Sürücünü qiymətləndirin',
    'Rate Driver': 'Sürücünü qiymətləndir',
    'Submit': 'Göndər',
    'Rate your hotel': 'Oteli qiymətləndirin',
    'Submit rating': 'Qiyməti göndər',
    'Update rating': 'Qiyməti yenilə',
    'Add a comment (optional)': 'Rəy əlavə edin (könüllü)',
    'Please select a rating from 1 to 5': '1-dən 5-ə qədər qiymət seçin',
    'Please select a rating from 1 to 10': '1-dən 10-a qədər qiymət seçin',
    'Thanks for your rating': 'Qiymətləndirməyiniz üçün təşəkkürlər',
    'Destination': 'Təyinat yeri',
    'Call': 'Zəng et',
    'Print Customer Name': 'Müştəri adını çap et',
    'Customer Name Report': 'Müştəri adı hesabatı',
    'Share via WhatsApp': 'WhatsApp ilə paylaş',
    'Download': 'Yüklə',
    'Print': 'Çap et',
    'Open PDF': 'PDF-i aç',
    'The report is not available yet. Please try again later.':
        'Hesabat hələ əlçatan deyil. Bir az sonra yenidən cəhd edin.',
    'Only the assigned driver can access this report.':
        'Bu hesabata yalnız təyin olunmuş sürücü daxil ola bilər.',
    'Message': 'Mesaj',
    'View Driver': 'Sürücüyə bax',
    'trips': 'səfər',
    'Driver will be assigned before your trip.':
        'Sürücü səfərdən əvvəl təyin olunacaq.',
    'Your driver has arrived': 'Sürücünüz çatdı',
    'is on the way': 'yoldadır',
    "Today's activities are complete": 'Bu günün fəaliyyətləri tamamlandı',
    'Enjoy your evening': 'Axşamınız xoş keçsin',
    'No upcoming activities': 'Gələcək fəaliyyət yoxdur',
    "Today's Plan": 'Bu günün planı',
    'View More': 'Daha çox bax',
    'View Less': 'Daha az bax',
    'No activities scheduled for today':
        'Bu gün üçün planlaşdırılmış fəaliyyət yoxdur',
    'Staying tonight': 'Bu gecə qalacağı yer',
    'more activities': 'daha çox fəaliyyət',
    'SIM Card': 'SIM kart',
    'eSIM Card': 'eSIM kart',
    'SIM cards': 'SIM kartlar',
    'Awaiting delivery': 'Təhvil gözlənilir',
    'Delivered by driver': 'Sürücü tərəfindən təhvil verildi',
    'Awaiting Delivery': 'Təhvil gözlənilir',
    'Delivery Confirmed': 'Təhvil təsdiqləndi',
    'Confirmed by': 'Təsdiqləyən',
    'Confirmed on': 'Təsdiq tarixi',
    'SIM quantity': 'SIM sayı',
    'SIM Received': 'SIM qəbul edildi',
    'Not Received — Reported': 'Qəbul edilmədi — bildirildi',
    'Confirm SIM Received': 'SIM-in qəbulunu təsdiqlə',
    'SIM Not Received Yet': 'SIM hələ qəbul edilməyib',
    'Have you received your SIM cards?': 'SIM kartlarınızı qəbul etdiniz?',
    'Have you not received your SIM cards yet?':
        'SIM kartlarınızı hələ qəbul etməmisiniz?',
    'Confirm Receipt': 'Qəbulu təsdiqlə',
    'Report Not Received': 'Qəbul edilmədiyini bildir',
    'SIM receipt confirmed': 'SIM-in qəbulu təsdiqləndi',
    'Your report was sent. We will follow up shortly.':
        'Bildirişiniz göndərildi. Tezliklə sizinlə əlaqə saxlayacağıq.',
    'Could not update SIM status. Please try again.':
        'SIM statusunu yeniləmək mümkün olmadı. Yenidən cəhd edin.',
    'Flowers': 'Güllər',
    'flowers': 'gül',
    'Flowers quantity': 'Gül sayı',
    'Flowers Received': 'Güllər qəbul edildi',
    'Confirm Flowers Received': 'Güllərin qəbulunu təsdiqlə',
    'Flowers Not Received Yet': 'Güllər hələ qəbul edilməyib',
    'Have you received your flowers?': 'Güllərinizi qəbul etdiniz?',
    'Have you not received your flowers yet?':
        'Güllərinizi hələ qəbul etməmisiniz?',
    'Flowers receipt confirmed': 'Güllərin qəbulu təsdiqləndi',
    'Could not update flowers status. Please try again.':
        'Güllərin statusunu yeniləmək mümkün olmadı. Yenidən cəhd edin.',
    'Have you delivered the flowers to the customer?':
        'Gülləri müştəriyə təhvil verdiniz?',
    'Flowers delivery confirmed': 'Güllərin təhvili təsdiqləndi',
    'Confirm Flowers Delivered?': 'Güllərin təhvili təsdiqlənsin?',
    'Flowers marked as Delivered': 'Güllər təhvil verilmiş kimi qeyd edildi',
    'Tomorrow': 'Sabah',
    'View Tomorrow': 'Sabaha bax',
    'Day': 'Gün',
    'of': '/',
    'Your': 'Sizin',
    'Your trip starts in': 'Səfəriniz başlayır:',
    'days': 'gün',
    'day': 'gün',

    // ─── Trip tab ──────────────────────────────────────────────────────────
    'Trip Overview': 'Səfərin icmalı',
    'Reference': 'İstinad',
    'Check-in': 'Giriş',
    'Check-out': 'Çıxış',
    'Duration': 'Müddət',
    'Flights': 'Uçuşlar',
    'Hotels': 'Otellər',
    'Flight': 'Uçuş',
    'Airline': 'Aviaşirkət',
    'Route': 'Marşrut',
    'Departure': 'Yola düşmə',
    'Arrival': 'Çatma',
    'Hotel': 'Otel',
    'Hotel Details': 'Otel təfərrüatları',
    'Hotel Phone': 'Otelin telefonu',
    'Close': 'Bağla',
    'Get Directions': 'Yol tarifi al',
    'Call Hotel': 'Otelə zəng et',
    'Maps': 'Xəritə',
    'Phone number not available': 'Telefon nömrəsi əlçatan deyil',
    'Map location not available': 'Xəritə məkanı əlçatan deyil',
    'Unable to open. Please try again.':
        'Açmaq mümkün olmadı. Yenidən cəhd edin.',
    'Location': 'Məkan',
    'Nights': 'Gecə',
    'Room': 'Otaq',
    'Extra Services': 'Əlavə xidmətlər',
    'No extra services': 'Əlavə xidmət yoxdur',
    'pending': 'gözləyir',
    'active': 'aktiv',
    'Call Us': 'Bizə zəng edin',
    'Chat with our team': 'Komandamızla yazışın',
    'Email': 'E-poçt',
    'FAQ': 'Tez-tez verilən suallar',
    'Frequently asked questions': 'Tez-tez verilən suallar',
    'Currency': 'Valyuta',
    'Failed to load trip data': 'Səfər məlumatlarını yükləmək mümkün olmadı',
    'Something went wrong': 'Nəsə xəta baş verdi',

    // ─── Driver home ───────────────────────────────────────────────────────
    'CURRENT TRIP': 'CARİ SƏFƏR',
    'NEXT TODAY': 'BU GÜN NÖVBƏTİ',
    'TOMORROW': 'SABAH',
    'TODAY': 'BU GÜN',
    'UPCOMING': 'GƏLƏCƏK',
    'COMPLETED': 'TAMAMLANMIŞ',
    'Your assigned trips will appear here':
        'Sizə təyin olunmuş səfərlər burada görünəcək',
    'View Details': 'Təfərrüatlara bax',
    'Start Trip': 'Səfərə başla',
    'Arrived': 'Çatdım',
    'Next Assigned Trip': 'Növbəti təyin olunmuş səfər',
    'Color': 'Rəng',
    'Plate': 'Nömrə nişanı',
    'Trips': 'Səfərlər',
    'UPCOMING TRIP': 'GƏLƏCƏK SƏFƏR',
    'ACTIVE': 'AKTİV',
    'NOW': 'İNDİ',
    'View Trip': 'Səfərə bax',
    'View Full Trip': 'Səfərin tam məlumatına bax',
    'HOTEL CHECK-IN': 'OTELƏ GİRİŞ',
    'HOTEL CHECK-OUT': 'OTELDƏN ÇIXIŞ',
    'CURRENT HOTEL': 'CARİ OTEL',
    'FINAL NIGHT': 'SON GECƏ',
    'Night': 'Gecə',
    'more segments': 'daha çox hissə',
    'Full Trip Details': 'Səfərin tam təfərrüatları',
    'ARRIVAL': 'ÇATMA',
    'ARRIVAL FLIGHT': 'GƏLİŞ UÇUŞU',
    'DEPARTURE': 'YOLA DÜŞMƏ',
    'TRANSPORTATION': 'NƏQLİYYAT',
    'Airport': 'Hava limanı',
    'First Pickup': 'İlk götürülmə',
    'Passengers': 'Sərnişinlər',
    'Arrival Time': 'Çatma vaxtı',
    'Departure Time': 'Yola düşmə vaxtı',
    'Terminal': 'Terminal',
    'Gate': 'Çıxış qapısı',
    'Guest': 'Qonaq',

    // ─── Location permission ───────────────────────────────────────────────
    'Location Required': 'Məkan tələb olunur',
    'To operate as a driver, we need access to your location.':
        'Sürücü kimi fəaliyyət göstərmək üçün məkanınıza giriş lazımdır.',
    'Assigned trip navigation': 'Təyin olunmuş səfərlər üzrə naviqasiya',
    'Live driver location sharing': 'Sürücünün canlı məkanının paylaşılması',
    'Pickup point tracking': 'Götürülmə nöqtəsinin izlənməsi',
    'Customer driver tracking': 'Müştəri tərəfindən sürücünün izlənməsi',
    'Trip operations and routing': 'Səfər əməliyyatları və marşrutlaşdırma',
    'Enable Location': 'Məkanı aktiv et',
    'Open Settings': 'Parametrləri aç',
    'Location Access Denied': 'Məkana giriş rədd edildi',
    'Location permission was denied. Please enable it to continue.':
        'Məkan icazəsi rədd edildi. Davam etmək üçün onu aktiv edin.',
    'Location permission is permanently denied. Please open Settings to enable it.':
        'Məkan icazəsi birdəfəlik rədd edilib. Aktiv etmək üçün Parametrləri açın.',
    'Location services are disabled on your device. Please enable them in Settings.':
        'Cihazınızda məkan xidmətləri söndürülüb. Onları Parametrlərdə aktiv edin.',
    'Your location will be shared with Sphinx Travel during your trips, including when the app is in the background.':
        'Məkanınız səfərləriniz zamanı, o cümlədən tətbiq arxa planda olduqda da Sphinx Travel ilə paylaşılacaq.',
    'Open Location Settings': 'Məkan parametrlərini aç',
    'Assigned trips': 'Təyin olunmuş səfərlər',
    'Navigation': 'Naviqasiya',
    'Pickup tracking': 'Götürülmənin izlənməsi',
    'Live trip tracking': 'Səfərin canlı izlənməsi',
    'Live trip operations': 'Canlı səfər əməliyyatları',

    // ─── Profile completion ────────────────────────────────────────────────
    'Complete Your Profile': 'Profilinizi tamamlayın',
    'Required before you can start accepting trips.':
        'Səfərləri qəbul etməyə başlamazdan əvvəl tələb olunur.',
    'Personal Photos': 'Şəxsi fotolar',
    'Clear photos of yourself for customer identification.':
        'Müştərilərin sizi tanıması üçün aydın şəkilləriniz.',
    'Vehicle Photos': 'Nəqliyyat vasitəsinin fotoları',
    'Photos of your vehicle from multiple angles.':
        'Nəqliyyat vasitənizin müxtəlif bucaqlardan şəkilləri.',
    'Vehicle Information': 'Nəqliyyat vasitəsi haqqında məlumat',
    'Ratings': 'Qiymətlər',
    'No ratings yet': 'Hələ ki, qiymət yoxdur',
    'Model Year': 'Buraxılış ili',
    'Personal photos': 'Şəxsi fotolar',
    'Vehicle photos': 'Nəqliyyat vasitəsinin fotoları',
    'Vehicle Model': 'Nəqliyyat vasitəsinin modeli',
    'e.g. Toyota Camry': 'məs. Toyota Camry',
    'Submit Profile': 'Profili göndər',
    'uploaded': 'yükləndi',
    'Add Photo': 'Foto əlavə et',
    'Take Photo': 'Foto çək',
    'Choose from Gallery': 'Qalereyadan seç',
    'Replace Photo': 'Fotonu dəyişdir',
    'Remove Photo': 'Fotonu sil',
    'Submitting your profile...': 'Profiliniz göndərilir...',
    'Verifying with Odoo...': 'Odoo ilə yoxlanılır...',
    'Profile submitted successfully!': 'Profil uğurla göndərildi!',
    'Failed to submit profile. Please try again.':
        'Profili göndərmək mümkün olmadı. Yenidən cəhd edin.',
    'Please fill in all required fields and upload all photos.':
        'Zəhmət olmasa, bütün məcburi sahələri doldurun və bütün fotoları yükləyin.',
    'Uploading photos...': 'Fotolar yüklənir...',
    'Failed to upload photo. Tap to retry.':
        'Fotonu yükləmək mümkün olmadı. Yenidən cəhd etmək üçün toxunun.',
    'Exactly 3 personal photos required': 'Dəqiq 3 şəxsi foto tələb olunur',
    'Exactly 5 vehicle photos required':
        'Nəqliyyat vasitəsinin dəqiq 5 fotosu tələb olunur',

    // ─── Header & tomorrow card ────────────────────────────────────────────
    'Hello': 'Salam',
    'guests': 'qonaq',
    'DEPARTURE FLIGHT': 'GETMƏ UÇUŞU',
    'NEW TRIP': 'YENİ SƏFƏR',
    'AIRPORT PICKUP': 'HAVA LİMANINDAN QARŞILAMA',
    'You have an airport pickup scheduled tomorrow for a new trip.':
        'Sabah yeni səfər üçün hava limanından qarşılama planlaşdırılıb.',
    'You have an assignment tomorrow for a new trip.':
        'Sabah yeni səfər üçün tapşırığınız var.',
    'Booking': 'Rezervasiya',
    'Every Trip Your Excellence.': 'Hər səfər sizin peşəkarlığınızdır.',

    // ─── Nav & settings ────────────────────────────────────────────────────
    'Support coming soon': 'Dəstək tezliklə əlçatan olacaq',
    'Appearance': 'Görünüş',
    'System': 'Sistem',
    'Light': 'Açıq',
    'Dark': 'Tünd',

    // ─── Trip / hotel details ──────────────────────────────────────────────
    'Hotel Name': 'Otelin adı',
    'Full Address': 'Tam ünvan',
    'Address not available': 'Ünvan əlçatan deyil',
    'Phone Number': 'Telefon nömrəsi',
    'Phone': 'Telefon',
    'Not available': 'Əlçatan deyil',
    'Open in Google Maps': 'Google Maps-də aç',
    'Trip Duration': 'Səfərin müddəti',
    'Arrival flight details not available':
        'Gəliş uçuşunun təfərrüatları əlçatan deyil',
    'Trip Information': 'Səfər haqqında məlumat',
    'Flight Info': 'Uçuş məlumatı',
    'Flight Number': 'Uçuş nömrəsi',
    'Notes': 'Qeydlər',
    'Trip Progress': 'Səfərin gedişi',
    'Trip Completed!': 'Səfər tamamlandı!',
    'Trip Reference': 'Səfər nömrəsi',
    'Customer Name': 'Müştərinin adı',
    'SIM Quantity': 'SIM kartların sayı',
    'Current Status': 'Cari status',
    'Confirm SIM Cards Delivered?': 'SIM kartların təhvili təsdiqlənsin?',
    'SIM cards marked as Delivered':
        'SIM kartlar təhvil verilmiş kimi qeyd edildi',
    'Failed to confirm delivery. Please try again.':
        'Təhvili təsdiqləmək mümkün olmadı. Yenidən cəhd edin.',

    // ─── Profile extras ────────────────────────────────────────────────────
    'Driver Name': 'Sürücünün adı',
    'e.g. John Smith': 'məs. Elnur Məmmədov',
    'e.g. Toyota Camry 2020': 'məs. Toyota Camry 2020',
    'Vehicle Color': 'Nəqliyyat vasitəsinin rəngi',
    'e.g. Black': 'məs. Qara',
    'From Odoo': 'Odoo-dan',
    'Vehicle Type': 'Nəqliyyat vasitəsinin növü',
    'Select vehicle type': 'Nəqliyyat vasitəsinin növünü seçin',
    'Sedan': 'Sedan',
    'Minivan': 'Minivan',
    'Sprinter': 'Sprinter',
    'Minibus': 'Mikroavtobus',

    // ─── Generic UI ────────────────────────────────────────────────────────
    'We encountered an unexpected error while processing your request.':
        'Sorğunuz işlənərkən gözlənilməz xəta baş verdi.',
    'Travel Operations': 'Səyahət əməliyyatları',
    'TEST MODE': 'TEST REJİMİ',
    'Your account is linked to your booking. Use the phone number provided during booking.':
        'Hesabınız rezervasiyanızla əlaqələndirilib. Rezervasiya zamanı göstərilən telefon nömrəsindən istifadə edin.',

    // ─── Status labels ─────────────────────────────────────────────────────
    'Passenger Picked Up': 'Sərnişin götürüldü',
    'Complete Trip': 'Səfəri tamamla',
    'Scheduled': 'Planlaşdırılıb',
    'Confirmed': 'Təsdiqlənib',
    'Cancelled': 'Ləğv edilib',
    'e.g.': 'məs.',
    'Traveler': 'Səyyah',

    // ─── Notifications ─────────────────────────────────────────────────────
    'Notifications': 'Bildirişlər',
    'No notifications yet': 'Hələ ki, bildiriş yoxdur',
    'New updates about your trips will appear here.':
        'Səfərlərinizlə bağlı yeniliklər burada görünəcək.',
    'Demo mode: notifications are not connected to the server yet.':
        'Demo rejim: bildirişlər hələ serverə qoşulmayıb.',
    'Could not load notifications.': 'Bildirişləri yükləmək mümkün olmadı.',
    'Mark all as read': 'Hamısını oxunmuş kimi qeyd et',
    'Mark as read': 'Oxunmuş kimi qeyd et',
    'Booking updated': 'Rezervasiya yeniləndi',
    'Trip assigned': 'Səfər təyin edildi',
    'Trip unassigned': 'Səfər təyinatı ləğv edildi',
    'This trip is no longer available to you.':
        'Bu səfər artıq sizin üçün əlçatan deyil.',
    'New notification': 'Yeni bildiriş',
    'Marking notifications as read is not available yet.':
        'Bildirişləri oxunmuş kimi qeyd etmək hələ əlçatan deyil.',
    'Could not update notifications. Please try again.':
        'Bildirişləri yeniləmək mümkün olmadı. Yenidən cəhd edin.',
    'Unread': 'Oxunmamış',
    'Read': 'Oxunmuş',
    'Yesterday': 'Dünən',

    // ─── Live tracking ─────────────────────────────────────────────────────
    'Track Your Driver': 'Sürücünüzü izləyin',
    'Airport pickup': 'Hava limanından qarşılama',
    'Hotel pickup': 'Oteldən götürülmə',
    'Tracking opens 30 minutes before pickup':
        'İzləmə götürülmədən 30 dəqiqə əvvəl açılır',
    'Waiting for your driver to share location':
        'Sürücünün məkanı paylaşması gözlənilir',
    'Live tracking active': 'Canlı izləmə aktivdir',
    'Tracking ended': 'İzləmə başa çatdı',
    'Location Unavailable': 'Məkan əlçatan deyil',
    'Open in Maps': 'Xəritədə aç',
    'Navigate': 'Naviqasiya',
    'Last update': 'Son yeniləmə',
    'Estimated arrival': 'Təxmini çatma vaxtı',
    'Just now': 'İndicə',
    'Your driver was updated. Tracking now follows the new driver.':
        'Sürücünüz dəyişdirildi. İzləmə indi yeni sürücüyə aiddir.',
    'Share Live Location': 'Canlı məkanı paylaş',
    'Let your passenger follow you during pickup':
        'Götürülmə zamanı sərnişinin sizi izləməsinə icazə verin',
    'Start Location Sharing': 'Məkan paylaşımına başla',
    'Stop Location Sharing': 'Məkan paylaşımını dayandır',
    'Sharing your location': 'Məkanınız paylaşılır',
    'Location sharing is off': 'Məkan paylaşımı söndürülüb',
    'Available 30 minutes before pickup':
        'Götürülmədən 30 dəqiqə əvvəl əlçatan olur',
    'Location permission is required to share your location.':
        'Məkanı paylaşmaq üçün məkan icazəsi tələb olunur.',
    'Please turn on location services on your device.':
        'Zəhmət olmasa, cihazınızda məkan xidmətlərini aktiv edin.',
    'Live tracking is not available yet. Please try again later.':
        'Canlı izləmə hələ əlçatan deyil. Bir az sonra yenidən cəhd edin.',
    'Sharing is only available during the pickup period.':
        'Paylaşım yalnız götürülmə dövründə əlçatandır.',
    'Could not start sharing. Please try again.':
        'Paylaşımı başlatmaq mümkün olmadı. Yenidən cəhd edin.',
    'TourOps — sharing location': 'TourOps — məkan paylaşılır',
    'Your location is shared with your passenger during pickup.':
        'Götürülmə zamanı məkanınız sərnişinlə paylaşılır.',
  };
}
