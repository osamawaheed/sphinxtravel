import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/chat_models.dart';
import '../../../services/chat/chat_services.dart';
import '../../../services/chat/chat_audio_diagnostics.dart';
import '../../../theme/app_theme.dart';
import '../chat_strings.dart';
import './chat_text_bubble.dart';

/// Voice message bubble: play/pause, waveform with live progress,
/// elapsed / total duration, timestamp, status. Phase 3.1 adds a compact
/// transcript / translated-text block under the player.
class ChatVoiceBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMine;

  /// Sender shown as the avatar (with microphone badge) on the right.
  final ChatParticipant? sender;

  /// Live playback state of the whole chat player. The bubble only reacts to
  /// it when [ChatPlaybackState.messageId] matches this message.
  final Stream<ChatPlaybackState> playback;
  final ChatPlaybackState initialPlayback;
  final String timeLabel;
  final ChatStrings strings;
  final Future<void> Function() onTogglePlay;

  /// Id of the voice message currently being loaded (signed URL / source
  /// load). The play icon shows a spinner only while it equals this message.
  final ValueListenable<String?>? loadingMessageId;

  /// Chat translation language (decides text direction of translated text).
  final String? translationLanguage;

  /// Retries a failed transcription. Null => no retry button.
  final VoidCallback? onRetryTranscription;

  /// Real failure reason (HTTP status / server error code). Shown only to the
  /// recipient, below the generic "Transcription unavailable" message.
  final String? failureReason;

  /// Phase 3.2: generates / plays the translated audio. Null => no button.
  /// Resolves to the outcome so the bubble can show loading / error states.
  final Future<ChatTtsStatus> Function({bool retry})? onListenTranslated;

  /// Exact server-side reason of the last translated-audio failure (for
  /// example `http_503:ElevenLabs not configured`). Shown next to the
  /// generic message so a missing provider is reported precisely.
  final String? Function()? ttsReasonProvider;

  const ChatVoiceBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.sender,
    required this.playback,
    required this.initialPlayback,
    required this.timeLabel,
    required this.strings,
    required this.onTogglePlay,
    this.loadingMessageId,
    this.translationLanguage,
    this.onRetryTranscription,
    this.failureReason,
    this.onListenTranslated,
    this.ttsReasonProvider,
  });

  static String fmt(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static final ValueNotifier<String?> _noLoading = ValueNotifier<String?>(null);

  @override
  State<ChatVoiceBubble> createState() => _ChatVoiceBubbleState();
}

class _ChatVoiceBubbleState extends State<ChatVoiceBubble> {
  bool _ttsLoading = false;
  ChatTtsStatus? _ttsOutcome;
  bool _toggleBusy = false;

  ChatMessage get message => widget.message;
  bool get isMine => widget.isMine;
  ChatStrings get strings => widget.strings;

  /// One physical tap = one playback action. The guard stays set only while
  /// the previous toggle request is still in flight (signed URL fetch, source
  /// load, play/pause), so overlapping requests cannot stop each other's
  /// audio. It is always released in `finally`, so controls are never locked.
  Future<void> _handleToggle() async {
    if (_toggleBusy) {
      ChatAudioDiagnostics.instance.logEvent(
        'DUPLICATE_GESTURE',
        'ignored: previous toggle still in flight message=${message.id}',
      );
      return;
    }
    _toggleBusy = true;
    try {
      await widget.onTogglePlay();
    } catch (_) {
      // Failures are surfaced by the screen's own handler.
    } finally {
      _toggleBusy = false;
    }
  }

  @override
  void didUpdateWidget(covariant ChatVoiceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different message (never expected with keyed rows) or a different
    // translation language must not inherit the previous TTS outcome.
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.translationLanguage != widget.translationLanguage) {
      _ttsOutcome = null;
      _ttsLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDarkActive;
    final bubbleColor = isMine
        ? (dark ? AppTheme.darkSoftGoldBg : AppTheme.softGoldBg)
        : AppTheme.cardWhite;
    final totalSeconds = message.voiceDurationSeconds ?? 0;
    final fmt = ChatVoiceBubble.fmt;
    final screenWidth = MediaQuery.of(context).size.width;
    // Previous width (98% of screen) + 30%, capped to the space the chat row
    // really offers (screen minus list padding) so small screens never clip.
    final maxAvailable = screenWidth - 32;
    final bubbleWidth = MediaQuery.of(context).size.width * 0.80;

    return Container(
      width: bubbleWidth,
      constraints: BoxConstraints(maxWidth: bubbleWidth),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(16),
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
      child: StreamBuilder<ChatPlaybackState>(
        stream: widget.playback,
        initialData: widget.initialPlayback,
        builder: (context, snap) {
          final st = snap.data ?? const ChatPlaybackState();
          final active = st.messageId == message.id;
          final playing = active && st.playing;

          // Prefer the real decoded duration once the player knows it.
          final totalMs = (active && (st.duration?.inMilliseconds ?? 0) > 0)
              ? st.duration!.inMilliseconds
              : totalSeconds * 1000;
          final posMs = active
              ? st.position.inMilliseconds.clamp(0, totalMs > 0 ? totalMs : 1)
              : 0;
          final progress = totalMs > 0 ? posMs / totalMs : 0.0;

          final shownSeconds = active && posMs > 0
              ? (posMs / 1000).floor()
              : (totalMs / 1000).round();
          final label = active && posMs > 0
              ? '${fmt(shownSeconds)} / ${fmt((totalMs / 1000).round())}'
              : fmt(shownSeconds);

          final hasButton = _hasListenTranslatedButton();

          final playIcon = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleToggle,
            child: SizedBox(
              width: 34,
              height: 42,
              child: Center(
                child: ValueListenableBuilder<String?>(
                  valueListenable:
                      widget.loadingMessageId ?? ChatVoiceBubble._noLoading,
                  builder: (context, loadingId, _) {
                    final loading = loadingId == message.id && !playing;
                    return loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.luxuryAccent,
                            ),
                          )
                        : Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: AppTheme.luxuryAccent,
                            size: 40,
                          );
                  },
                ),
              ),
            ),
          );

          final waveform = Expanded(
            child: SizedBox(
              height: 28,
              width: double.infinity,
              child: CustomPaint(
                painter: _VoiceWavePainter(
                  bars: _organicBars(),
                  progress: progress.clamp(0.0, 1.0),
                  showHead: true,
                  playedColor: Colors.black,
                  idleColor: const Color(0xFFB8B8B8),
                  headColor: const Color(0xFF53A6FA),
                ),
              ),
            ),
          );

          final durationTimeRow = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  // avatar 46 + gap 8 + play 34 + gap 4 = 92
                  padding: const EdgeInsets.only(left: 92),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Invisible placeholder keeps the duration/ticks layout identical;
              // the visible timestamp is drawn separately, 5% lower.
              Opacity(
                opacity: 0,
                child: Text(
                  widget.timeLabel,
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryText,
                    fontSize: 11,
                    height: 1.1,
                  ),
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                ChatStatusTicks(status: message.status),
              ],
            ],
          );

          // Timestamp only, aligned exactly where it sits inside
          // [durationTimeRow] (right edge minus ticks width when mine).
          final timestampOnly = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                widget.timeLabel,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 11,
                  height: 1.1,
                ),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                Opacity(
                  opacity: 0,
                  child: ChatStatusTicks(status: message.status),
                ),
              ],
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 76,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Avatar: centered on the Y axis of the fixed player area
                    // (identical with or without "Listen Translated").
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Center(child: _avatarWithMic()),
                    ),
                    // Play icon + waveform row, vertically centered.
                    Positioned(
                      left: 54,
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          playIcon,
                          const SizedBox(width: 4),
                          waveform,
                        ],
                      ),
                    ),
                    // Duration / ticks row: same top as the timestamp so both
                    // share one horizontal baseline.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 55.0,
                      height: 14,
                      child: durationTimeRow,
                    ),
                    // Timestamp only: stays at 55.0 from the top.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 55.0,
                      height: 14,
                      child: timestampOnly,
                    ),
                  ],
                ),
              ),
              ..._translatedAudioBlock(),
              hasButton ? const SizedBox(height: 8) : const SizedBox.shrink(),
              // Keep the bottom padding stable while loading / status text
              // replaces the button (no layout jump).
            ],
          );
        },
      ),
    );
  }

  /// Mirrors the visibility rules of [_translatedAudioBlock] so layout can
  /// adapt when the "Listen Translated" button is present.
  bool _hasListenTranslatedButton() {
    final m = message;
    final spokenLang = (m.transcriptLanguage ?? m.originalLanguage)
        .toLowerCase();
    final targetLang = (widget.translationLanguage ?? '').toLowerCase();
    final sameLanguage = targetLang.isNotEmpty && spokenLang == targetLang;
    return !(isMine ||
        m.isDemo ||
        widget.onListenTranslated == null ||
        m.transcriptionState != ChatTranscriptionState.ready ||
        m.languageUncertain ||
        sameLanguage ||
        !m.hasTranslation);
  }

  Widget _avatarWithMic() {
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ChatAvatar(participant: widget.sender, size: 46),
          Positioned(
            right: -5,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.luxuryAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMine
                      ? (AppTheme.isDarkActive
                            ? AppTheme.darkSoftGoldBg
                            : AppTheme.softGoldBg)
                      : AppTheme.cardWhite,
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.mic_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _small =>
      GoogleFonts.inter(color: AppTheme.secondaryText, fontSize: 12.5);

  Future<void> _listenTranslated({bool retry = false}) async {
    final cb = widget.onListenTranslated;
    if (cb == null || _ttsLoading) return;
    setState(() {
      _ttsLoading = true;
      _ttsOutcome = null;
    });
    ChatTtsStatus outcome;
    try {
      outcome = await cb(retry: retry);
    } catch (_) {
      outcome = ChatTtsStatus.failed;
    }
    if (!mounted) return;
    setState(() {
      _ttsLoading = false;
      // `ready` means the screen started playback; nothing else to show.
      _ttsOutcome = outcome == ChatTtsStatus.ready ? null : outcome;
    });
  }

  /// Voice bubbles are audio-only from the user's side: transcription and
  /// translated text stay stored on the message but are never rendered here.

  /// Phase 3.2: "Listen Translated" for RECEIVED voice messages whose
  /// translation exists. Original playback above is untouched.
  List<Widget> _translatedAudioBlock() {
    final s = strings;
    final m = message;
    // Hide the button when the spoken language already matches the language
    // the user selected for chat translation.
    final spokenLang = (m.transcriptLanguage ?? m.originalLanguage)
        .toLowerCase();
    final targetLang = (widget.translationLanguage ?? '').toLowerCase();
    final sameLanguage = targetLang.isNotEmpty && spokenLang == targetLang;
    if (isMine ||
        m.isDemo ||
        widget.onListenTranslated == null ||
        m.transcriptionState != ChatTranscriptionState.ready ||
        m.languageUncertain ||
        sameLanguage ||
        !m.hasTranslation) {
      return const [];
    }

    if (_ttsLoading) {
      return [_status(s.generatingTranslatedAudio)];
    }

    final outcome = _ttsOutcome;
    final String? message_ = switch (outcome) {
      ChatTtsStatus.disabled => s.translatedAudioDisabled,
      ChatTtsStatus.unavailable => s.translatedAudioUnavailable,
      ChatTtsStatus.failed => s.translatedAudioFailed,
      ChatTtsStatus.pending => s.generatingTranslatedAudio,
      _ => null,
    };

    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 0),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _listenTranslated(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.softGoldBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.record_voice_over_rounded,
                  size: 18,
                  color: AppTheme.navyText,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    s.listenTranslated,
                    style: GoogleFonts.inter(
                      color: AppTheme.navyText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      if (message_ != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppTheme.secondaryText,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(() {
                  final r = outcome == ChatTtsStatus.ready
                      ? null
                      : widget.ttsReasonProvider?.call();
                  return (r == null || r.isEmpty) ? message_ : '$message_ ($r)';
                }(), style: _small),
              ),
              if (outcome == ChatTtsStatus.failed) ...[
                const SizedBox(width: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _listenTranslated(retry: true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Text(
                      s.retry,
                      style: GoogleFonts.inter(
                        color: AppTheme.luxuryAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
    ];
  }

  Widget _status(String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.luxuryAccent,
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: _small),
        ],
      ),
    );
  }

  static const List<double> _defaultWave = [
    .3,
    .6,
    .4,
    .8,
    .5,
    .7,
    .3,
    .6,
    .45,
    .75,
    .35,
    .65,
  ];

  List<double>? _cachedBars;
  String? _cachedBarsKey;

  /// Real amplitude data when the message carries a meaningful waveform,
  /// otherwise a stable, irregular waveform seeded from the message id.
  List<double> _organicBars() {
    final real = message.waveform;
    final key = '${message.id}|${real?.length ?? 0}';
    if (_cachedBars != null && _cachedBarsKey == key) return _cachedBars!;
    List<double> result;
    if (real != null && real.length >= 24) {
      result = real;
    } else {
      result = _generateWave(message.id.toString(), 64);
    }
    _cachedBars = result;
    _cachedBarsKey = key;
    return result;
  }

  static List<double> _generateWave(String seedStr, int count) {
    int h = 2166136261;
    for (final c in seedStr.codeUnits) {
      h = ((h ^ c) * 16777619) & 0x7fffffff;
    }
    int state = h == 0 ? 123456789 : h;
    double next() {
      // xorshift-style LCG, deterministic per message.
      state = (state * 1103515245 + 12345) & 0x7fffffff;
      return state / 0x7fffffff;
    }

    final out = <double>[];
    double envelope = 0.5;
    for (int i = 0; i < count; i++) {
      // Slowly drifting envelope so phrases rise and fall naturally.
      envelope = (envelope + (next() - 0.5) * 0.35).clamp(0.25, 0.95);
      final r = next();
      double v;
      if (r < 0.22) {
        v = 0.08 + next() * 0.14; // very short
      } else if (r < 0.62) {
        v = 0.25 + next() * 0.3 * envelope + 0.1; // medium
      } else {
        v = 0.55 + next() * 0.45 * envelope; // tall
      }
      out.add(v.clamp(0.08, 1.0));
    }
    return out;
  }
}

/// WhatsApp-style waveform: thin rounded bars with irregular heights,
/// played bars dark, unplayed bars light gray, plus a round progress dot.
class _VoiceWavePainter extends CustomPainter {
  final List<double> bars;
  final double progress;
  final bool showHead;
  final Color playedColor;
  final Color idleColor;
  final Color headColor;

  _VoiceWavePainter({
    required this.bars,
    required this.progress,
    required this.showHead,
    required this.playedColor,
    required this.idleColor,
    required this.headColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0) return;
    const barW = 1.8;
    const gap = 1.8;
    final count = ((size.width + gap) / (barW + gap)).floor().clamp(8, 400);
    final step = size.width / count;
    final midY = size.height / 2;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barW;
    for (int i = 0; i < count; i++) {
      final src =
          bars[(i * bars.length / count).floor().clamp(0, bars.length - 1)];
      final h = barW + (size.height - barW) * src.clamp(0.08, 1.0);
      final x = i * step + step / 2;
      paint.color = (i + 0.5) / count <= progress ? playedColor : idleColor;
      canvas.drawLine(
        Offset(x, midY - h / 2 + barW / 2),
        Offset(x, midY + h / 2 - barW / 2),
        paint,
      );
    }
    if (showHead) {
      final hx = (size.width * progress).clamp(5.0, size.width - 5.0);
      canvas.drawCircle(Offset(hx, midY), 5.0, Paint()..color = headColor);
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWavePainter old) =>
      old.progress != progress ||
      old.showHead != showHead ||
      old.bars != bars ||
      old.playedColor != playedColor ||
      old.idleColor != idleColor ||
      old.headColor != headColor;
}

/// Centered "Driver Changed" system message.
class ChatSystemMessage extends StatelessWidget {
  final String newDriverName;
  final String timeLabel;
  final ChatStrings strings;

  const ChatSystemMessage({
    super.key,
    required this.newDriverName,
    required this.timeLabel,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppTheme.borderColor, height: 1)),
          Flexible(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.isDarkActive
                    ? AppTheme.darkCard
                    : const Color(0xFFF1EEE8),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.softGoldBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_car_filled_rounded,
                      size: 18,
                      color: AppTheme.luxuryAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          strings.driverChanged,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppTheme.navyText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.isNowAssigned(newDriverName),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: AppTheme.primaryText,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeLabel,
                          style: GoogleFonts.inter(
                            color: AppTheme.secondaryText,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: Divider(color: AppTheme.borderColor, height: 1)),
        ],
      ),
    );
  }
}
