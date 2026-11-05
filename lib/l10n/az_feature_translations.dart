/// Azerbaijani (Latin, az-AZ) overlay for [ChatStrings], [ChatInboxStrings]
/// and [WalletStrings]. Keyed by the exact English source text. Only consulted
/// when the locale is `az` and the string has no inline `'az'` entry.
class AzFeatureTranslations {
  AzFeatureTranslations._();

  static String? lookup(String english) => _map[english];

  static const Map<String, String> _map = {
    // ─── Chat ──────────────────────────────────────────────────────────────
    'Current Trip': 'Cari səfər',
    'Today': 'Bu gün',
    'Driver': 'Sürücü',
    'Customer': 'Müştəri',
    'Online': 'Onlayn',
    'Offline': 'Oflayn',
    'Type a message…': 'Mesaj yazın…',
    'View Original': 'Orijinala bax',
    'Translate Messages To': 'Mesajları bu dilə tərcümə et',
    'View Translated': 'Tərcüməyə bax',
    'Translation unavailable': 'Tərcümə əlçatan deyil',
    'Original': 'Orijinal',
    'Driver Changed': 'Sürücü dəyişdirildi',
    'Demo preview — sample messages. Voice messages are real but saved on this device only.':
        'Demo önizləmə — nümunə mesajlar. Səs mesajları həqiqidir, lakin yalnız bu cihazda saxlanılır.',
    'Recording…': 'Yazılır…',
    'Cancel': 'Ləğv et',
    'Slide to cancel': 'Ləğv etmək üçün sürüşdürün',
    'Release to cancel': 'Ləğv etmək üçün buraxın',
    'Swipe up to lock': 'Kilidləmək üçün yuxarı sürüşdürün',
    'Recording locked': 'Yazı kilidləndi',
    'Delete recording': 'Yazını sil',
    'Send recording': 'Yazını göndər',
    'Microphone access was denied. Allow it to record voice messages.':
        'Mikrofona giriş rədd edildi. Səs mesajı yazmaq üçün icazə verin.',
    'Settings': 'Parametrlər',
    'Could not record audio. Please try again.':
        'Səsi yazmaq mümkün olmadı. Yenidən cəhd edin.',
    'Recording too short. Hold on a little longer.':
        'Yazı çox qısadır. Bir az daha basılı saxlayın.',
    'Recording cancelled.': 'Yazı ləğv edildi.',
    'Maximum 1:00 reached. Tap send to share or delete to discard.':
        'Maksimum 1:00-a çatıldı. Paylaşmaq üçün göndər, ləğv etmək üçün sil düyməsinə toxunun.',
    'Recording ready': 'Yazı hazırdır',
    'Voice message could not be sent. Your recording is kept — tap send to retry.':
        'Səs mesajı göndərilə bilmədi. Yazınız saxlanılıb — yenidən cəhd üçün göndər düyməsinə toxunun.',
    'Transcribing…': 'Mətnə çevrilir…',
    'Translating…': 'Tərcümə olunur…',
    'View Original Text': 'Orijinal mətnə bax',
    'View Translated Text': 'Tərcümə olunmuş mətnə bax',
    'Transcription unavailable': 'Mətnə çevirmə əlçatan deyil',
    'Spoken language could not be identified':
        'Danışıq dili müəyyən edilə bilmədi',
    'Message translation is temporarily unavailable':
        'Mesaj tərcüməsi müvəqqəti əlçatan deyil',
    'Voice transcription is temporarily unavailable':
        'Səsin mətnə çevrilməsi müvəqqəti əlçatan deyil',
    'Voice translation is temporarily unavailable':
        'Səs tərcüməsi müvəqqəti əlçatan deyil',
    'Retry': 'Yenidən cəhd et',
    'This voice message could not be played.':
        'Bu səs mesajını oxutmaq mümkün olmadı.',
    'Demo voice message — no audio file attached.':
        'Demo səs mesajı — audio fayl əlavə olunmayıb.',
    'Voice messages are saved on this device only (demo).':
        'Səs mesajları yalnız bu cihazda saxlanılır (demo).',
    'Voice recording is not supported here. Use the Android or iOS app.':
        'Səs yazısı burada dəstəklənmir. Android və ya iOS tətbiqindən istifadə edin.',
    'Voice playback is not connected yet.': 'Səsin oxudulması hələ qoşulmayıb.',
    'Send attachment': 'Əlavə göndər',
    'Photo': 'Foto',
    'Video': 'Video',
    'Document': 'Sənəd',
    'This file is larger than 10 MB.': 'Bu fayl 10 MB-dan böyükdür.',
    'This file type is not supported.': 'Bu fayl növü dəstəklənmir.',
    'The selected file could not be read.':
        'Seçilmiş faylı oxumaq mümkün olmadı.',
    'File sending is not enabled on the server yet. Your file was not sent.':
        'Fayl göndərilməsi serverdə hələ aktiv deyil. Faylınız göndərilmədi.',
    'The file could not be sent. Please try again.':
        'Faylı göndərmək mümkün olmadı. Yenidən cəhd edin.',
    'Sending file…': 'Fayl göndərilir…',
    'Attachment': 'Əlavə',
    'The file could not be opened.': 'Faylı açmaq mümkün olmadı.',
    'No phone number available.': 'Telefon nömrəsi əlçatan deyil.',
    'Chat details': 'Çat təfərrüatları',
    'One continuous conversation per booking. Messages are kept when the driver changes. Live delivery and read receipts are active on the test backend. Translation is added server-side.':
        'Hər rezervasiya üçün bir fasiləsiz söhbət. Sürücü dəyişdikdə mesajlar saxlanılır. Canlı çatdırılma və oxunma bildirişləri test serverində aktivdir. Tərcümə server tərəfindən əlavə olunur.',
    'Close': 'Bağla',
    'Search emoji': 'Emoji axtar',
    'No emoji found': 'Emoji tapılmadı',
    'Recent': 'Son istifadə olunanlar',
    'Smileys': 'Smaylıklar',
    'People': 'İnsanlar',
    'Nature': 'Təbiət',
    'Food': 'Yemək',
    'Travel': 'Səyahət',
    'Symbols': 'Simvollar',
    'Could not load': 'Yükləmək mümkün olmadı',
    'Open / Download': 'Aç / Yüklə',
    'Zoom in': 'Böyüt',
    'Zoom out': 'Kiçilt',
    'Play video': 'Videonu oxut',
    'Page': 'Səhifə',
    'Word document': 'Word sənədi',
    'Excel spreadsheet': 'Excel cədvəli',
    'Text file': 'Mətn faylı',
    'File': 'Fayl',
    'Sent': 'Göndərildi',
    'Sending…': 'Göndərilir…',
    'Failed': 'Alınmadı',
    'Delivered': 'Çatdırıldı',
    'Read': 'Oxundu',
    'TEST environment — booking RQ.TEST14596 on the Supabase test database. Not live Odoo data.':
        'TEST mühiti — RQ.TEST14596 rezervasiyası Supabase test bazasındadır. Canlı Odoo məlumatı deyil.',
    'Live chat is blocked': 'Canlı çat bloklanıb',
    'Message was not sent.': 'Mesaj göndərilmədi.',
    'Sending is disabled: no authenticated sender identity is available for this booking.':
        'Göndərmə deaktivdir: bu rezervasiya üçün təsdiqlənmiş göndərən kimliyi yoxdur.',
    'Connected to Supabase test chat (messages are stored; read receipts update when the recipient opens the chat).':
        'Supabase test çatına qoşuldu (mesajlar saxlanılır; alıcı çatı açdıqda oxunma bildirişi yenilənir).',
    'Yesterday': 'Dünən',

    // ─── Chat inbox ────────────────────────────────────────────────────────
    'Chat': 'Çat',
    'Messages': 'Mesajlar',
    'Your trip conversations': 'Səfər söhbətləriniz',
    'Search booking reference or customer':
        'Rezervasiya nömrəsi və ya müştəri üzrə axtar',
    'All': 'Hamısı',
    'Active': 'Aktiv',
    'Completed': 'Tamamlanmış',
    'Voice message': 'Səs mesajı',
    'No messages yet': 'Hələ ki, mesaj yoxdur',
    'No conversations found': 'Söhbət tapılmadı',
    'Conversations for your bookings will appear here.':
        'Rezervasiyalarınız üzrə söhbətlər burada görünəcək.',
    'Chat access is blocked by the server':
        'Çata giriş server tərəfindən bloklanıb',
    'This trip is completed. The conversation is read-only.':
        'Bu səfər tamamlanıb. Söhbət yalnız oxumaq üçündür.',
    'Support': 'Dəstək',
    'Call, WhatsApp, email and FAQ':
        'Zəng, WhatsApp, e-poçt və tez-tez verilən suallar',
    'Messages are read-only': 'Mesajlar yalnız oxumaq üçündür',

    // ─── Wallet ────────────────────────────────────────────────────────────
    'Wallet': 'Pul kisəsi',
    'Available Balance': 'Əlçatan balans',
    'Total Earnings': 'Ümumi qazanc',
    'Pending Payouts': 'Gözləyən ödənişlər',
    'Request Payout': 'Ödəniş tələb et',
    'Transactions': 'Əməliyyatlar',
    'No transactions yet': 'Hələ ki, əməliyyat yoxdur',
    'Wallet not available yet': 'Pul kisəsi hələ əlçatan deyil',
    'Your wallet is being connected to the TourOps system. Balances and payouts will appear here once it is ready.':
        'Pul kisəniz TourOps sisteminə qoşulur. Hazır olduqda balans və ödənişlər burada görünəcək.',
    'Could not load your wallet.': 'Pul kisənizi yükləmək mümkün olmadı.',
    'Requested Amount': 'Tələb olunan məbləğ',
    'Remaining Available': 'Qalan əlçatan məbləğ',
    'Booking': 'Rezervasiya',
    'Select booking': 'Rezervasiyanı seçin',
    'Bank Details': 'Bank rekvizitləri',
    'Beneficiary Name': 'Faydalanan şəxsin adı',
    'Bank Name': 'Bankın adı',
    'Select bank': 'Bankı seçin',
    'IBAN / Account Number': 'IBAN / Hesab nömrəsi',
    'Tax Identification Number': 'Vergi ödəyicisinin eyniləşdirmə nömrəsi',
    'Confirm Request': 'Tələbi təsdiqlə',
    'Your bank details are saved securely for future requests and can be updated at any time.':
        'Bank rekvizitləriniz gələcək tələblər üçün təhlükəsiz saxlanılır və istənilən vaxt yenilənə bilər.',
    'This field is required': 'Bu sahə məcburidir',
    'Enter a valid amount': 'Düzgün məbləğ daxil edin',
    'Amount exceeds your available balance': 'Məbləğ əlçatan balansınızı aşır',
    'No available balance to withdraw': 'Çıxarmaq üçün əlçatan balans yoxdur',
    'Payout request submitted. Status: Pending.':
        'Ödəniş tələbi göndərildi. Status: Gözləyir.',
    'Could not submit your payout request. Please try again.':
        'Ödəniş tələbini göndərmək mümkün olmadı. Yenidən cəhd edin.',
    'Payout Request': 'Ödəniş tələbi',
    'Payout Approved': 'Ödəniş təsdiqləndi',
    'Payout Paid': 'Ödəniş edildi',
    'Payout Rejected': 'Ödəniş rədd edildi',
    'Pending': 'Gözləyir',
    'Approved': 'Təsdiqləndi',
    'Paid': 'Ödənildi',
    'Rejected': 'Rədd edildi',
  };
}
