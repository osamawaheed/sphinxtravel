import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/chat_models.dart';
import '../../../theme/app_theme.dart';
import '../chat_strings.dart';
import './chat_media_widgets.dart';
import './chat_text_bubble.dart' show ChatStatusTicks;

/// Bubble for a file attachment. Image, video and PDF messages are rendered as
/// WhatsApp-style edge-to-edge media bubbles (no padding, no card background,
/// clipped to the rounded bubble) with the timestamp + receipt ticks overlaid
/// bottom-right on a subtle dark gradient. DOC / DOCX / XLS / XLSX / TXT keep
/// the compact document card. All media is fetched through cached, short-lived
/// signed URLs (private bucket).
class ChatFileBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final ChatStrings strings;
  final String timeLabel;

  /// Opens / downloads the file externally (signed URL).
  final VoidCallback onOpen;

  /// Returns a cached signed URL (refreshes only when asked).
  final ChatUrlResolver resolveUrl;

  const ChatFileBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.strings,
    required this.timeLabel,
    required this.onOpen,
    required this.resolveUrl,
  });

  Future<void> _openImage(BuildContext context) async {
    final url = await resolveUrl();
    if (url == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ChatImageViewerPage(
          url: url,
          title: message.fileName ?? strings.attachment,
          strings: strings,
        ),
      ),
    );
  }

  void _openVideo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ChatVideoPlayerPage(
          resolveUrl: resolveUrl,
          title: message.fileName ?? strings.attachment,
          strings: strings,
        ),
      ),
    );
  }

  void _openPdf(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ChatPdfViewerPage(
          resolveUrl: resolveUrl,
          title: message.fileName ?? strings.attachment,
          strings: strings,
          onDownload: onOpen,
        ),
      ),
    );
  }

  Widget _media(BuildContext context, ChatMediaKind kind) {
    switch (kind) {
      case ChatMediaKind.image:
        return ChatInlineImage(
          message: message,
          strings: strings,
          resolveUrl: resolveUrl,
          onOpenViewer: () => _openImage(context),
        );
      case ChatMediaKind.video:
        return ChatVideoCard(
          message: message,
          strings: strings,
          resolveUrl: resolveUrl,
          onPlay: () => _openVideo(context),
        );
      case ChatMediaKind.pdf:
        return ChatPdfCard(
          message: message,
          strings: strings,
          resolveUrl: resolveUrl,
          onOpenViewer: () => _openPdf(context),
          onDownload: onOpen,
        );
      case ChatMediaKind.document:
        return const SizedBox.shrink();
    }
  }

  /// Timestamp (+ receipt ticks for my messages) shown on the media itself.
  Widget _overlayStamp() {
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 4)];
    return PositionedDirectional(
      end: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 14, 8, 5),
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.bottomRight,
              radius: 1.0,
              colors: [Color(0x99000000), Color(0x00000000)],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeLabel,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  shadows: shadow,
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 3),
                Transform.scale(
                  scale: 0.62,
                  child: ChatStatusTicks(status: message.status),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kind = chatMediaKindOf(message);
    final maxW = (MediaQuery.of(context).size.width * 0.74).clamp(180.0, 300.0);
    final radius = BorderRadius.circular(18);

    if (kind != ChatMediaKind.document) {
      // WhatsApp-style: media IS the bubble. Clip to the rounded outer shape.
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: SizedBox(
          width: maxW,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(children: [_media(context, kind), _overlayStamp()]),
          ),
        ),
      );
    }

    final dark = AppTheme.isDarkActive;
    final bubbleColor = isMine
        ? (dark ? AppTheme.darkSoftGoldBg : AppTheme.softGoldBg)
        : AppTheme.cardWhite;
    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMine ? Colors.transparent : AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChatDocumentCard(message: message, strings: strings, onOpen: onOpen),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 6),
                    ChatStatusTicks(status: message.status),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
