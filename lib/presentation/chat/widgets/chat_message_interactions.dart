import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/chat_models.dart';
import '../../../theme/app_theme.dart';
import '../chat_strings.dart';
import './chat_emoji_panel.dart';

/// Default quick reactions (WhatsApp style).
/// Defined with explicit Unicode code points (+ U+FE0F emoji presentation
/// selector) so every glyph renders as a native colour emoji.
final List<String> kChatQuickReactions = <String>[
  String.fromCharCodes(<int>[0x1F44D]), // thumbs up
  String.fromCharCodes(<int>[0x2764, 0xFE0F]), // red heart
  String.fromCharCodes(<int>[0x1F602]), // face with tears of joy
  String.fromCharCodes(<int>[0x1F62E]), // face with open mouth
  String.fromCharCodes(<int>[0x1F622]), // crying face
  String.fromCharCodes(<int>[0x1F64F]), // folded hands
  String.fromCharCodes(<int>[0x2705, 0xFE0F]), // check mark button
];

/// Short, single-line description of a message used by the reply preview
/// and by the quoted section inside a bubble.
String chatMessageSnippet(ChatMessage m, ChatStrings s) {
  if (m.deletedForEveryone) return s.messageDeletedQuote;
  if (m.isVoice) return s.voiceMessageLabel;
  if (m.isFile) {
    final n = (m.fileName ?? '').trim();
    return n.isEmpty ? s.attachmentLabel : n;
  }
  final t = (m.hasTranslation ? m.translatedText! : m.originalText).trim();
  return t.replaceAll(RegExp(r'\s+'), ' ');
}

// ---------------------------------------------------------------------------
// Reply preview above the composer
// ---------------------------------------------------------------------------

class ChatReplyPreviewBar extends StatelessWidget {
  final String senderName;
  final String snippet;
  final bool isVoice;
  final bool isFile;
  final VoidCallback onCancel;

  const ChatReplyPreviewBar({
    super.key,
    required this.senderName,
    required this.snippet,
    required this.onCancel,
    this.isVoice = false,
    this.isFile = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.isDarkActive
        ? AppTheme.luxuryAccent
        : AppTheme.brandNavy;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppTheme.softGoldBg,
        borderRadius: BorderRadius.circular(16),
        border: BorderDirectional(start: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isVoice || isFile) ...[
                      Icon(
                        isVoice ? Icons.mic_rounded : Icons.attach_file_rounded,
                        size: 15,
                        color: AppTheme.secondaryText,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: AppTheme.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onCancel,
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: AppTheme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quoted message inside a sent bubble
// ---------------------------------------------------------------------------

class ChatQuotedMessage extends StatelessWidget {
  final String senderName;
  final String snippet;
  final bool isVoice;
  final bool isFile;
  final bool deleted;
  final VoidCallback? onTap;

  const ChatQuotedMessage({
    super.key,
    required this.senderName,
    required this.snippet,
    required this.onTap,
    this.isVoice = false,
    this.isFile = false,
    this.deleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.isDarkActive
        ? AppTheme.luxuryAccent
        : AppTheme.brandNavy;
    final width = MediaQuery.of(context).size.width * 0.74;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: BorderDirectional(start: BorderSide(color: accent, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              senderName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVoice || isFile) ...[
                  Icon(
                    isVoice ? Icons.mic_rounded : Icons.attach_file_rounded,
                    size: 14,
                    color: AppTheme.secondaryText,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    snippet,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 13.5,
                      fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reactions shown below a bubble
// ---------------------------------------------------------------------------

class ChatReactionsRow extends StatelessWidget {
  final List<ChatReaction> reactions;
  final ChatRole viewerRole;
  final String? viewerId;
  final ValueChanged<String> onTapEmoji;

  const ChatReactionsRow({
    super.key,
    required this.reactions,
    required this.viewerRole,
    required this.viewerId,
    required this.onTapEmoji,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    final mineEmoji = reactions
        .where((r) => r.reactorRole == viewerRole && r.reactorId == viewerId)
        .map((r) => r.emoji)
        .toSet();
    final accent = AppTheme.isDarkActive
        ? AppTheme.luxuryAccent
        : AppTheme.brandNavy;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final e in counts.entries)
            GestureDetector(
              onTap: () => onTapEmoji(e.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: mineEmoji.contains(e.key)
                      ? accent.withValues(alpha: 0.14)
                      : AppTheme.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: mineEmoji.contains(e.key)
                        ? accent
                        : AppTheme.borderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.key,
                      textScaler: TextScaler.noScaling,
                      style: GoogleFonts.notoColorEmoji(fontSize: 15),
                    ),
                    if (e.value > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${e.value}',
                        style: GoogleFonts.inter(
                          color: AppTheme.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

// ---------------------------------------------------------------------------
// Swipe right to reply (does not compete with vertical scrolling)
// ---------------------------------------------------------------------------

class ChatSwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  const ChatSwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<ChatSwipeToReply> createState() => _ChatSwipeToReplyState();
}

class _ChatSwipeToReplyState extends State<ChatSwipeToReply>
    with SingleTickerProviderStateMixin {
  static const double _threshold = 64;
  static const double _maxDrag = 90;

  double _dx = 0;
  bool _crossed = false;
  late final AnimationController _back = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  Animation<double>? _backAnim;

  @override
  void dispose() {
    _back.dispose();
    super.dispose();
  }

  void _update(DragUpdateDetails d) {
    // "Right" is the reading-forward direction in LTR; in RTL the visual
    // swipe is also left-to-right on screen, so use the raw x delta.
    final next = (_dx + d.delta.dx).clamp(0.0, _maxDrag);
    final crossedNow = next >= _threshold;
    if (crossedNow && !_crossed) HapticFeedback.lightImpact();
    setState(() {
      _dx = next;
      _crossed = crossedNow;
    });
  }

  void _end([DragEndDetails? _]) {
    final trigger = _crossed;
    final from = _dx;
    _backAnim =
        Tween<double>(begin: from, end: 0).animate(
          CurvedAnimation(parent: _back, curve: Curves.easeOut),
        )..addListener(() {
          if (mounted) setState(() => _dx = _backAnim!.value);
        });
    _back.forward(from: 0);
    _crossed = false;
    if (trigger) widget.onReply();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final progress = (_dx / _threshold).clamp(0.0, 1.0);
    final accent = AppTheme.isDarkActive
        ? AppTheme.luxuryAccent
        : AppTheme.brandNavy;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: _end,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 4,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.6 + 0.4 * progress,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: _crossed ? 0.22 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.reply_rounded, size: 20, color: accent),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dx, 0), child: widget.child),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Long-press overlay: reaction bar + floating menu over a dimmed backdrop
// ---------------------------------------------------------------------------

class ChatMenuAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool disabled;

  const ChatMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.disabled = false,
  });
}

/// Shows the WhatsApp-style overlay for the bubble occupying [anchor].
/// [snapshot] is the (already rendered) message bubble so it stays clearly
/// visible above the blur.
Future<void> showChatMessageOverlay({
  required BuildContext context,
  required Rect anchor,
  required Widget snapshot,
  required bool mine,
  required String? currentEmoji,
  required ChatStrings strings,
  required ValueChanged<String> onReact,
  required List<ChatMenuAction> actions,
  required bool canReact,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (ctx, _, __) {
      return _ChatMessageOverlay(
        anchor: anchor,
        snapshot: snapshot,
        mine: mine,
        currentEmoji: currentEmoji,
        strings: strings,
        onReact: onReact,
        actions: actions,
        canReact: canReact,
      );
    },
    transitionBuilder: (ctx, anim, _, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}

class _ChatMessageOverlay extends StatelessWidget {
  final Rect anchor;
  final Widget snapshot;
  final bool mine;
  final String? currentEmoji;
  final ChatStrings strings;
  final ValueChanged<String> onReact;
  final List<ChatMenuAction> actions;
  final bool canReact;

  const _ChatMessageOverlay({
    required this.anchor,
    required this.snapshot,
    required this.mine,
    required this.currentEmoji,
    required this.strings,
    required this.onReact,
    required this.actions,
    required this.canReact,
  });

  static const double _barHeight = 50;
  static const double _gap = 8;
  static const double _menuWidth = 230;
  static const double _rowHeight = 46;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final top = mq.padding.top + 8;
    final bottom = size.height - mq.padding.bottom - 8;
    final menuHeight = actions.length * _rowHeight + 8;
    final barH = canReact ? _barHeight : 0.0;
    final barGap = canReact ? _gap : 0.0;

    final bubbleH = anchor.height;
    final totalH = barH + barGap + bubbleH + _gap + menuHeight;
    // Preferred: keep the bubble where it is; shift the whole stack only
    // when it would leave the safe area.
    var bubbleTop = anchor.top;
    var stackTop = bubbleTop - barH - barGap;
    var stackBottom = bubbleTop + bubbleH + _gap + menuHeight;
    if (stackTop < top) {
      final shift = top - stackTop;
      bubbleTop += shift;
      stackTop += shift;
      stackBottom += shift;
    }
    if (stackBottom > bottom) {
      final shift = stackBottom - bottom;
      bubbleTop -= shift;
      stackTop -= shift;
      stackBottom -= shift;
    }
    // A very tall bubble: pin to top and let it be clipped under the menu.
    if (totalH > bottom - top) {
      bubbleTop = top + barH + barGap;
    }
    final barTop = bubbleTop - barH - barGap;
    final menuTop = bubbleTop + bubbleH + _gap;

    final isRtl = Directionality.of(context) == TextDirection.rtl;
    // `mine` bubbles sit at the trailing edge, others at the leading edge.
    final alignRight = isRtl ? !mine : mine;

    double clampLeft(double w, {required bool right}) {
      final l = right ? anchor.right - w : anchor.left;
      return l.clamp(8.0, size.width - w - 8.0);
    }

    // 7 emoji buttons (38) + circular (+) button (32 + 6 margin) + padding (12).
    final barW = math.min(
      kChatQuickReactions.length * 38.0 + 38.0 + 12.0,
      size.width - 16.0,
    );
    final barLeft = clampLeft(barW, right: alignRight);
    final menuLeft = clampLeft(_menuWidth, right: alignRight);

    // The dialog route has no Material ancestor, so every Text (emojis in the
    // reaction pill, menu rows) falls back to the debug yellow double
    // underline. A transparent Material + explicit no-decoration text style
    // removes it without touching any reaction / long-press behaviour.
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: const TextStyle(decoration: TextDecoration.none),
        child: _buildStack(
          context,
          size: size,
          barTop: barTop,
          barLeft: barLeft,
          barW: barW,
          bubbleTop: bubbleTop,
          menuTop: menuTop,
          menuLeft: menuLeft,
        ),
      ),
    );
  }

  Widget _buildStack(
    BuildContext context, {
    required Size size,
    required double barTop,
    required double barLeft,
    required double barW,
    required double bubbleTop,
    required double menuTop,
    required double menuLeft,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        ),
        if (canReact)
          Positioned(
            top: barTop,
            left: barLeft,
            width: barW,
            height: _barHeight,
            child: _ReactionBar(
              current: currentEmoji,
              onPick: (e) {
                Navigator.of(context).pop();
                onReact(e);
              },
              onMore: () async {
                final nav = Navigator.of(context);
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => ChatEmojiPanel(
                    strings: strings,
                    onSelected: (e) => Navigator.of(ctx).pop(e),
                    onClose: () => Navigator.of(ctx).pop(),
                  ),
                );
                if (nav.canPop()) nav.pop();
                if (picked != null && picked.isNotEmpty) onReact(picked);
              },
            ),
          ),
        Positioned(
          top: bubbleTop,
          left: anchor.left.clamp(0.0, size.width),
          width: anchor.width,
          child: IgnorePointer(
            child: Material(
              type: MaterialType.transparency,
              child: DefaultTextStyle.merge(
                style: const TextStyle(decoration: TextDecoration.none),
                child: snapshot,
              ),
            ),
          ),
        ),
        Positioned(
          top: menuTop,
          left: menuLeft,
          width: _menuWidth,
          child: Material(
            color: AppTheme.cardWhite,
            elevation: 8,
            shadowColor: Colors.black45,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in actions)
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      a.onTap?.call();
                    },
                    child: SizedBox(
                      height: _rowHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                a.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: a.destructive
                                      ? Colors.redAccent
                                      : (a.disabled
                                            ? AppTheme.secondaryText.withValues(
                                                alpha: 0.6,
                                              )
                                            : AppTheme.primaryText),
                                ),
                              ),
                            ),
                            Icon(
                              a.icon,
                              size: 21,
                              color: a.destructive
                                  ? Colors.redAccent
                                  : (a.disabled
                                        ? AppTheme.secondaryText.withValues(
                                            alpha: 0.6,
                                          )
                                        : AppTheme.secondaryText),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionBar extends StatefulWidget {
  final String? current;
  final ValueChanged<String> onPick;
  final VoidCallback onMore;

  const _ReactionBar({
    required this.current,
    required this.onPick,
    required this.onMore,
  });

  @override
  State<_ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<_ReactionBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Staggered 0..1 progress for item [i] of [n] (emojis pop in one by one).
  double _itemProgress(int i, int n) {
    final start = 0.08 + (i / n) * 0.45;
    final end = (start + 0.42).clamp(0.0, 1.0);
    final t = ((_ctrl.value - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDarkActive;
    final pillColor = dark ? const Color(0xFF2A2724) : const Color(0xFFFFFCF5);
    final total = kChatQuickReactions.length + 1;

    final pill = Container(
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.35 : 0.14),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < kChatQuickReactions.length; i++)
                _ReactionEmojiButton(
                  emoji: kChatQuickReactions[i],
                  selected: widget.current == kChatQuickReactions[i],
                  progress: _itemProgress(i, total),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onPick(kChatQuickReactions[i]);
                  },
                ),
              _ReactionMoreButton(
                progress: _itemProgress(total - 1, total),
                onTap: widget.onMore,
              ),
            ],
          );
        },
      ),
    );

    // Pill grows from its anchor edge with a soft fade.
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
      child: ScaleTransition(
        scale: Tween<double>(
          begin: 0.86,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack)),
        alignment: Alignment.bottomCenter,
        child: pill,
      ),
    );
  }
}

class _ReactionEmojiButton extends StatefulWidget {
  final String emoji;
  final bool selected;
  final double progress;
  final VoidCallback onTap;

  const _ReactionEmojiButton({
    required this.emoji,
    required this.selected,
    required this.progress,
    required this.onTap,
  });

  @override
  State<_ReactionEmojiButton> createState() => _ReactionEmojiButtonState();
}

class _ReactionEmojiButtonState extends State<_ReactionEmojiButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDarkActive;
    final accent = dark ? AppTheme.luxuryAccent : AppTheme.brandNavy;
    final p = widget.progress.clamp(0.0, 1.2);
    final pressScale = _pressed ? 1.22 : 1.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Opacity(
        opacity: widget.progress.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - p.clamp(0.0, 1.0)) * 10),
          child: AnimatedScale(
            scale: pressScale * (0.6 + 0.4 * p),
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.selected
                    ? accent.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
              child: Text(
                widget.emoji,
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                strutStyle: const StrutStyle(
                  fontSize: 24,
                  height: 1.2,
                  forceStrutHeight: true,
                ),
                style: GoogleFonts.notoColorEmoji(fontSize: 24, height: 1.2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReactionMoreButton extends StatefulWidget {
  final double progress;
  final VoidCallback onTap;

  const _ReactionMoreButton({required this.progress, required this.onTap});

  @override
  State<_ReactionMoreButton> createState() => _ReactionMoreButtonState();
}

class _ReactionMoreButtonState extends State<_ReactionMoreButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDarkActive;
    final p = widget.progress.clamp(0.0, 1.2);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Opacity(
        opacity: widget.progress.clamp(0.0, 1.0),
        child: AnimatedScale(
          scale: (_pressed ? 0.9 : 1.0) * (0.6 + 0.4 * p),
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark ? const Color(0xFF3A3632) : const Color(0xFFF1EBDD),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 20,
              color: dark ? const Color(0xFFD9D2C3) : const Color(0xFF6B6558),
            ),
          ),
        ),
      ),
    );
  }
}
