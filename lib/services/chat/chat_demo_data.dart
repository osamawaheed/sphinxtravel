import '../../models/chat_models.dart';

/// LOCAL DEMO DATA ONLY.
///
/// Everything in this file is sample content for Phase 1 UI review. It is
/// never read from, or written to, Odoo or any backend. Every object created
/// here carries `isDemo: true` so the UI can label it.
class ChatDemoData {
  ChatDemoData._();

  static const String demoBookingReference = 'RQ.13509';
  static const String demoTripTitle = 'Tbilisi City Tour';

  static const ChatParticipant demoDriverAlico = ChatParticipant(
    id: 'demo-driver-alico',
    name: 'Alico',
    role: ChatRole.driver,
  );
  static const ChatParticipant demoDriverGiorgi = ChatParticipant(
    id: 'demo-driver-giorgi',
    name: 'Giorgi',
    role: ChatRole.driver,
  );
  static const ChatParticipant demoCustomerMeir = ChatParticipant(
    id: 'demo-customer-meir',
    name: 'Meir',
    role: ChatRole.customer,
  );

  /// Builds a demo conversation. Real participant names (when known) replace
  /// the demo names for the *current user*; the counterpart stays demo.
  static ChatConversation conversation({
    required ChatRole viewerRole,
    String? bookingReference,
    String? currentUserName,
    String? currentUserPhoto,
    String? counterpartName,
    String? counterpartPhoto,
  }) {
    final isCustomer = viewerRole == ChatRole.customer;
    final me = ChatParticipant(
      id: 'demo-me',
      name: (currentUserName ?? '').trim().isNotEmpty
          ? currentUserName!.trim()
          : (isCustomer ? demoCustomerMeir.name : demoDriverGiorgi.name),
      role: viewerRole,
      photoUrl: currentUserPhoto,
    );
    final other = ChatParticipant(
      id: 'demo-counterpart',
      name: (counterpartName ?? '').trim().isNotEmpty
          ? counterpartName!.trim()
          : (isCustomer ? demoDriverGiorgi.name : demoCustomerMeir.name),
      role: isCustomer ? ChatRole.driver : ChatRole.customer,
      photoUrl: counterpartPhoto,
    );
    return ChatConversation(
      id: 'demo-conversation',
      bookingReference: (bookingReference ?? '').trim().isNotEmpty
          ? bookingReference!.trim()
          : demoBookingReference,
      tripTitle: demoTripTitle,
      currentUser: me,
      counterpart: other,
      isDemo: true,
    );
  }

  static const List<double> _wave = [
    .2,
    .35,
    .5,
    .3,
    .7,
    .9,
    .6,
    .4,
    .8,
    1,
    .7,
    .5,
    .3,
    .6,
    .85,
    .55,
    .35,
    .25,
    .5,
    .75,
    .45,
    .3,
    .2,
    .4,
    .6,
    .35,
    .2,
  ];

  /// Demo history that mirrors the approved reference design:
  /// Alico (driver) <-> Meir (customer), a Driver Changed system message,
  /// then Giorgi (new driver) continuing the same conversation.
  ///
  /// `translatedText` is intentionally null: Phase 1 does NOT fabricate
  /// translations. Messages show their original text with a
  /// "translation unavailable" state.
  static List<ChatMessage> history({DateTime? now}) {
    final base = now ?? DateTime.now();
    DateTime at(int h, int m) =>
        DateTime(base.year, base.month, base.day, h, m);

    return [
      ChatMessage(
        id: 'demo-1',
        kind: ChatMessageKind.text,
        sender: demoDriverAlico,
        originalText: "I'm on my way.",
        originalLanguage: 'en',
        translationState: ChatTranslationState.unavailable,
        sentAt: at(9, 12),
        status: ChatDeliveryStatus.sent,
        isDemo: true,
      ),
      ChatMessage(
        id: 'demo-2',
        kind: ChatMessageKind.text,
        sender: demoCustomerMeir,
        originalText: 'أنا مستنيك عند مدخل الفندق.',
        originalLanguage: 'ar',
        translationState: ChatTranslationState.unavailable,
        sentAt: at(9, 14),
        status: ChatDeliveryStatus.sent,
        isDemo: true,
      ),
      ChatMessage(
        id: 'demo-3',
        kind: ChatMessageKind.voice,
        sender: demoDriverAlico,
        originalLanguage: 'ka',
        sentAt: at(9, 16),
        status: ChatDeliveryStatus.sent,
        voiceDurationSeconds: 14,
        waveform: _wave,
        isDemo: true,
      ),
      ChatMessage(
        id: 'demo-4',
        kind: ChatMessageKind.text,
        sender: demoCustomerMeir,
        originalText: 'تمام، هكون جاهز خلال ٥ دقايق.',
        originalLanguage: 'ar',
        translationState: ChatTranslationState.unavailable,
        sentAt: at(9, 17),
        status: ChatDeliveryStatus.sent,
        isDemo: true,
      ),
      ChatMessage(
        id: 'demo-5',
        kind: ChatMessageKind.system,
        originalText: 'Giorgi',
        sentAt: at(11, 5),
        isDemo: true,
      ),
      ChatMessage(
        id: 'demo-6',
        kind: ChatMessageKind.text,
        sender: demoDriverGiorgi,
        originalText: "I'll arrive in 10 minutes.",
        originalLanguage: 'en',
        translationState: ChatTranslationState.unavailable,
        sentAt: at(11, 7),
        status: ChatDeliveryStatus.sent,
        isDemo: true,
      ),
    ];
  }

  /// Quick message catalogue (English source keys).
  static const List<ChatQuickMessage> quickMessages = [
    ChatQuickMessage('qm-1', "I'm on my way."),
    ChatQuickMessage('qm-2', "I'll arrive in 10 minutes."),
    ChatQuickMessage('qm-3', "I've arrived."),
    ChatQuickMessage('qm-4', "I'm waiting outside."),
    ChatQuickMessage('qm-5', 'Please share your location.'),
    ChatQuickMessage('qm-6', "I'll be ready in 5 minutes."),
    ChatQuickMessage('qm-7', 'Where are you?'),
  ];
}
