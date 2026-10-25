import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

import '../../../models/chat_models.dart';
import '../../../theme/app_theme.dart';
import '../chat_strings.dart';
import './chat_emoji_panel.dart';

/// Horizontal Quick Messages strip shown above the input.
class ChatQuickMessagesBar extends StatelessWidget {
  final List<ChatQuickMessage> items;
  final ChatStrings strings;
  final ValueChanged<ChatQuickMessage> onSelect;

  const ChatQuickMessagesBar({
    super.key,
    required this.items,
    required this.strings,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.softGoldBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 18,
                    color: AppTheme.luxuryAccent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    strings.quickMessages,
                    style: GoogleFonts.inter(
                      color: AppTheme.isDarkActive
                          ? AppTheme.luxuryAccent
                          : const Color(0xFF7A5A1E),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }
          final q = items[i - 1];
          final label = strings.quick(q.key);
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => onSelect(q),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 13.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Input row: attach, text field, mic, send.
///
/// Voice gestures (WhatsApp style) on the mic button:
/// * press & hold  -> [onHoldStart] (recording begins)
/// * release       -> [onHoldRelease] (stop & send)
/// * swipe up      -> lock (recording continues hands-free)
/// * swipe left    -> [onHoldCancel] (discard, never uploaded)
/// Pointer events are used so touch and mouse (Chrome preview) both work.
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final ChatStrings strings;
  final bool isRecording;
  final Duration recordingElapsed;

  /// Recording finished (60 s limit / failed upload) and the audio is held
  /// locally waiting for an explicit Send / Delete.
  final bool voiceReady;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  /// Tap on the Send button of the locked / ready bar.
  final VoidCallback onMicTap;
  final VoidCallback onCancelRecording;
  final ValueChanged<String> onChanged;
  final bool hasText;

  /// Returns true when recording really started.
  final Future<bool> Function() onHoldStart;
  final VoidCallback onHoldRelease;
  final VoidCallback onHoldCancel;

  /// Optional external focus node so the screen can focus the text field
  /// (e.g. after a Reply). When null the bar owns its own node.
  final FocusNode? focusNode;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.strings,
    required this.isRecording,
    required this.recordingElapsed,
    required this.onAttach,
    required this.onSend,
    required this.onMicTap,
    required this.onCancelRecording,
    required this.onChanged,
    required this.hasText,
    required this.onHoldStart,
    required this.onHoldRelease,
    required this.onHoldCancel,
    this.voiceReady = false,
    this.focusNode,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  static const double _lockDistance = 70;
  static const double _cancelDistance = 90;

  late final AnimationController _wave;

  int? _pointer;
  Offset _origin = Offset.zero;
  Offset _delta = Offset.zero;
  bool _holding = false;
  bool _locked = false;

  /// Pointer released/cancelled before the async start finished.
  bool _releasedEarly = false;
  bool _starting = false;

  final FocusNode _ownFocus = FocusNode();
  FocusNode get _inputFocus => widget.focusNode ?? _ownFocus;
  bool _emojiOpen = false;

  /// Guards against the same physical Enter press sending twice (web can
  /// deliver both a KeyDown and a repeat/duplicate event for one press).
  DateTime? _lastEnterSend;

  @override
  void initState() {
    super.initState();
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
    _inputFocus.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    // Typing again closes the emoji panel so the keyboard can be used.
    if (_inputFocus.hasFocus && _emojiOpen && mounted) {
      setState(() => _emojiOpen = false);
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    _inputFocus.removeListener(_onFocusChanged);
    _ownFocus.dispose();
    super.dispose();
  }

  /// Desktop / Chrome physical keyboard:
  ///   Enter        -> send (never inserts a newline, never sends empty)
  ///   Shift+Enter  -> default behaviour: newline at the cursor
  /// Only KeyDown (not repeat/up) triggers a send, and a short guard blocks
  /// duplicate events. Android soft keyboards keep their normal newline key.
  KeyEventResult _onInputKey(FocusNode node, KeyEvent event) {
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored; // Shift+Enter: let TextField add \n
    }
    // Do not interfere with IME composition (Arabic/CJK candidate commit).
    final composing = widget.controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      final last = _lastEnterSend;
      final duplicate =
          last != null &&
          now.difference(last) < const Duration(milliseconds: 350);
      if (!duplicate && widget.controller.text.trim().isNotEmpty) {
        _lastEnterSend = now;
        widget.onSend();
      }
    }
    // Swallow KeyDown, KeyRepeat and KeyUp so no newline is ever inserted.
    return KeyEventResult.handled;
  }

  void _toggleEmoji() {
    if (_emojiOpen) {
      setState(() => _emojiOpen = false);
      _inputFocus.requestFocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _emojiOpen = true);
    }
  }

  /// Inserts [emoji] at the current cursor / replaces the selection, keeping
  /// existing text. Works for repeated selections.
  void _insertEmoji(String emoji) {
    final c = widget.controller;
    final text = c.text;
    var start = c.selection.start;
    var end = c.selection.end;
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }
    if (start > end) {
      final t = start;
      start = end;
      end = t;
    }
    final next = text.replaceRange(start, end, emoji);
    c.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    widget.onChanged(next);
  }

  @override
  void didUpdateWidget(covariant ChatInputBar old) {
    super.didUpdateWidget(old);
    // Recording ended from outside (60 s limit, failure): reset gesture state.
    if (old.isRecording && !widget.isRecording) {
      _holding = false;
      _locked = false;
      _delta = Offset.zero;
    }
  }

  bool get _isRtl => Directionality.of(context) == TextDirection.rtl;

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _onDown(PointerDownEvent e) async {
    if (_pointer != null || _starting) return;
    if (widget.isRecording || widget.voiceReady) return;
    _pointer = e.pointer;
    _origin = e.position;
    _delta = Offset.zero;
    _releasedEarly = false;
    _starting = true;
    setState(() {
      _holding = true;
      _locked = false;
    });
    final started = await widget.onHoldStart();
    _starting = false;
    if (!mounted) return;
    if (!started) {
      setState(() => _holding = false);
      _pointer = null;
      return;
    }
    if (_releasedEarly) {
      // Finger lifted while the recorder was still starting.
      _releasedEarly = false;
      _finishGesture(send: !_cancelledEarly);
    }
  }

  bool _cancelledEarly = false;

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer || !_holding || _locked) return;
    setState(() => _delta = e.position - _origin);
    final horizontal = _isRtl ? _delta.dx : -_delta.dx;
    if (-_delta.dy >= _lockDistance && -_delta.dy > horizontal) {
      setState(() {
        _locked = true;
        _delta = Offset.zero;
      });
    } else if (horizontal >= _cancelDistance && horizontal > -_delta.dy) {
      _cancelGesture();
    }
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_starting) {
      _releasedEarly = true;
      _cancelledEarly = false;
      return;
    }
    if (_locked) {
      // Locked: releasing the finger must NOT stop or send.
      setState(() => _delta = Offset.zero);
      return;
    }
    _finishGesture(send: true);
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_starting) {
      _releasedEarly = true;
      _cancelledEarly = true;
      return;
    }
    if (_locked) return;
    _cancelGesture();
  }

  void _finishGesture({required bool send}) {
    setState(() {
      _holding = false;
      _delta = Offset.zero;
    });
    if (send) {
      widget.onHoldRelease();
    } else {
      widget.onHoldCancel();
    }
  }

  void _cancelGesture() {
    _pointer = null;
    setState(() {
      _holding = false;
      _locked = false;
      _delta = Offset.zero;
    });
    widget.onHoldCancel();
  }

  Widget _waveform(Color color, {required bool animate}) {
    return AnimatedBuilder(
      animation: _wave,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(14, (i) {
            final phase = (_wave.value * 2 * math.pi) + i * 0.7;
            final h = animate ? 6 + 14 * ((math.sin(phase) + 1) / 2) : 8.0;
            return Container(
              width: 3,
              height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  /// Bar shown while holding (unlocked), locked, or when a recording is held.
  /// The mic button is always the LAST child of the Row and is wrapped by the
  /// same keyed [Listener] as in the idle bar, so the active pointer keeps
  /// delivering move/up events while the layout switches.
  Widget _recordingStrip({required bool lockedOrReady}) {
    final s = widget.strings;
    final navy = AppTheme.isDarkActive
        ? AppTheme.luxuryAccent
        : AppTheme.brandNavy;
    final onNavy = AppTheme.isDarkActive ? AppTheme.brandNavy : Colors.white;
    final horizontal = _isRtl ? _delta.dx : -_delta.dx;
    final cancelProgress = (horizontal / _cancelDistance).clamp(0.0, 1.0);
    final nearCancel = cancelProgress > 0.6;
    final live = widget.isRecording;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        height: 56,
        padding: const EdgeInsetsDirectional.only(start: 6, end: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: lockedOrReady ? AppTheme.luxuryAccent : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            if (lockedOrReady)
              Tooltip(
                message: s.deleteRecording,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onCancelRecording,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.errorRed,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 12),
            const SizedBox(width: 8),
            Icon(
              live ? Icons.fiber_manual_record_rounded : Icons.mic_rounded,
              size: 16,
              color: live ? AppTheme.errorRed : AppTheme.luxuryAccent,
            ),
            const SizedBox(width: 6),
            Text(
              _fmt(widget.recordingElapsed),
              style: GoogleFonts.inter(
                color: AppTheme.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: lockedOrReady
                  ? Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: _waveform(AppTheme.luxuryAccent, animate: live),
                    )
                  : Opacity(
                      opacity: 1 - cancelProgress * 0.7,
                      child: Transform.translate(
                        offset: Offset(
                          _isRtl ? cancelProgress * 24 : -cancelProgress * 24,
                          0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isRtl
                                  ? Icons.chevron_right_rounded
                                  : Icons.chevron_left_rounded,
                              size: 20,
                              color: nearCancel
                                  ? AppTheme.errorRed
                                  : AppTheme.secondaryText,
                            ),
                            Flexible(
                              child: Text(
                                nearCancel
                                    ? s.releaseToCancel
                                    : s.slideToCancel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: nearCancel
                                      ? AppTheme.errorRed
                                      : AppTheme.secondaryText,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            if (lockedOrReady)
              Tooltip(
                message: s.sendRecording,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onMicTap,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: navy,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.send_rounded, color: onNavy, size: 20),
                  ),
                ),
              )
            else
              _micListener(navy, onNavy),
          ],
        ),
      ),
    );
  }

  final GlobalKey _micKey = GlobalKey();

  Widget _micListener(Color navy, Color onNavy) {
    return Listener(
      key: _micKey,
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: _micButton(navy, onNavy),
    );
  }

  /// Mic button with the press-and-hold gesture. While held it grows and a
  /// lock hint floats above it.
  Widget _micButton(Color navy, Color onNavy) {
    final s = widget.strings;
    final lockProgress = (-_delta.dy / _lockDistance).clamp(0.0, 1.0);
    final holdingNow = _holding && !_locked;

    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (holdingNow)
            PositionedDirectional(
              bottom: 62,
              start: -3,
              child: Opacity(
                opacity: 0.55 + 0.45 * lockProgress,
                child: Container(
                  width: 56,
                  height: 92 - lockProgress * 18,
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: lockProgress > 0.8
                          ? AppTheme.luxuryAccent
                          : AppTheme.borderColor,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        lockProgress > 0.8
                            ? Icons.lock_rounded
                            : Icons.lock_open_rounded,
                        size: 20,
                        color: AppTheme.luxuryAccent,
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 20,
                        color: AppTheme.secondaryText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: holdingNow
                ? Offset(
                    _delta.dx.clamp(-120.0, 120.0),
                    _delta.dy.clamp(-_lockDistance, 0.0),
                  )
                : Offset.zero,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: holdingNow ? 62 : 50,
              height: holdingNow ? 62 : 50,
              decoration: BoxDecoration(
                color: holdingNow ? AppTheme.errorRed : AppTheme.softGoldBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mic_rounded,
                color: holdingNow ? Colors.white : AppTheme.luxuryAccent,
                semanticLabel: s.swipeUpToLock,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navy = AppTheme.isDarkActive
        ? AppTheme.luxuryAccent
        : AppTheme.brandNavy;
    final onNavy = AppTheme.isDarkActive ? AppTheme.brandNavy : Colors.white;
    final strings = widget.strings;

    // Locked recording, or a recording held after the 60 s limit / failed
    // upload: dedicated recording interface with Delete + Send.
    final lockedOrReady = widget.voiceReady || (widget.isRecording && _locked);
    if (lockedOrReady) {
      return _recordingStrip(lockedOrReady: true);
    }

    // Unlocked hold: the mic keeps the same GlobalKey'd Listener, so Flutter
    // reparents (not recreates) it and the active pointer keeps streaming.
    final holdingStrip = _holding || widget.isRecording;

    if (holdingStrip) {
      return _recordingStrip(lockedOrReady: false);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_emojiOpen)
          ChatEmojiPanel(
            strings: strings,
            onSelected: _insertEmoji,
            onClose: () => setState(() => _emojiOpen = false),
          ),
        _idleRow(navy, onNavy, strings),
      ],
    );
  }

  Widget _idleRow(Color navy, Color onNavy, ChatStrings strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onAttach,
            child: Container(
              width: 46,
              height: 46,
              margin: const EdgeInsets.only(bottom: 3),
              decoration: BoxDecoration(
                color: AppTheme.softGoldBg,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: AppTheme.navyText),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsetsDirectional.only(
                start: 18,
                end: 12,
                top: 4,
                bottom: 4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    // Web/desktop: Enter sends, Shift+Enter inserts a newline
                    // (handled in _onInputKey). Android keeps the normal
                    // multiline soft keyboard and the Send button.
                    child: Focus(
                      onKeyEvent: kIsWeb ? _onInputKey : null,
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _inputFocus,
                        onChanged: widget.onChanged,
                        minLines: 1,
                        maxLines: 4,
                        expands: false,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        scrollPhysics: const ClampingScrollPhysics(),
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryText,
                          fontSize: 15.5,
                          height: 1.3,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          isCollapsed: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          hintText: strings.typeMessage,
                          hintStyle: GoogleFonts.inter(
                            color: AppTheme.secondaryText,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggleEmoji,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        _emojiOpen
                            ? Icons.keyboard_alt_outlined
                            : Icons.sentiment_satisfied_alt_rounded,
                        color: _emojiOpen
                            ? AppTheme.luxuryAccent
                            : AppTheme.secondaryText,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: !widget.hasText
                ? _micListener(navy, onNavy)
                : InkWell(
                    customBorder: const CircleBorder(),
                    onTap: widget.onSend,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: navy,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.send_rounded, color: onNavy, size: 22),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
