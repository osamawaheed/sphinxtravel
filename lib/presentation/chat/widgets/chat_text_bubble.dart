import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/chat_models.dart';
import '../../../theme/app_theme.dart';
import '../../../services/api_client.dart';
import '../chat_strings.dart';

/// Circular avatar with initials fallback.
class ChatAvatar extends StatelessWidget {
  final ChatParticipant? participant;
  final double size;
  final bool showOnlineDot;

  const ChatAvatar({
    super.key,
    required this.participant,
    this.size = 40,
    this.showOnlineDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = (participant?.name ?? '').trim();
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      color: AppTheme.softGoldBg,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: GoogleFonts.inter(
          color: AppTheme.luxuryAccent,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    final url = participant?.photoUrl;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: (url == null || url.trim().isEmpty)
            ? fallback
            : _ChatProfileImage(
                photoUrl: url,
                size: size,
                fallback: fallback,
                placeholder: Container(
                  width: size,
                  height: size,
                  color: AppTheme.softGoldBg,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: size * 0.34,
                    height: size * 0.34,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.luxuryAccent,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Loads a profile photo with the existing app auth headers (Odoo `/web/image`
/// URLs are protected), shows [placeholder] while loading and [fallback]
/// (initial) only when the URL is empty or the image genuinely fails.
/// Header lookups are cached per widget so rebuilds do not reload the image.
class _ChatProfileImage extends StatefulWidget {
  final String photoUrl;
  final double size;
  final Widget fallback;
  final Widget placeholder;

  const _ChatProfileImage({
    required this.photoUrl,
    required this.size,
    required this.fallback,
    required this.placeholder,
  });

  @override
  State<_ChatProfileImage> createState() => _ChatProfileImageState();
}

class _ChatProfileImageState extends State<_ChatProfileImage> {
  static Map<String, String>? _cachedHeaders;
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    _headers = _cachedHeaders;
    if (_headers == null) _loadHeaders();
  }

  Future<void> _loadHeaders() async {
    Map<String, String> headers;
    try {
      headers = await ApiClient.authHeaders();
    } catch (_) {
      headers = const <String, String>{};
    }
    _cachedHeaders = headers;
    if (mounted) setState(() => _headers = headers);
  }

  @override
  Widget build(BuildContext context) {
    final url = ApiClient.resolveUrl(widget.photoUrl);
    if (url.isEmpty) return widget.fallback;
    final headers = _headers;
    if (headers == null) return widget.placeholder;
    // Auth headers are only sent to the app's own API host, never to third
    // party image hosts.
    final apiHost = Uri.tryParse(ApiClient.baseUrl)?.host;
    final sameHost = Uri.tryParse(url)?.host == apiHost;
    return Image.network(
      url,
      headers: sameHost && headers.isNotEmpty ? headers : null,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : widget.placeholder,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}

/// One chat bubble (text). Shows sender name + role, timestamp, delivery
/// status (only what the backend actually reported) and View Original /
/// Translated controls.
class ChatTextBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMine;
  final ChatStrings strings;
  final String timeLabel;

  /// Chat translation language; decides the direction of translated text.
  final String? translationLanguage;

  const ChatTextBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.strings,
    required this.timeLabel,
    this.translationLanguage,
  });

  @override
  State<ChatTextBubble> createState() => _ChatTextBubbleState();
}

class _ChatTextBubbleState extends State<ChatTextBubble> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final s = widget.strings;
    final mine = widget.isMine;
    final dark = AppTheme.isDarkActive;

    final bubbleColor = mine
        ? (dark ? AppTheme.darkSoftGoldBg : AppTheme.softGoldBg)
        : AppTheme.cardWhite;
    final showTranslated = m.hasTranslation && !_showOriginal;
    final text = showTranslated ? m.translatedText! : m.originalText;
    final originalIsRtl = m.originalLanguage == 'ar';
    final textDirection = showTranslated
        ? (widget.translationLanguage != null
              ? (widget.translationLanguage == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr)
              : Directionality.of(context))
        : (originalIsRtl ? TextDirection.rtl : TextDirection.ltr);

    final canToggle = m.hasTranslation;
    final unavailable = m.translationState == ChatTranslationState.unavailable;

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.74,
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: mine ? Colors.transparent : AppTheme.borderColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Directionality(
            textDirection: textDirection,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.timeLabel,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 6),
                ChatStatusTicks(status: m.status),
              ],
            ],
          ),
          if (!canToggle &&
              !unavailable &&
              m.disabledService == 'text_translation') ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 16,
                  color: AppTheme.secondaryText,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    s.textTranslationDisabled,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (canToggle || unavailable) ...[
            const SizedBox(height: 8),
            if (canToggle)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _showOriginal = !_showOriginal),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.translate_rounded,
                        size: 16,
                        color: AppTheme.secondaryText,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _showOriginal
                              ? s.viewTranslated
                              : '${s.viewOriginal} (${s.languageName(m.originalLanguage)})',
                          style: GoogleFonts.inter(
                            color: AppTheme.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showOriginal
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppTheme.secondaryText,
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.translate_rounded,
                    size: 16,
                    color: AppTheme.secondaryText,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${s.translationUnavailable} · ${s.original} (${s.languageName(m.originalLanguage)})',
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// Shows ticks only for statuses the backend really reported.
/// sending = clock, sent = one gray check, read = two blue checks.
class ChatStatusTicks extends StatelessWidget {
  final ChatDeliveryStatus status;
  const ChatStatusTicks({super.key, required this.status});

  static const Color sentGray = Color(0xFF9CA3AF);
  static const Color readBlue = Color(0xFF34B7F1);

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ChatDeliveryStatus.sending:
        return const Icon(Icons.schedule_rounded, size: 14, color: sentGray);
      case ChatDeliveryStatus.sent:
      case ChatDeliveryStatus.delivered:
        // `delivered` is never reported by the backend; treated as sent so
        // two gray checks are never shown.
        return const Icon(Icons.check_rounded, size: 22.5, color: sentGray);
      case ChatDeliveryStatus.read:
        return const Icon(Icons.done_all_rounded, size: 22.5, color: readBlue);
      case ChatDeliveryStatus.failed:
        return const Icon(
          Icons.error_outline_rounded,
          size: 15,
          color: AppTheme.errorRed,
        );
    }
  }
}
