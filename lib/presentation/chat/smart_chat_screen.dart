import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/chat_models.dart';
import '../../services/chat/chat_audio_diagnostics.dart';
import '../../services/chat/chat_demo_data.dart';
import '../../services/chat/chat_device_audio_service.dart';
import '../../services/chat/chat_inbox_service.dart';
import '../../services/chat/chat_local_services.dart';
import '../../services/chat/chat_presence_service.dart';
import '../../services/chat/chat_services.dart';
import '../../services/chat/chat_supabase_service.dart';
import '../../services/chat/chat_test_config.dart';
import '../../services/chat/chat_translation_prefs.dart';
import '../../services/chat/chat_unread_service.dart';
import '../../services/api_client.dart';
import '../../services/driver_api_service.dart';
import '../../theme/app_theme.dart';
import './chat_inbox_strings.dart';
import './chat_strings.dart';
import './widgets/chat_input_widgets.dart';
import './widgets/chat_file_bubble.dart';
import './widgets/chat_media_widgets.dart';
import './widgets/chat_message_interactions.dart';
import './widgets/chat_text_bubble.dart';
import './widgets/chat_voice_bubble.dart';
import '../../services/chat/chat_audio_unlock.dart';

/// Smart Chat screen (Phase 1 — frontend only).
///
/// Real inputs (from existing Odoo-backed screens): [role], [bookingReference],
/// [currentUserName], [counterpartName], photos and [counterpartPhone].
/// Message content is LOCAL DEMO data until Phase 2 connects the backend.
class SmartChatScreen extends StatefulWidget {
  final ChatRole role;
  final String? bookingReference;
  final String? tripTitle;
  final String? currentUserName;
  final String? currentUserPhoto;
  final String? counterpartName;
  final String? counterpartPhoto;
  final String? counterpartPhone;

  /// Odoo id of the CURRENT conversation partner (assigned driver for the
  /// customer view, customer for the driver view). Used only to decide which
  /// historical messages may show the counterpart's profile photo.
  final int? counterpartOdooId;

  /// Authenticated Odoo id of the current user (partner/driver). When null
  /// and the booking is not the explicit TEST booking, sending is disabled.
  final int? currentUserOdooId;

  /// Real Odoo booking id (from the Odoo trips list). Used only to create a
  /// missing conversation; never invented. Null => creation is reported as a
  /// blocker instead.
  final int? odooBookingId;

  /// Completed trips open in read-only mode: history stays visible but
  /// sending text, quick messages and voice is disabled.
  final bool readOnly;

  const SmartChatScreen({
    super.key,
    required this.role,
    this.bookingReference,
    this.tripTitle,
    this.currentUserName,
    this.currentUserPhoto,
    this.counterpartName,
    this.counterpartPhoto,
    this.counterpartPhone,
    this.counterpartOdooId,
    this.currentUserOdooId,
    this.odooBookingId,
    this.readOnly = false,
  });

  @override
  State<SmartChatScreen> createState() => _SmartChatScreenState();
}

class _SmartChatScreenState extends State<SmartChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late final LocalDemoChatRepository _repo;
  late final DeviceChatAudioService _audio;
  late ChatConversation _conversation;

  // Supabase TEST backend (text messages only). Null until a live
  // conversation has been resolved; the local demo repo is the fallback.
  SupabaseChatRepository? _live;
  String? _liveConversationId;
  StreamSubscription<ChatMessage>? _liveSub;
  StreamSubscription<ChatReadReceipt>? _receiptSub;
  StreamSubscription<void>? _resyncSub;
  StreamSubscription<ChatTranslationUpdate>? _translationSub;
  StreamSubscription<ChatTranscriptionUpdate>? _transcriptionSub;
  StreamSubscription<String>? _deletionSub;
  StreamSubscription<ChatReaction>? _reactionUpsertSub;
  StreamSubscription<ChatReaction>? _reactionRemovalSub;
  StreamSubscription<ChatAudioFailure>? _playbackErrorSub;
  String? _backendError;
  bool _isTestBooking = false;

  /// Closure resolved from Odoo (trip status / dates) when the caller did not
  /// already pass `readOnly`. Closed conversations are read-only everywhere.
  bool _closedByOdoo = false;
  bool get _readOnly => widget.readOnly || _closedByOdoo;

  // Read-receipt state: only true while the app is in the foreground.
  bool _foreground = true;
  bool _markingRead = false;
  bool _markAgain = false;
  Timer? _markDebounce;
  Timer? _receiptPoll;
  int _zeroRowStreak = 0;

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _hasText = false;

  // Reply / reactions state.
  final FocusNode _inputFocus = FocusNode();
  ChatMessage? _replyTo;
  String? _highlightId;
  Timer? _highlightTimer;
  final Map<String, GlobalKey> _rowKeys = <String, GlobalKey>{};
  final Map<String, GlobalKey> _bubbleKeys = <String, GlobalKey>{};

  GlobalKey _rowKey(String id) =>
      _rowKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'row-$id'));
  GlobalKey _bubbleKey(String id) =>
      _bubbleKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'bubble-$id'));

  /// Real failure reason per voice message id (HTTP status / server code),
  /// shown to the recipient instead of only the generic message.
  final Map<String, String> _transcriptionErrors = <String, String>{};

  /// Exact server reason of the last translated-audio failure per message
  /// (e.g. `http_503:ElevenLabs not configured`).
  final Map<String, String> _ttsReasons = <String, String>{};

  bool _recording = false;
  bool _busyRecording = false;
  Duration _elapsed = Duration.zero;
  Timer? _recTimer;

  /// Phase 3.1: maximum voice recording length.
  static const int _maxRecordingSeconds = 60;

  /// Recording stopped at the 60 s limit and kept locally; sent only after
  /// the user explicitly taps Send (or discarded with Delete).
  ChatRecordedAudio? _pendingAudio;

  // Translation language state.
  String _translationLang = 'en';
  int _switchGeneration = 0;

  /// Incremented on every playback tap. A tap whose `await` (URL signing /
  /// TTS generation) finishes after a newer tap is discarded, so a slow
  /// request can never start audio for a message the user already left.
  int _playRequest = 0;

  /// Id of the voice message whose audio is currently being loaded, used
  /// to ignore repeated taps while the same message is still loading.
  String? _loadingVoiceId;

  /// Same value exposed to the voice bubbles so a loading indicator is shown
  /// ONLY while audio is genuinely being fetched / loaded.
  final ValueNotifier<String?> _loadingVoiceNotifier = ValueNotifier<String?>(
    null,
  );

  void _setLoadingVoice(String? id) {
    _loadingVoiceId = id;
    _loadingVoiceNotifier.value = id;
  }

  /// Last app interface language seen by this screen. When it changes while
  /// the chat is open, the new language becomes the recipient's selected
  /// translation language (single source of truth) immediately.
  String? _lastAppLang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appLang = AppLocalizations.of(context).locale;
    final previous = _lastAppLang;
    _lastAppLang = appLang;
    if (previous == null || previous == appLang) return;
    if (!ChatTranslationLanguages.isAllowedFor(widget.role, appLang)) return;
    if (appLang == _translationLang) return;
    // The user just picked a new language: it overrides the previously saved
    // chat choice for text, voice translation and the TTS target.
    _switchTranslationLanguage(appLang);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Preload the modern emoji font so emojis in bubbles, the picker and the
    // reaction bar share one consistent style.
    GoogleFonts.pendingFonts([GoogleFonts.notoColorEmoji()]);
    // TEMPORARY: audio diagnostics are available for any booking in the TEST
    // build only (AUDIO_DIAGNOSTICS flag, off for production builds). Enabled
    // here (not after async loading) so the button is always visible.
    ChatAudioDiagnostics.instance.setEnabled(true);
    _repo = LocalDemoChatRepository(viewerRole: widget.role);
    _audio = DeviceChatAudioService();
    // Playback that never starts (decode error, unsupported format such as
    // WebM/Opus on iOS, rejected play(), timeout): the service has already
    // reset the player to Play, so just tell the user and allow a retry.
    _playbackErrorSub = _audio.playbackErrors.listen((_) {
      _setLoadingVoice(null);
      if (mounted) _toast(_s.playbackFailed);
    });
    _conversation = ChatDemoData.conversation(
      viewerRole: widget.role,
      bookingReference: widget.bookingReference,
      currentUserName: widget.currentUserName,
      currentUserPhoto: widget.currentUserPhoto,
      counterpartName: widget.counterpartName,
      counterpartPhoto: widget.counterpartPhoto,
    );
    _load();
  }

  /// Enforces the closure rule for entry points that did not pass `readOnly`
  /// (direct navigation, notifications, ...). Uses the Odoo driver trips list
  /// as the source of truth and fails open only when Odoo is unreachable (the
  /// server enforces closure on every insert regardless).
  Future<void> _resolveClosure() async {
    if (widget.readOnly || widget.role != ChatRole.driver) return;
    final ref = (widget.bookingReference ?? '').trim();
    final bid = widget.odooBookingId ?? 0;
    if (ref.isEmpty && bid <= 0) return;
    try {
      final trips = await DriverApiService(ApiClient()).loadTrips();
      for (final t in trips) {
        if ((bid > 0 && t.id == bid) ||
            (ref.isNotEmpty && t.reference == ref)) {
          if (ChatInboxService.isTripCompleted(t) && mounted) {
            _live?.closed = true;
            setState(() => _closedByOdoo = true);
          }
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    _resolveClosure();
    final localHistory = await _repo.loadHistory(
      conversationId: _conversation.id,
    );
    if (!mounted) return;

    // Try the Supabase TEST backend first. The reference used for lookup is
    // the one passed by the screen; the explicit test reference is used only
    // when the screen did not receive a real booking reference.
    final passed = (widget.bookingReference ?? '').trim();
    final lookupRef = passed.isNotEmpty
        ? passed
        : ChatTestConfig.testBookingReference;
    _isTestBooking = ChatTestConfig.isTestReference(lookupRef);

    final lang = AppLocalizations.of(context).locale;
    final senderId =
        widget.currentUserOdooId ??
        (_isTestBooking ? ChatTestConfig.testSenderIdFor(widget.role) : null);

    // The selected CHAT translation language decides translation and the
    // "Listen Translated" target. A saved in-chat choice (per user and role)
    // is restored; the app interface language is only the default when the
    // user never picked a chat language.
    final resolvedLang = await ChatTranslationPrefs.resolve(
      widget.role,
      senderId,
      lang,
    );
    if (!mounted) return;
    // A language switch during loading already updated _translationLang.
    final chatLang = _switchGeneration > 0 ? _translationLang : resolvedLang;
    _translationLang = chatLang;

    final live = SupabaseChatRepository(
      viewerRole: widget.role,
      viewerName: _conversation.currentUser.name,
      viewerLanguage: chatLang,
      senderId: senderId,
      odooBookingId: widget.odooBookingId,
    );

    try {
      final convId = await live.ensureConversation(
        lookupRef,
        odooBookingId: widget.odooBookingId,
      );
      final history = await live.loadHistory(convId);
      final reactions = await live.loadReactions(convId);
      if (!mounted) {
        await live.dispose();
        return;
      }
      live.closed = _readOnly;
      _live = live;
      _liveConversationId = convId;
      // Make sure this user is publishing presence for the booking this chat
      // shows (merged with the home screens' bookings). Real ids only: a
      // negative TEST id is never published.
      if ((senderId ?? 0) > 0) {
        ChatPresenceService.instance.ensureBooking(
          role: widget.role == ChatRole.driver ? 'driver' : 'customer',
          userId: senderId!,
          reference: lookupRef,
          bookingId: widget.odooBookingId,
        );
      }
      _liveSub = live.watchMessages(convId).listen(_onLiveMessage);
      _receiptSub = live.readReceipts.listen(_onReadReceipt);
      _resyncSub = live.reconnected.listen((_) => _resyncAfterReconnect());
      _deletionSub = live.deletedForEveryone.listen(_onRemoteDeletion);
      _reactionUpsertSub = live.reactionUpserts.listen(_onReactionUpsert);
      _reactionRemovalSub = live.reactionRemovals.listen(_onReactionRemoval);
      live.watchReactions(convId);
      _translationSub = live.translationUpdates.listen(_onTranslationUpdate);
      _transcriptionSub = live.transcriptionUpdates.listen(
        _onTranscriptionUpdate,
      );
      live.watchTranslations();
      setState(() {
        _conversation = ChatConversation(
          id: convId,
          bookingReference: lookupRef,
          tripTitle: _conversation.tripTitle,
          currentUser: _conversation.currentUser,
          counterpart: _conversation.counterpart,
          isDemo: false,
        );
        _messages = _withReactions(history, reactions);
        _backendError = null;
        _loading = false;
      });
      _jumpToEnd();
      _resolveReplyOriginals();
      _startReceiptPolling();
      _markDeliveredNow();
      _markVisibleIncomingAsRead();
      _requestPendingTranslations();
      _requestPendingTranscriptions();
    } on ChatBackendException catch (e) {
      await live.dispose();
      if (!mounted) return;
      // Report the exact reason; fall back to clearly-labeled local demo.
      setState(() {
        _backendError =
            '${e.issue.name}'
            '${e.code != null ? ' [${e.code}]' : ''}: ${e.detail}';
        _messages = List.of(localHistory);
        _loading = false;
      });
      _jumpToEnd();
    } catch (e) {
      await live.dispose();
      if (!mounted) return;
      setState(() {
        _backendError = 'unknown: $e';
        _messages = List.of(localHistory);
        _loading = false;
      });
      _jumpToEnd();
    }
  }

  void _onLiveMessage(ChatMessage m) {
    if (!mounted) return;
    // De-duplicate: our own inserts are already in the list.
    if (_messages.any((x) => x.id == m.id)) return;
    setState(() {
      _messages = [..._messages, m]
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    });
    _jumpToEnd();
    if (m.replyToId != null) _resolveReplyOriginals();
    if (m.translationState == ChatTranslationState.pending) {
      _requestPendingTranslations();
    }
    if (m.isVoice &&
        m.transcriptionState == ChatTranscriptionState.pending &&
        m.sender != null &&
        m.sender!.role != widget.role) {
      _requestPendingTranscriptions();
    }
    // Never mark our own messages; for incoming ones, wait until the bubble
    // has been rendered, then batch via a short debounce.
    if (m.sender != null && m.sender!.role != widget.role) {
      _markDeliveredNow();
      _scheduleMarkRead();
    }
  }

  /// Schedules a batched read-marking AFTER the next frame has rendered the
  /// new incoming message(s). Several messages in quick succession collapse
  /// into a single RPC call.
  void _scheduleMarkRead() {
    _markDebounce?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _markDebounce?.cancel();
      _markDebounce = Timer(const Duration(milliseconds: 350), () {
        if (mounted) _markVisibleIncomingAsRead();
      });
    });
  }

  /// DELIVERED = this device is in the foreground with a live Realtime
  /// subscription and the incoming row has actually reached it. Persisted via
  /// RPC; the sender's UI updates from the resulting UPDATE event.
  bool _markingDelivered = false;
  Future<void> _markDeliveredNow() async {
    final live = _live;
    final convId = _liveConversationId;
    if (live == null || convId == null || !mounted || !_foreground) return;
    if (_markingDelivered) return;
    _markingDelivered = true;
    try {
      await live.markIncomingAsDelivered(conversationId: convId);
    } finally {
      _markingDelivered = false;
    }
  }

  /// Removes an optimistic bubble whose insert failed (no false checkmark).
  void _failPending(String pendingId) {
    setState(() {
      _messages = [
        for (final x in _messages)
          if (x.id != pendingId) x,
      ];
    });
  }

  /// Realtime UPDATE: the recipient received / read one of our messages.
  void _onReadReceipt(ChatReadReceipt r) {
    if (!mounted) return;
    _applyReceiptStates({r.messageId: r});
  }

  void _applyReadStates(Map<String, DateTime> reads) {
    _applyReceiptStates({
      for (final e in reads.entries)
        e.key: ChatReadReceipt(messageId: e.key, readAt: e.value),
    });
  }

  /// Applies persisted delivered/read timestamps. Never downgrades: a
  /// message that is already `read` stays `read`.
  void _applyReceiptStates(Map<String, ChatReadReceipt> receipts) {
    if (receipts.isEmpty) return;
    var changed = false;
    final next = [
      for (final m in _messages)
        if (!m.isDemo && receipts.containsKey(m.id))
          () {
            final r = receipts[m.id]!;
            if (r.readAt != null && m.status != ChatDeliveryStatus.read) {
              changed = true;
              return m.copyWith(
                status: ChatDeliveryStatus.read,
                readAt: r.readAt,
                deliveredAt: r.deliveredAt ?? m.deliveredAt ?? r.readAt,
              );
            }
            if (r.readAt == null &&
                r.deliveredAt != null &&
                m.status != ChatDeliveryStatus.read &&
                m.status != ChatDeliveryStatus.delivered) {
              changed = true;
              return m.copyWith(
                status: ChatDeliveryStatus.delivered,
                deliveredAt: r.deliveredAt,
              );
            }
            return m;
          }()
        else
          m,
    ];
    if (changed) setState(() => _messages = next);
  }

  /// After a Realtime reconnect events may have been missed: re-read the
  /// persisted read_at values (and any messages sent while offline).
  Future<void> _resyncAfterReconnect() async {
    final live = _live;
    final convId = _liveConversationId;
    if (live == null || convId == null || !mounted) return;
    try {
      final fresh = await live.loadHistory(convId);
      if (!mounted) return;
      final known = {for (final m in _messages) m.id};
      final added = [
        for (final m in fresh)
          if (!known.contains(m.id)) m,
      ];
      final merged = [..._messages, ...added]
        ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
      setState(() => _messages = merged);
      if (added.isNotEmpty) _jumpToEnd();
      _applyReadStates({
        for (final m in fresh)
          if (m.readAt != null) m.id: m.readAt!,
      });
      _applyReceiptStates({
        for (final m in fresh)
          if (m.deliveredAt != null && m.readAt == null)
            m.id: ChatReadReceipt(messageId: m.id, deliveredAt: m.deliveredAt),
      });
      _markDeliveredNow();
      _markVisibleIncomingAsRead();
      _applyFreshTranslations(fresh);
      _requestPendingTranslations();
      _requestPendingTranscriptions();
    } catch (_) {
      // Keep current state; next reconnect / re-open will retry.
    }
  }

  void _applyFreshTranslations(List<ChatMessage> fresh) {
    for (final f in fresh) {
      if (f.hasTranslation) {
        _onTranslationUpdate(
          ChatTranslationUpdate(messageId: f.id, text: f.translatedText!),
        );
      }
    }
  }

  /// Asks the server to translate every displayed incoming text message that
  /// still has no stored translation. The original stays visible meanwhile;
  /// failures never block delivery and are retried on the next resync.
  Future<void> _requestPendingTranslations({int? expectedGeneration}) async {
    final live = _live;
    if (live == null || !mounted) return;
    final pending = [
      for (final m in _messages)
        if (!m.isDemo &&
            !m.isVoice &&
            !m.id.startsWith('pending-') &&
            m.translationState == ChatTranslationState.pending)
          m.id,
    ];
    for (final id in pending) {
      // Stop if the user switched language again meanwhile.
      if (expectedGeneration != null &&
          expectedGeneration != _switchGeneration) {
        return;
      }
      final ok = await live.requestTranslation(id);
      if (!ok && mounted) _markTranslationUnavailable(id);
    }
  }

  void _markTranslationUnavailable(String id) {
    setState(() {
      _messages = [
        for (final m in _messages)
          if (m.id == id && m.translationState == ChatTranslationState.pending)
            m.copyWith(translationState: ChatTranslationState.unavailable)
          else
            m,
      ];
    });
  }

  // ----------------------------------------------------- voice transcription

  /// Requests (once, server-side) the transcript + translation for every
  /// stored voice message that has none yet. Audio stays playable meanwhile.
  /// The server reuses saved transcripts, so reopening never re-transcribes.
  Future<void> _requestPendingTranscriptions() async {
    final live = _live;
    if (live == null || !mounted) return;
    final ids = [
      for (final m in _messages)
        if (!m.isDemo &&
            m.isVoice &&
            !m.id.startsWith('pending-') &&
            m.sender != null &&
            m.sender!.role != widget.role &&
            m.transcriptionState == ChatTranscriptionState.pending &&
            (m.voiceDurationSeconds ?? 0) <= _maxRecordingSeconds + 1)
          m.id,
    ];
    for (final id in ids) {
      if (!mounted) return;
      await live.requestTranscription(id);
    }
  }

  Future<void> _retryTranscription(ChatMessage m) async {
    final live = _live;
    if (live == null) return;
    setState(() {
      _messages = [
        for (final x in _messages)
          if (x.id == m.id)
            x.copyWith(transcriptionState: ChatTranscriptionState.pending)
          else
            x,
      ];
    });
    await live.requestTranscription(m.id, retry: true, force: true);
  }

  /// Permanent speech-to-text rejections (any 4xx except 429, e.g. stt_400)
  /// or an exhausted attempt budget will not succeed on retry, so the retry
  /// button is not offered and nothing is re-sent. The recording is kept.
  bool _isPermanentSttError(String? reason) {
    final r = reason ?? '';
    if (r == 'max_attempts' || r.startsWith('max_attempts')) return true;
    final m = RegExp(r'stt_(\d{3})').firstMatch(r);
    if (m == null) return false;
    final code = int.tryParse(m.group(1)!) ?? 0;
    return code >= 400 && code < 500 && code != 429;
  }

  void _onTranscriptionUpdate(ChatTranscriptionUpdate u) {
    if (!mounted) return;
    setState(() {
      if (u.failed && (u.failureReason ?? '').isNotEmpty) {
        _transcriptionErrors[u.messageId] = u.failureReason!;
      } else {
        _transcriptionErrors.remove(u.messageId);
      }
      _messages = [
        for (final m in _messages)
          if (m.id == u.messageId && m.isVoice)
            _applyTranscription(m, u)
          else
            m,
      ];
    });
  }

  ChatMessage _applyTranscription(ChatMessage m, ChatTranscriptionUpdate u) {
    if (u.skipped) {
      return m.copyWith(transcriptionState: ChatTranscriptionState.none);
    }
    if (u.serviceDisabled && (u.transcriptText ?? '').isEmpty) {
      // Transcription switch is OFF: no transcript, no retry, no loader.
      // The original audio remains fully playable.
      return m.copyWith(
        transcriptionState: ChatTranscriptionState.none,
        disabledService: u.disabledService ?? 'voice_transcription',
      );
    }
    if (u.failed) {
      return m.copyWith(transcriptionState: ChatTranscriptionState.failed);
    }
    final incoming = m.sender != null && m.sender!.role != widget.role;
    final src = u.sourceLanguage;
    var next = m.copyWith(
      transcriptionState: ChatTranscriptionState.ready,
      transcriptText: u.transcriptText,
      transcriptLanguage: src,
      originalLanguage: src,
      languageUncertain: false,
      // Translation switch OFF: keep the original transcript and show a
      // small notice. Otherwise clear any earlier notice (re-enabled).
      disabledService: u.serviceDisabled ? u.disabledService : null,
      clearDisabledService: !u.serviceDisabled,
    );
    if (!incoming || u.sameLanguage) {
      return next.copyWith(
        translationState: ChatTranslationState.notRequired,
        clearTranslation: true,
        languageUncertain: incoming && u.languageUncertain,
      );
    }
    if (u.translatedText.isNotEmpty) {
      return next.copyWith(
        translatedText: u.translatedText,
        translationState: ChatTranslationState.translated,
      );
    }
    return next.copyWith(
      translationState: u.translationFailed
          ? ChatTranslationState.unavailable
          : ChatTranslationState.pending,
      clearTranslation: true,
    );
  }

  /// A translation arrived (Realtime or server response): swap it in without
  /// reopening the conversation.
  void _onTranslationUpdate(ChatTranslationUpdate u) {
    if (!mounted) return;
    var changed = false;
    final next = [
      for (final m in _messages)
        if (m.id == u.messageId &&
            (!m.isVoice || (m.sender != null && m.sender!.role != widget.role)))
          () {
            final src = u.sourceLanguage;
            if (u.serviceDisabled) {
              // Text translation switch is OFF: stop the pending state, show
              // the original with a small notice. Nothing is retried.
              if (m.disabledService == 'text_translation' &&
                  m.translationState != ChatTranslationState.pending) {
                return m;
              }
              changed = true;
              return m.copyWith(
                translationState: ChatTranslationState.notRequired,
                clearTranslation: true,
                disabledService: 'text_translation',
              );
            }
            if (u.same) {
              if (m.translationState == ChatTranslationState.notRequired &&
                  m.translatedText == null &&
                  m.disabledService == null) {
                return m;
              }
              changed = true;
              return m.copyWith(
                translationState: ChatTranslationState.notRequired,
                clearTranslation: true,
                clearDisabledService: true,
                originalLanguage: m.isVoice ? null : src,
              );
            }
            if (m.translatedText == u.text &&
                m.translationState == ChatTranslationState.translated) {
              return m;
            }
            changed = true;
            return m.copyWith(
              translatedText: u.text,
              translationState: ChatTranslationState.translated,
              clearDisabledService: true,
              originalLanguage: m.isVoice ? null : src,
              // A Realtime translation row for a voice message proves the
              // transcript exists server-side. Mark it ready so the translated
              // text and "Listen Translated" appear for the recipient even if
              // the transcription response has not been applied yet. A
              // `failed` state is also recovered. The transcript text itself
              // arrives with the function response / re-read.
              transcriptionState:
                  m.isVoice &&
                      (m.transcriptionState == ChatTranscriptionState.failed ||
                          m.transcriptionState ==
                              ChatTranscriptionState.pending)
                  ? ChatTranscriptionState.ready
                  : null,
              languageUncertain: m.isVoice ? false : null,
            );
          }()
        else
          m,
    ];
    if (changed) setState(() => _messages = next);
  }

  /// Opens the "Translate Messages To" selector.
  Future<void> _openTranslationPicker() async {
    final s = _s;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.translateMessagesTo,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final code in ChatTranslationLanguages.forRole(widget.role))
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  onTap: () => Navigator.of(ctx).pop(code),
                  leading: Text(
                    ChatTranslationLanguages.flags[code] ?? '',
                    style: const TextStyle(fontSize: 22),
                  ),
                  title: Text(
                    code == 'en'
                        ? 'English'
                        : '${s.languageName(code)} '
                              '(${ChatTranslationLanguages.nativeNames[code]})',
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryText,
                      fontSize: 15,
                      fontWeight: code == _translationLang
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  trailing: code == _translationLang
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppTheme.luxuryAccent,
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted || picked == _translationLang) return;
    await _switchTranslationLanguage(picked);
  }

  /// Applies a new chat translation language immediately. Only translation
  /// state changes: no messages are added, read_at / unread counts are not
  /// touched, and the app interface language is unchanged.
  Future<void> _switchTranslationLanguage(String lang) async {
    final generation = ++_switchGeneration;
    setState(() => _translationLang = lang);
    await ChatTranslationPrefs.save(widget.role, _live?.senderId, lang);
    final live = _live;
    if (live == null || !mounted) return;

    live.setViewerLanguage(lang);
    live.resetTranscribingMarkers();

    // Incoming text messages become pending (original shown) until the cached
    // or freshly requested translation for the new language is applied.
    final ids = <String>[];
    final voiceIds = <String>[];
    setState(() {
      _messages = [
        for (final m in _messages)
          if (!m.isDemo &&
              !m.isVoice &&
              !m.isFile &&
              !m.isSystem &&
              !m.id.startsWith('pending-') &&
              m.sender != null &&
              m.sender!.role != widget.role)
            () {
              ids.add(m.id);
              return m.copyWith(
                clearTranslation: true,
                translationState: ChatTranslationState.pending,
              );
            }()
          else if (!m.isDemo &&
              m.isVoice &&
              m.transcriptionState == ChatTranscriptionState.ready &&
              !m.id.startsWith('pending-') &&
              m.sender != null &&
              m.sender!.role != widget.role)
            () {
              // Transcript is language independent: only the translation is
              // refreshed. The server never re-transcribes a stored voice.
              voiceIds.add(m.id);
              return m.copyWith(
                clearTranslation: true,
                translationState: ChatTranslationState.pending,
              );
            }()
          else
            m,
      ];
    });
    if (ids.isEmpty && voiceIds.isEmpty) return;

    // 1) Reuse cached translations for the new language.
    final cached = await live.loadTranslationsFor([...ids, ...voiceIds]);
    if (!mounted || generation != _switchGeneration) return;
    for (final e in cached.entries) {
      if (e.value.isNotEmpty) {
        _onTranslationUpdate(
          ChatTranslationUpdate(messageId: e.key, text: e.value),
        );
      }
    }
    // 2) Request only the missing ones (server also short-circuits
    //    same-language and cached rows, so OpenAI is not called needlessly).
    await _requestPendingTranslations(expectedGeneration: generation);
    for (final id in voiceIds) {
      if (!mounted || generation != _switchGeneration) return;
      final stillPending = _messages.any(
        (m) => m.id == id && m.translationState == ChatTranslationState.pending,
      );
      if (stillPending) await live.requestTranscription(id);
    }
  }

  /// Marks INCOMING live messages as read in Supabase.
  ///
  /// Only runs when ALL hold: live conversation resolved, the screen is
  /// mounted (conversation open), the app is in the foreground, and there is
  /// at least one displayed incoming message without read_at. Never marks
  /// the viewer's own messages; the RPC enforces the same rule server-side.
  Future<void> _markVisibleIncomingAsRead() async {
    final live = _live;
    final convId = _liveConversationId;
    if (live == null || convId == null) return;
    if (!mounted || !_foreground) return;
    if (_markingRead) {
      // A call is in flight: remember to run once more so messages that
      // arrived meanwhile are not left unread.
      _markAgain = true;
      return;
    }
    if (live.senderId == null) return;
    final unread = _messages
        .where(
          (m) =>
              !m.isDemo &&
              !m.isSystem &&
              !m.id.startsWith('pending-') &&
              m.sender != null &&
              m.sender!.role != widget.role &&
              m.readAt == null,
        )
        .map((m) => m.id)
        .toList();
    if (unread.isEmpty) return;
    _markingRead = true;
    try {
      final marked = await live.markIncomingAsRead(conversationId: convId);
      debugPrint(
        '[chat] markVisibleIncomingAsRead unread_shown=${unread.length} '
        'rpc_rows=$marked',
      );
      // Confirm against the database (source of truth), not the RPC return.
      final persisted = await live.loadReadStatesFor(unread);
      if (!mounted) return;
      final confirmed = persisted.length;
      if (confirmed < unread.length) {
        _zeroRowStreak++;
        debugPrint(
          '[chat] read_at NOT persisted for ${unread.length - confirmed} of '
          '${unread.length} incoming messages (rpc_rows=$marked). '
          'Check chat_mark_messages_read role/id matching.',
        );
        if (_zeroRowStreak >= 2) {
          setState(
            () => _backendError =
                'readReceipts: chat_mark_messages_read returned $marked '
                'row(s) but read_at is still empty for '
                '${unread.length - confirmed} of ${unread.length} incoming '
                'message(s). conversation=$convId '
                'role=${widget.role.name} odoo_id=${live.senderId}',
          );
        }
      } else {
        _zeroRowStreak = 0;
        // Reflect persisted read_at locally so we do not re-call the RPC.
        setState(() {
          _messages = [
            for (final m in _messages)
              persisted.containsKey(m.id)
                  ? m.copyWith(
                      status: m.sender?.role == widget.role
                          ? ChatDeliveryStatus.read
                          : m.status,
                      readAt: persisted[m.id],
                    )
                  : m,
          ];
          if ((_backendError ?? '').startsWith('readReceipts:')) {
            _backendError = null;
          }
        });
      }
    } on ChatBackendException catch (e) {
      // Always show the latest exact blocker for read receipts.
      if (mounted) {
        setState(
          () => _backendError =
              'readReceipts: ${e.code != null ? '[${e.code}] ' : ''}${e.detail}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _backendError = 'readReceipts: $e');
      }
    } finally {
      _markingRead = false;
      // Counts are re-read from Supabase (source of truth) after the RPC.
      ChatUnreadService.instance.refreshAll();
      if (_markAgain && mounted) {
        _markAgain = false;
        _scheduleMarkRead();
      }
    }
  }

  /// Sender side safety net: while the chat is open and we have outgoing
  /// messages without a read_at, periodically re-read the PERSISTED read_at
  /// (normal RLS SELECT). This only reflects what the recipient's app wrote;
  /// it never fabricates a receipt. Realtime still updates instantly when
  /// the UPDATE event is published.
  void _startReceiptPolling() {
    _receiptPoll?.cancel();
    _receiptPoll = Timer.periodic(const Duration(seconds: 4), (_) async {
      final live = _live;
      if (live == null || !mounted || !_foreground) return;
      final pending = [
        for (final m in _messages)
          if (!m.isDemo &&
              !m.id.startsWith('pending-') &&
              m.sender?.role == widget.role &&
              m.status != ChatDeliveryStatus.read)
            m.id,
      ];
      if (pending.isEmpty) return;
      try {
        final states = await live.loadReceiptStatesFor(pending);
        if (mounted) _applyReceiptStates(states);
      } catch (_) {
        // Keep polling; errors here must never disturb the chat.
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final fg = state == AppLifecycleState.resumed;
    if (fg == _foreground) return;
    _foreground = fg;
    if (fg) {
      // Re-join presence (reconnect after background / lost socket), then
      // re-sync receipts and mark anything received meanwhile.
      ChatPresenceService.instance.onResumed();
      _resyncAfterReconnect();
    } else {
      // Background: never mark; drop any pending scheduled marking.
      _markDebounce?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _markDebounce?.cancel();
    _receiptPoll?.cancel();
    _recTimer?.cancel();
    _liveSub?.cancel();
    _receiptSub?.cancel();
    _resyncSub?.cancel();
    _translationSub?.cancel();
    _transcriptionSub?.cancel();
    _deletionSub?.cancel();
    _reactionUpsertSub?.cancel();
    _reactionRemovalSub?.cancel();
    _highlightTimer?.cancel();
    _inputFocus.dispose();
    _playbackErrorSub?.cancel();
    _loadingVoiceNotifier.dispose();
    ChatAudioDiagnostics.instance.setEnabled(false);
    // Leaving the conversation: refresh persisted unread counts.
    ChatUnreadService.instance.refreshAll();
    _live?.dispose();
    _audio.dispose();
    _repo.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ChatStrings get _s => ChatStrings(AppLocalizations.of(context).locale);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = ChatStrings(l10n.locale);

    return Directionality(
      textDirection: l10n.isRtlLocale ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppTheme.mainBackground,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(s),
              _buildTripCard(s),
              _buildDemoBanner(s),
              if (_readOnly && widget.role == ChatRole.driver && !_loading)
                _buildCompletedBanner(l10n.locale),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMessages(s),
              ),
              if (_readOnly)
                _buildReadOnlyNotice(l10n.locale)
              else ...[
                ChatQuickMessagesBar(
                  items: widget.role == ChatRole.customer
                      ? ChatDemoData.customerQuickMessages
                      : ChatDemoData.quickMessages,
                  strings: ChatStrings(_translationLang),
                  onSelect: (q) =>
                      _sendText(ChatStrings(_translationLang).quick(q.key)),
                ),
                if (_replyTo != null) _buildReplyPreview(s),
                ChatInputBar(
                  controller: _input,
                  focusNode: _inputFocus,
                  strings: s,
                  isRecording: _recording,
                  voiceReady: _pendingAudio != null,
                  recordingElapsed: _elapsed,
                  hasText: _hasText,
                  onChanged: (v) =>
                      setState(() => _hasText = v.trim().isNotEmpty),
                  onAttach: _onAttach,
                  onSend: () => _sendText(_input.text),
                  onMicTap: _toggleRecording,
                  onCancelRecording: _cancelRecording,
                  onHoldStart: _holdStart,
                  onHoldRelease: _holdRelease,
                  onHoldCancel: _holdCancel,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyNotice(String locale) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.softGoldBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppTheme.luxuryAccent,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ChatInboxStrings(locale).readOnlyNotice,
                style: GoogleFonts.inter(
                  color: AppTheme.navyText,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Blue "Completed" status banner (same blue as the blue trip status badge).
  Widget _buildCompletedBanner(String locale) {
    const blue = Color(0xFF1565C0);
    final label = ChatInboxStrings(locale).statusCompleted;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: blue.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: blue.withAlpha(64)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_rounded, size: 18, color: blue),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: blue,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.softGoldBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.navyText, size: 22),
      ),
    );
  }

  /// Compact globe button that opens the "Translate Messages To" selector.
  Widget _globeButton() {
    return Tooltip(
      message: _s.translateMessagesTo,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _openTranslationPicker,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.softGoldBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.language_rounded,
            color: AppTheme.navyText,
            size: 20,
          ),
        ),
      ),
    );
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------------------------------------------------------------
  // Attachments
  //   A. Picking (device file picker)         -> _onAttach / _pickAttachment
  //   B. Upload + send (private Supabase)     -> _sendAttachment
  // ---------------------------------------------------------------------
  bool _sendingFile = false;

  /// Local (compressed) bytes of attachments still uploading, keyed by the
  /// optimistic `pending-…` message id. Lets the tile render instantly.
  final Map<String, Uint8List> _pendingFileBytes = <String, Uint8List>{};

  static const Set<String> _compressibleExt = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
  };

  /// Downscales big camera photos (the real upload/display bottleneck:
  /// multi-MB originals) to max 1600 px / q80. Falls back to the original
  /// bytes on any failure or when it would not shrink the file.
  Future<Uint8List> _optimizeImage(Uint8List bytes, String name) async {
    if (kIsWeb) return bytes;
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    if (!_compressibleExt.contains(ext) || bytes.length < 200 * 1024) {
      return bytes;
    }
    try {
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1600,
        minHeight: 1600,
        quality: 80,
        format: ext == 'png' ? CompressFormat.png : CompressFormat.jpeg,
      );
      if (out.isNotEmpty && out.length < bytes.length) return out;
    } catch (e) {
      debugPrint('[chat] image compress skipped: $e');
    }
    return bytes;
  }

  Future<void> _onAttach() async {
    if (_readOnly || _sendingFile) return;
    final s = _s;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.attachTitle,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.softGoldBg,
                  child: const Icon(
                    Icons.image_outlined,
                    color: AppTheme.luxuryAccent,
                  ),
                ),
                title: Text(
                  s.attachImage,
                  style: GoogleFonts.inter(color: AppTheme.primaryText),
                ),
                onTap: () => Navigator.of(ctx).pop('image'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.softGoldBg,
                  child: const Icon(
                    Icons.videocam_outlined,
                    color: AppTheme.luxuryAccent,
                  ),
                ),
                title: Text(
                  s.attachVideo,
                  style: GoogleFonts.inter(color: AppTheme.primaryText),
                ),
                onTap: () => Navigator.of(ctx).pop('video'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppTheme.softGoldBg,
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppTheme.luxuryAccent,
                  ),
                ),
                title: Text(
                  s.attachDocument,
                  style: GoogleFonts.inter(color: AppTheme.primaryText),
                ),
                onTap: () => Navigator.of(ctx).pop('document'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _pickAttachment(kind: choice);
  }

  Future<void> _pickAttachment({required String kind}) async {
    final s = _s;
    // Photos open the native gallery (PHPicker on iOS) instead of the Files
    // app. Video / documents keep using the file picker.
    if (kind == 'image' && !kIsWeb) {
      try {
        final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
        );
        if (picked == null || !mounted) return;
        final imgBytes = await picked.readAsBytes();
        if (imgBytes.isEmpty) {
          _toast(s.attachReadFailed);
          return;
        }
        var imgName = picked.name.trim();
        if (imgName.isEmpty) imgName = 'photo.jpg';
        final imgDot = imgName.lastIndexOf('.');
        final imgExt = imgDot < 0
            ? ''
            : imgName.substring(imgDot + 1).toLowerCase();
        if (!SupabaseChatRepository.attachmentExtensions.contains(imgExt)) {
          // Gallery items without a usable extension are sent as JPEG.
          final base = imgDot < 0 ? imgName : imgName.substring(0, imgDot);
          imgName = '$base.jpg';
        }
        if (imgBytes.length > SupabaseChatRepository.maxAttachmentBytes) {
          _toast(s.attachTooLarge);
          return;
        }
        await _sendAttachment(imgBytes, imgName);
      } catch (e) {
        debugPrint('[chat] gallery picker failed: $e');
        _toast(s.attachReadFailed);
      }
      return;
    }
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: kind == 'image'
            ? const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'heic']
            : kind == 'video'
            ? const ['mp4', 'webm']
            : const ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt'],
        allowMultiple: false,
        withData: true,
      );
    } catch (e) {
      debugPrint('[chat] file picker failed: $e');
      _toast(s.attachReadFailed);
      return;
    }
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.first;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) {
      _toast(s.attachReadFailed);
      return;
    }
    final dot = f.name.lastIndexOf('.');
    final ext = dot < 0 ? '' : f.name.substring(dot + 1).toLowerCase();
    if (!SupabaseChatRepository.attachmentExtensions.contains(ext)) {
      _toast(s.attachUnsupported);
      return;
    }
    if (bytes.length > SupabaseChatRepository.maxAttachmentBytes) {
      _toast(s.attachTooLarge);
      return;
    }
    await _sendAttachment(bytes, f.name);
  }

  Future<void> _sendAttachment(Uint8List bytes, String name) async {
    final s = _s;
    final live = _live;
    final convId = _liveConversationId;
    if (live == null || convId == null) {
      // No live backend (local demo): never pretend the file was sent.
      _toast(s.attachNotDeployed);
      return;
    }
    // Optimistic tile first: the chat never blocks while compressing/uploading.
    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    final isImage = const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'heic',
    }.contains(ext);
    setState(() {
      _sendingFile = true;
      if (isImage) _pendingFileBytes[pendingId] = bytes;
      _messages = [
        ..._messages,
        ChatMessage(
          id: pendingId,
          kind: ChatMessageKind.file,
          sender: ChatParticipant(
            id: '${live.senderId ?? ''}',
            name: _conversation.currentUser.name,
            role: widget.role,
          ),
          originalLanguage: _translationLang,
          sentAt: DateTime.now(),
          status: ChatDeliveryStatus.sending,
          isDemo: false,
          fileName: name,
          fileMime: isImage ? 'image/$ext' : null,
          fileSizeBytes: bytes.length,
        ),
      ];
    });
    _jumpToEnd();
    try {
      final optimized = await _optimizeImage(bytes, name);
      if (mounted && isImage && !identical(optimized, bytes)) {
        setState(() => _pendingFileBytes[pendingId] = optimized);
      }
      final sent = await live.sendFile(
        conversationId: convId,
        bytes: optimized,
        fileName: name,
        language: _translationLang,
      );
      if (!mounted) return;
      // Warm the signed-URL cache so the final tile appears without a
      // second round trip.
      final p = sent.filePath;
      if (p != null && p.isNotEmpty) {
        unawaited(live.cachedSignedFileUrl(p, messageId: sent.id));
      }
      setState(() {
        final already = _messages.any((x) => x.id == sent.id);
        _messages = [
          for (final x in _messages)
            if (x.id != pendingId) x,
          if (!already) sent,
        ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        _pendingFileBytes.remove(pendingId);
      });
      _jumpToEnd();
    } on ChatBackendException catch (e) {
      debugPrint('[chat] attachment send failed: $e');
      if (!mounted) return;
      _pendingFileBytes.remove(pendingId);
      _failPending(pendingId);
      if (e.issue == ChatBackendIssue.attachmentsNotDeployed) {
        _toast(s.attachNotDeployed);
      } else if (e.issue == ChatBackendIssue.missingSenderIdentity) {
        _toast(s.noSenderIdentity);
      } else {
        _toast(s.attachSendFailed);
      }
    } catch (e) {
      debugPrint('[chat] attachment send failed: $e');
      if (mounted) {
        _pendingFileBytes.remove(pendingId);
        _failPending(pendingId);
        _toast(s.attachSendFailed);
      }
    } finally {
      if (mounted) setState(() => _sendingFile = false);
    }
  }

  /// Cached short-lived signed URL for an attachment (private bucket). The
  /// URL is reused while valid and only refreshed when [forceRefresh] is set
  /// (e.g. after a load failure on an expired URL).
  Future<String?> _resolveFileUrl(
    ChatMessage m, {
    bool forceRefresh = false,
  }) async {
    final live = _live;
    final path = m.filePath;
    if (live == null || path == null || path.isEmpty) return null;
    return live.cachedSignedFileUrl(
      path,
      messageId: m.id,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _openFile(ChatMessage m) async {
    if (m.id.startsWith('pending-')) return;
    final url = await _resolveFileUrl(m);
    if (!mounted) return;
    if (url == null) {
      _toast(_s.attachOpenFailed);
      return;
    }
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) _toast(_s.attachOpenFailed);
    } catch (_) {
      if (mounted) _toast(_s.attachOpenFailed);
    }
  }

  String _time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    final ap = d.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:$m $ap';
  }

  Future<void> _sendText(String text, {String? languageOverride}) async {
    final t = text.trim();
    if (t.isEmpty || _readOnly) return;
    final lang = languageOverride ?? AppLocalizations.of(context).locale;
    final replyId = _replyTargetId();

    // Live Supabase TEST path.
    final live = _live;
    final convId = _liveConversationId;
    if (live != null && convId != null) {
      // STATE 1 — SENDING: optimistic bubble with a clock. No checkmark is
      // shown until Supabase confirms the insert.
      final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
      setState(() {
        _messages = [
          ..._messages,
          ChatMessage(
            id: pendingId,
            kind: ChatMessageKind.text,
            sender: ChatParticipant(
              id: '${live.senderId ?? ''}',
              name: _conversation.currentUser.name,
              role: widget.role,
            ),
            originalText: t,
            originalLanguage: lang,
            sentAt: DateTime.now(),
            status: ChatDeliveryStatus.sending,
            isDemo: false,
            replyToId: replyId,
          ),
        ];
        _input.clear();
        _hasText = false;
        _replyTo = null;
      });
      _jumpToEnd();
      try {
        final sent = await live.sendText(
          conversationId: convId,
          text: t,
          language: lang,
          replyToId: replyId,
        );
        if (!mounted) return;
        setState(() {
          // Replace the pending bubble with the stored row (STATE 2 — SENT).
          // If Realtime already delivered the stored row, drop the pending one.
          final already = _messages.any((x) => x.id == sent.id);
          _messages = [
            for (final x in _messages)
              if (x.id != pendingId) x,
            if (!already) sent,
          ]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        });
        _jumpToEnd();
      } on ChatBackendException catch (e) {
        if (!mounted) return;
        _failPending(pendingId);
        if (e.issue == ChatBackendIssue.missingSenderIdentity) {
          _toast(_s.noSenderIdentity);
        } else if (replyId != null && _looksLikeMissingReplyColumn(e)) {
          _toast(_s.replyNotSavedYet);
        } else {
          _toast(
            '${_s.sendFailed} ${e.code != null ? '[${e.code}] ' : ''}${e.detail}',
          );
        }
      } catch (e) {
        if (!mounted) return;
        _failPending(pendingId);
        _toast('${_s.sendFailed} $e');
      }
      return;
    }

    final sent = await _repo.sendText(
      conversationId: _conversation.id,
      text: t,
      language: lang,
    );
    if (!mounted) return;
    setState(() {
      _messages = [
        ..._messages,
        ChatMessage(
          id: sent.id,
          kind: sent.kind,
          sender: _conversation.currentUser,
          originalText: sent.originalText,
          originalLanguage: sent.originalLanguage,
          sentAt: sent.sentAt,
          status: sent.status,
          isDemo: true,
          replyToId: replyId,
        ),
      ];
      _input.clear();
      _hasText = false;
      _replyTo = null;
    });
    _jumpToEnd();
  }

  Future<void> _toggleRecording() async {
    if (_busyRecording || _readOnly) return;
    _busyRecording = true;
    try {
      if (_pendingAudio != null) {
        // Recording was stopped (60 s limit) and kept: Send was tapped.
        await _sendPendingAudio();
      } else if (_recording) {
        // Locked recording: Send tapped.
        await _finishRecordingAndSend();
      } else {
        await _beginRecording();
      }
    } finally {
      _busyRecording = false;
    }
  }

  /// Press-and-hold on the mic: starts recording. Returns true if recording
  /// really started. Refuses while another recording / send is in flight.
  Future<bool> _holdStart() async {
    if (_busyRecording || _recording || _pendingAudio != null) return false;
    if (_readOnly) return false;
    _busyRecording = true;
    try {
      return await _beginRecording();
    } finally {
      _busyRecording = false;
    }
  }

  /// Finger released without locking: stop and send.
  Future<void> _holdRelease() async {
    if (_busyRecording || !_recording) return;
    _busyRecording = true;
    try {
      await _finishRecordingAndSend();
    } finally {
      _busyRecording = false;
    }
  }

  /// Swipe-left (before lock) or interrupted gesture: discard, never upload.
  Future<void> _holdCancel() async {
    if (_busyRecording) {
      // Start still in flight: wait briefly then discard.
      for (var i = 0; i < 20 && _busyRecording; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    if (!_recording) return;
    await _cancelRecording();
  }

  Future<bool> _beginRecording() async {
    final s = _s;
    try {
      await _audio.startRecording();
    } on ChatAudioException catch (e) {
      if (!mounted) return false;
      _showAudioFailure(e.failure, s);
      return false;
    } catch (_) {
      if (!mounted) return false;
      _toast(s.recordingFailed);
      return false;
    }
    if (!mounted) {
      await _audio.cancelRecording();
      return false;
    }
    _recTimer?.cancel();
    _elapsed = Duration.zero;
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
      if (_elapsed.inSeconds >= _maxRecordingSeconds) {
        _recTimer?.cancel();
        _autoStopAtLimit();
      }
    });
    setState(() => _recording = true);
    return true;
  }

  /// 60 s reached: stop, KEEP the audio and wait for an explicit Send.
  /// Never auto-sends and never discards the recording.
  Future<void> _autoStopAtLimit() async {
    if (_busyRecording || !_recording) return;
    _busyRecording = true;
    final s = _s;
    try {
      ChatRecordedAudio? audio;
      ChatAudioFailure? failure;
      try {
        audio = await _audio.stopRecording();
      } on ChatAudioException catch (e) {
        failure = e.failure;
      } catch (_) {
        failure = ChatAudioFailure.startFailed;
      }
      if (!mounted) return;
      if (failure != null || audio == null) {
        setState(() {
          _recording = false;
          _elapsed = Duration.zero;
        });
        _showAudioFailure(failure ?? ChatAudioFailure.startFailed, s);
        return;
      }
      setState(() {
        _recording = false;
        _elapsed = Duration(
          seconds: audio!.durationSeconds.clamp(1, _maxRecordingSeconds),
        );
        _pendingAudio = ChatRecordedAudio(
          path: audio.path,
          durationSeconds: audio.durationSeconds.clamp(1, _maxRecordingSeconds),
        );
      });
      _toast(s.recordingLimitReached);
    } finally {
      _busyRecording = false;
    }
  }

  Future<void> _sendPendingAudio() async {
    final audio = _pendingAudio;
    if (audio == null) return;
    final ok = await _sendVoice(audio);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _pendingAudio = null;
        _elapsed = Duration.zero;
      });
    } else {
      // Upload failed: keep the audio so the user can retry; nothing is lost.
      _toast(_s.voiceSendFailed);
    }
  }

  Future<void> _finishRecordingAndSend() async {
    final s = _s;
    _recTimer?.cancel();
    ChatRecordedAudio? audio;
    ChatAudioFailure? failure;
    try {
      audio = await _audio.stopRecording();
    } on ChatAudioException catch (e) {
      failure = e.failure;
    } catch (_) {
      failure = ChatAudioFailure.startFailed;
    }
    if (!mounted) return;
    setState(() {
      _recording = false;
      _elapsed = Duration.zero;
    });
    if (failure != null) {
      _showAudioFailure(failure, s);
      return;
    }
    if (audio == null) {
      _toast(s.recordingFailed);
      return;
    }
    final capped = ChatRecordedAudio(
      path: audio.path,
      durationSeconds: audio.durationSeconds.clamp(1, _maxRecordingSeconds),
    );
    final ok = await _sendVoice(capped);
    if (!ok && mounted) {
      // Keep the recording ready so the user can retry sending.
      setState(() {
        _pendingAudio = capped;
        _elapsed = Duration(seconds: capped.durationSeconds);
      });
      _toast(s.voiceSendFailed);
    }
  }

  /// Sends a recorded voice message. With a live conversation the ORIGINAL
  /// audio is uploaded to the private `chat-voice` bucket and a
  /// `chat_messages` row is created; otherwise the local demo path is used.
  /// Returns false when the upload failed (the audio is kept by the caller).
  Future<bool> _sendVoice(ChatRecordedAudio audio) async {
    final live = _live;
    final convId = _liveConversationId;
    final replyId = _replyTargetId();
    if (live != null && convId != null) {
      try {
        final sent = await live.sendVoice(
          conversationId: convId,
          localSource: audio.path,
          durationSeconds: audio.durationSeconds,
          language: _translationLang,
          replyToId: replyId,
        );
        if (!mounted) return true;
        setState(() {
          if (_messages.every((x) => x.id != sent.id)) {
            // Sender sees ONLY the original voice player: no transcription,
            // translation, retry or AI status (state stays `none`).
            _messages = [..._messages, sent];
          }
          _replyTo = null;
        });
        _jumpToEnd();
        return true;
      } catch (e) {
        debugPrint('[chat] voice send failed: $e');
        return false;
      }
    }

    final sent = await _repo.sendVoice(
      conversationId: _conversation.id,
      localPath: audio.path,
      durationSeconds: audio.durationSeconds,
    );
    if (!mounted) return true;
    setState(() {
      _messages = [
        ..._messages,
        ChatMessage(
          id: sent.id,
          kind: ChatMessageKind.voice,
          sender: _conversation.currentUser,
          sentAt: sent.sentAt,
          status: sent.status,
          voiceDurationSeconds: audio.durationSeconds,
          voiceUrl: audio.path,
          waveform: _waveformFor(audio.durationSeconds),
          isDemo: true,
          replyToId: replyId,
        ),
      ];
      _replyTo = null;
    });
    _jumpToEnd();
    return true;
  }

  /// Builds a simple deterministic waveform for a locally recorded voice
  /// message (used only by the local demo path).
  List<double> _waveformFor(int durationSeconds) {
    const bars = 32;
    return List<double>.generate(
      bars,
      (i) => 0.3 + 0.7 * (((i * 7 + durationSeconds * 3) % 10) / 10),
    );
  }

  Future<void> _cancelRecording() async {
    _recTimer?.cancel();
    final hadPending = _pendingAudio != null;
    try {
      if (hadPending) {
        // Discard a held recording (60 s limit or failed upload).
        _pendingAudio = null;
      } else {
        await _audio.cancelRecording();
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _recording = false;
      _elapsed = Duration.zero;
      _pendingAudio = null;
    });
    _toast(_s.recordingCancelled);
  }

  void _showAudioFailure(ChatAudioFailure f, ChatStrings s) {
    switch (f) {
      case ChatAudioFailure.permissionDenied:
      case ChatAudioFailure.permissionPermanentlyDenied:
        _toastWithSettings(s.micPermissionDenied, s.openSettings);
        break;
      case ChatAudioFailure.tooShort:
        _toast(s.recordingTooShort);
        break;
      case ChatAudioFailure.playbackFailed:
        _toast(s.playbackFailed);
        break;
      case ChatAudioFailure.unsupported:
        _toast(s.voiceUnavailable);
        break;
      case ChatAudioFailure.recorderBusy:
      case ChatAudioFailure.startFailed:
      case ChatAudioFailure.emptyFile:
        _toast(s.recordingFailed);
        break;
    }
  }

  void _toastWithSettings(String text, String actionLabel) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: actionLabel,
            onPressed: () {
              // Opens the OS app-settings page so the user can re-enable the
              // microphone. Skipped on web (browser manages permissions).
              if (!kIsWeb) {
                openAppSettings();
              }
            },
          ),
        ),
      );
  }

  Future<void> _togglePlay(ChatMessage m) async {
    // MUST run synchronously inside the tap, before any await (signed-URL
    // network call below): mobile browsers reject play() otherwise.
    unlockWebAudioOnGesture();
    final s = _s;
    final diag = ChatAudioDiagnostics.instance;
    final tapAt = DateTime.now();
    final storageKey = (m.voiceUrl ?? '').startsWith('sb:')
        ? m.voiceUrl!.substring(3)
        : null;
    // Stable identity of this message's audio. Signed URLs change on every
    // request and are never used to decide what is loaded.
    final stableKey = storageKey ?? 'msg:${m.id}';

    final cur = _audio.currentPlayback;

    // 1) PAUSE: decided from live player state, before any network work.
    if (cur.messageId == m.id && cur.playing) {
      diag.logEvent(
        'UI_TAP_PAUSE',
        'user tap while playing pos=${cur.position.inMilliseconds}ms',
      );
      try {
        await _audio.pause();
      } catch (_) {}
      return;
    }

    // 2) RESUME the already loaded audio of this message: no signed URL, no
    //    network, no stop()/setUrl()/seek. Direct play() on the kept source.
    if (_audio.isLoaded(m.id, sourceKey: stableKey)) {
      if (_loadingVoiceId == m.id) {
        diag.logEvent('DUPLICATE_GESTURE', 'ignored: still loading ${m.id}');
        return;
      }
      diag.logEvent(
        'UI_TAP_PLAY',
        'resume-loaded sameMsg=true pos=${cur.position.inMilliseconds}ms '
            'signedUrlFetched=false',
      );
      try {
        await _audio.play(m.id, '', sourceKey: stableKey);
      } on ChatAudioException catch (e) {
        debugPrint('[chat] resume failed message=${m.id} ${e.failure}');
        if (mounted) _showAudioFailure(e.failure, s);
      } catch (e) {
        debugPrint('[chat] resume failed message=${m.id}: $e');
        if (mounted) _toast(s.playbackFailed);
      }
      return;
    }

    // 3) FIRST LOAD (or replay after the source was cleared): fetch the
    //    signed URL, then load. Loading indicator is shown from the tap.
    if (_loadingVoiceId == m.id) {
      diag.logEvent('DUPLICATE_GESTURE', 'ignored: already loading ${m.id}');
      return;
    }
    final request = ++_playRequest;
    _setLoadingVoice(m.id);
    try {
      var src = m.voiceUrl ?? '';
      if (src.startsWith('sb:')) {
        // Stored voice from the private bucket: short-lived signed URL issued
        // by the server after verifying the viewer is a participant. The URL
        // is signed for THIS message id every time (never cached).
        final signed = await _live?.signedAudioUrl(
          src.substring(3),
          messageId: m.id,
        );
        // The user tapped another message while this one was being signed.
        if (request != _playRequest) return;
        if (signed == null) {
          debugPrint(
            '[chat] play aborted: no signed url message=${m.id} '
            'mine=${m.sender?.role == widget.role}',
          );
          if (mounted) _toast(s.playbackFailed);
          return;
        }
        src = signed;
      }
      if (src.isEmpty) {
        // Seeded demo voice messages carry no audio file; never pretend.
        _toast(s.voiceDemoNoAudio);
        return;
      }
      debugPrint(
        '[chat] play tap message=${m.id} request=$request '
        'src=${Uri.tryParse(src)?.replace(query: '').toString()}',
      );
      diag.logEvent(
        'UI_TAP_PLAY',
        'cur.playing=${cur.playing} sameMsg=${cur.messageId == m.id} '
            'signLatency=${DateTime.now().difference(tapAt).inMilliseconds}ms',
      );
      await _audio.play(m.id, src, sourceKey: stableKey);
    } on ChatAudioException catch (e) {
      debugPrint('[chat] playback failed message=${m.id} failure=${e.failure}');
      if (mounted) _showAudioFailure(e.failure, s);
    } catch (e) {
      debugPrint('[chat] playback failed message=${m.id}: $e');
      if (mounted) _toast(s.playbackFailed);
    } finally {
      if (_loadingVoiceId == m.id) _setLoadingVoice(null);
    }
  }

  /// Phase 3.2: requests (once, cached server-side) and plays the translated
  /// audio of a received voice message. The original audio is not touched.
  Future<ChatTtsStatus> _listenTranslated(
    ChatMessage m, {
    bool retry = false,
  }) async {
    // Synchronous, inside the tap: see _togglePlay.
    unlockWebAudioOnGesture();
    final live = _live;
    if (live == null) return ChatTtsStatus.unavailable;
    // The TTS target must ALWAYS be the recipient's selected chat language.
    if (live.viewerLanguage != _translationLang) {
      live.setViewerLanguage(_translationLang);
    }
    final cur = _audio.currentPlayback;
    // Tapping again while this translated audio plays pauses it.
    if (cur.messageId == 'tts:${m.id}:$_translationLang' && cur.playing) {
      await _audio.pause();
      return ChatTtsStatus.ready;
    }
    final request = ++_playRequest;
    final requestLang = _translationLang;
    final res = await live.requestTranslatedAudio(m.id, retry: retry);
    if (res.status != ChatTtsStatus.ready || res.url == null) {
      if (res.reason != null && res.reason!.isNotEmpty) {
        _ttsReasons[m.id] = res.reason!;
      } else {
        _ttsReasons.remove(m.id);
      }
      return res.status;
    }
    _ttsReasons.remove(m.id);
    try {
      debugPrint(
        '[chat] tts play message=${m.id} lang=$requestLang request=$request',
      );
      await _audio.play('tts:${m.id}:$requestLang', res.url!);
      return ChatTtsStatus.ready;
    } on ChatAudioException catch (e) {
      debugPrint('[chat] tts playback failed message=${m.id} ${e.failure}');
      return ChatTtsStatus.failed;
    } catch (e) {
      debugPrint('[chat] tts playback failed message=${m.id}: $e');
      return ChatTtsStatus.failed;
    }
  }

  Future<void> _call() async {
    final p = (widget.counterpartPhone ?? '').replaceAll(
      RegExp(r'[\s\-\(\)]'),
      '',
    );
    if (p.isEmpty) {
      _toast(_s.callUnavailable);
      return;
    }
    try {
      await launchUrl(Uri.parse('tel:$p'));
    } catch (_) {
      _toast(_s.callUnavailable);
    }
  }

  void _showDetails() {
    final s = _s;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.chatDetails,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                s.chatDetailsBody,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              if (_live != null && !_readOnly) ...[
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _confirmDeleteConversation();
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    label: Text(
                      s.deleteConversation,
                      style: GoogleFonts.inter(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(s.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Delete message / conversation
  // ---------------------------------------------------------------------

  /// Placeholder shown in place of a message removed for everyone. It never
  /// renders the original text, image, file or audio player.
  Widget _buildDeletedBubble(ChatStrings s, ChatMessage m, bool mine) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 16, color: AppTheme.secondaryText),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              s.messageDeleted,
              style: GoogleFonts.inter(
                color: AppTheme.secondaryText,
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _time(m.sentAt),
            style: GoogleFonts.inter(
              color: AppTheme.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onMessageLongPress(ChatMessage m, bool mine) async {
    if (m.isSystem || m.deletedForEveryone) return;
    final s = _s;
    final canEveryone = mine && _live != null && !_readOnly;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.cardWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
                title: Text(
                  s.deleteForMe,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(ctx).pop('me'),
              ),
              if (canEveryone)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    s.deleteForEveryone,
                    style: GoogleFonts.inter(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop('everyone'),
                ),
              ListTile(
                leading: Icon(
                  Icons.close_rounded,
                  color: AppTheme.secondaryText,
                ),
                title: Text(
                  s.cancel,
                  style: GoogleFonts.inter(color: AppTheme.secondaryText),
                ),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;
    final forEveryone = action == 'everyone';
    final ok = await _confirm(
      title: s.deleteMessageTitle,
      body: forEveryone ? s.deleteForEveryoneBody : s.deleteForMeBody,
      confirmLabel: forEveryone ? s.deleteForEveryone : s.deleteForMe,
    );
    if (ok != true || !mounted) return;
    await _deleteMessage(m, forEveryone: forEveryone);
  }

  // ---------------------------------------------------------------------
  // Reply / reactions / long-press overlay
  // ---------------------------------------------------------------------

  /// Only persisted (non pending / non local) messages can be referenced.
  String? _replyTargetId() {
    final r = _replyTo;
    if (r == null) return null;
    if (r.isDemo || r.id.startsWith('pending-')) return null;
    return r.id;
  }

  bool _looksLikeMissingReplyColumn(ChatBackendException e) {
    final d = e.detail.toLowerCase();
    return d.contains('reply_to_message_id') || e.code == 'PGRST204';
  }

  String _senderLabel(ChatMessage m) {
    if (_isMine(m)) return _s.you;
    final n = (m.sender?.name ?? '').trim();
    return n.isEmpty ? _conversation.counterpart.name : n;
  }

  void _startReply(ChatMessage m) {
    if (_readOnly || m.isSystem || m.deletedForEveryone) return;
    if (m.id.startsWith('pending-')) return;
    setState(() => _replyTo = m);
    // Focus after the preview bar is laid out so the keyboard opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _inputFocus.requestFocus();
    });
  }

  Widget _buildReplyPreview(ChatStrings s) {
    final r = _replyTo!;
    return ChatReplyPreviewBar(
      senderName: _senderLabel(r),
      snippet: chatMessageSnippet(r, s),
      isVoice: r.isVoice,
      isFile: r.isFile,
      onCancel: () => setState(() => _replyTo = null),
    );
  }

  ChatMessage? _findMessage(String? id) {
    if (id == null) return null;
    for (final x in _messages) {
      if (x.id == id) return x;
    }
    return null;
  }

  /// Reply originals outside the loaded window (preview only; never part of
  /// the chronological list, so pagination / ordering are unaffected).
  final Map<String, ChatMessage> _replyOriginals = <String, ChatMessage>{};
  final Set<String> _replyOriginalsRequested = <String>{};
  bool _navigatingToOriginal = false;

  Future<void> _resolveReplyOriginals() async {
    final live = _live;
    final convId = _liveConversationId;
    if (live == null || convId == null || !mounted) return;
    final known = {for (final m in _messages) m.id};
    final missing = <String>{
      for (final m in _messages)
        if (m.replyToId != null &&
            !known.contains(m.replyToId) &&
            !_replyOriginals.containsKey(m.replyToId) &&
            !_replyOriginalsRequested.contains(m.replyToId))
          m.replyToId!,
    };
    if (missing.isEmpty) return;
    _replyOriginalsRequested.addAll(missing);
    final found = await live.loadMessagesByIds(convId, missing.toList());
    if (!mounted || found.isEmpty) return;
    setState(() {
      for (final f in found) {
        _replyOriginals[f.id] = f;
      }
    });
  }

  Future<void> _scrollToOriginal(String id) async {
    // Rapid repeated taps: ignore while a navigation is already running.
    if (_navigatingToOriginal) return;
    _navigatingToOriginal = true;
    try {
      // 1) Already loaded: scroll straight to it.
      if (_findMessage(id) == null) {
        // 2) Not loaded: fetch it (and its neighbours) from the backend,
        //    scoped to this conversation so access rules still apply.
        final live = _live;
        final convId = _liveConversationId;
        if (live == null || convId == null) {
          _toast(_s.originalNotFound);
          return;
        }
        List<ChatMessage> window;
        try {
          window = await live.loadAroundMessage(convId, id);
        } catch (_) {
          _toast(_s.originalNotFound);
          return;
        }
        if (!mounted) return;
        if (!window.any((x) => x.id == id)) {
          _toast(_s.originalNotFound);
          return;
        }
        List<ChatReaction> reactions = const [];
        try {
          reactions = await live.loadReactions(convId);
        } catch (_) {}
        if (!mounted) return;
        final known = {for (final m in _messages) m.id};
        final added = _withReactions([
          for (final m in window)
            if (!known.contains(m.id)) m,
        ], reactions);
        if (added.isNotEmpty) {
          setState(() {
            _messages = [..._messages, ...added]
              ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
          });
          _requestPendingTranslations();
          _requestPendingTranscriptions();
        }
        // Wait for the row to be laid out before scrolling to it.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
      var ctx = _rowKeys[id]?.currentContext;
      if (ctx == null) {
        await WidgetsBinding.instance.endOfFrame;
        ctx = _rowKeys[id]?.currentContext;
      }
      if (ctx == null || !mounted) {
        _toast(_s.originalNotFound);
        return;
      }
      await Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      _highlightTimer?.cancel();
      setState(() => _highlightId = id);
      _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _highlightId = null);
      });
    } finally {
      _navigatingToOriginal = false;
    }
  }

  List<ChatMessage> _withReactions(
    List<ChatMessage> msgs,
    List<ChatReaction> reactions,
  ) {
    if (reactions.isEmpty) return msgs;
    final byMsg = <String, List<ChatReaction>>{};
    for (final r in reactions) {
      byMsg.putIfAbsent(r.messageId, () => <ChatReaction>[]).add(r);
    }
    return [
      for (final m in msgs)
        byMsg.containsKey(m.id) ? m.copyWith(reactions: byMsg[m.id]) : m,
    ];
  }

  String? get _viewerId =>
      _live?.senderId == null ? null : '${_live!.senderId}';

  bool _isViewerReaction(ChatReaction r) =>
      r.reactorRole == widget.role && r.reactorId == _viewerId;

  String? _myReactionOn(ChatMessage m) {
    for (final r in m.reactions) {
      if (_isViewerReaction(r)) return r.emoji;
    }
    return null;
  }

  void _replaceReactions(String messageId, List<ChatReaction> next) {
    final idx = _messages.indexWhere((x) => x.id == messageId);
    if (idx < 0) return;
    setState(() {
      _messages = [
        for (final x in _messages)
          x.id == messageId ? x.copyWith(reactions: next) : x,
      ];
    });
  }

  void _onReactionUpsert(ChatReaction r) {
    if (!mounted) return;
    final m = _findMessage(r.messageId);
    if (m == null) return;
    final next = [
      for (final x in m.reactions)
        if (!(x.reactorRole == r.reactorRole && x.reactorId == r.reactorId)) x,
      r,
    ];
    _replaceReactions(m.id, next);
  }

  void _onReactionRemoval(ChatReaction r) {
    if (!mounted) return;
    final m = _findMessage(r.messageId);
    if (m == null) return;
    final next = [
      for (final x in m.reactions)
        if (!(x.reactorRole == r.reactorRole && x.reactorId == r.reactorId)) x,
    ];
    _replaceReactions(m.id, next);
  }

  /// Selecting the same emoji again removes the reaction; a different one
  /// replaces it. Persisted through the backend; rolled back on failure.
  Future<void> _react(ChatMessage m, String emoji) async {
    final live = _live;
    final viewerId = _viewerId;
    if (_readOnly || m.deletedForEveryone) return;
    if (live == null || viewerId == null || m.isDemo) {
      _toast(_s.featureNotAvailable);
      return;
    }
    final previous = List<ChatReaction>.of(m.reactions);
    final mine = _myReactionOn(m);
    final removing = mine == emoji;
    final others = [
      for (final x in previous)
        if (!_isViewerReaction(x)) x,
    ];
    final optimistic = removing
        ? others
        : [
            ...others,
            ChatReaction(
              messageId: m.id,
              reactorRole: widget.role,
              reactorId: viewerId,
              emoji: emoji,
            ),
          ];
    HapticFeedback.selectionClick();
    _replaceReactions(m.id, optimistic);
    try {
      await live.setReaction(m.id, removing ? '' : emoji);
    } catch (e) {
      debugPrint('[chat] reaction failed: $e');
      if (!mounted) return;
      _replaceReactions(m.id, previous);
      _toast(_s.reactionFailed);
    }
  }

  Future<void> _copyMessage(ChatMessage m) async {
    final text = chatMessageCopyText(m);
    if (text.isEmpty) {
      _toast(_s.nothingToCopy);
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast(_s.copied);
  }

  /// Text that Copy puts on the clipboard (text messages only).
  String chatMessageCopyText(ChatMessage m) {
    if (m.isVoice || m.isFile || m.isSystem || m.deletedForEveryone) return '';
    return (m.hasTranslation ? m.translatedText! : m.originalText).trim();
  }

  void _openMessageOverlay(
    ChatMessage m,
    bool mine,
    Widget Function() buildSnapshot,
  ) {
    if (m.isSystem || m.deletedForEveryone) return;
    final box = _bubbleKey(m.id).currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      _onMessageLongPress(m, mine);
      return;
    }
    final origin = box.localToGlobal(Offset.zero);
    final anchor = origin & box.size;
    final s = _s;
    HapticFeedback.mediumImpact();
    final canInteract = !_readOnly && !m.id.startsWith('pending-');
    showChatMessageOverlay(
      context: context,
      anchor: anchor,
      snapshot: buildSnapshot(),
      mine: mine,
      currentEmoji: _myReactionOn(m),
      strings: s,
      canReact: canInteract && _live != null && !m.isDemo,
      onReact: (e) => _react(m, e),
      actions: [
        if (canInteract)
          ChatMenuAction(
            icon: Icons.reply_rounded,
            label: s.reply,
            onTap: () => _startReply(m),
          ),
        ChatMenuAction(
          icon: Icons.shortcut_rounded,
          label: s.forward,
          disabled: true,
          onTap: () => _toast(s.featureNotAvailable),
        ),
        if (chatMessageCopyText(m).isNotEmpty)
          ChatMenuAction(
            icon: Icons.copy_rounded,
            label: s.copy,
            onTap: () => _copyMessage(m),
          ),
        ChatMenuAction(
          icon: Icons.star_border_rounded,
          label: s.star,
          disabled: true,
          onTap: () => _toast(s.featureNotAvailable),
        ),
        ChatMenuAction(
          icon: Icons.delete_outline_rounded,
          label: s.deleteAction,
          destructive: true,
          onTap: () => _onMessageLongPress(m, mine),
        ),
        ChatMenuAction(
          icon: Icons.more_horiz_rounded,
          label: s.more,
          onTap: () => _onMessageLongPress(m, mine),
        ),
      ],
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    final s = _s;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: AppTheme.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          body,
          style: GoogleFonts.inter(color: AppTheme.secondaryText, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stops the shared player when it is playing (or holding) audio that
  /// belongs to [messageId] - original or translated. Uses the existing
  /// pause API only; playback logic itself is untouched.
  void _stopAudioIfPlaying(String messageId) {
    final cur = _audio.currentPlayback;
    final id = cur.messageId;
    if (id == null) return;
    if (id == messageId || id.startsWith('tts:$messageId:')) {
      ChatAudioDiagnostics.instance.logEvent(
        'UI_STOP_IF_PLAYING',
        'message removed/deleted -> pause()',
      );
      _playRequest++;
      _audio.pause();
    }
  }

  void _applyLocalRemoval(String messageId, {required bool tombstone}) {
    _stopAudioIfPlaying(messageId);
    setState(() {
      _messages = tombstone
          ? [
              for (final x in _messages)
                x.id == messageId
                    ? ChatMessage(
                        id: x.id,
                        kind: x.kind,
                        sender: x.sender,
                        sentAt: x.sentAt,
                        status: x.status,
                        readAt: x.readAt,
                        isDemo: x.isDemo,
                        deletedForEveryone: true,
                      )
                    : x,
            ]
          : [
              for (final x in _messages)
                if (x.id != messageId) x,
            ];
    });
  }

  Future<void> _deleteMessage(
    ChatMessage m, {
    required bool forEveryone,
  }) async {
    final s = _s;
    final live = _live;
    // Demo / offline messages: local only (fake ids never reach the backend).
    if (m.isDemo || live == null) {
      _applyLocalRemoval(m.id, tombstone: forEveryone);
      _toast(s.messageDeletedToast);
      return;
    }
    try {
      if (forEveryone) {
        await live.deleteMessageForEveryone(m.id);
      } else {
        await live.deleteMessageForMe(m.id);
      }
      if (!mounted) return;
      _applyLocalRemoval(m.id, tombstone: forEveryone);
      _toast(s.messageDeletedToast);
    } on ChatBackendException catch (e) {
      debugPrint('[chat] delete failed: ${e.issue} ${e.detail}');
      if (!mounted) return;
      _toast(
        e.issue == ChatBackendIssue.attachmentsNotDeployed
            ? s.deleteNotAvailable
            : s.deleteFailed,
      );
    } catch (e) {
      debugPrint('[chat] delete failed: $e');
      if (mounted) _toast(s.deleteFailed);
    }
  }

  /// A deletion made by the sender on another device (Realtime UPDATE).
  void _onRemoteDeletion(String messageId) {
    if (!mounted) return;
    final idx = _messages.indexWhere((x) => x.id == messageId);
    if (idx < 0 || _messages[idx].deletedForEveryone) return;
    _applyLocalRemoval(messageId, tombstone: true);
  }

  Future<void> _confirmDeleteConversation() async {
    final s = _s;
    final ok = await _confirm(
      title: s.deleteConversationTitle,
      body: s.deleteConversationBody,
      confirmLabel: s.deleteConversation,
    );
    if (ok != true || !mounted) return;
    final live = _live;
    final convId = _liveConversationId;
    if (live == null || convId == null) {
      _toast(s.deleteNotAvailable);
      return;
    }
    try {
      _audio.pause();
      await live.deleteConversationForMe(convId);
      if (!mounted) return;
      _toast(s.conversationDeleted);
      Navigator.of(context).maybePop();
    } on ChatBackendException catch (e) {
      debugPrint('[chat] delete conversation failed: ${e.issue} ${e.detail}');
      if (!mounted) return;
      _toast(
        e.issue == ChatBackendIssue.attachmentsNotDeployed
            ? s.deleteNotAvailable
            : s.deleteFailed,
      );
    } catch (e) {
      debugPrint('[chat] delete conversation failed: $e');
      if (mounted) _toast(s.deleteFailed);
    }
  }

  Widget _buildHeader(ChatStrings s) {
    final other = _conversation.counterpart;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _circleButton(
            isRtl
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          ChatAvatar(participant: other, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  other.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _buildPresenceLine(s, other.role),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _globeButton(),
          const SizedBox(width: 8),
          _circleButton(Icons.call_rounded, _call),
          const SizedBox(width: 8),
          _circleButton(Icons.more_vert_rounded, _showDetails),
        ],
      ),
    );
  }

  /// Real presence of the other participant (Supabase Realtime Presence at
  /// app/session level). Read-only here: opening/closing the chat never
  /// changes anyone's presence.
  Widget _buildPresenceLine(ChatStrings s, ChatRole otherRole) {
    return ValueListenableBuilder<int>(
      valueListenable: ChatPresenceService.instance.changes,
      builder: (context, _, __) {
        final online = ChatPresenceService.instance.isCounterpartOnline(
          counterpartRole: otherRole == ChatRole.driver ? 'driver' : 'customer',
          bookingReference: _conversation.bookingReference,
          bookingId: widget.odooBookingId,
        );
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online
                    ? const Color(0xFF34C759)
                    : const Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                online ? s.online : s.offline,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTripCard(ChatStrings s) {
    final title = (widget.tripTitle ?? '').trim().isNotEmpty
        ? widget.tripTitle!.trim()
        : _conversation.tripTitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.directions_car_filled_rounded,
              color: AppTheme.luxuryAccent,
              size: 34,
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.currentTrip,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoBanner(ChatStrings s) {
    final live = _live != null;
    if (_loading || live) {
      return const SizedBox.shrink();
    }
    if (_backendError == null) {
      return const SizedBox.shrink();
    }
    final String message = '${s.backendBlockedTitle}: $_backendError';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.softGoldBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: AppTheme.luxuryAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: message.contains('[JWT-DIAG]')
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          message,
                          style: GoogleFonts.inter(
                            color: AppTheme.navyText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      message,
                      style: GoogleFonts.inter(
                        color: AppTheme.navyText,
                        fontSize: 12,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(ChatStrings s, DateTime d) {
    const months = [
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
    ];
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.isDarkActive
              ? AppTheme.darkCard
              : const Color(0xFFF1EEE8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${s.today}, ${d.day} ${months[d.month - 1]}',
          style: GoogleFonts.inter(
            color: AppTheme.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _isMine(ChatMessage m) {
    final sender = m.sender;
    if (sender == null) return false;
    // Live (Supabase) messages: ownership is the sender role plus, when
    // known, the authenticated sender id. The role is stored server-side.
    if (!m.isDemo) {
      final myId = _live?.senderId;
      if (myId != null && sender.id == '$myId') return true;
      return sender.role == widget.role && myId == null;
    }
    // Demo history: the viewer's own side is determined by role only.
    // Real ownership comes from the authenticated Odoo identity in Phase 2.
    if (sender.id == _conversation.currentUser.id) return true;
    if (widget.role == ChatRole.customer) {
      return sender.role == ChatRole.customer;
    }
    // Driver viewer: only the currently assigned demo driver is "me";
    // earlier driver (Alico) stays identified as a previous author.
    return sender.id == ChatDemoData.demoDriverGiorgi.id;
  }

  Widget _buildMessages(ChatStrings s) {
    final children = <Widget>[];
    if (_messages.isNotEmpty) {
      children.add(_dateChip(s, _messages.first.sentAt));
    }
    for (final m in _messages) {
      if (m.isSystem) {
        children.add(
          ChatSystemMessage(
            newDriverName: m.originalText,
            timeLabel: _time(m.sentAt),
            strings: s,
          ),
        );
        continue;
      }
      final mine = _isMine(m);
      // Live messages always show the real stored sender name/role.
      // Demo messages keep the previous mapping (own side = current user).
      final ChatParticipant? sender = !m.isDemo
          ? _withProfilePhoto(m.sender, mine)
          : (mine
                ? _conversation.currentUser
                : (m.sender?.role == _conversation.counterpart.role &&
                          m.sender?.id == ChatDemoData.demoCustomerMeir.id
                      ? _conversation.counterpart
                      : m.sender));
      children.add(_buildRow(s, m, mine, sender));
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      children: children,
    );
  }

  /// Attaches the real profile photo to a stored sender (same name, id and
  /// role; only `photoUrl` is added).
  /// * Viewer's own messages -> the viewer's photo.
  /// * Counterpart messages -> the counterpart's photo ONLY when the stored
  ///   sender id equals the current counterpart's Odoo id. Messages from a
  ///   previous (replaced) driver keep their own identity and get no photo
  ///   of the newly assigned driver.
  ChatParticipant? _withProfilePhoto(ChatParticipant? sender, bool mine) {
    if (sender == null) return null;
    String? photo;
    if (mine) {
      photo = _conversation.currentUser.photoUrl;
    } else if (sender.role == _conversation.counterpart.role) {
      final cid = widget.counterpartOdooId;
      if (cid != null && sender.id == '$cid') {
        photo = _conversation.counterpart.photoUrl;
      }
    }
    if (photo == null || photo.trim().isEmpty) return sender;
    return ChatParticipant(
      id: sender.id,
      name: sender.name,
      role: sender.role,
      photoUrl: photo,
    );
  }

  Widget _buildRow(
    ChatStrings s,
    ChatMessage m,
    bool mine,
    ChatParticipant? sender,
  ) {
    final Widget content = m.deletedForEveryone
        ? _buildDeletedBubble(s, m, mine)
        : m.isFile
        ? ChatFileBubble(
            message: m,
            isMine: mine,
            strings: s,
            timeLabel: _time(m.sentAt),
            onOpen: () => _openFile(m),
            localBytes: _pendingFileBytes[m.id],
            resolveUrl: ({bool forceRefresh = false}) =>
                _resolveFileUrl(m, forceRefresh: forceRefresh),
          )
        : m.isVoice
        ? ChatVoiceBubble(
            key: ValueKey<String>('voice-${m.id}'),
            message: m,
            isMine: mine,
            sender: sender,
            playback: _audio.playbackState,
            initialPlayback: _audio.currentPlayback,
            timeLabel: _time(m.sentAt),
            strings: s,
            translationLanguage: _translationLang,
            failureReason: _transcriptionErrors[m.id],
            onListenTranslated: _live == null
                ? null
                : ({bool retry = false}) => _listenTranslated(m, retry: retry),
            ttsReasonProvider: () => _ttsReasons[m.id],
            onRetryTranscription:
                m.transcriptionState == ChatTranscriptionState.failed &&
                    !_isPermanentSttError(_transcriptionErrors[m.id])
                ? () => _retryTranscription(m)
                : null,
            onTogglePlay: () => _togglePlay(m),
            loadingMessageId: _loadingVoiceNotifier,
          )
        : ChatTextBubble(
            message: m,
            isMine: mine,
            strings: s,
            timeLabel: _time(m.sentAt),
            translationLanguage: _translationLang,
          );

    // Quoted original (persisted reference) shown inside the sent bubble.
    final quoted = m.deletedForEveryone
        ? null
        : (_findMessage(m.replyToId) ??
              (m.replyToId == null ? null : _replyOriginals[m.replyToId]));
    final hasQuote = !m.deletedForEveryone && m.replyToId != null;
    final Widget? quoteWidget = !hasQuote
        ? null
        : ChatQuotedMessage(
            senderName: quoted == null ? '' : _senderLabel(quoted),
            snippet: quoted == null
                ? s.originalNotFound
                : chatMessageSnippet(quoted, s),
            isVoice: quoted?.isVoice ?? false,
            isFile: quoted?.isFile ?? false,
            deleted: quoted == null || quoted.deletedForEveryone,
            onTap: quoted == null ? null : () => _scrollToOriginal(quoted.id),
          );

    // Static look-alike used only inside the long-press overlay. The live
    // voice bubble (audio streams / ValueKey) is never duplicated.
    Widget snapshot() {
      if (m.isVoice) {
        return _overlayVoiceSnapshot(s, m, mine);
      }
      if (m.isFile) {
        if (chatMediaKindOf(m) == ChatMediaKind.image) {
          return ChatOverlayImage(
            message: m,
            localBytes: _pendingFileBytes[m.id],
            width: (MediaQuery.of(context).size.width * 0.74).clamp(
              180.0,
              300.0,
            ),
            resolveUrl: ({bool forceRefresh = false}) =>
                _resolveFileUrl(m, forceRefresh: forceRefresh),
          );
        }
        return _overlayFileSnapshot(s, m);
      }
      return Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (quoteWidget != null) quoteWidget,
          ChatTextBubble(
            message: m,
            isMine: mine,
            strings: s,
            timeLabel: _time(m.sentAt),
            translationLanguage: _translationLang,
          ),
        ],
      );
    }

    final highlighted = _highlightId == m.id;
    final canSwipe =
        !_readOnly && !m.deletedForEveryone && !m.id.startsWith('pending-');

    final Widget bubbleBody = Column(
      crossAxisAlignment: mine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [if (quoteWidget != null) quoteWidget, content],
    );

    final Widget bubble = m.deletedForEveryone
        ? content
        : ChatSwipeToReply(
            enabled: canSwipe,
            onReply: () => _startReply(m),
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onLongPress: () => _openMessageOverlay(m, mine, snapshot),
              child: KeyedSubtree(key: _bubbleKey(m.id), child: bubbleBody),
            ),
          );

    final Widget reactions = ChatReactionsRow(
      reactions: m.reactions,
      viewerRole: widget.role,
      viewerId: _viewerId,
      onTapEmoji: (e) => _react(m, e),
    );

    return AnimatedContainer(
      key: _rowKey(m.id),
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.luxuryAccent.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        key: ValueKey<String>('chat-row-${m.id}'),
        padding: const EdgeInsetsDirectional.only(bottom: 4, start: 4, end: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: mine
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!mine && !m.isVoice) ...[
              ChatAvatar(participant: sender, size: 40),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: mine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      bottom: 4,
                      start: 4,
                      end: 4,
                    ),
                    child: Text(
                      sender?.name ?? '',
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  bubble,
                  if (!m.deletedForEveryone) reactions,
                ],
              ),
            ),
            if (mine && !m.isVoice) ...[
              const SizedBox(width: 10),
              ChatAvatar(participant: sender, size: 40),
            ],
          ],
        ),
      ),
    );
  }

  Widget _overlayVoiceSnapshot(ChatStrings s, ChatMessage m, bool mine) {
    final secs = m.voiceDurationSeconds ?? 0;
    final label =
        '${(secs ~/ 60).toString()}:${(secs % 60).toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: mine ? AppTheme.softGoldBg : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: mine ? Colors.transparent : AppTheme.borderColor,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_rounded, color: AppTheme.secondaryText),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '${s.voiceMessageLabel}  $label',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlayFileSnapshot(ChatStrings s, ChatMessage m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file_rounded, color: AppTheme.secondaryText),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              chatMessageSnippet(m, s),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.primaryText,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
