
/// Smart Chat domain models.
///
/// These models are backend-agnostic. In Phase 2 they will be populated from
/// Supabase Realtime (messages) and Odoo 17 (booking, drivers, permissions).
/// Nothing in here is produced by a simulated backend.
library;

enum ChatRole { customer, driver }

enum ChatMessageKind { text, voice, system, file }

/// Delivery lifecycle. Phase 1 never claims `delivered` or `read` for real
/// messages — those values may only be set by a real backend in Phase 2.
enum ChatDeliveryStatus { sending, sent, delivered, read, failed }

/// Translation lifecycle for a text message.
enum ChatTranslationState {
  /// Message is already in the viewer's language / no translation needed.
  notRequired,

  /// A real translation exists (Phase 2 only).
  translated,

  /// Translation could not be produced; the original is shown.
  unavailable,

  /// Translation is being produced server-side; the original is shown until
  /// it arrives (then replaced automatically).
  pending,
}

/// Phase 3.2: outcome of asking the server for translated (AI) audio.
enum ChatTtsStatus { ready, pending, disabled, unavailable, failed }

class ChatTtsResult {
  final ChatTtsStatus status;

  /// Short-lived signed URL when [status] is [ChatTtsStatus.ready].
  final String? url;
  final bool retryable;

  /// Exact server-side reason when the audio could not be produced, e.g.
  /// `ElevenLabs not configured`, `tts_401`, `service_disabled:voice_tts_generation`,
  /// `needs_transcript`, `http_503`. Null when ready.
  final String? reason;
  const ChatTtsResult({
    required this.status,
    this.url,
    this.retryable = true,
    this.reason,
  });
}

/// Speech-to-text lifecycle for a voice message (Phase 3.1).
enum ChatTranscriptionState {
  /// Not requested / not applicable (text, demo or own-device preview).
  none,

  /// Server is transcribing / translating; the audio stays playable.
  pending,

  /// Transcript available.
  ready,

  /// Transcription failed; audio still playable, retry offered.
  failed,
}

class ChatParticipant {
  final String id;
  final String name;
  final ChatRole role;
  final String? photoUrl;

  const ChatParticipant({
    required this.id,
    required this.name,
    required this.role,
    this.photoUrl,
  });
}

/// One emoji reaction of one participant on one message.
class ChatReaction {
  final String messageId;
  final ChatRole reactorRole;
  final String reactorId;
  final String emoji;

  const ChatReaction({
    required this.messageId,
    required this.reactorRole,
    required this.reactorId,
    required this.emoji,
  });
}

class ChatMessage {
  final String id;
  final ChatMessageKind kind;

  /// Authenticated sender (null for system messages).
  final ChatParticipant? sender;

  /// Original text, exactly as typed by the sender. Never modified.
  final String originalText;

  /// ISO language code of [originalText] (en, ar, ru, ka).
  final String originalLanguage;

  /// Translated text in the viewer's language. Only set by a real
  /// translation provider (Phase 2).
  final String? translatedText;
  final ChatTranslationState translationState;

  final DateTime sentAt;
  final ChatDeliveryStatus status;

  /// Timestamp at which the recipient actually viewed this message
  /// (public.chat_messages.read_at). Null => not read yet.
  final DateTime? readAt;

  /// Timestamp at which the recipient's live session received this message
  /// (public.chat_messages.delivered_at). Null => not delivered yet.
  final DateTime? deliveredAt;

  /// Voice messages.
  final int? voiceDurationSeconds;
  final String? voiceUrl;
  final List<double>? waveform;

  /// Voice transcription (Phase 3.1). Stored separately on the server;
  /// [originalText] is never used for voice messages.
  final String? transcriptText;
  final String? transcriptLanguage;
  final ChatTranscriptionState transcriptionState;

  /// Server could not identify the spoken language (no translation guessed).
  final bool languageUncertain;

  /// Set when the matching server-side AI switch is OFF for this message
  /// (`text_translation`, `voice_transcription`, `voice_text_translation`).
  /// UI shows a small "temporarily unavailable" notice; nothing is retried.
  final String? disabledService;

  /// True when this message came from the local demo data set.
  final bool isDemo;

  /// File attachments (kind == file). Stored in the PRIVATE `chat-files`
  /// bucket; opened through short-lived signed URLs only.
  final String? filePath;
  final String? fileName;
  final String? fileMime;
  final int? fileSizeBytes;

  /// True when the sender removed this message for everyone. Content and
  /// media references are cleared server-side; the UI shows a tombstone.
  final bool deletedForEveryone;

  /// Id of the message this one replies to (persisted reference).
  final String? replyToId;

  /// Persisted emoji reactions (one per participant).
  final List<ChatReaction> reactions;

  const ChatMessage({
    required this.id,
    required this.kind,
    this.sender,
    this.originalText = '',
    this.originalLanguage = 'en',
    this.translatedText,
    this.translationState = ChatTranslationState.notRequired,
    required this.sentAt,
    this.status = ChatDeliveryStatus.sent,
    this.readAt,
    this.deliveredAt,
    this.voiceDurationSeconds,
    this.voiceUrl,
    this.waveform,
    this.transcriptText,
    this.transcriptLanguage,
    this.transcriptionState = ChatTranscriptionState.none,
    this.languageUncertain = false,
    this.disabledService,
    this.isDemo = false,
    this.filePath,
    this.fileName,
    this.fileMime,
    this.fileSizeBytes,
    this.deletedForEveryone = false,
    this.replyToId,
    this.reactions = const <ChatReaction>[],
  });

  bool get isSystem => kind == ChatMessageKind.system;
  bool get isVoice => kind == ChatMessageKind.voice;
  bool get isFile => kind == ChatMessageKind.file;
  bool get hasTranslation =>
      translationState == ChatTranslationState.translated &&
      (translatedText ?? '').isNotEmpty;

  ChatMessage copyWith({
    ChatDeliveryStatus? status,
    DateTime? readAt,
    DateTime? deliveredAt,
    String? translatedText,
    ChatTranslationState? translationState,
    String? voiceUrl,
    String? originalLanguage,
    String? transcriptText,
    String? transcriptLanguage,
    ChatTranscriptionState? transcriptionState,
    bool? languageUncertain,
    String? disabledService,
    bool clearDisabledService = false,
    bool clearTranslation = false,
    bool? deletedForEveryone,
    List<ChatReaction>? reactions,
  }) {
    return ChatMessage(
      id: id,
      kind: kind,
      sender: sender,
      originalText: originalText,
      originalLanguage: originalLanguage ?? this.originalLanguage,
      translatedText: clearTranslation
          ? null
          : (translatedText ?? this.translatedText),
      translationState: translationState ?? this.translationState,
      sentAt: sentAt,
      status: status ?? this.status,
      readAt: readAt ?? this.readAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      voiceDurationSeconds: voiceDurationSeconds,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      waveform: waveform,
      transcriptText: transcriptText ?? this.transcriptText,
      transcriptLanguage: transcriptLanguage ?? this.transcriptLanguage,
      transcriptionState: transcriptionState ?? this.transcriptionState,
      languageUncertain: languageUncertain ?? this.languageUncertain,
      disabledService: clearDisabledService
          ? null
          : (disabledService ?? this.disabledService),
      isDemo: isDemo,
      filePath: filePath,
      fileName: fileName,
      fileMime: fileMime,
      fileSizeBytes: fileSizeBytes,
      deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
      replyToId: replyToId,
      reactions: reactions ?? this.reactions,
    );
  }
}

/// One continuous conversation per booking (Odoo booking reference).
class ChatConversation {
  final String id;
  final String bookingReference;
  final String tripTitle;
  final ChatParticipant currentUser;

  /// The counterpart shown in the header (assigned driver for a customer,
  /// the customer for a driver).
  final ChatParticipant counterpart;

  /// True when the data comes from the local demo set, not a real backend.
  final bool isDemo;

  const ChatConversation({
    required this.id,
    required this.bookingReference,
    required this.tripTitle,
    required this.currentUser,
    required this.counterpart,
    this.isDemo = false,
  });
}

class ChatQuickMessage {
  final String id;

  /// English source key; localized for display by ChatStrings.
  final String key;
  const ChatQuickMessage(this.id, this.key);
}

/// Languages supported by Smart Chat.
class ChatLanguages {
  static String nameOf(String code) {
    switch (code) {
      case 'ar':
        return 'Arabic';
      case 'ru':
        return 'Russian';
      case 'ka':
        return 'Georgian';
      default:
        return 'English';
    }
  }
}