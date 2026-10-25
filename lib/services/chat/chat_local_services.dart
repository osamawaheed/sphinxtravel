import 'dart:async';

import '../../models/chat_models.dart';
import './chat_demo_data.dart';
import './chat_services.dart';

/// Phase 1 local implementations. These are NOT backends:
///  * no network calls
///  * no real translation
///  * no real delivery / read receipts
///  * voice recording/playback is handled by DeviceChatAudioService (local only)
/// They exist so the UI can be reviewed and so Phase 2 can swap in real
/// implementations behind the same interfaces.

class LocalChatAccessService implements ChatAccessService {
  const LocalChatAccessService();

  @override
  Future<ChatAccessResult> canAccess({
    required String bookingReference,
    required ChatRole role,
  }) async {
    // Odoo 17 permission check is not connected yet (Phase 2).
    return const ChatAccessResult(
      allowed: false,
      reason: 'Odoo access validation not connected',
    );
  }
}

class LocalChatTranslationService implements ChatTranslationService {
  const LocalChatTranslationService();

  @override
  bool get isAvailable => false;

  @override
  Future<String> translate({
    required String text,
    required String fromLanguage,
    required String toLanguage,
  }) {
    // Never fabricate a translation.
    throw const ChatServiceUnavailable('Translation provider not connected');
  }
}

/// In-memory repository seeded with clearly labeled demo history.
/// Sent messages stay `sent` — it never reports delivered/read.
class LocalDemoChatRepository implements ChatRepository {
  LocalDemoChatRepository({required this.viewerRole});

  final ChatRole viewerRole;
  final List<ChatMessage> _messages = ChatDemoData.history();
  final StreamController<ChatMessage> _incoming =
      StreamController<ChatMessage>.broadcast();
  int _seq = 0;

  @override
  Future<ChatConversation> openConversation({
    required String bookingReference,
    required ChatRole role,
  }) async {
    return ChatDemoData.conversation(
      viewerRole: role,
      bookingReference: bookingReference,
    );
  }

  @override
  Future<List<ChatMessage>> loadHistory({
    required String conversationId,
    DateTime? before,
    int limit = 30,
  }) async {
    return List.unmodifiable(_messages);
  }

  @override
  Stream<ChatMessage> watchMessages(String conversationId) => _incoming.stream;

  @override
  Future<ChatMessage> sendText({
    required String conversationId,
    required String text,
    required String language,
  }) async {
    final msg = ChatMessage(
      id: 'local-${++_seq}',
      kind: ChatMessageKind.text,
      originalText: text,
      originalLanguage: language,
      sentAt: DateTime.now(),
      status: ChatDeliveryStatus.sent,
      isDemo: true,
    );
    _messages.add(msg);
    return msg;
  }

  @override
  Future<ChatMessage> sendVoice({
    required String localPath,
    required String conversationId,
    required int durationSeconds,
  }) async {
    final msg = ChatMessage(
      id: 'local-${++_seq}',
      kind: ChatMessageKind.voice,
      sentAt: DateTime.now(),
      status: ChatDeliveryStatus.sent,
      voiceDurationSeconds: durationSeconds,
      voiceUrl: localPath,
      isDemo: true,
    );
    _messages.add(msg);
    return msg;
  }

  @override
  Future<void> markRead({
    required String conversationId,
    required String upToMessageId,
  }) async {}

  @override
  Future<int> unreadCount(String conversationId) async => 0;

  void dispose() => _incoming.close();
}

class ChatServiceUnavailable implements Exception {
  final String message;
  const ChatServiceUnavailable(this.message);

  @override
  String toString() => message;
}
