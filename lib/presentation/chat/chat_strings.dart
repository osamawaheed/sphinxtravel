/// Smart Chat UI strings (English, Arabic, Russian, Georgian).
class ChatStrings {
  final String locale;
  const ChatStrings(this.locale);

  String _t(Map<String, String> m) => m[locale] ?? m['en'] ?? '';

  String get currentTrip => _t({
    'en': 'Current Trip',
    'ar': 'الرحلة الحالية',
    'ru': 'Текущая поездка',
    'ka': 'მიმდინარე მოგზაურობა',
  });
  String get today =>
      _t({'en': 'Today', 'ar': 'اليوم', 'ru': 'Сегодня', 'ka': 'დღეს'});
  String get roleDriver =>
      _t({'en': 'Driver', 'ar': 'سائق', 'ru': 'Водитель', 'ka': 'მძღოლი'});
  String get roleCustomer =>
      _t({'en': 'Customer', 'ar': 'عميل', 'ru': 'Клиент', 'ka': 'კლიენტი'});
  String get online =>
      _t({'en': 'Online', 'ar': 'متصل', 'ru': 'В сети', 'ka': 'ონლაინ'});
  String get offline => _t({
    'en': 'Offline',
    'ar': 'غير متصل',
    'ru': 'Не в сети',
    'ka': 'ოფლაინ',
  });
  String get typeMessage => _t({
    'en': 'Type a message…',
    'ar': 'اكتب رسالة…',
    'ru': 'Введите сообщение…',
    'ka': 'დაწერეთ შეტყობინება…',
  });
  String get quickMessages => _t({
    'en': 'Quick Messages',
    'ar': 'رسائل سريعة',
    'ru': 'Быстрые сообщения',
    'ka': 'სწრაფი შეტყობინებები',
  });
  String get viewOriginal => _t({
    'en': 'View Original',
    'ar': 'عرض الأصل',
    'ru': 'Показать оригинал',
    'ka': 'ორიგინალის ნახვა',
  });
  String get translateMessagesTo => _t({
    'en': 'Translate Messages To',
    'ar': 'ترجمة الرسائل إلى',
    'ru': 'Переводить сообщения на',
    'ka': 'შეტყობინებების თარგმნა',
  });

  String get viewTranslated => _t({
    'en': 'View Translated',
    'ar': 'عرض الترجمة',
    'ru': 'Показать перевод',
    'ka': 'თარგმანის ნახვა',
  });
  String get translationUnavailable => _t({
    'en': 'Translation unavailable',
    'ar': 'الترجمة غير متاحة',
    'ru': 'Перевод недоступен',
    'ka': 'თარგმანი მიუწვდომელია',
  });
  String get original => _t({
    'en': 'Original',
    'ar': 'الأصل',
    'ru': 'Оригинал',
    'ka': 'ორიგინალი',
  });
  String get driverChanged => _t({
    'en': 'Driver Changed',
    'ar': 'تم تغيير السائق',
    'ru': 'Водитель изменён',
    'ka': 'მძღოლი შეიცვალა',
  });
  String isNowAssigned(String name) => _t({
    'en': '$name is now assigned to this trip',
    'ar': 'تم تعيين $name لهذه الرحلة',
    'ru': '$name الآن назначен на эту поездку',
    'ka': '$name ახლა დანიშნულია ამ მოგზაურობაზე',
  });
  String get demoBanner => _t({
    'en':
        'Demo preview — sample messages. Voice messages are real but saved on this device only.',
    'ar':
        'معاينة تجريبية — رسائل نموذجية. الرسائل الصوتية حقيقية لكنها تُحفظ على هذا الجهاز فقط.',
    'ru':
        'Демо-просмотр — примеры сообщений. Голосовые сообщения настоящие, но хранятся только на этом устройстве.',
    'ka':
        'დემო გადახედვა — ნიმუშის შეტყობინებები. ხმოვანი შეტყობინებები რეალურია, მაგრამ ინახება მხოლოდ ამ მოწყობილობაზე.',
  });
  String get recording => _t({
    'en': 'Recording…',
    'ar': 'جارٍ التسجيل…',
    'ru': 'Запись…',
    'ka': 'ჩაწერა…',
  });
  String get cancel =>
      _t({'en': 'Cancel', 'ar': 'إلغاء', 'ru': 'Отмена', 'ka': 'გაუქმება'});
  String get slideToCancel => _t({
    'en': 'Slide to cancel',
    'ar': 'اسحب للإلغاء',
    'ru': 'Сдвиньте для отмены',
    'ka': 'გასაუქმებლად გადაასრიალეთ',
  });
  String get releaseToCancel => _t({
    'en': 'Release to cancel',
    'ar': 'أفلت للإلغاء',
    'ru': 'Отпустите для отмены',
    'ka': 'გაუშვით გასაუქმებლად',
  });
  String get swipeUpToLock => _t({
    'en': 'Swipe up to lock',
    'ar': 'اسحب للأعلى للقفل',
    'ru': 'Проведите вверх для фиксации',
    'ka': 'ასაკეტად გადაასრიალეთ ზემოთ',
  });
  String get recordingLocked => _t({
    'en': 'Recording locked',
    'ar': 'التسجيل مقفل',
    'ru': 'Запись зафиксирована',
    'ka': 'ჩაწერა დაბლოკილია',
  });
  String get deleteRecording => _t({
    'en': 'Delete recording',
    'ar': 'حذف التسجيل',
    'ru': 'Удалить запись',
    'ka': 'ჩანაწერის წაშლა',
  });
  String get sendRecording => _t({
    'en': 'Send recording',
    'ar': 'إرسال التسجيل',
    'ru': 'Отправить запись',
    'ka': 'ჩანაწერის გაგზავნა',
  });
  String get micPermissionDenied => _t({
    'en': 'Microphone access was denied. Allow it to record voice messages.',
    'ar': 'تم رفض الوصول إلى الميكروفون. اسمح به لتسجيل الرسائل الصوتية.',
    'ru':
        'Доступ к микрофону запрещён. Разрешите его для записи голосовых сообщений.',
    'ka':
        'მიკროფონზე წვდომა უარყოფილია. დაუშვით ხმოვანი შეტყობინებების ჩასაწერად.',
  });
  String get openSettings => _t({
    'en': 'Settings',
    'ar': 'الإعدادات',
    'ru': 'Настройки',
    'ka': 'პარამეტრები',
  });
  String get recordingFailed => _t({
    'en': 'Could not record audio. Please try again.',
    'ar': 'تعذر تسجيل الصوت. حاول مرة أخرى.',
    'ru': 'Не удалось записать аудио. Попробуйте ещё раз.',
    'ka': 'აუდიოს ჩაწერა ვერ მოხერხდა. სცადეთ თავიდან.',
  });
  String get recordingTooShort => _t({
    'en': 'Recording too short. Hold on a little longer.',
    'ar': 'التسجيل قصير جدًا. استمر لفترة أطول قليلًا.',
    'ru': 'Запись слишком короткая. Говорите чуть дольше.',
    'ka': 'ჩანაწერი ძალიან მოკლეა. ცოტა ხანს გააგრძელეთ.',
  });
  String get recordingCancelled => _t({
    'en': 'Recording cancelled.',
    'ar': 'تم إلغاء التسجيل.',
    'ru': 'Запись отменена.',
    'ka': 'ჩაწერა გაუქმდა.',
  });
  String get recordingLimitReached => _t({
    'en': 'Maximum 1:00 reached. Tap send to share or delete to discard.',
    'ar': 'تم بلوغ الحد الأقصى 1:00. اضغط إرسال للمشاركة أو حذف للتجاهل.',
    'ru': 'Достигнут максимум 1:00. Нажмите «Отправить» или удалите запись.',
    'ka':
        'მიღწეულია მაქსიმუმი 1:00. გასაგზავნად დააჭირეთ გაგზავნას ან წაშალეთ.',
  });
  String get recordingReady => _t({
    'en': 'Recording ready',
    'ar': 'التسجيل جاهز',
    'ru': 'Запись готова',
    'ka': 'ჩანაწერი მზადაა',
  });
  String get voiceSendFailed => _t({
    'en':
        'Voice message could not be sent. Your recording is kept — tap send to retry.',
    'ar':
        'تعذر إرسال الرسالة الصوتية. تم الاحتفاظ بتسجيلك — اضغط إرسال لإعادة المحاولة.',
    'ru':
        'Не удалось отправить голосовое сообщение. Запись сохранена — нажмите «Отправить», чтобы повторить.',
    'ka':
        'ხმოვანი შეტყობინება ვერ გაიგზავნა. ჩანაწერი შენახულია — ხელახლა გასაგზავნად დააჭირეთ გაგზავნას.',
  });
  String get transcribing => _t({
    'en': 'Transcribing…',
    'ar': 'جارٍ التفريغ النصي…',
    'ru': 'Расшифровка…',
    'ka': 'ტრანსკრიფცია…',
  });
  String get translatingVoice => _t({
    'en': 'Translating…',
    'ar': 'جارٍ الترجمة…',
    'ru': 'Перевод…',
    'ka': 'თარგმნა…',
  });
  String get viewOriginalText => _t({
    'en': 'View Original Text',
    'ar': 'عرض النص الأصلي',
    'ru': 'Показать исходный текст',
    'ka': 'ორიგინალი ტექსტის ნახვა',
  });
  String get viewTranslatedText => _t({
    'en': 'View Translated Text',
    'ar': 'عرض النص المترجم',
    'ru': 'Показать перевод',
    'ka': 'თარგმნილი ტექსტის ნახვა',
  });
  String get transcriptionFailed => _t({
    'en': 'Transcription unavailable',
    'ar': 'التفريغ النصي غير متاح',
    'ru': 'Расшифровка недоступна',
    'ka': 'ტრანსკრიფცია მიუწვდომელია',
  });
  String get languageUncertain => _t({
    'en': 'Spoken language could not be identified',
    'ar': 'تعذر تحديد اللغة المنطوقة',
    'ru': 'Не удалось определить язык речи',
    'ka': 'წარმოთქმული ენის ამოცნობა ვერ მოხერხდა',
  });
  String get textTranslationDisabled => _t({
    'en': 'Message translation is temporarily unavailable',
    'ar': 'ترجمة الرسائل غير متاحة مؤقتًا',
    'ru': 'Перевод сообщений временно недоступен',
    'ka': 'შეტყობინებების თარგმნა დროებით მიუწვდომელია',
  });
  String get voiceTranscriptionDisabled => _t({
    'en': 'Voice transcription is temporarily unavailable',
    'ar': 'تفريغ الرسائل الصوتية غير متاح مؤقتًا',
    'ru': 'Расшифровка голосовых сообщений временно недоступна',
    'ka': 'ხმოვანი შეტყობინებების ტრანსკრიფცია დროებით მიუწვდომელია',
  });
  String get voiceTranslationDisabled => _t({
    'en': 'Voice translation is temporarily unavailable',
    'ar': 'ترجمة الرسائل الصوتية غير متاحة مؤقتًا',
    'ru': 'Перевод голосовых сообщений временно недоступен',
    'ka': 'ხმოვანი შეტყობინებების თარგმნა დროებით მიუწვდომელია',
  });
  String get retry => _t({
    'en': 'Retry',
    'ar': 'إعادة المحاولة',
    'ru': 'Повторить',
    'ka': 'ხელახლა',
  });
  String get listenTranslated => _t({
    'en': 'Listen Translated',
    'ar': 'استمع إلى الترجمة',
    'ru': 'Слушать перевод',
    'ka': 'თარგმნილის მოსმენა',
    'az': 'Tərcümə olunanı dinlə',
  });
  String get generatingTranslatedAudio => _t({
    'en': 'Preparing translated audio…',
    'ar': 'جارٍ تجهيز الصوت المترجم…',
    'ru': 'Подготовка озвучки перевода…',
    'ka': 'მზადდება თარგმნილი აუდიო…',
    'az': 'Tərcümə olunmuş səs hazırlanır…',
  });
  String get translatedAudioFailed => _t({
    'en': 'Translated audio could not be prepared',
    'ar': 'تعذر تجهيز الصوت المترجم',
    'ru': 'Не удалось подготовить озвучку перевода',
    'ka': 'თარგმნილი აუდიოს მომზადება ვერ მოხერხდა',
    'az': 'Tərcümə olunmuş səs hazırlana bilmədi',
  });
  String get translatedAudioDisabled => _t({
    'en': 'Translated audio is temporarily unavailable',
    'ar': 'الصوت المترجم غير متاح مؤقتًا',
    'ru': 'Озвучка перевода временно недоступна',
    'ka': 'თარგმნილი აუდიო დროებით მიუწვდომელია',
    'az': 'Tərcümə olunmuş səs müvəqqəti əlçatmazdır',
  });
  String get translatedAudioUnavailable => _t({
    'en': 'Translated audio is not available for this message',
    'ar': 'الصوت المترجم غير متاح لهذه الرسالة',
    'ru': 'Озвучка перевода недоступна для этого сообщения',
    'ka': 'თარგმნილი აუდიო ამ შეტყობინებისთვის მიუწვდომელია',
    'az': 'Bu mesaj üçün tərcümə olunmuş səs əlçatmazdır',
  });
  String get playbackFailed => _t({
    'en': 'This voice message could not be played.',
    'ar': 'تعذر تشغيل هذه الرسالة الصوتية.',
    'ru': 'Не удалось воспроизвести это голосовое сообщение.',
    'ka': 'ამ ხმოვანი შეტყობინების დაკვრა ვერ მოხერხდა.',
  });
  String get voiceDemoNoAudio => _t({
    'en': 'Demo voice message — no audio file attached.',
    'ar': 'رسالة صوتية تجريبية — لا يوجد ملف صوتي.',
    'ru': 'Демо голосовое сообщение — аудиофайла нет.',
    'ka': 'დემო ხმოვანი შეტყობინება — აუდიოფაილი არ არის.',
  });
  String get voiceLocalOnly => _t({
    'en': 'Voice messages are saved on this device only (demo).',
    'ar': 'تُحفظ الرسائل الصوتية على هذا الجهاز فقط (تجريبي).',
    'ru': 'Голосовые сообщения сохраняются только на этом устройстве (демо).',
    'ka': 'ხმოვანი შეტყობინებები ინახება მხოლოდ ამ მოწყობილობაზე (დემო).',
  });
  String get voiceUnavailable => _t({
    'en': 'Voice recording is not supported here. Use the Android or iOS app.',
    'ar': 'تسجيل الصوت غير مدعوم هنا. استخدم تطبيق أندرويد أو iOS.',
    'ru':
        'Запись голоса здесь не поддерживается. Используйте приложение для Android или iOS.',
    'ka':
        'ხმოვანი ჩაწერა აქ მხარდაჭერილი არ არის. გამოიყენეთ Android ან iOS აპი.',
  });
  String get playbackUnavailable => _t({
    'en': 'Voice playback is not connected yet.',
    'ar': 'تشغيل الصوت غير متصل بعد.',
    'ru': 'Воспроизведение голоса пока не подключено.',
    'ka': 'ხმოვანი დაკვრა ჯერ არ არის დაკავშირებული.',
  });
  String get attachTitle => _t({
    'en': 'Send attachment',
    'ar': 'إرسال مرفق',
    'ru': 'Отправить вложение',
    'ka': 'დანართის გაგზავნა',
  });
  String get attachImage =>
      _t({'en': 'Photo', 'ar': 'صورة', 'ru': 'Фото', 'ka': 'ფოტო'});
  String get attachVideo =>
      _t({'en': 'Video', 'ar': 'فيديو', 'ru': 'Видео', 'ka': 'ვიდეო'});
  String get attachDocument => _t({
    'en': 'Document',
    'ar': 'مستند',
    'ru': 'Документ',
    'ka': 'დოკუმენტი',
  });
  String get attachTooLarge => _t({
    'en': 'This file is larger than 10 MB.',
    'ar': 'حجم الملف أكبر من 10 ميغابايت.',
    'ru': 'Файл больше 10 МБ.',
    'ka': 'ფაილი 10 მბ-ზე დიდია.',
  });
  String get attachUnsupported => _t({
    'en': 'This file type is not supported.',
    'ar': 'نوع الملف غير مدعوم.',
    'ru': 'Этот тип файла не поддерживается.',
    'ka': 'ფაილის ტიპი არ არის მხარდაჭერილი.',
  });
  String get attachReadFailed => _t({
    'en': 'The selected file could not be read.',
    'ar': 'تعذرت قراءة الملف المحدد.',
    'ru': 'Не удалось прочитать выбранный файл.',
    'ka': 'არჩეული ფაილის წაკითხვა ვერ მოხერხდა.',
  });
  String get attachNotDeployed => _t({
    'en':
        'File sending is not enabled on the server yet. Your file was not sent.',
    'ar': 'إرسال الملفات غير مفعّل على الخادم بعد. لم يتم إرسال ملفك.',
    'ru': 'Отправка файлов на сервере пока не включена. Файл не отправлен.',
    'ka': 'ფაილების გაგზავნა სერვერზე ჯერ არ არის ჩართული. ფაილი არ გაიგზავნა.',
  });
  String get attachSendFailed => _t({
    'en': 'The file could not be sent. Please try again.',
    'ar': 'تعذر إرسال الملف. حاول مرة أخرى.',
    'ru': 'Не удалось отправить файл. Попробуйте ещё раз.',
    'ka': 'ფაილის გაგზავნა ვერ მოხერხდა. სცადეთ ხელახლა.',
  });
  String get attachSending => _t({
    'en': 'Sending file…',
    'ar': 'جارٍ إرسال الملف…',
    'ru': 'Отправка файла…',
    'ka': 'ფაილის გაგზავნა…',
  });
  String get attachment =>
      _t({'en': 'Attachment', 'ar': 'مرفق', 'ru': 'Вложение', 'ka': 'დანართი'});
  String get attachOpenFailed => _t({
    'en': 'The file could not be opened.',
    'ar': 'تعذر فتح الملف.',
    'ru': 'Не удалось открыть файл.',
    'ka': 'ფაილის გახსნა ვერ მოხერხდა.',
  });
  String get callUnavailable => _t({
    'en': 'No phone number available.',
    'ar': 'لا يوجد رقم هاتف متاح.',
    'ru': 'Номер телефона недоступен.',
    'ka': 'ტელეფონის ნომერი მიუწვდომელია.',
  });
  String get chatDetails => _t({
    'en': 'Chat details',
    'ar': 'تفاصيل الدردشة',
    'ru': 'Детали чата',
    'ka': 'ჩატის დეტალები',
  });
  String get chatDetailsBody => _t({
    'en':
        'One continuous conversation per booking. Messages are kept when the driver changes. '
        'Live delivery and read receipts are active on the test backend. Translation is added server-side.',
    'ar':
        'محادثة واحدة مستمرة لكل حجز. تُحفظ الرسائل عند تغيير السائق. '
        'التسليم المباشر وإشعارات القراءة مفعّلة على الخادم التجريبي. تُضاف الترجمة من الخادم.',
    'ru':
        'Один непрерывный диалог на бронирование. Сообщения сохраняются при смене водителя. '
        'Доставка и отметки о прочтении работают на тестовом бэкенде. Перевод добавляется на сервере.',
    'ka':
        'ერთი უწყვეტი საუბარი თითო ჯავშანზე. შეტყობინებები ინახება მძღოლის შეცვლისას. '
        'მიწოდება და წაკითხვის ნიშნები აქტიურია სატესტო ბექენდზე. თარგმანი ემატება სერვერზე.',
  });
  String get close =>
      _t({'en': 'Close', 'ar': 'إغلاق', 'ru': 'Закрыть', 'ka': 'დახურვა'});
  String get emojiSearchHint => _t({
    'en': 'Search emoji',
    'ar': 'ابحث عن إيموجي',
    'ru': 'Поиск эмодзи',
    'ka': 'ემოჯის ძებნა',
  });
  String get emojiNoResults => _t({
    'en': 'No emoji found',
    'ar': 'لا توجد نتائج',
    'ru': 'Ничего не найдено',
    'ka': 'ვერ მოიძებნა',
  });
  String get emojiRecent =>
      _t({'en': 'Recent', 'ar': 'الأخيرة', 'ru': 'Недавние', 'ka': 'ბოლო'});
  String get emojiSmileys =>
      _t({'en': 'Smileys', 'ar': 'وجوه', 'ru': 'Смайлики', 'ka': 'სმაილები'});
  String get emojiGestures =>
      _t({'en': 'People', 'ar': 'أشخاص', 'ru': 'Люди', 'ka': 'ხალხი'});
  String get emojiNature =>
      _t({'en': 'Nature', 'ar': 'طبيعة', 'ru': 'Природа', 'ka': 'ბუნება'});
  String get emojiFood =>
      _t({'en': 'Food', 'ar': 'طعام', 'ru': 'Еда', 'ka': 'საკვები'});
  String get emojiTravel => _t({
    'en': 'Travel',
    'ar': 'سفر',
    'ru': 'Путешествия',
    'ka': 'მოგზაურობა',
  });
  String get emojiSymbols =>
      _t({'en': 'Symbols', 'ar': 'رموز', 'ru': 'Символы', 'ka': 'სიმბოლოები'});
  String get mediaLoadFailed => _t({
    'en': 'Could not load',
    'ar': 'تعذر التحميل',
    'ru': 'Не удалось загрузить',
    'ka': 'ჩატვირთვა ვერ მოხერხდა',
  });

  String get openDownload => _t({
    'en': 'Open / Download',
    'ar': 'فتح / تنزيل',
    'ru': 'Открыть / Скачать',
    'ka': 'გახსნა / ჩამოტვირთვა',
  });
  String get zoomIn =>
      _t({'en': 'Zoom in', 'ar': 'تكبير', 'ru': 'Увеличить', 'ka': 'გადიდება'});
  String get zoomOut => _t({
    'en': 'Zoom out',
    'ar': 'تصغير',
    'ru': 'Уменьшить',
    'ka': 'დაპატარავება',
  });
  String get playVideo => _t({
    'en': 'Play video',
    'ar': 'تشغيل الفيديو',
    'ru': 'Воспроизвести видео',
    'ka': 'ვიდეოს ჩართვა',
  });
  String get pageWord =>
      _t({'en': 'Page', 'ar': 'صفحة', 'ru': 'Стр.', 'ka': 'გვ.'});
  String pagesCount(int n) => _t({
    'en': '$n pages',
    'ar': '$n صفحات',
    'ru': 'Страниц: $n',
    'ka': '$n გვერდი',
  });
  String get docTypeWord => _t({
    'en': 'Word document',
    'ar': 'مستند Word',
    'ru': 'Документ Word',
    'ka': 'Word დოკუმენტი',
  });
  String get docTypeExcel => _t({
    'en': 'Excel spreadsheet',
    'ar': 'جدول Excel',
    'ru': 'Таблица Excel',
    'ka': 'Excel ცხრილი',
  });
  String get docTypeText => _t({
    'en': 'Text file',
    'ar': 'ملف نصي',
    'ru': 'Текстовый файл',
    'ka': 'ტექსტური ფაილი',
  });
  String get docTypeOther =>
      _t({'en': 'File', 'ar': 'ملف', 'ru': 'Файл', 'ka': 'ფაილი'});
  String get sent => _t({
    'en': 'Sent',
    'ar': 'أُرسلت',
    'ru': 'Отправлено',
    'ka': 'გაგზავნილია',
  });
  String get sending => _t({
    'en': 'Sending…',
    'ar': 'جارٍ الإرسال…',
    'ru': 'Отправка…',
    'ka': 'იგზავნება…',
  });
  String get failed =>
      _t({'en': 'Failed', 'ar': 'فشل', 'ru': 'Ошибка', 'ka': 'ვერ გაიგზავნა'});
  String get delivered => _t({
    'en': 'Delivered',
    'ar': 'تم التسليم',
    'ru': 'Доставлено',
    'ka': 'მიწოდებულია',
  });
  String get read =>
      _t({'en': 'Read', 'ar': 'مقروءة', 'ru': 'Прочитано', 'ka': 'წაკითხულია'});

  String get testBanner => _t({
    'en':
        'TEST environment — booking RQ.TEST14596 on the Supabase test database. Not live Odoo data.',
    'ar':
        'بيئة اختبار — الحجز RQ.TEST14596 على قاعدة بيانات Supabase التجريبية. ليست بيانات Odoo الحية.',
    'ru':
        'ТЕСТОВАЯ среда — бронирование RQ.TEST14596 в тестовой базе Supabase. Не реальные данные Odoo.',
    'ka':
        'ტესტ გარემო — ჯავშანი RQ.TEST14596 Supabase სატესტო ბაზაში. არა რეალური Odoo მონაცემები.',
  });
  String get backendBlockedTitle => _t({
    'en': 'Live chat is blocked',
    'ar': 'الدردشة المباشرة محظورة',
    'ru': 'Живой чат заблокирован',
    'ka': 'ცოცხალი ჩატი დაბლოკილია',
  });
  String get sendFailed => _t({
    'en': 'Message was not sent.',
    'ar': 'لم يتم إرسال الرسالة.',
    'ru': 'Сообщение не отправлено.',
    'ka': 'შეტყობინება არ გაიგზავნა.',
  });
  String get noSenderIdentity => _t({
    'en':
        'Sending is disabled: no authenticated sender identity is available for this booking.',
    'ar': 'الإرسال معطل: لا توجد هوية مرسل موثقة لهذا الحجز.',
    'ru':
        'Отправка отключена: для этого бронирования нет подтверждённой личности отправителя.',
    'ka':
        'გაგზავნა გათიშულია: ამ ჯავშანზე ავთენტიფიცირებული გამგზავნი არ არის.',
  });
  String get liveConnected => _t({
    'en':
        'Connected to Supabase test chat (messages are stored; read receipts update when the recipient opens the chat).',
    'ar':
        'متصل بدردشة Supabase التجريبية (الرسائل محفوظة؛ تظهر علامة القراءة عند فتح المستلم للدردشة).',
    'ru':
        'Подключено к тестовому чату Supabase (сообщения сохраняются; отметки о прочтении появляются, когда получатель открывает чат).',
    'ka':
        'დაკავშირებულია Supabase სატესტო ჩატთან (შეტყობინებები ინახება; წაკითხვის ნიშნები ჩანს, როცა მიმღები ჩატს გახსნის).',
  });

  // ---- Delete message / conversation ----
  String get deleteLabel => _t({
    'en': 'Delete',
    'ar': 'حذف',
    'ru': 'Удалить',
    'ka': 'წაშლა',
    'az': 'Sil',
  });
  String get deleteForMe => _t({
    'en': 'Delete for me',
    'ar': 'حذف لدي',
    'ru': 'Удалить у меня',
    'ka': 'ჩემთვის წაშლა',
    'az': 'Mənim üçün sil',
  });
  String get deleteForEveryone => _t({
    'en': 'Delete for everyone',
    'ar': 'حذف للجميع',
    'ru': 'Удалить у всех',
    'ka': 'ყველასთვის წაშლა',
    'az': 'Hamı üçün sil',
  });
  String get deleteMessageTitle => _t({
    'en': 'Delete message?',
    'ar': 'حذف الرسالة؟',
    'ru': 'Удалить сообщение?',
    'ka': 'წაშალოთ შეტყობინება?',
    'az': 'Mesaj silinsin?',
  });
  String get deleteForMeBody => _t({
    'en':
        'This message will be removed from your chat only. '
        'The other person will still see it.',
    'ar': 'ستتم إزالة هذه الرسالة من دردشتك فقط. سيظل الطرف الآخر يراها.',
    'ru':
        'Сообщение будет удалено только из вашего чата. '
        'Собеседник его по-прежнему увидит.',
    'ka':
        'შეტყობინება წაიშლება მხოლოდ თქვენი ჩატიდან. '
        'მეორე მხარე მას კვლავ დაინახავს.',
    'az':
        'Bu mesaj yalnız sizin çatınızdan silinəcək. '
        'Qarşı tərəf onu görməyə davam edəcək.',
  });
  String get deleteForEveryoneBody => _t({
    'en':
        'This message will be deleted for everyone in this chat. '
        'This cannot be undone.',
    'ar': 'سيتم حذف هذه الرسالة للجميع في هذه الدردشة. لا يمكن التراجع عن ذلك.',
    'ru':
        'Сообщение будет удалено у всех участников чата. '
        'Это действие нельзя отменить.',
    'ka':
        'შეტყობინება წაიშლება ჩატის ყველა მონაწილისთვის. '
        'ამის გაუქმება შეუძლებელია.',
    'az':
        'Bu mesaj çatdakı hamı üçün silinəcək. '
        'Bunu geri qaytarmaq mümkün deyil.',
  });
  String get messageDeleted => _t({
    'en': 'This message was deleted',
    'ar': 'تم حذف هذه الرسالة',
    'ru': 'Это сообщение удалено',
    'ka': 'ეს შეტყობინება წაშლილია',
    'az': 'Bu mesaj silindi',
  });
  String get reply => _t({
    'en': 'Reply',
    'ar': 'رد',
    'ru': 'Ответить',
    'ka': 'პასუხი',
    'az': 'Cavab ver',
  });
  String get forward => _t({
    'en': 'Forward',
    'ar': 'إعادة توجيه',
    'ru': 'Переслать',
    'ka': 'გადაგზავნა',
    'az': 'Yönləndir',
  });
  String get copy => _t({
    'en': 'Copy',
    'ar': 'نسخ',
    'ru': 'Копировать',
    'ka': 'კოპირება',
    'az': 'Kopyala',
  });
  String get star => _t({
    'en': 'Star',
    'ar': 'تمييز بنجمة',
    'ru': 'В избранное',
    'ka': 'ვარსკვლავი',
    'az': 'Ulduzla',
  });
  String get deleteAction => _t({
    'en': 'Delete',
    'ar': 'حذف',
    'ru': 'Удалить',
    'ka': 'წაშლა',
    'az': 'Sil',
  });
  String get more => _t({
    'en': 'More',
    'ar': 'المزيد',
    'ru': 'Ещё',
    'ka': 'მეტი',
    'az': 'Daha çox',
  });
  String get copied => _t({
    'en': 'Copied',
    'ar': 'تم النسخ',
    'ru': 'Скопировано',
    'ka': 'დაკოპირდა',
    'az': 'Kopyalandı',
  });
  String get nothingToCopy => _t({
    'en': 'This message has no text to copy.',
    'ar': 'لا يوجد نص لنسخه في هذه الرسالة.',
    'ru': 'В этом сообщении нет текста для копирования.',
    'ka': 'ამ შეტყობინებას კოპირებადი ტექსტი არ აქვს.',
    'az': 'Bu mesajda kopyalanacaq mətn yoxdur.',
  });
  String get featureNotAvailable => _t({
    'en': 'Not available yet.',
    'ar': 'غير متاح بعد.',
    'ru': 'Пока недоступно.',
    'ka': 'ჯერ მიუწვდომელია.',
    'az': 'Hələ mövcud deyil.',
  });
  String get reactionFailed => _t({
    'en': 'Could not save the reaction. Please try again.',
    'ar': 'تعذر حفظ التفاعل. حاول مرة أخرى.',
    'ru': 'Не удалось сохранить реакцию. Попробуйте ещё раз.',
    'ka': 'რეაქციის შენახვა ვერ მოხერხდა. სცადეთ ხელახლა.',
    'az': 'Reaksiyanı saxlamaq mümkün olmadı. Yenidən cəhd edin.',
  });
  String get replyingTo => _t({
    'en': 'Replying to',
    'ar': 'الرد على',
    'ru': 'Ответ для',
    'ka': 'პასუხი:',
    'az': 'Cavab:',
  });
  String get you =>
      _t({'en': 'You', 'ar': 'أنت', 'ru': 'Вы', 'ka': 'თქვენ', 'az': 'Siz'});
  String get voiceMessageLabel => _t({
    'en': 'Voice message',
    'ar': 'رسالة صوتية',
    'ru': 'Голосовое сообщение',
    'ka': 'ხმოვანი შეტყობინება',
    'az': 'Səs mesajı',
  });
  String get attachmentLabel => _t({
    'en': 'Attachment',
    'ar': 'مرفق',
    'ru': 'Вложение',
    'ka': 'დანართი',
    'az': 'Əlavə',
  });
  String get messageDeletedQuote => _t({
    'en': 'Message deleted',
    'ar': 'تم حذف الرسالة',
    'ru': 'Сообщение удалено',
    'ka': 'შეტყობინება წაიშალა',
    'az': 'Mesaj silindi',
  });
  String get originalNotFound => _t({
    'en': 'Original message not found.',
    'ar': 'لم يتم العثور على الرسالة الأصلية.',
    'ru': 'Исходное сообщение не найдено.',
    'ka': 'ორიგინალი შეტყობინება ვერ მოიძებნა.',
    'az': 'Orijinal mesaj tapılmadı.',
  });
  String get replyNotSavedYet => _t({
    'en': 'Replies are not available until the chat update is applied.',
    'ar': 'الردود غير متاحة حتى يتم تطبيق تحديث الدردشة.',
    'ru': 'Ответы недоступны, пока не применено обновление чата.',
    'ka': 'პასუხები მიუწვდომელია ჩატის განახლების გამოყენებამდე.',
    'az': 'Çat yeniləməsi tətbiq olunana qədər cavablar mövcud deyil.',
  });
  String get messageDeletedToast => _t({
    'en': 'Message deleted',
    'ar': 'تم حذف الرسالة',
    'ru': 'Сообщение удалено',
    'ka': 'შეტყობინება წაიშალა',
    'az': 'Mesaj silindi',
  });
  String get deleteFailed => _t({
    'en': 'Could not delete. Please try again.',
    'ar': 'تعذر الحذف. حاول مرة أخرى.',
    'ru': 'Не удалось удалить. Попробуйте ещё раз.',
    'ka': 'წაშლა ვერ მოხერხდა. სცადეთ ხელახლა.',
    'az': 'Silmək mümkün olmadı. Yenidən cəhd edin.',
  });
  String get deleteNotAvailable => _t({
    'en': 'Delete is not available yet.',
    'ar': 'الحذف غير متاح بعد.',
    'ru': 'Удаление пока недоступно.',
    'ka': 'წაშლა ჯერ მიუწვდომელია.',
    'az': 'Silmə hələ əlçatan deyil.',
  });
  String get deleteConversation => _t({
    'en': 'Delete conversation',
    'ar': 'حذف المحادثة',
    'ru': 'Удалить переписку',
    'ka': 'საუბრის წაშლა',
    'az': 'Söhbəti sil',
  });
  String get deleteConversationTitle => _t({
    'en': 'Delete conversation?',
    'ar': 'حذف المحادثة؟',
    'ru': 'Удалить переписку?',
    'ka': 'წაშალოთ საუბარი?',
    'az': 'Söhbət silinsin?',
  });
  String get deleteConversationBody => _t({
    'en':
        'This conversation will be removed from your chat list and history '
        'only. The other participant keeps theirs. It will reappear if a new '
        'message arrives.',
    'ar':
        'ستتم إزالة هذه المحادثة من قائمتك وسجلّك فقط. يحتفظ الطرف الآخر '
        'بمحادثته. ستظهر مجددًا عند وصول رسالة جديدة.',
    'ru':
        'Переписка будет удалена только из вашего списка и истории. '
        'У собеседника она сохранится. Она появится снова при новом сообщении.',
    'ka':
        'საუბარი წაიშლება მხოლოდ თქვენი სიიდან და ისტორიიდან. '
        'მეორე მონაწილეს ის შეუნარჩუნდება. ახალი შეტყობინების მიღებისას '
        'ისევ გამოჩნდება.',
    'az':
        'Bu söhbət yalnız sizin siyahınızdan və tarixçənizdən silinəcək. '
        'Digər iştirakçıda qalacaq. Yeni mesaj gəldikdə yenidən görünəcək.',
  });
  String get conversationDeleted => _t({
    'en': 'Conversation deleted',
    'ar': 'تم حذف المحادثة',
    'ru': 'Переписка удалена',
    'ka': 'საუბარი წაიშალა',
    'az': 'Söhbət silindi',
  });

  String languageName(String code) {
    switch (code) {
      case 'az':
        return _t({
          'en': 'Azerbaijani',
          'ar': 'الأذربيجانية',
          'ru': 'Азербайджанский',
          'ka': 'აზერბაიჯანული',
        });
      case 'ar':
        return _t({
          'en': 'Arabic',
          'ar': 'العربية',
          'ru': 'Арабский',
          'ka': 'არაბული',
        });
      case 'ru':
        return _t({
          'en': 'Russian',
          'ar': 'الروسية',
          'ru': 'Русский',
          'ka': 'რუსული',
        });
      case 'ka':
        return _t({
          'en': 'Georgian',
          'ar': 'الجورجية',
          'ru': 'Грузинский',
          'ka': 'ქართული',
        });
      default:
        return _t({
          'en': 'English',
          'ar': 'الإنجليزية',
          'ru': 'Английский',
          'ka': 'ინგლისური',
        });
    }
  }

  /// Quick message text in the sender's language. The recipient-language
  /// version is produced by the translation service in Phase 2.
  String quick(String englishKey) {
    final m = _quick[englishKey];
    if (m == null) return englishKey;
    return m[locale] ?? englishKey;
  }

  static const Map<String, Map<String, String>> _quick = {
    "I'm on my way.": {
      'ar': 'أنا في الطريق.',
      'ru': 'Я уже в пути.',
      'ka': 'გზაში ვარ.',
    },
    "I'll arrive in 10 minutes.": {
      'ar': 'سأصل خلال 10 دقائق.',
      'ru': 'Буду через 10 минут.',
      'ka': '10 წუთში მივალ.',
    },
    "I've arrived.": {'ar': 'لقد وصلت.', 'ru': 'Я приехал.', 'ka': 'მივედი.'},
    "I'm waiting outside.": {
      'ar': 'أنا أنتظر في الخارج.',
      'ru': 'Я жду снаружи.',
      'ka': 'გარეთ გელოდებით.',
    },
    'Please share your location.': {
      'ar': 'من فضلك شارك موقعك.',
      'ru': 'Пожалуйста, поделитесь геолокацией.',
      'ka': 'გთხოვთ, გააზიაროთ ლოკაცია.',
    },
    "I'll be ready in 5 minutes.": {
      'ar': 'سأكون جاهزًا خلال 5 دقائق.',
      'ru': 'Буду готов через 5 минут.',
      'ka': '5 წუთში მზად ვიქნები.',
    },
    'Where are you?': {'ar': 'أين أنت؟', 'ru': 'Где вы?', 'ka': 'სად ხართ?'},
  };
}
