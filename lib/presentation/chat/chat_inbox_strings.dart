/// Strings for the Driver Messages inbox (English, Arabic, Russian, Georgian).
class ChatInboxStrings {
  final String locale;
  const ChatInboxStrings(this.locale);

  String _t(Map<String, String> m) => m[locale] ?? m['en'] ?? '';

  String get navChat =>
      _t({'en': 'Chat', 'ar': 'الدردشة', 'ru': 'Чат', 'ka': 'ჩატი'});

  String get title => _t({
    'en': 'Messages',
    'ar': 'الرسائل',
    'ru': 'Сообщения',
    'ka': 'შეტყობინებები',
  });

  String get subtitle => _t({
    'en': 'Your trip conversations',
    'ar': 'محادثات رحلاتك',
    'ru': 'Ваши переписки по поездкам',
    'ka': 'თქვენი მოგზაურობის საუბრები',
  });

  String get searchHint => _t({
    'en': 'Search booking reference or customer',
    'ar': 'ابحث برقم الحجز أو اسم العميل',
    'ru': 'Поиск по номеру брони или клиенту',
    'ka': 'მოძებნეთ ჯავშნის ნომრით ან კლიენტით',
  });

  String get filterAll =>
      _t({'en': 'All', 'ar': 'الكل', 'ru': 'Все', 'ka': 'ყველა'});

  String get filterActive =>
      _t({'en': 'Active', 'ar': 'نشط', 'ru': 'Активные', 'ka': 'აქტიური'});

  String get filterCompleted => _t({
    'en': 'Completed',
    'ar': 'مكتمل',
    'ru': 'Завершённые',
    'ka': 'დასრულებული',
  });

  String get statusActive =>
      _t({'en': 'Active', 'ar': 'نشط', 'ru': 'Активна', 'ka': 'აქტიური'});

  String get statusCompleted => _t({
    'en': 'Completed',
    'ar': 'مكتمل',
    'ru': 'Завершена',
    'ka': 'დასრულებული',
  });

  String get voiceMessage => _t({
    'en': 'Voice message',
    'ar': 'رسالة صوتية',
    'ru': 'Голосовое сообщение',
    'ka': 'ხმოვანი შეტყობინება',
  });

  String get noMessagesYet => _t({
    'en': 'No messages yet',
    'ar': 'لا توجد رسائل بعد',
    'ru': 'Сообщений пока нет',
    'ka': 'შეტყობინებები ჯერ არ არის',
  });

  String get emptyTitle => _t({
    'en': 'No conversations found',
    'ar': 'لا توجد محادثات',
    'ru': 'Переписки не найдены',
    'ka': 'საუბრები ვერ მოიძებნა',
  });

  String get emptyBody => _t({
    'en': 'Conversations for your bookings will appear here.',
    'ar': 'ستظهر هنا محادثات حجوزاتك.',
    'ru': 'Здесь появятся переписки по вашим броням.',
    'ka': 'აქ გამოჩნდება თქვენი ჯავშნების საუბრები.',
  });

  String get retry => _t({
    'en': 'Retry',
    'ar': 'إعادة المحاولة',
    'ru': 'Повторить',
    'ka': 'ხელახლა',
  });

  String get yesterday =>
      _t({'en': 'Yesterday', 'ar': 'أمس', 'ru': 'Вчера', 'ka': 'გუშინ'});

  String get accessBlocked => _t({
    'en': 'Chat access is blocked by the server',
    'ar': 'الوصول إلى الدردشة محظور من الخادم',
    'ru': 'Доступ к чату заблокирован сервером',
    'ka': 'ჩატზე წვდომა სერვერმა დაბლოკა',
  });

  String get readOnlyNotice => _t({
    'en': 'This trip is completed. The conversation is read-only.',
    'ar': 'اكتملت هذه الرحلة. المحادثة للقراءة فقط.',
    'ru': 'Поездка завершена. Переписка доступна только для чтения.',
    'ka': 'მოგზაურობა დასრულებულია. საუბარი მხოლოდ წასაკითხია.',
  });

  String get support => _t({
    'en': 'Support',
    'ar': 'الدعم',
    'ru': 'Поддержка',
    'ka': 'მხარდაჭერა',
  });

  String get supportSubtitle => _t({
    'en': 'Call, WhatsApp, email and FAQ',
    'ar': 'اتصال، واتساب، بريد إلكتروني وأسئلة شائعة',
    'ru': 'Звонок, WhatsApp, email и FAQ',
    'ka': 'ზარი, WhatsApp, ელფოსტა და FAQ',
  });
}
