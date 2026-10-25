import '../../models/chat_models.dart';

/// Integration-ready contracts for Smart Chat.
///
/// Phase 1 ships only local implementations (see `chat_local_services.dart`).
/// Phase 2 will add:
///  * [ChatRepository]       -> Supabase Realtime + database
///  * [ChatTranslationService] -> AI translation provider
///  * [ChatAccessService]    -> Odoo 17 booking / driver assignment check
///  * [ChatAudioService]     -> real recorder + player + storage upload
///
/// Odoo 17 remains the source of truth for bookings, identities, driver
/// assignments and chat access permissions.

/// Result of asking Odoo whether the current user may open a conversation.
class ChatAccessResult {
  final bool allowed;
  final String? reason;
  const ChatAccessResult({required this.allowed, this.reason});
}

abstract class ChatAccessService {
  /// Must be validated by Odoo 17 (booking participant / currently assigned
  /// driver). Phase 1 local implementation never grants real access.
  Future<ChatAccessResult> canAccess({
    required String bookingReference,
    required ChatRole role,
  });
}

abstract class ChatRepository {
  /// Creates or fetches the single conversation for a booking.
  Future<ChatConversation> openConversation({
    required String bookingReference,
    required ChatRole role,
  });

  /// Paginated history, newest last. [before] is the cursor for older pages.
  Future<List<ChatMessage>> loadHistory({
    required String conversationId,
    DateTime? before,
    int limit = 30,
  });

  /// Live incoming messages (Realtime). Includes reconnection handling.
  Stream<ChatMessage> watchMessages(String conversationId);

  Future<ChatMessage> sendText({
    required String conversationId,
    required String text,
    required String language,
  });

  Future<ChatMessage> sendVoice({
    required String conversationId,
    required String localPath,
    required int durationSeconds,
  });

  Future<void> markRead({
    required String conversationId,
    required String upToMessageId,
  });

  Future<int> unreadCount(String conversationId);
}

abstract class ChatTranslationService {
  /// Whether a real translation provider is connected.
  bool get isAvailable;

  /// Returns the translated text, or throws if translation fails. The
  /// caller must then fall back to the original text with an
  /// "unavailable" indicator. Names, hotel names and booking references
  /// must be preserved by the provider.
  Future<String> translate({
    required String text,
    required String fromLanguage,
    required String toLanguage,
  });
}

enum ChatRecordingState { idle, recording }

/// Why a recording could not start / finish. Mapped to friendly localized
/// text by the UI; never shown as a raw technical error.
enum ChatAudioFailure {
  permissionDenied,
  permissionPermanentlyDenied,
  recorderBusy,
  startFailed,
  tooShort,
  emptyFile,
  playbackFailed,
  unsupported,
}

class ChatAudioException implements Exception {
  final ChatAudioFailure failure;
  const ChatAudioException(this.failure);

  @override
  String toString() => 'ChatAudioException($failure)';
}

/// Live playback state of the message currently loaded in the player.
class ChatPlaybackState {
  final String? messageId;
  final bool playing;
  final Duration position;
  final Duration? duration;
  const ChatPlaybackState({
    this.messageId,
    this.playing = false,
    this.position = Duration.zero,
    this.duration,
  });
}

abstract class ChatAudioService {
  /// Whether real audio capture/playback is connected.
  bool get isAvailable;

  /// Asks for microphone permission. Throws [ChatAudioException] with
  /// [ChatAudioFailure.permissionDenied] / [permissionPermanentlyDenied].
  Future<bool> requestMicrophonePermission();

  /// Starts recording to local storage. Throws [ChatAudioException].
  Future<void> startRecording();

  /// Stops and returns the recording. Throws [ChatAudioException] when the
  /// recording is too short or empty.
  Future<ChatRecordedAudio?> stopRecording();

  /// Stops and discards the recording (and deletes the temp file).
  Future<void> cancelRecording();

  /// Starts / resumes playback of [source] (local path or blob URL).
  ///
  /// [sourceKey] is a STABLE identity of the audio (e.g. the storage path).
  /// When given, it (not the possibly changing signed [source] URL) decides
  /// whether the already loaded audio is the same one.
  Future<void> play(String messageId, String source, {String? sourceKey});
  Future<void> pause();

  /// True when [messageId] (with [sourceKey]) is the audio currently loaded
  /// in the player, so it can be resumed without a new source / signed URL.
  bool isLoaded(String messageId, {String? sourceKey});

  /// Position / duration / playing state of the active message.
  Stream<ChatPlaybackState> get playbackState;
  ChatPlaybackState get currentPlayback;

  /// Emits when playback could not start (decode error, unsupported format,
  /// rejected play(), timeout). The player is already reset to a retryable
  /// state when this fires.
  Stream<ChatAudioFailure> get playbackErrors;

  void dispose();
}

class ChatRecordedAudio {
  final String path;
  final int durationSeconds;
  const ChatRecordedAudio({required this.path, required this.durationSeconds});
}
