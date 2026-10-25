import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Smallest valid WAV (44 bytes header, 1 silent sample) as a data URI.
const String _silentWav =
    'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAIA+AAACABAAZGF0YQAAAAA=';

web.AudioContext? _ctx;
bool _unlocked = false;

/// Mobile Chrome / iOS WebKit only allow `HTMLMediaElement.play()` and
/// `AudioContext` output while the tap's transient user activation is alive.
/// The chat first awaits a signed-URL / TTS network call and `setUrl`, so the
/// real `play()` runs AFTER the activation is consumed and is rejected with
/// `NotAllowedError` (which just_audio_web never awaits, so it was invisible).
///
/// This MUST be called synchronously from the tap handler, before any `await`.
/// It resumes a shared AudioContext and plays a silent clip, which marks the
/// document as having produced audio from a gesture (sticky activation), so
/// the later `play()` on just_audio's element is allowed.
void unlockWebAudioOnGesture() {
  try {
    final ctx = _ctx ??= web.AudioContext();
    if (ctx.state == 'suspended') {
      ctx.resume().toDart.then(
        (_) =>
            debugPrint('[chat] audio unlock ctx.resume ok state=${ctx.state}'),
        onError: (Object e) =>
            debugPrint('[chat] audio unlock ctx.resume FAILED: $e'),
      );
    }
  } catch (e) {
    debugPrint('[chat] audio unlock AudioContext error: $e');
  }

  if (_unlocked) return;
  try {
    final a = web.HTMLAudioElement()
      ..src = _silentWav
      ..volume = 0;
    a.play().toDart.then(
      (_) {
        _unlocked = true;
        debugPrint('[chat] audio unlock silent play ok');
      },
      onError: (Object e) {
        // The REAL browser error (NotAllowedError, NotSupportedError, ...).
        debugPrint('[chat] audio unlock silent play FAILED: $e');
      },
    );
  } catch (e) {
    debugPrint('[chat] audio unlock element error: $e');
  }
}

/// One-line description of the browser audio environment for diagnostics.
String describeWebAudioEnvironment() {
  try {
    final probe = web.HTMLAudioElement();
    String can(String t) => probe.canPlayType(t).isEmpty ? 'no' : 'yes';
    return 'ctx=${_ctx?.state ?? 'none'} '
        'webm_opus=${can('audio/webm; codecs="opus"')} '
        'mp3=${can('audio/mpeg')} mp4_aac=${can('audio/mp4; codecs="mp4a.40.2"')} '
        'ua=${web.window.navigator.userAgent}';
  } catch (e) {
    return 'env_error=$e';
  }
}
