import '../../../l10n/az_feature_translations.dart';
import '../../../models/wallet_models.dart';

/// Driver Wallet strings (English, Russian, Georgian, Azerbaijani).
class WalletStrings {
  final String locale;
  const WalletStrings(this.locale);

  String _t(Map<String, String> m) {
    if (locale == 'az' && m['az'] == null) {
      final en = m['en'];
      final az = en == null ? null : AzFeatureTranslations.lookup(en);
      if (az != null) return az;
    }
    return m[locale] ?? m['en'] ?? '';
  }

  String get wallet => _t({'en': 'Wallet', 'ru': 'Кошелёк', 'ka': 'საფულე'});
  String get availableBalance => _t({
    'en': 'Available Balance',
    'ru': 'Доступный баланс',
    'ka': 'ხელმისაწვდომი ბალანსი',
  });
  String get totalEarnings => _t({
    'en': 'Total Earnings',
    'ru': 'Общий доход',
    'ka': 'ჯამური შემოსავალი',
  });
  String get pendingPayouts => _t({
    'en': 'Pending Payouts',
    'ru': 'Ожидающие выплаты',
    'ka': 'მომლოდინე გადახდები',
  });
  String get requestPayout => _t({
    'en': 'Request Payout',
    'ru': 'Запросить выплату',
    'ka': 'გადახდის მოთხოვნა',
  });
  String get transactions =>
      _t({'en': 'Transactions', 'ru': 'Транзакции', 'ka': 'ტრანზაქციები'});
  String get noTransactions => _t({
    'en': 'No transactions yet',
    'ru': 'Транзакций пока нет',
    'ka': 'ტრანზაქციები ჯერ არ არის',
  });
  String get unavailableTitle => _t({
    'en': 'Wallet not available yet',
    'ru': 'Кошелёк пока недоступен',
    'ka': 'საფულე ჯერ მიუწვდომელია',
  });
  String get unavailableBody => _t({
    'en':
        'Your wallet is being connected to the TourOps system. '
        'Balances and payouts will appear here once it is ready.',
    'ru':
        'Ваш кошелёк подключается к системе TourOps. '
        'Баланс и выплаты появятся здесь, когда он будет готов.',
    'ka':
        'თქვენი საფულე უკავშირდება TourOps სისტემას. '
        'ბალანსი და გადახდები აქ გამოჩნდება, როცა მზად იქნება.',
  });
  String get loadError => _t({
    'en': 'Could not load your wallet.',
    'ru': 'Не удалось загрузить кошелёк.',
    'ka': 'საფულის ჩატვირთვა ვერ მოხერხდა.',
  });
  String get retry => _t({
    'en': 'Retry',
    'ru': 'Повторить',
    'ka': 'ხელახლა ცდა',
    'az': 'Yenidən cəhd et',
  });

  // Payout screen
  String get payoutTitle => _t({
    'en': 'Request Payout',
    'ru': 'Запрос выплаты',
    'ka': 'გადახდის მოთხოვნა',
    'az': 'Ödəniş tələbi',
  });
  String get requestedAmount => _t({
    'en': 'Requested Amount',
    'ru': 'Запрашиваемая сумма',
    'ka': 'მოთხოვნილი თანხა',
  });
  String get remainingAvailable => _t({
    'en': 'Remaining Available',
    'ru': 'Останется доступно',
    'ka': 'დარჩება ხელმისაწვდომი',
  });
  String get booking =>
      _t({'en': 'Booking', 'ru': 'Бронирование', 'ka': 'ჯავშანი'});
  String get selectBooking => _t({
    'en': 'Select booking',
    'ru': 'Выберите бронирование',
    'ka': 'აირჩიეთ ჯავშანი',
  });
  String bookingAvailable(String ref, String amount, String currency) => _t({
    'en': '$ref — $amount $currency available',
    'ru': '$ref — доступно $amount $currency',
    'ka': '$ref — ხელმისაწვდომია $amount $currency',
    'az': '$ref — $amount $currency əlçatandır',
  });
  String requestSubmittedFor(String ref) => _t({
    'en': 'Payout request submitted for $ref. Status: Pending.',
    'ru': 'Запрос на выплату по $ref отправлен. Статус: В ожидании.',
    'ka': 'გადახდის მოთხოვნა $ref-ისთვის გაიგზავნა. სტატუსი: მოლოდინში.',
    'az': '$ref üçün ödəniş tələbi göndərildi. Status: Gözləyir.',
  });
  String get bankDetails => _t({
    'en': 'Bank Details',
    'ru': 'Банковские реквизиты',
    'ka': 'საბანკო რეკვიზიტები',
  });
  String get beneficiaryName => _t({
    'en': 'Beneficiary Name',
    'ru': 'Имя получателя',
    'ka': 'მიმღების სახელი',
  });
  String get bankName => _t({
    'en': 'Bank Name',
    'ru': 'Название банка',
    'ka': 'ბანკის დასახელება',
  });
  String get selectBank =>
      _t({'en': 'Select bank', 'ru': 'Выберите банк', 'ka': 'აირჩიეთ ბანკი'});
  String get iban => _t({
    'en': 'IBAN / Account Number',
    'ru': 'IBAN / Номер счёта',
    'ka': 'IBAN / ანგარიშის ნომერი',
  });
  String get taxId => _t({
    'en': 'Tax Identification Number',
    'ru': 'ИНН',
    'ka': 'საიდენტიფიკაციო ნომერი',
    'az': 'VÖEN',
  });
  String get confirmRequest => _t({
    'en': 'Confirm Request',
    'ru': 'Подтвердить запрос',
    'ka': 'მოთხოვნის დადასტურება',
  });
  String get savedSecurely => _t({
    'en':
        'Your bank details are saved securely for future requests '
        'and can be updated at any time.',
    'ru':
        'Ваши банковские реквизиты надёжно сохраняются для будущих '
        'запросов и могут быть изменены в любое время.',
    'ka':
        'თქვენი საბანკო რეკვიზიტები უსაფრთხოდ ინახება მომავალი '
        'მოთხოვნებისთვის და შეგიძლიათ ნებისმიერ დროს შეცვალოთ.',
  });
  String get fieldRequired => _t({
    'en': 'This field is required',
    'ru': 'Обязательное поле',
    'ka': 'ველი სავალდებულოა',
  });
  String get invalidAmount => _t({
    'en': 'Enter a valid amount',
    'ru': 'Введите корректную сумму',
    'ka': 'შეიყვანეთ სწორი თანხა',
  });
  String get amountExceeds => _t({
    'en': 'Amount exceeds your available balance',
    'ru': 'Сумма превышает доступный баланс',
    'ka': 'თანხა აღემატება ხელმისაწვდომ ბალანსს',
  });
  String get noBalance => _t({
    'en': 'No available balance to withdraw',
    'ru': 'Нет доступных средств для вывода',
    'ka': 'გასატანი ბალანსი არ არის',
  });
  String get requestSubmitted => _t({
    'en': 'Payout request submitted. Status: Pending.',
    'ru': 'Запрос на выплату отправлен. Статус: В ожидании.',
    'ka': 'გადახდის მოთხოვნა გაიგზავნა. სტატუსი: მოლოდინში.',
  });
  String get requestFailed => _t({
    'en': 'Could not submit your payout request. Please try again.',
    'ru': 'Не удалось отправить запрос. Попробуйте снова.',
    'ka': 'მოთხოვნის გაგზავნა ვერ მოხერხდა. სცადეთ ხელახლა.',
  });

  // Transactions
  String typeLabel(WalletTransactionType t) {
    switch (t) {
      case WalletTransactionType.tripEarning:
        return _t({
          'en': 'Trip Cost',
          'ar': 'تكلفة الرحلة',
          'ru': 'Стоимость поездки',
          'ka': 'მგზავრობის ღირებულება',
          'az': 'Səfərin dəyəri',
        });
      case WalletTransactionType.payoutRequest:
        return _t({
          'en': 'Payout Request',
          'ru': 'Запрос выплаты',
          'ka': 'გადახდის მოთხოვნა',
          'az': 'Ödəniş tələbi',
        });
      case WalletTransactionType.payoutApproved:
        return _t({
          'en': 'Payout Approved',
          'ru': 'Выплата одобрена',
          'ka': 'გადახდა დამტკიცებულია',
          'az': 'Ödəniş təsdiqləndi',
        });
      case WalletTransactionType.payoutPaid:
        return _t({
          'en': 'Payout Paid',
          'ru': 'Выплата произведена',
          'ka': 'გადახდა განხორციელდა',
          'az': 'Ödəniş edildi',
        });
      case WalletTransactionType.payoutRejected:
        return _t({
          'en': 'Payout Rejected',
          'ru': 'Выплата отклонена',
          'ka': 'გადახდა უარყოფილია',
          'az': 'Ödəniş rədd edildi',
        });
    }
  }

  String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return _t({
          'en': 'Pending',
          'ru': 'В ожидании',
          'ka': 'მოლოდინში',
          'az': 'Gözləyir',
        });
      case 'approved':
        return _t({
          'en': 'Approved',
          'ru': 'Одобрено',
          'ka': 'დამტკიცებული',
          'az': 'Təsdiqləndi',
        });
      case 'paid':
        return _t({
          'en': 'Paid',
          'ru': 'Выплачено',
          'ka': 'გადახდილი',
          'az': 'Ödənildi',
        });
      case 'rejected':
        return _t({
          'en': 'Rejected',
          'ru': 'Отклонено',
          'ka': 'უარყოფილი',
          'az': 'Rədd edildi',
        });
      default:
        return _t({
          'en': 'Completed',
          'ru': 'Завершено',
          'ka': 'დასრულებული',
          'az': 'Tamamlandı',
        });
    }
  }

  /// Short month name (1..12) for transaction dates.
  String shortMonth(int month) {
    const en = [
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
    ];
    const az = [
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
    ];
    return locale == 'az' ? az[month - 1] : en[month - 1];
  }
}
