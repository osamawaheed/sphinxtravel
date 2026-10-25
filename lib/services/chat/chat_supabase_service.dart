import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/chat_models.dart';
import './chat_audio_diagnostics.dart';
import './chat_services.dart';
import './chat_voice_io.dart';

/// Why a Supabase chat operation failed. The exact backend message is kept in
/// [detail] so it can be reported (RLS / auth / missing row) instead of being
/// hidden or "fixed" by weakening security.
enum ChatBackendIssue {
  notConfigured,
  conversationNotFound,
  missingBookingId,
  conversationCreateBlocked,
  rlsOrAuthBlocked,
  missingSenderIdentity,
  network,

  /// Attachment migration (`tourops_test_chat_attachments.sql`) not applied.
  attachmentsNotDeployed,
  unknown,
}

class ChatBackendException implements Exception {
  final ChatBackendIssue issue;
  final String detail;
  final String? code;
  const ChatBackendException(this.issue, this.detail, {this.code});

  @override
  String toString() => 'ChatBackendException($issue, code=$code): $detail';
}

/// Supabase TEST-database implementation of the chat repository.
///
/// * Uses only SUPABASE_URL / SUPABASE_ANON_KEY (via the initialized client).
/// * Never creates conversations: `odoo_booking_id` is NOT NULL and the numeric
///   Odoo id is not known to Flutter. The conversation must already exist.
/// * Never calls the protected `chat-translate` Edge Function (it needs a
///   server-side internal token). Translations are READ from
///   `chat_translations`, written server-side.
/// * Never bypasses RLS: if access is blocked, the exact error is surfaced.
class SupabaseChatRepository {
  SupabaseChatRepository({
    required this.viewerRole,
    required this.viewerName,
    required String viewerLanguage,
    required this.senderId,
  }) : _viewerLanguage = viewerLanguage;

  final ChatRole viewerRole;
  final String viewerName;

  /// Chat translation language of the viewer (independent of the app
  /// interface language). Changeable at runtime via [setViewerLanguage].
  String _viewerLanguage;
  String get viewerLanguage => _viewerLanguage;

  /// Authenticated Odoo sender id, or the explicit negative TEST id.
  /// Null => sending is refused (no impersonation / invented identity).
  final int? senderId;

  RealtimeChannel? _channel;
  final StreamController<ChatMessage> _incoming =
      StreamController<ChatMessage>.broadcast();

  SupabaseClient get _client => Supabase.instance.client;

  bool get isConfigured {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  ChatBackendException _map(Object e) {
    if (e is PostgrestException) {
      final msg =
          '${e.message}${(e.details ?? '').toString().isNotEmpty ? ' — ${e.details}' : ''}';
      final code = e.code;
      final blocked =
          code == '42501' ||
          code == 'PGRST301' ||
          code == '401' ||
          code == '403' ||
          msg.toLowerCase().contains('row-level security') ||
          msg.toLowerCase().contains('permission denied') ||
          msg.toLowerCase().contains('jwt');
      return ChatBackendException(
        blocked ? ChatBackendIssue.rlsOrAuthBlocked : ChatBackendIssue.unknown,
        msg,
        code: code,
      );
    }
    final s = e.toString();
    if (s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Failed host lookup')) {
      return ChatBackendException(ChatBackendIssue.network, s);
    }
    return ChatBackendException(ChatBackendIssue.unknown, s);
  }

  /// Fetches the single existing conversation for a booking reference.
  /// Returns its uuid. Throws [ChatBackendException] with the exact reason.
  Future<String> findConversationId(String bookingReference) async {
    if (!isConfigured) {
      throw const ChatBackendException(
        ChatBackendIssue.notConfigured,
        'Supabase is not initialized (SUPABASE_URL / SUPABASE_ANON_KEY missing).',
      );
    }
    try {
      final rows = await _client
          .from('chat_conversations')
          .select('id, booking_reference')
          .eq('booking_reference', bookingReference)
          .order('created_at', ascending: true)
          .limit(1);
      if (rows.isEmpty) {
        // An empty result is either "no such row" or RLS silently filtering
        // every row for the anon role. Both are reported honestly.
        throw ChatBackendException(
          ChatBackendIssue.conversationNotFound,
          'No chat_conversations row visible for booking_reference '
          '"$bookingReference". Either it does not exist, or RLS hides it '
          'from the current role (anon).',
        );
      }
      return rows.first['id'] as String;
    } on ChatBackendException {
      rethrow;
    } catch (e) {
      throw _map(e);
    }
  }

  /// Finds the conversation for a booking; if missing, creates it ONLY when a
  /// real Odoo booking id is supplied. The id is never guessed or derived from
  /// the reference. Uses the normal anon/authenticated client under RLS.
  ///
  /// Duplicate prevention: lookup by `booking_reference` first, and
  /// `odoo_booking_id` is UNIQUE in the database. A concurrent insert that
  /// hits the unique constraint (23505) is resolved by re-reading the row.
  Future<String> ensureConversation(
    String bookingReference, {
    int? odooBookingId,
  }) async {
    try {
      return await findConversationId(bookingReference);
    } on ChatBackendException catch (e) {
      if (e.issue != ChatBackendIssue.conversationNotFound) rethrow;
      final bookingId = odooBookingId;
      if (bookingId == null || bookingId <= 0) {
        throw ChatBackendException(
          ChatBackendIssue.missingBookingId,
          'No conversation exists for "$bookingReference" and the real Odoo '
          'booking id is not available to the app, so none was created '
          '(the id is never invented). Backend change required: expose the '
          'Odoo booking id for this booking, or create the chat_conversations '
          'row server-side.',
        );
      }
      return _createConversation(bookingReference, bookingId);
    }
  }

  Future<String> _createConversation(
    String bookingReference,
    int odooBookingId,
  ) async {
    try {
      final row = await _client
          .from('chat_conversations')
          .insert({
            'odoo_booking_id': odooBookingId,
            'booking_reference': bookingReference,
          })
          .select('id')
          .single();
      return row['id'] as String;
    } on PostgrestException catch (e) {
      // Unique violation => another client created it first. Reuse it.
      if (e.code == '23505') {
        final existing = await _client
            .from('chat_conversations')
            .select('id')
            .eq('odoo_booking_id', odooBookingId)
            .limit(1);
        if (existing.isNotEmpty) return existing.first['id'] as String;
      }
      final mapped = _map(e);
      if (mapped.issue == ChatBackendIssue.rlsOrAuthBlocked) {
        throw ChatBackendException(
          ChatBackendIssue.conversationCreateBlocked,
          'Creating the conversation for "$bookingReference" '
          '(odoo_booking_id=$odooBookingId) was refused by the database: '
          '${mapped.detail}. Backend change required: add an INSERT RLS '
          'policy on public.chat_conversations for the app role, or create '
          'the row server-side (Odoo / Edge Function with a service role).',
          code: e.code,
        );
      }
      throw mapped;
    } catch (e) {
      if (e is ChatBackendException) rethrow;
      throw _map(e);
    }
  }

  ChatParticipant _participantFrom(Map<String, dynamic> row) {
    final role = (row['sender_role'] as String?) == 'driver'
        ? ChatRole.driver
        : ChatRole.customer;
    return ChatParticipant(
      id: '${row['odoo_sender_id']}',
      name: (row['sender_name'] as String?) ?? '',
      role: role,
    );
  }

  ChatMessage _messageFrom(
    Map<String, dynamic> row, {
    Map<String, String>? translationsByMessage,
    Map<String, Map<String, String>> voiceTranscripts = const {},
  }) {
    final isVoice = row['message_type'] == 'voice';
    final isFile = row['message_type'] == 'file';
    final id = row['id'] as String;
    final lang = (row['original_language'] as String?) ?? 'en';
    final translated = translationsByMessage?[id];
    final text = (row['original_text'] as String?) ?? '';
    // Do not trust the sender's interface language: detect by script. Latin
    // text is ambiguous (English vs Azerbaijani) and is resolved server-side.
    final scriptLang = _detectLanguage(text);
    final latinAmbiguous = scriptLang == 'en';
    final detected = scriptLang ?? lang;
    final isIncoming =
        (row['sender_role'] as String?) !=
        (viewerRole == ChatRole.driver ? 'driver' : 'customer');
    // Latin text may be English or Azerbaijani, so the server decides.
    // Other scripts are decided locally.
    final needsTranslation =
        !isVoice &&
        !isFile &&
        isIncoming &&
        (latinAmbiguous ? true : detected != viewerLanguage);

    ChatTranslationState state = ChatTranslationState.notRequired;
    if (needsTranslation) {
      state = (translated ?? '').isNotEmpty
          ? ChatTranslationState.translated
          : ChatTranslationState.pending;
    }

    // Voice (Phase 3.1): transcript + translation arrive from the server.
    // The audio is always playable regardless of these states.
    final voiceAudioPath = isVoice ? (row['audio_path'] as String?) : null;
    final voiceTranscript = isVoice ? voiceTranscripts[id] : null;
    ChatTranscriptionState tState = ChatTranscriptionState.none;
    String? tText;
    String? tLang;
    String? vTranslated;
    ChatTranslationState vState = ChatTranslationState.notRequired;
    if (isVoice && voiceAudioPath != null && isIncoming) {
      // Only the RECIPIENT gets transcript / translation. The sender's own
      // voice messages stay as a plain player (state `none`).
      if (voiceTranscript != null &&
          (voiceTranscript['transcript_text'] ?? '').isNotEmpty) {
        final storedLang = (voiceTranscript['detected_language'] ?? '').trim();
        if (storedLang.isEmpty) {
          // Transcript saved earlier without a language: let the server
          // re-resolve it (no new OpenAI call) so the translation and
          // "Listen Translated" become available.
          tState = ChatTranscriptionState.pending;
        } else {
          tState = ChatTranscriptionState.ready;
          tText = voiceTranscript['transcript_text'];
          tLang = storedLang;
          if (tLang != viewerLanguage) {
            vTranslated = translated;
            vState = (translated ?? '').isNotEmpty
                ? ChatTranslationState.translated
                : ChatTranslationState.pending;
          }
        }
      } else {
        tState = ChatTranscriptionState.pending;
      }
    }

    return ChatMessage(
      id: id,
      kind: isFile
          ? ChatMessageKind.file
          : (isVoice ? ChatMessageKind.voice : ChatMessageKind.text),
      sender: _participantFrom(row),
      originalText: isVoice ? '' : text,
      // For ambiguous Latin text keep the stored language when it is a Latin
      // one (en/az); the server returns the authoritative source language.
      originalLanguage: isVoice
          ? (tLang ?? lang)
          : (latinAmbiguous && (lang == 'en' || lang == 'az')
                ? lang
                : detected),
      translatedText: isVoice ? vTranslated : translated,
      translationState: isVoice ? vState : state,
      transcriptText: tText,
      transcriptLanguage: tLang,
      transcriptionState: tState,
      voiceUrl: voiceAudioPath == null ? null : 'sb:$voiceAudioPath',
      sentAt: DateTime.parse(row['created_at'] as String).toLocal(),
      // The row exists in the database => it was stored (one gray check).
      // `delivered` only when the recipient's live session wrote delivered_at;
      // `read` only when the recipient's app wrote read_at.
      status: row['read_at'] != null
          ? ChatDeliveryStatus.read
          : (row['delivered_at'] != null
                ? ChatDeliveryStatus.delivered
                : ChatDeliveryStatus.sent),
      readAt: row['read_at'] != null
          ? DateTime.tryParse('${row['read_at']}')?.toLocal()
          : null,
      deliveredAt: row['delivered_at'] != null
          ? DateTime.tryParse('${row['delivered_at']}')?.toLocal()
          : null,
      voiceDurationSeconds: row['audio_duration_seconds'] as int?,
      filePath: isFile ? (row['file_path'] as String?) : null,
      fileName: isFile ? (row['file_name'] as String?) : null,
      fileMime: isFile ? (row['file_mime'] as String?) : null,
      fileSizeBytes: isFile ? (row['file_size_bytes'] as num?)?.toInt() : null,
      isDemo: false,
      deletedForEveryone: row['deleted_for_everyone_at'] != null,
      replyToId: row['reply_to_message_id'] as String?,
    );
  }

  /// Translations already written server-side for the viewer's language.
  Future<Map<String, String>> _loadTranslations(List<String> messageIds) async {
    if (messageIds.isEmpty) return const {};
    try {
      final rows = await _client
          .from('chat_translations')
          .select('message_id, translated_text')
          .inFilter('message_id', messageIds)
          .eq('target_language', viewerLanguage);
      return {
        for (final r in rows)
          r['message_id'] as String: (r['translated_text'] as String?) ?? '',
      };
    } catch (_) {
      // Missing/blocked translations must never break the chat: messages
      // simply show as "translation unavailable".
      return const {};
    }
  }

  /// Public wrapper: cached translations for the CURRENT viewer language.
  Future<Map<String, String>> loadTranslationsFor(List<String> ids) =>
      _loadTranslations(ids);

  // --------------------------------------------------------------- voice (3.1)

  /// Transcripts are stored in `chat_voice_transcriptions` (private table, no
  /// anon policy). When the table is not readable the map is simply empty and
  /// the server response fills the state after `requestTranscription`.
  Future<Map<String, Map<String, String>>> _loadTranscripts(
    List<String> voiceIds,
  ) async {
    if (voiceIds.isEmpty) return const {};
    try {
      final rows = await _client
          .from('chat_voice_transcriptions')
          .select('message_id, transcript_text, detected_language, status')
          .inFilter('message_id', voiceIds)
          .eq('status', 'ready');
      return {
        for (final r in rows)
          r['message_id'] as String: {
            'transcript_text': (r['transcript_text'] as String?) ?? '',
            'detected_language': (r['detected_language'] as String?) ?? '',
          },
      };
    } catch (_) {
      return const {};
    }
  }

  final StreamController<ChatTranscriptionUpdate> _transcriptions =
      StreamController<ChatTranscriptionUpdate>.broadcast();
  final Set<String> _transcribing = <String>{};

  /// Transcription/translation results for voice messages.
  Stream<ChatTranscriptionUpdate> get transcriptionUpdates =>
      _transcriptions.stream;

  /// Cached translation of already-transcribed voice messages for the
  /// current viewer language (no OpenAI call involved).
  Future<Map<String, String>> loadVoiceTranslationsFor(List<String> ids) =>
      _loadTranslations(ids);

  /// Asks the server to transcribe (once) and translate one voice message
  /// into the viewer's chat translation language. Only ids are sent. Never
  /// throws; the audio stays playable whatever happens.
  Future<bool> requestTranscription(
    String messageId, {
    bool retry = false,
    bool force = false,
  }) async {
    if (!force && _transcribing.contains(messageId)) return true;
    _transcribing.add(messageId);
    final requestLang = viewerLanguage;
    try {
      final res = await _client.functions.invoke(
        'chat-transcribe-message',
        body: {
          'message_id': messageId,
          'target_language': requestLang,
          'viewer_role': viewerRole == ChatRole.driver ? 'driver' : 'customer',
          'viewer_id': senderId,
          if (retry) 'retry': true,
        },
      );
      final data = res.data;
      debugPrint(
        '[chat] transcribe http=${res.status} message=$messageId '
        'viewer=${viewerRole.name}/$senderId body=$data',
      );
      if (data is! Map) {
        _emitTranscription(
          ChatTranscriptionUpdate(
            messageId: messageId,
            failed: true,
            failureReason: 'http_${res.status}_unexpected_body',
          ),
        );
        return false;
      }
      final status = '${data['status']}';
      if (status == 'service_disabled') {
        // Admin switch is OFF: not an error. No retry, no polling, no stuck
        // loader. The original audio stays playable.
        _transcribing.remove(messageId);
        _recheckCount.remove(messageId);
        _emitTranscription(
          ChatTranscriptionUpdate(
            messageId: messageId,
            serviceDisabled: true,
            disabledService: '${data['service'] ?? 'voice_transcription'}',
          ),
        );
        return false;
      }
      if (status == 'pending') {
        // Another request is transcribing; try again shortly. The server
        // never re-transcribes (atomic claim), so polling is free of cost.
        _transcribing.remove(messageId);
        _schedulePendingRecheck(messageId);
        return false;
      }
      if (status == 'failed') {
        final code = '${data['error_code'] ?? 'failed'}';
        _emitTranscription(
          ChatTranscriptionUpdate(
            messageId: messageId,
            failed: true,
            failureReason: _terminalReason(code, data),
          ),
        );
        return false;
      }
      if (status != 'ready') {
        // skipped (not voice / too long): nothing to show, no retry needed.
        _emitTranscription(
          ChatTranscriptionUpdate(messageId: messageId, skipped: true),
        );
        return true;
      }
      final transcript = '${data['transcript_text'] ?? ''}';
      final source = data['source_language'] as String?;
      final translated = '${data['translated_text'] ?? ''}';
      final trStatus = '${data['translation_status'] ?? ''}';
      final uncertain =
          data['language_uncertain'] == true ||
          trStatus == 'language_uncertain';
      // Ignore a result for a language the user has already switched away
      // from (the transcript itself is still language independent).
      final stale = requestLang != viewerLanguage;
      final translationDisabled = trStatus == 'service_disabled';
      _emitTranscription(
        ChatTranscriptionUpdate(
          messageId: messageId,
          transcriptText: transcript,
          sourceLanguage: source,
          translatedText: stale ? '' : translated,
          translationFailed: !stale && trStatus == 'failed',
          // 'language_uncertain': the server could not reliably identify the
          // spoken language, so no translation direction is guessed. Show the
          // original transcript only. 'service_disabled' (translation switch
          // OFF) also keeps the original transcript visible.
          sameLanguage:
              !stale &&
              (trStatus == 'same_language' || uncertain || translationDisabled),
          languageUncertain: !stale && uncertain,
          serviceDisabled: !stale && translationDisabled,
          disabledService: translationDisabled
              ? 'voice_text_translation'
              : null,
        ),
      );
      return true;
    } on FunctionException catch (e) {
      // supabase_flutter throws on any non-2xx. Keep the REAL status/body.
      var reason = 'http_${e.status}:${_shortDetail(e.details)}';
      final det = e.details;
      if (det is Map && '${det['status']}' == 'failed') {
        // Server-side failure body (e.g. 500 internal_error): honour its
        // retryable/attempts fields so the client never loops forever.
        final code = '${det['error_code'] ?? 'failed'}';
        reason = '${_terminalReason(code, det)}:http_${e.status}';
      }
      debugPrint(
        '[chat] transcribe FAILED http=${e.status} message=$messageId '
        'viewer=${viewerRole.name}/$senderId details=${e.details} '
        'reason=${e.reasonPhrase}',
      );
      _transcribing.remove(messageId);
      _emitTranscription(
        ChatTranscriptionUpdate(
          messageId: messageId,
          failed: true,
          failureReason: reason,
        ),
      );
      return false;
    } catch (e) {
      debugPrint('[chat] transcribe FAILED (client) message=$messageId: $e');
      _transcribing.remove(messageId);
      _emitTranscription(
        ChatTranscriptionUpdate(
          messageId: messageId,
          failed: true,
          failureReason: 'client:${_shortDetail(e)}',
        ),
      );
      return false;
    }
  }

  String _shortDetail(Object? d) {
    final s = '$d'.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s.length > 120 ? s.substring(0, 120) : s;
  }

  /// A failed transcription is terminal (no further retry offered) when the
  /// server says it is not retryable or the attempt budget is spent. The
  /// original error code is kept in the text for diagnostics.
  String _terminalReason(String code, Map data) {
    if (code == 'max_attempts') return code;
    final retryable = data['retryable'] != false;
    final attempts = int.tryParse('${data['attempts'] ?? ''}') ?? 0;
    final max = int.tryParse('${data['max_attempts'] ?? ''}') ?? 0;
    final spent = max > 0 && attempts >= max;
    if (!retryable && spent) return 'max_attempts:$code';
    return code;
  }

  final Map<String, int> _recheckCount = <String, int>{};

  /// The server answered `pending` (another request owns the transcription).
  /// Re-ask a few times with a growing delay; each call is cheap because the
  /// server returns the stored result without calling OpenAI again.
  void _schedulePendingRecheck(String messageId) {
    final n = (_recheckCount[messageId] ?? 0) + 1;
    if (n > 6 || _transcriptions.isClosed) {
      _recheckCount.remove(messageId);
      return;
    }
    _recheckCount[messageId] = n;
    Future<void>.delayed(Duration(seconds: 2 + n * 2), () {
      if (_transcriptions.isClosed) return;
      requestTranscription(messageId);
    });
  }

  void _emitTranscription(ChatTranscriptionUpdate u) {
    if (!_transcriptions.isClosed) _transcriptions.add(u);
  }

  /// Forget in-flight markers (language switch re-requests only translation
  /// of already-stored transcripts; the server never re-transcribes).
  void resetTranscribingMarkers() => _transcribing.clear();

  /// Phase 3.2: asks the server for the TRANSLATED audio of a received voice
  /// message (generated on demand, cached privately, never regenerated).
  /// Only ids are sent. Never throws.
  Future<ChatTtsResult> requestTranslatedAudio(
    String messageId, {
    bool retry = false,
  }) async {
    if (senderId == null) {
      return const ChatTtsResult(status: ChatTtsStatus.failed);
    }
    try {
      final res = await _client.functions.invoke(
        'chat-tts-message',
        body: {
          'message_id': messageId,
          'target_language': viewerLanguage,
          'viewer_role': viewerRole == ChatRole.driver ? 'driver' : 'customer',
          'viewer_id': senderId,
          if (retry) 'retry': true,
        },
      );
      final data = res.data;
      debugPrint(
        '[chat] tts http=${res.status} message=$messageId '
        'lang=$viewerLanguage body=${data is Map ? {...data, 'url': data['url'] == null ? null : '<signed-url>'} : data}',
      );
      if (data is! Map) {
        return ChatTtsResult(
          status: ChatTtsStatus.failed,
          reason: 'http_${res.status}_unexpected_body',
        );
      }
      final status = '${data['status'] ?? ''}';
      if (status == 'ready' && data['url'] is String) {
        final url = (data['url'] as String).replaceAll(
          '/storage/v1/storage/v1/',
          '/storage/v1/',
        );
        if (url.isNotEmpty) {
          return ChatTtsResult(status: ChatTtsStatus.ready, url: url);
        }
      }
      if (status == 'service_disabled') {
        return ChatTtsResult(
          status: ChatTtsStatus.disabled,
          reason: 'service_disabled:${data['service'] ?? 'voice_tts'}',
        );
      }
      if (status == 'pending') {
        return const ChatTtsResult(status: ChatTtsStatus.pending);
      }
      if (status == 'skipped' ||
          status == 'needs_transcript' ||
          status == 'needs_translation') {
        return ChatTtsResult(
          status: ChatTtsStatus.unavailable,
          reason: status == 'skipped'
              ? 'skipped:${data['reason'] ?? ''}'
              : status,
        );
      }
      return ChatTtsResult(
        status: ChatTtsStatus.failed,
        retryable: data['retryable'] != false,
        reason: '${data['error_code'] ?? data['error'] ?? 'failed'}',
      );
    } on FunctionException catch (e) {
      debugPrint(
        '[chat] tts FAILED http=${e.status} message=$messageId '
        'viewer=${viewerRole.name}/$senderId lang=$viewerLanguage '
        'details=${e.details}',
      );
      // Keep the real server reason (e.g. "ElevenLabs not configured",
      // "Function not configured") so a missing provider is reported exactly.
      final det = e.details;
      final serverReason = det is Map
          ? '${det['error_code'] ?? det['error'] ?? ''}'
          : '$det';
      return ChatTtsResult(
        status: ChatTtsStatus.failed,
        reason:
            'http_${e.status}${serverReason.isEmpty ? '' : ':${_shortDetail(serverReason)}'}',
      );
    } catch (e) {
      debugPrint('[chat] tts FAILED (client): $e');
      return ChatTtsResult(
        status: ChatTtsStatus.failed,
        reason: 'client:${_shortDetail(e)}',
      );
    }
  }

  /// Short-lived signed URL for playing a stored voice message from the
  /// PRIVATE `chat-voice` bucket (no public access is created).
  ///
  /// The anon role has no SELECT policy on storage.objects (by design), so
  /// signing client-side is denied for the recipient. The Edge Function
  /// verifies the viewer is a participant of the conversation and signs with
  /// the service role.
  ///
  /// Every step logs the REAL HTTP status / error so playback failures can be
  /// traced: sign_audio request -> function response -> URL shape -> fallback.
  Future<String?> signedAudioUrl(String audioPath, {String? messageId}) async {
    if (messageId != null && senderId != null) {
      try {
        final res = await _client.functions.invoke(
          'chat-transcribe-message',
          body: {
            'action': 'sign_audio',
            'message_id': messageId,
            'viewer_role': viewerRole == ChatRole.driver
                ? 'driver'
                : 'customer',
            'viewer_id': senderId,
          },
        );
        final data = res.data;
        debugPrint(
          '[chat] sign_audio http=${res.status} message=$messageId '
          'viewer=${viewerRole.name}/$senderId body=$data',
        );
        if (data is Map && data['url'] is String) {
          final url = data['url'] as String;
          if (url.isNotEmpty) {
            // Guard against a duplicated /storage/v1 segment.
            final fixed = url.replaceAll(
              '/storage/v1/storage/v1/',
              '/storage/v1/',
            );
            debugPrint(
              '[chat] sign_audio url_ok host=${Uri.tryParse(fixed)?.host} '
              'path=${Uri.tryParse(fixed)?.path}',
            );
            return fixed;
          }
        }
        debugPrint('[chat] sign_audio unexpected response: $data');
      } on FunctionException catch (e) {
        debugPrint(
          '[chat] sign_audio FAILED http=${e.status} message=$messageId '
          'viewer=${viewerRole.name}/$senderId details=${e.details}',
        );
      } catch (e) {
        debugPrint('[chat] sign_audio FAILED (client): $e');
      }
    } else {
      debugPrint(
        '[chat] sign_audio skipped: messageId=$messageId senderId=$senderId',
      );
    }
    try {
      final url = await _client.storage
          .from('chat-voice')
          .createSignedUrl(audioPath, 3600);
      debugPrint('[chat] createSignedUrl fallback ok path=$audioPath');
      return url;
    } on StorageException catch (e) {
      debugPrint(
        '[chat] createSignedUrl FAILED status=${e.statusCode} '
        'message=${e.message} path=$audioPath',
      );
      return null;
    } catch (e) {
      debugPrint('[chat] createSignedUrl FAILED: $e');
      return null;
    }
  }

  /// Uploads the ORIGINAL recording to the private `chat-voice` bucket and
  /// inserts the `chat_messages` voice row. `original_text` stays empty.
  /// Throws [ChatBackendException] so the caller keeps the local audio and
  /// can offer a retry (the recording is never lost).
  Future<ChatMessage> sendVoice({
    required String conversationId,
    required String localSource,
    required int durationSeconds,
    String language = 'en',
    String? replyToId,
  }) async {
    final id = senderId;
    if (id == null) {
      throw const ChatBackendException(
        ChatBackendIssue.missingSenderIdentity,
        'No authenticated Odoo sender id is available, so the voice message '
        'was not sent (identity is never invented).',
      );
    }
    final bytes = await readRecordedBytes(localSource);
    if (bytes == null || bytes.isEmpty) {
      throw const ChatBackendException(
        ChatBackendIssue.unknown,
        'The recorded audio could not be read for upload.',
      );
    }
    // The browser decides the real container (WebM/Opus in Chrome, MP4/AAC in
    // Safari, WAV as a fallback). Detect it from the bytes so the stored file
    // name and Content-Type always match the actual audio.
    final fmt = _detectAudioFormat(bytes, fallbackIsWeb: kIsWeb);
    final ext = fmt.ext;
    final mime = fmt.mime;
    ChatAudioDiagnostics.instance.setRecording(mime: mime, extension: ext);
    debugPrint(
      '[chat] voice upload format ext=$ext mime=$mime bytes=${bytes.length}',
    );
    final role = viewerRole == ChatRole.driver ? 'driver' : 'customer';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$conversationId/${role}_${id}_$ts.$ext';
    // Step 1: upload the ORIGINAL audio to the private bucket.
    try {
      await _client.storage
          .from('chat-voice')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
    } catch (e) {
      debugPrint('[chat] voice step=storage_upload failed: $e');
      throw _mapVoiceStep('storage upload', e);
    }
    // Step 2: create the chat_messages voice row.
    try {
      final row = await _client
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'odoo_sender_id': id,
            'sender_name': viewerName,
            'sender_role': role,
            'message_type': 'voice',
            'audio_path': path,
            'audio_duration_seconds': durationSeconds,
            'original_language': language,
            if (replyToId != null) 'reply_to_message_id': replyToId,
          })
          .select()
          .single();
      final msg = _messageFrom(Map<String, dynamic>.from(row));
      // Keep playing from the local recording for the sender.
      return msg.copyWith(voiceUrl: localSource);
    } catch (e) {
      debugPrint('[chat] voice step=message_insert failed: $e');
      throw _mapVoiceStep('chat_messages insert', e);
    }
  }

  /// Maps a failure of one voice-send step to a [ChatBackendException] that
  /// names the step. StorageException (401/403 / row-level security) is
  /// reported as [ChatBackendIssue.rlsOrAuthBlocked]; the original recording
  /// is always kept by the caller.
  ChatBackendException _mapVoiceStep(String step, Object e) {
    if (e is StorageException) {
      final status = e.statusCode ?? '';
      final msg = e.message.toLowerCase();
      final blocked =
          status == '401' ||
          status == '403' ||
          msg.contains('row-level security') ||
          msg.contains('unauthorized');
      return ChatBackendException(
        blocked ? ChatBackendIssue.rlsOrAuthBlocked : ChatBackendIssue.unknown,
        '$step failed: ${e.message}',
        code: status.isEmpty ? null : status,
      );
    }
    final mapped = _map(e);
    return ChatBackendException(
      mapped.issue,
      '$step failed: ${mapped.detail}',
      code: mapped.code,
    );
  }

  static const int maxAttachmentBytes = 10 * 1024 * 1024;

  static const Map<String, String> _attachmentMimeByExt = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'heic': 'image/heic',
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt': 'text/plain',
    // Video: requires tourops_test_chat_video.sql (MIME allow-list + path
    // regex). Until that migration is applied the upload is rejected by
    // Storage and reported as "attachments not deployed".
    'mp4': 'video/mp4',
    'webm': 'video/webm',
  };

  /// Signed URL cache: one URL per message, reused until shortly before it
  /// expires (server TTL is 300 s). Never regenerated on widget rebuilds.
  static const Duration _signedUrlTtl = Duration(seconds: 300);
  static const Duration _signedUrlSafety = Duration(seconds: 45);
  final Map<String, _CachedSignedUrl> _signedUrlCache =
      <String, _CachedSignedUrl>{};
  final Map<String, Future<String?>> _signedUrlInflight =
      <String, Future<String?>>{};

  /// Returns a valid cached signed URL, or requests a new one (de-duplicated
  /// across concurrent callers). Set [forceRefresh] after a load failure.
  Future<String?> cachedSignedFileUrl(
    String filePath, {
    required String messageId,
    bool forceRefresh = false,
  }) {
    final now = DateTime.now();
    final hit = _signedUrlCache[messageId];
    if (!forceRefresh &&
        hit != null &&
        hit.expiresAt.isAfter(now.add(_signedUrlSafety))) {
      return Future<String?>.value(hit.url);
    }
    final running = _signedUrlInflight[messageId];
    if (running != null && !forceRefresh) return running;
    final future = signedFileUrl(filePath, messageId: messageId)
        .then((url) {
          if (url != null) {
            _signedUrlCache[messageId] = _CachedSignedUrl(
              url,
              DateTime.now().add(_signedUrlTtl),
            );
          }
          return url;
        })
        .whenComplete(() => _signedUrlInflight.remove(messageId));
    _signedUrlInflight[messageId] = future;
    return future;
  }

  /// Allowed attachment extensions (also used by the picker filter).
  static List<String> get attachmentExtensions =>
      _attachmentMimeByExt.keys.toList(growable: false);

  /// Uploads an attachment to the PRIVATE `chat-files` bucket, then inserts
  /// the `chat_messages` row (`message_type = 'file'`).
  ///
  /// Throws [ChatBackendException]. When the server migration
  /// (`tourops_test_chat_attachments.sql`) has not been applied the bucket /
  /// column / CHECK constraint is missing: that is reported as
  /// [ChatBackendIssue.attachmentsNotDeployed], never as a fake success.
  Future<ChatMessage> sendFile({
    required String conversationId,
    required Uint8List bytes,
    required String fileName,
    String language = 'en',
  }) async {
    final id = senderId;
    if (id == null) {
      throw const ChatBackendException(
        ChatBackendIssue.missingSenderIdentity,
        'No authenticated Odoo sender id is available, so the file was not '
        'sent (identity is never invented).',
      );
    }
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    final mime = _attachmentMimeByExt[ext];
    if (mime == null) {
      throw ChatBackendException(
        ChatBackendIssue.unknown,
        'Unsupported file type: .$ext',
      );
    }
    if (bytes.isEmpty || bytes.length > maxAttachmentBytes) {
      throw ChatBackendException(
        ChatBackendIssue.unknown,
        'File is empty or larger than 10 MB.',
      );
    }
    final role = viewerRole == ChatRole.driver ? 'driver' : 'customer';
    final ts = DateTime.now().millisecondsSinceEpoch;
    // Storage key is generated server-safe (never the user's file name).
    final path = '$conversationId/${role}_${id}_$ts.$ext';
    try {
      await _client.storage
          .from('chat-files')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, upsert: false),
          );
    } catch (e) {
      debugPrint('[chat] file step=storage_upload failed: $e');
      if (e is StorageException) {
        final msg = e.message.toLowerCase();
        final status = e.statusCode ?? '';
        if (msg.contains('bucket not found') ||
            status == '404' ||
            (msg.contains('not found') && msg.contains('bucket')) ||
            (mime.startsWith('video/') &&
                (msg.contains('mime') ||
                    msg.contains('not allowed') ||
                    msg.contains('row-level security') ||
                    status == '400' ||
                    status == '403' ||
                    status == '415'))) {
          throw ChatBackendException(
            ChatBackendIssue.attachmentsNotDeployed,
            'storage upload failed: ${e.message}',
            code: status.isEmpty ? null : status,
          );
        }
      }
      throw _mapVoiceStep('storage upload', e);
    }
    try {
      final row = await _client
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'odoo_sender_id': id,
            'sender_name': viewerName,
            'sender_role': role,
            'message_type': 'file',
            'file_path': path,
            'file_name': fileName,
            'file_mime': mime,
            'file_size_bytes': bytes.length,
            'original_language': language,
          })
          .select()
          .single();
      return _messageFrom(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('[chat] file step=message_insert failed: $e');
      final mapped = _map(e);
      final text = mapped.detail.toLowerCase();
      final schemaMissing =
          (e is PostgrestException &&
              (e.code == '23514' || e.code == 'PGRST204')) ||
          text.contains('message_type_check') ||
          text.contains('file_path') ||
          text.contains('could not find');
      throw ChatBackendException(
        schemaMissing ? ChatBackendIssue.attachmentsNotDeployed : mapped.issue,
        'chat_messages insert failed: ${mapped.detail}',
        code: mapped.code,
      );
    }
  }

  /// Short-lived signed URL for a stored attachment (private bucket).
  ///
  /// The anon role has no SELECT policy on storage.objects, so the client
  /// cannot sign directly. This asks the `chat-transcribe-message` Edge
  /// Function style `sign_file` action ONLY if a server-side signer is
  /// deployed; otherwise it returns null and the UI says the file cannot be
  /// opened. No public URL is ever created.
  Future<String?> signedFileUrl(String filePath, {String? messageId}) async {
    if (messageId == null || senderId == null) return null;
    try {
      final res = await _client.functions.invoke(
        'chat-file-sign',
        body: {
          'message_id': messageId,
          'viewer_role': viewerRole == ChatRole.driver ? 'driver' : 'customer',
          'viewer_id': senderId,
        },
      );
      final data = res.data;
      if (data is Map && data['url'] is String) {
        final url = data['url'] as String;
        if (url.isNotEmpty) {
          return url.replaceAll('/storage/v1/storage/v1/', '/storage/v1/');
        }
      }
    } catch (e) {
      debugPrint('[chat] chat-file-sign failed: $e');
    }
    return null;
  }

  /// Switches the translation language at runtime. Pending-request memory is
  /// cleared (it is per language) and the Realtime listener is re-created for
  /// the new language. No message or read state is touched.
  void setViewerLanguage(String language) {
    if (language == _viewerLanguage) return;
    _viewerLanguage = language;
    _requested.clear();
    watchTranslations();
  }

  /// Script-based language detection (mirrors the server). Arabic, Georgian
  /// and Cyrillic (Russian) have unique Unicode blocks. Latin script returns
  /// 'en' here only as "Latin"; English vs Azerbaijani is decided server-side.
  /// Returns null when the text has no letters (numbers / symbols only).
  static String? _detectLanguage(String text) {
    var ar = 0, ka = 0, ru = 0, en = 0;
    for (final c in text.runes) {
      if ((c >= 0x0600 && c <= 0x06ff) ||
          (c >= 0x0750 && c <= 0x077f) ||
          (c >= 0xfb50 && c <= 0xfdff) ||
          (c >= 0xfe70 && c <= 0xfeff)) {
        ar++;
      } else if ((c >= 0x10a0 && c <= 0x10ff) || (c >= 0x1c90 && c <= 0x1cbf)) {
        ka++;
      } else if (c >= 0x0400 && c <= 0x04ff) {
        ru++;
      } else if ((c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a)) {
        en++;
      }
    }
    final max = [ar, ka, ru, en].reduce((a, b) => a > b ? a : b);
    if (max == 0) return null;
    if (max == ar) return 'ar';
    if (max == ka) return 'ka';
    if (max == ru) return 'ru';
    return 'en';
  }

  final StreamController<ChatTranslationUpdate> _translations =
      StreamController<ChatTranslationUpdate>.broadcast();
  final Set<String> _requested = <String>{};
  RealtimeChannel? _trChannel;

  /// Translations that arrived (Realtime or Edge Function response).
  Stream<ChatTranslationUpdate> get translationUpdates => _translations.stream;

  /// Subscribes to new `chat_translations` rows for the viewer's language.
  /// Rows for other conversations are ignored by the screen (unknown id).
  void watchTranslations() {
    _trChannel?.unsubscribe();
    _trChannel = _client
        .channel('chat_translations:$viewerLanguage:${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_translations',
          callback: (payload) => _emitTranslationRow(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_translations',
          callback: (payload) => _emitTranslationRow(payload.newRecord),
        )
        .subscribe();
  }

  void _emitTranslationRow(Map<String, dynamic> raw) {
    final row = Map<String, dynamic>.from(raw);
    if (row['target_language'] != viewerLanguage) return;
    final id = row['message_id'] as String?;
    final text = (row['translated_text'] as String?) ?? '';
    if (id == null || text.isEmpty || _translations.isClosed) return;
    _translations.add(ChatTranslationUpdate(messageId: id, text: text));
  }

  /// Asks the server (Edge Function `chat-translate-message`) to translate one
  /// message into the viewer's language. Only the message id and target
  /// language are sent; no API key or internal token exists in the app.
  /// Never throws: on failure returns false so the original stays visible.
  Future<bool> requestTranslation(String messageId) async {
    if (_requested.contains(messageId)) return true;
    _requested.add(messageId);
    // Language this request is made for; a result that arrives after the user
    // switched to another language is ignored (never shown for the wrong one).
    final requestLang = viewerLanguage;
    try {
      final res = await _client.functions.invoke(
        'chat-translate-message',
        body: {'message_id': messageId, 'target_language': requestLang},
      );
      if (requestLang != viewerLanguage) return true;
      final data = res.data;
      if (data is Map) {
        final status = data['status'];
        if (status == 'service_disabled') {
          // Admin switch is OFF: show the original, no retry, no loader.
          if (!_translations.isClosed) {
            _translations.add(
              ChatTranslationUpdate(
                messageId: messageId,
                text: '',
                serviceDisabled: true,
              ),
            );
          }
          // Keep it marked as requested so it is not re-asked in a loop.
          return true;
        }
        final text = (data['translated_text'] as String?) ?? '';
        final src = data['source_language'] as String?;
        if (status == 'same_language') {
          if (!_translations.isClosed) {
            _translations.add(
              ChatTranslationUpdate(
                messageId: messageId,
                text: '',
                same: true,
                sourceLanguage: src,
              ),
            );
          }
          return true;
        }
        if (text.isNotEmpty) {
          if (!_translations.isClosed) {
            _translations.add(
              ChatTranslationUpdate(
                messageId: messageId,
                text: text,
                sourceLanguage: src,
              ),
            );
          }
          return true;
        }
      }
      _requested.remove(messageId);
      return false;
    } catch (e) {
      debugPrint('[chat] chat-translate-message failed: $e');
      _requested.remove(messageId);
      return false;
    }
  }

  /// Chronological history (oldest first).
  Future<List<ChatMessage>> loadHistory(
    String conversationId, {
    int limit = 100,
  }) async {
    try {
      final rows = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .limit(limit);
      var list = List<Map<String, dynamic>>.from(rows);
      // "Delete for Me" / "Delete Conversation": persisted per user, applied
      // here so hidden messages never reach the UI (not UI-only hiding).
      final hidden = await loadHiddenMessageIds(conversationId);
      if (hidden.isNotEmpty) {
        list = [
          for (final r in list)
            if (!hidden.contains(r['id'] as String)) r,
        ];
      }
      final tr = await _loadTranslations([
        for (final r in list) r['id'] as String,
      ]);
      final vt = await _loadTranscripts([
        for (final r in list)
          if (r['message_type'] == 'voice') r['id'] as String,
      ]);
      return [
        for (final r in list)
          _messageFrom(r, translationsByMessage: tr, voiceTranscripts: vt),
      ];
    } catch (e) {
      throw _map(e);
    }
  }

  /// Fetches ONE message (scoped to [conversationId], so RLS and the
  /// conversation boundary still apply) plus a small window of messages
  /// around it, oldest first. Returns an empty list when the target does not
  /// exist, is hidden for this viewer, or is not accessible.
  Future<List<ChatMessage>> loadAroundMessage(
    String conversationId,
    String messageId, {
    int before = 20,
    int after = 20,
  }) async {
    try {
      final target = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .eq('id', messageId)
          .maybeSingle();
      if (target == null) return const [];
      final hidden = await loadHiddenMessageIds(conversationId);
      if (hidden.contains(messageId)) return const [];
      final createdAt = '${target['created_at']}';
      final olderRows = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .lt('created_at', createdAt)
          .order('created_at', ascending: false)
          .limit(before);
      final newerRows = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .gt('created_at', createdAt)
          .order('created_at', ascending: true)
          .limit(after);
      var list = <Map<String, dynamic>>[
        ...List<Map<String, dynamic>>.from(olderRows).reversed,
        Map<String, dynamic>.from(target),
        ...List<Map<String, dynamic>>.from(newerRows),
      ];
      if (hidden.isNotEmpty) {
        list = [
          for (final r in list)
            if (!hidden.contains(r['id'] as String)) r,
        ];
      }
      final tr = await _loadTranslations([
        for (final r in list) r['id'] as String,
      ]);
      final vt = await _loadTranscripts([
        for (final r in list)
          if (r['message_type'] == 'voice') r['id'] as String,
      ]);
      return [
        for (final r in list)
          _messageFrom(r, translationsByMessage: tr, voiceTranscripts: vt),
      ];
    } catch (e) {
      throw _map(e);
    }
  }

  /// Batch-resolves reply originals (for the quoted preview only) that are
  /// not part of the loaded window. Scoped to the conversation, hidden
  /// messages excluded; missing/inaccessible ids are simply absent.
  Future<List<ChatMessage>> loadMessagesByIds(
    String conversationId,
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .inFilter('id', ids);
      var list = List<Map<String, dynamic>>.from(rows);
      final hidden = await loadHiddenMessageIds(conversationId);
      if (hidden.isNotEmpty) {
        list = [
          for (final r in list)
            if (!hidden.contains(r['id'] as String)) r,
        ];
      }
      return [for (final r in list) _messageFrom(r)];
    } catch (e) {
      debugPrint('[chat] reply originals unavailable: $e');
      return const [];
    }
  }

  /// Subscribes to Realtime INSERTs for this conversation only.
  ///
  /// Text and voice rows use the SAME channel and path. The row is emitted to
  /// the UI immediately (never gated on the translation / transcript lookups,
  /// which can be slow or fail); enrichment is merged in afterwards.
  Stream<ChatMessage> watchMessages(String conversationId) {
    _channel?.unsubscribe();
    // Unique topic per subscription: re-opening the same conversation must
    // never collide with the previous (still closing) channel of that topic.
    _channel = _client
        .channel('chat_messages:$conversationId:${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final row = Map<String, dynamic>.from(payload.newRecord);
            if (row.isEmpty || row['id'] == null) return;
            debugPrint(
              '[chat] realtime INSERT id=${row['id']} '
              'type=${row['message_type']} role=${row['sender_role']}',
            );
            _deliverInsertedRow(row);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            final row = Map<String, dynamic>.from(payload.newRecord);
            if (row.isEmpty || row['id'] == null) return;
            if (row['deleted_for_everyone_at'] != null &&
                !_deletions.isClosed) {
              _deletions.add(row['id'] as String);
            }
            final readAt = row['read_at'];
            final deliveredAt = row['delivered_at'];
            if ((readAt == null && deliveredAt == null) || _receipts.isClosed) {
              return;
            }
            _receipts.add(
              ChatReadReceipt(
                messageId: row['id'] as String,
                readAt: readAt == null
                    ? null
                    : (DateTime.tryParse('$readAt')?.toLocal() ??
                          DateTime.now()),
                deliveredAt: deliveredAt == null
                    ? null
                    : DateTime.tryParse('$deliveredAt')?.toLocal(),
              ),
            );
          },
        )
        .subscribe((status, [error]) {
          debugPrint(
            '[chat] realtime status=$status conversation=$conversationId '
            'error=$error',
          );
          // Every time the channel becomes active, re-read the persisted rows:
          // messages inserted between loadHistory() and the subscription
          // becoming active (or while the socket was down) are never lost.
          // The screen de-duplicates by id, so this cannot create duplicates.
          if (status == RealtimeSubscribeStatus.subscribed) {
            if (!_resync.isClosed) _resync.add(null);
            _hasSubscribedOnce = true;
          }
        });
    return _incoming.stream;
  }

  /// Emits a realtime-inserted row right away, then (best effort) lets the
  /// translation / transcript enrichment follow through the existing streams.
  void _deliverInsertedRow(Map<String, dynamic> row) {
    try {
      if (!_incoming.isClosed) {
        _incoming.add(_messageFrom(row));
      }
    } catch (e) {
      debugPrint('[chat] realtime INSERT could not be mapped: $e');
      return;
    }
    final id = row['id'] as String;
    final isVoice = row['message_type'] == 'voice';
    () async {
      try {
        final tr = await _loadTranslations([id]);
        final vt = isVoice
            ? await _loadTranscripts([id])
            : const <String, Map<String, String>>{};
        if (tr.isEmpty && vt.isEmpty) return;
        if (!isVoice) {
          final t = tr[id];
          if (t != null && t.isNotEmpty && !_translations.isClosed) {
            _translations.add(ChatTranslationUpdate(messageId: id, text: t));
          }
        }
      } catch (_) {
        // Enrichment is best effort; delivery already happened.
      }
    }();
  }

  bool _hasSubscribedOnce = false;
  final StreamController<ChatReadReceipt> _receipts =
      StreamController<ChatReadReceipt>.broadcast();
  final StreamController<void> _resync = StreamController<void>.broadcast();
  final StreamController<String> _deletions =
      StreamController<String>.broadcast();

  /// Message ids removed "for everyone" (Realtime UPDATE from the database).
  Stream<String> get deletedForEveryone => _deletions.stream;

  String get _roleName => viewerRole == ChatRole.driver ? 'driver' : 'customer';

  ChatBackendException _deleteError(Object e) {
    final mapped = _map(e);
    final text = mapped.detail.toLowerCase();
    if (e is PostgrestException &&
        (e.code == 'PGRST202' ||
            e.code == '42883' ||
            text.contains('could not find the function'))) {
      return ChatBackendException(
        ChatBackendIssue.attachmentsNotDeployed,
        'Delete migration (tourops_test_chat_delete.sql) is not applied: '
        '${mapped.detail}',
        code: e.code,
      );
    }
    return mapped;
  }

  /// Message ids hidden for THIS viewer (Delete for Me + deleted
  /// conversation cut-off). Returns an empty set if the migration is not
  /// applied yet, so existing chat keeps working.
  Future<Set<String>> loadHiddenMessageIds(String conversationId) async {
    final id = senderId;
    if (id == null) return <String>{};
    try {
      final res = await _client.rpc(
        'chat_get_hidden_message_ids',
        params: {
          'p_conversation_id': conversationId,
          'p_actor_role': _roleName,
          'p_actor_odoo_id': id,
        },
      );
      final out = <String>{};
      if (res is List) {
        for (final r in res) {
          if (r is Map && r['message_id'] != null) {
            out.add('${r['message_id']}');
          } else if (r is String) {
            out.add(r);
          }
        }
      }
      return out;
    } catch (e) {
      debugPrint('[chat] hidden ids unavailable: $e');
      return <String>{};
    }
  }

  /// "Delete for Me": hides one message for this viewer only.
  Future<void> deleteMessageForMe(String messageId) async {
    final id = senderId;
    if (id == null) {
      throw const ChatBackendException(
        ChatBackendIssue.missingSenderIdentity,
        'No authenticated Odoo id; nothing was deleted.',
      );
    }
    try {
      final ok = await _client.rpc(
        'chat_delete_message_for_me',
        params: {
          'p_message_id': messageId,
          'p_actor_role': _roleName,
          'p_actor_odoo_id': id,
        },
      );
      if (ok != true) {
        throw const ChatBackendException(
          ChatBackendIssue.unknown,
          'The message could not be hidden.',
        );
      }
    } on ChatBackendException {
      rethrow;
    } catch (e) {
      throw _deleteError(e);
    }
  }

  /// "Delete for Everyone": sender only (enforced in the database).
  Future<void> deleteMessageForEveryone(String messageId) async {
    final id = senderId;
    if (id == null) {
      throw const ChatBackendException(
        ChatBackendIssue.missingSenderIdentity,
        'No authenticated Odoo id; nothing was deleted.',
      );
    }
    try {
      final ok = await _client.rpc(
        'chat_delete_message_for_everyone',
        params: {
          'p_message_id': messageId,
          'p_actor_role': _roleName,
          'p_actor_odoo_id': id,
        },
      );
      if (ok != true) {
        throw const ChatBackendException(
          ChatBackendIssue.rlsOrAuthBlocked,
          'Only the sender can delete this message for everyone.',
        );
      }
    } on ChatBackendException {
      rethrow;
    } catch (e) {
      throw _deleteError(e);
    }
  }

  /// Removes the whole conversation for THIS user only. A newer message from
  /// the other participant makes it visible again.
  Future<void> deleteConversationForMe(String conversationId) async {
    final id = senderId;
    if (id == null) {
      throw const ChatBackendException(
        ChatBackendIssue.missingSenderIdentity,
        'No authenticated Odoo id; nothing was deleted.',
      );
    }
    try {
      final ok = await _client.rpc(
        'chat_delete_conversation_for_me',
        params: {
          'p_conversation_id': conversationId,
          'p_actor_role': _roleName,
          'p_actor_odoo_id': id,
        },
      );
      if (ok != true) {
        throw const ChatBackendException(
          ChatBackendIssue.unknown,
          'The conversation could not be deleted.',
        );
      }
    } on ChatBackendException {
      rethrow;
    } catch (e) {
      throw _deleteError(e);
    }
  }

  /// Realtime UPDATE events carrying a new `read_at` for one message.
  Stream<ChatReadReceipt> get readReceipts => _receipts.stream;

  /// Fires after Realtime reconnects so the screen can refresh statuses.
  Stream<void> get reconnected => _resync.stream;

  /// Persisted `read_at` per message id (used after reconnect / re-open).
  Future<Map<String, DateTime>> loadReadStates(String conversationId) async {
    try {
      final rows = await _client
          .from('chat_messages')
          .select('id, read_at')
          .eq('conversation_id', conversationId)
          .not('read_at', 'is', null);
      return {
        for (final r in rows)
          if (DateTime.tryParse('${r['read_at']}') != null)
            r['id'] as String: DateTime.parse('${r['read_at']}').toLocal(),
      };
    } catch (e) {
      throw _map(e);
    }
  }

  /// Marks INCOMING (opposite-role) messages of this conversation as
  /// DELIVERED. Only call this when this device is in the foreground with a
  /// live Realtime subscription that actually received the rows. Returns the
  /// rows newly marked. Fails quietly (returns 0) when the TEST migration
  /// `tourops_test_delivery_receipts.sql` is not applied yet: delivery is then
  /// simply not reported, never faked.
  Future<int> markIncomingAsDelivered({required String conversationId}) async {
    final id = senderId;
    if (id == null) return 0;
    final role = viewerRole == ChatRole.driver ? 'driver' : 'customer';
    try {
      final res = await _client.rpc(
        'chat_mark_messages_delivered',
        params: {
          'p_conversation_id': conversationId,
          'p_reader_role': role,
          'p_reader_odoo_id': id,
        },
      );
      final count = _rpcRowCount(res);
      debugPrint(
        '[chat] chat_mark_messages_delivered ok: conversation=$conversationId '
        'role=$role odoo_id=$id rows_marked=$count',
      );
      deliveryBackendError = null;
      return count;
    } catch (e) {
      final mapped = _map(e);
      deliveryBackendError =
          '${mapped.code != null ? '[${mapped.code}] ' : ''}${mapped.detail}';
      debugPrint(
        '[chat] chat_mark_messages_delivered FAILED: $deliveryBackendError',
      );
      return 0;
    }
  }

  /// Last exact error of the delivery RPC (null = last call succeeded).
  String? deliveryBackendError;

  /// Marks INCOMING (opposite-role) messages of this conversation as READ.
  ///
  /// Goes through the SECURITY DEFINER RPC `chat_mark_messages_read`, which
  /// only touches messages sent by the opposite role (never the caller's own)
  /// and also sets delivered_at. Call only when the recipient actually views
  /// the open conversation in the foreground. Returns rows newly marked, or
  /// throws the exact backend error.
  Future<int> markIncomingAsRead({required String conversationId}) async {
    final id = senderId;
    if (id == null) {
      throw const ChatBackendException(
        ChatBackendIssue.missingSenderIdentity,
        'No authenticated Odoo id for the reader, so nothing was marked read.',
      );
    }
    final role = viewerRole == ChatRole.driver ? 'driver' : 'customer';
    try {
      final res = await _client.rpc(
        'chat_mark_messages_read',
        params: {
          'p_conversation_id': conversationId,
          'p_reader_role': role,
          'p_reader_odoo_id': id,
        },
      );
      final count = _rpcRowCount(res);
      lastMarkReadCount = count;
      debugPrint(
        '[chat] chat_mark_messages_read ok: conversation=$conversationId '
        'role=$role odoo_id=$id rows_marked=$count',
      );
      return count;
    } catch (e) {
      final mapped = _map(e);
      debugPrint(
        '[chat] chat_mark_messages_read FAILED: conversation=$conversationId '
        'role=$role odoo_id=$id error=${mapped.detail} code=${mapped.code}',
      );
      throw mapped;
    }
  }

  /// Persisted delivered/read timestamps for the given message ids (normal
  /// RLS SELECT = source of truth). Missing `delivered_at` column => the
  /// query falls back to read_at only.
  Future<Map<String, ChatReadReceipt>> loadReceiptStatesFor(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('chat_messages')
          .select('id, read_at, delivered_at')
          .inFilter('id', ids);
      return _receiptsFromRows(rows);
    } catch (_) {
      try {
        final rows = await _client
            .from('chat_messages')
            .select('id, read_at')
            .inFilter('id', ids);
        return _receiptsFromRows(rows);
      } catch (e) {
        throw _map(e);
      }
    }
  }

  Map<String, ChatReadReceipt> _receiptsFromRows(List<dynamic> rows) {
    final out = <String, ChatReadReceipt>{};
    for (final r in rows) {
      final read = r['read_at'] == null
          ? null
          : DateTime.tryParse('${r['read_at']}')?.toLocal();
      final delivered = r['delivered_at'] == null
          ? null
          : DateTime.tryParse('${r['delivered_at']}')?.toLocal();
      if (read == null && delivered == null) continue;
      out[r['id'] as String] = ChatReadReceipt(
        messageId: r['id'] as String,
        readAt: read,
        deliveredAt: delivered,
      );
    }
    return out;
  }

  /// Rows newly marked by the last successful RPC call (null = never called).
  int? lastMarkReadCount;

  /// Raw RPC payload of the last successful call (for diagnostics).
  dynamic lastMarkReadRaw;

  /// Re-reads the persisted `read_at` for the given message ids using a normal
  /// RLS-governed SELECT. This is the source of truth used to confirm that the
  /// RPC really wrote `read_at` (never assumed from the RPC return value).
  Future<Map<String, DateTime>> loadReadStatesFor(List<String> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('chat_messages')
          .select('id, read_at')
          .inFilter('id', ids)
          .not('read_at', 'is', null);
      return {
        for (final r in rows)
          if (DateTime.tryParse('${r['read_at']}') != null)
            r['id'] as String: DateTime.parse('${r['read_at']}').toLocal(),
      };
    } catch (e) {
      throw _map(e);
    }
  }

  /// Normalizes the RPC result (int, numeric string, single-row list or map).
  int _rpcRowCount(dynamic res) {
    if (res == null) return 0;
    if (res is int) return res;
    if (res is num) return res.toInt();
    if (res is List) {
      if (res.isEmpty) return 0;
      return _rpcRowCount(res.first);
    }
    if (res is Map) {
      if (res.isEmpty) return 0;
      return _rpcRowCount(res.values.first);
    }
    return int.tryParse('$res') ?? 0;
  }

  /// Inserts a text message. The original text is stored untouched; the
  /// translation is produced server-side and read back later.
  Future<ChatMessage> sendText({
    required String conversationId,
    required String text,
    required String language,
    String? replyToId,
  }) async {
    final id = senderId;
    if (id == null) {
      throw const ChatBackendException(
        ChatBackendIssue.missingSenderIdentity,
        'No authenticated Odoo sender id is available, so the message was '
        'not sent (identity is never invented).',
      );
    }
    try {
      final row = await _client
          .from('chat_messages')
          .insert({
            'conversation_id': conversationId,
            'odoo_sender_id': id,
            'sender_name': viewerName,
            'sender_role': viewerRole == ChatRole.driver
                ? 'driver'
                : 'customer',
            'message_type': 'text',
            'original_text': text,
            'original_language': language,
            if (replyToId != null) 'reply_to_message_id': replyToId,
          })
          .select()
          .single();
      return _messageFrom(Map<String, dynamic>.from(row));
    } catch (e) {
      throw _map(e);
    }
  }

  // -------------------------------------------------------------------
  // Reactions (persisted in public.chat_message_reactions)
  // -------------------------------------------------------------------

  RealtimeChannel? _reactChannel;
  final StreamController<ChatReaction> _reactionUpserts =
      StreamController<ChatReaction>.broadcast();
  final StreamController<ChatReaction> _reactionRemovals =
      StreamController<ChatReaction>.broadcast();

  /// Reactions added / changed by any participant (Realtime).
  Stream<ChatReaction> get reactionUpserts => _reactionUpserts.stream;

  /// Reactions removed by any participant (Realtime).
  Stream<ChatReaction> get reactionRemovals => _reactionRemovals.stream;

  ChatReaction? _reactionFrom(Map<String, dynamic> row) {
    final mid = row['message_id'] as String?;
    final role = row['reactor_role'] as String?;
    final rid = row['reactor_odoo_id'];
    final emoji = row['emoji'] as String?;
    if (mid == null || role == null || rid == null) return null;
    return ChatReaction(
      messageId: mid,
      reactorRole: role == 'driver' ? ChatRole.driver : ChatRole.customer,
      reactorId: '$rid',
      emoji: emoji ?? '',
    );
  }

  /// Loads the persisted reactions of a conversation. Returns an empty list
  /// when the reactions migration has not been applied yet.
  Future<List<ChatReaction>> loadReactions(String conversationId) async {
    try {
      final rows = await _client
          .from('chat_message_reactions')
          .select()
          .eq('conversation_id', conversationId);
      return [
        for (final r in List<Map<String, dynamic>>.from(rows))
          if (_reactionFrom(r) != null) _reactionFrom(r)!,
      ];
    } catch (e) {
      debugPrint('[chat] reactions load skipped: $e');
      return const <ChatReaction>[];
    }
  }

  /// Live reaction changes for this conversation.
  void watchReactions(String conversationId) {
    _reactChannel?.unsubscribe();
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'conversation_id',
      value: conversationId,
    );
    void upsert(PostgresChangePayload p) {
      final r = _reactionFrom(Map<String, dynamic>.from(p.newRecord));
      if (r != null && !_reactionUpserts.isClosed) _reactionUpserts.add(r);
    }

    _reactChannel = _client
        .channel('chat_reactions:$conversationId:${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_message_reactions',
          filter: filter,
          callback: upsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_message_reactions',
          filter: filter,
          callback: upsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'chat_message_reactions',
          filter: filter,
          callback: (p) {
            final r = _reactionFrom(Map<String, dynamic>.from(p.oldRecord));
            if (r != null && !_reactionRemovals.isClosed) {
              _reactionRemovals.add(r);
            }
          },
        )
        .subscribe();
  }

  /// Sets, changes (same RPC) or removes ([emoji] empty) the viewer's
  /// reaction on [messageId]. Throws [ChatBackendException] on failure; the
  /// caller must roll back its optimistic UI state.
  Future<void> setReaction(String messageId, String emoji) async {
    final id = senderId;
    if (id == null) {
      throw const ChatBackendException(
        ChatBackendIssue.missingSenderIdentity,
        'No authenticated Odoo id; the reaction was not saved.',
      );
    }
    try {
      final ok = await _client.rpc(
        'chat_set_message_reaction',
        params: {
          'p_message_id': messageId,
          'p_actor_role': _roleName,
          'p_actor_odoo_id': id,
          'p_emoji': emoji,
        },
      );
      if (ok != true) {
        throw const ChatBackendException(
          ChatBackendIssue.unknown,
          'The reaction could not be saved.',
        );
      }
    } on ChatBackendException {
      rethrow;
    } catch (e) {
      throw _map(e);
    }
  }

  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
    await _reactChannel?.unsubscribe();
    _reactChannel = null;
    await _reactionUpserts.close();
    await _reactionRemovals.close();
    await _trChannel?.unsubscribe();
    _trChannel = null;
    await _translations.close();
    await _transcriptions.close();
    await _incoming.close();
    await _receipts.close();
    await _resync.close();
    await _deletions.close();
  }
}

/// A translation that became available for one message.
class ChatTranslationUpdate {
  final String messageId;
  final String text;

  /// True when the server determined the message is already in the viewer's
  /// language (original should simply be shown).
  final bool same;

  /// Server-detected language of the original message (when provided).
  final String? sourceLanguage;

  /// The server-side text translation switch is OFF (`service_disabled`).
  final bool serviceDisabled;
  const ChatTranslationUpdate({
    required this.messageId,
    required this.text,
    this.same = false,
    this.sourceLanguage,
    this.serviceDisabled = false,
  });
}

/// A persisted delivery / read receipt delivered through Realtime.
class ChatReadReceipt {
  final String messageId;
  final DateTime? readAt;
  final DateTime? deliveredAt;
  const ChatReadReceipt({
    required this.messageId,
    this.readAt,
    this.deliveredAt,
  });
}

/// A signed attachment URL with its local expiry time.
class _CachedSignedUrl {
  final String url;
  final DateTime expiresAt;
  const _CachedSignedUrl(this.url, this.expiresAt);
}

/// Server-side translation contract. Flutter NEVER calls `chat-translate`
/// (protected by CHAT_INTERNAL_TOKEN) and never holds OPENAI_API_KEY.
///
/// A trusted backend (database webhook / Odoo / server job) must call the
/// function and write rows into `chat_translations`; the app only reads them.
class ServerSideChatTranslationService implements ChatTranslationService {
  const ServerSideChatTranslationService();

  @override
  bool get isAvailable => false;

  @override
  Future<String> translate({
    required String text,
    required String fromLanguage,
    required String toLanguage,
  }) {
    throw const ChatBackendException(
      ChatBackendIssue.unknown,
      'Translation is performed server-side into chat_translations; '
      'the app does not call chat-translate directly.',
    );
  }
}

/// A transcription / voice translation result for one voice message.
class ChatTranscriptionUpdate {
  final String messageId;
  final String? transcriptText;
  final String? sourceLanguage;
  final String translatedText;

  /// True when the transcript is already in the viewer's language.
  final bool sameLanguage;
  final bool translationFailed;

  /// Server could not identify the spoken language (no direction guessed).
  final bool languageUncertain;

  /// Transcription failed: audio stays playable, retry is offered.
  final bool failed;

  /// Real failure reason (HTTP status / server error_code) for diagnostics.
  final String? failureReason;

  /// Server said this voice message is not transcribable (e.g. > 60 s).
  final bool skipped;

  /// The server-side AI switch for [disabledService] is OFF. Not an error:
  /// no retry is offered and the original audio / transcript stay available.
  final bool serviceDisabled;

  /// `voice_transcription` or `voice_text_translation` when [serviceDisabled].
  final String? disabledService;
  const ChatTranscriptionUpdate({
    required this.messageId,
    this.transcriptText,
    this.sourceLanguage,
    this.translatedText = '',
    this.sameLanguage = false,
    this.translationFailed = false,
    this.languageUncertain = false,
    this.failed = false,
    this.failureReason,
    this.skipped = false,
    this.serviceDisabled = false,
    this.disabledService,
  });
}

/// Identifies the real audio container from its leading bytes.
/// Never trusts the platform: WebM/Matroska (1A 45 DF A3), MP4/M4A
/// ("ftyp" at offset 4), WAV ("RIFF"..."WAVE"), Ogg ("OggS"), MP3 (ID3 or
/// frame sync). Unknown bytes fall back to the platform default.
({String ext, String mime}) _detectAudioFormat(
  Uint8List b, {
  required bool fallbackIsWeb,
}) {
  bool at(int i, List<int> sig) {
    if (b.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (b[i + k] != sig[k]) return false;
    }
    return true;
  }

  if (at(0, const [0x1A, 0x45, 0xDF, 0xA3])) {
    return (ext: 'webm', mime: 'audio/webm');
  }
  if (at(4, const [0x66, 0x74, 0x79, 0x70])) {
    return (ext: 'm4a', mime: 'audio/mp4');
  }
  if (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
      at(8, const [0x57, 0x41, 0x56, 0x45])) {
    return (ext: 'wav', mime: 'audio/wav');
  }
  if (at(0, const [0x4F, 0x67, 0x67, 0x53])) {
    return (ext: 'ogg', mime: 'audio/ogg');
  }
  if (at(0, const [0x49, 0x44, 0x33]) ||
      (b.length > 1 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0)) {
    return (ext: 'mp3', mime: 'audio/mpeg');
  }
  return fallbackIsWeb
      ? (ext: 'webm', mime: 'audio/webm')
      : (ext: 'm4a', mime: 'audio/mp4');
}
