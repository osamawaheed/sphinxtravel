import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/foundation.dart';

import './chat_audio_probe.dart';

/// TEMPORARY audio diagnostics store (TEST mode only).
///
/// Passive: it only RECORDS what the recording / playback code already does.
/// It never stores signed URLs, tokens or personal data - only the MIME type,
/// extension, HTTP status, Content-Type and player state values.
class ChatAudioDiagnostics extends ChangeNotifier {
  ChatAudioDiagnostics._();
  static final ChatAudioDiagnostics instance = ChatAudioDiagnostics._();

  /// Build-time switch (TEST environment only). Defaults to true in this test
  /// project and MUST be set to false for production builds
  /// (`--dart-define=AUDIO_DIAGNOSTICS=false`). It is independent of
  /// `kReleaseMode` so it also works in Rocket Preview release builds.
  static const bool buildAllowed = bool.fromEnvironment(
    'AUDIO_DIAGNOSTICS',
    defaultValue: true,
  );

  /// Master switch. Enabled by the chat screen (any booking) when the build
  /// flag allows it.
  bool _enabled = false;
  bool get enabled => _enabled && buildAllowed;

  /// Whether the diagnostics panel is currently open (toggled by the
  /// "Audio Diagnostics" button at the top of Smart Chat).
  bool _panelOpen = false;
  bool get panelOpen => _panelOpen && enabled;

  void setPanelOpen(bool value) {
    if (_panelOpen == value) return;
    _panelOpen = value;
    Future<void>.microtask(notifyListeners);
  }

  void setEnabled(bool value) {
    final v = value && buildAllowed;
    if (_enabled == v) return;
    _enabled = v;
    if (!v) _panelOpen = false;
    if (v) {
      _installErrorCapture();
    } else {
      _removeErrorCapture();
    }
    if (v && recordingSupport.isEmpty) {
      recordingSupport = probeRecordingSupport();
      environment = describeBrowserAndOs();
    }
    // Defer: this can be called from initState/dispose, where notifying
    // listeners synchronously would rebuild widgets mid-lifecycle.
    Future<void>.microtask(notifyListeners);
  }

  // Passive capture of uncaught audio-related errors (e.g. iPhone WebKit
  // NotSupportedError / NotAllowedError). Chains to the previous handlers so
  // existing error reporting is unchanged.
  FlutterExceptionHandler? _prevFlutterOnError;
  bool Function(Object, StackTrace)? _prevPlatformOnError;
  bool _captureInstalled = false;

  static bool _looksAudioRelated(String text) {
    final t = text.toLowerCase();
    return t.contains('audio') ||
        t.contains('just_audio') ||
        t.contains('notsupported') ||
        t.contains('notallowed') ||
        t.contains('mediaerror') ||
        t.contains('media_err') ||
        t.contains('play()') ||
        t.contains('decode');
  }

  void _installErrorCapture() {
    if (_captureInstalled) return;
    _captureInstalled = true;
    _prevFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final text = '${details.exception}';
      if (_looksAudioRelated('$text ${details.library ?? ''}')) {
        setError('uncaught: ${details.exception.runtimeType}: $text');
        markNotStarted('uncaught error');
      }
      final prev = _prevFlutterOnError;
      if (prev != null) {
        prev(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    _prevPlatformOnError = ui.PlatformDispatcher.instance.onError;
    ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final text = '$error';
      if (_looksAudioRelated(text)) {
        setError('uncaught: ${error.runtimeType}: $text');
        markNotStarted('uncaught error');
      }
      final prev = _prevPlatformOnError;
      return prev != null ? prev(error, stack) : false;
    };
  }

  void _removeErrorCapture() {
    if (!_captureInstalled) return;
    _captureInstalled = false;
    FlutterError.onError = _prevFlutterOnError;
    ui.PlatformDispatcher.instance.onError = _prevPlatformOnError;
    _prevFlutterOnError = null;
    _prevPlatformOnError = null;
  }

  // 1. Browser / OS
  String environment = '';

  // 2. MediaRecorder support
  Map<String, bool> recordingSupport = const {};

  // 3-4. Selected recording
  String recordingMime = '-';
  String recordingExtension = '-';
  String recordingEncoder = '-';

  // 5-6. HTTP probe of the audio URL
  String httpStatus = '-';
  String contentType = '-';
  String probeNote = '-';

  // 7-10. Player
  String playerInit = 'not initialized';
  String duration = '-';
  String position = '-';
  String processingState = '-';
  bool playing = false;

  // 11-12. Result
  String lastError = '-';
  String playbackStarted = 'no';
  String lastMessageId = '-';

  // Timestamped event timeline (TEST only). Passive ring buffer: it only
  // records events the playback code already produces.
  static const int _maxEvents = 120;
  final List<String> _events = <String>[];
  final Stopwatch _clock = Stopwatch()..start();
  String _lastPositionBucket = '';

  List<String> get events => List<String>.unmodifiable(_events);

  /// Adds one timeline line: `+12.345s EVENT detail`.
  void logEvent(String event, [String detail = '']) {
    if (!enabled) return;
    final t = (_clock.elapsedMilliseconds / 1000).toStringAsFixed(3);
    final line = detail.isEmpty ? '+${t}s $event' : '+${t}s $event $detail';
    _events.add(_sanitize(line));
    if (_events.length > _maxEvents) {
      _events.removeRange(0, _events.length - _maxEvents);
    }
    _touch();
  }

  /// Position updates are logged at most once per 250 ms bucket so the
  /// timeline stays readable.
  void logPosition(Duration pos) {
    if (!enabled) return;
    final bucket = '${pos.inMilliseconds ~/ 250}';
    if (bucket == _lastPositionBucket) return;
    _lastPositionBucket = bucket;
    logEvent('POSITION', '${pos.inMilliseconds}ms');
  }

  void clearEvents() {
    _events.clear();
    _lastPositionBucket = '';
    _touch();
  }

  /// Short caller description taken from the current stack (file:line of the
  /// first frames outside this class), e.g. for pause()/stop() invocations.
  static String callerOf([int frames = 4]) {
    try {
      final lines = StackTrace.current.toString().split('\n');
      final out = <String>[];
      for (final l in lines) {
        if (l.contains('chat_audio_diagnostics')) continue;
        final t = l.trim();
        if (t.isEmpty) continue;
        out.add(t.length > 70 ? t.substring(0, 70) : t);
        if (out.length >= frames) break;
      }
      return out.join(' < ');
    } catch (_) {
      return 'caller n/a';
    }
  }

  void _touch() {
    if (!enabled) return;
    notifyListeners();
  }

  /// A new playback attempt begins: clears the per-attempt fields.
  void beginPlayback(String messageId) {
    if (!enabled) return;
    lastMessageId = messageId.length > 8
        ? '${messageId.substring(0, 8)}...'
        : messageId;
    httpStatus = '-';
    contentType = '-';
    probeNote = '-';
    duration = '-';
    position = '-';
    processingState = 'loading (setUrl pending)';
    lastError = '-';
    playbackStarted = 'no';
    playing = false;
    _touch();
  }

  void setPlayerInit(String value) {
    if (!enabled) return;
    playerInit = value;
    _touch();
  }

  void setRecording({
    required String mime,
    required String extension,
    String? encoder,
  }) {
    if (!enabled) return;
    recordingMime = mime;
    recordingExtension = extension;
    if (encoder != null) recordingEncoder = encoder;
    _touch();
  }

  void setRecordingEncoder(String encoder) {
    if (!enabled) return;
    recordingEncoder = encoder;
    _touch();
  }

  void setProbe({String? status, String? type, String? note}) {
    if (!enabled) return;
    if (status != null) httpStatus = status;
    if (type != null) contentType = type;
    if (note != null) probeNote = note;
    _touch();
  }

  void setPlayerValues({
    String? duration,
    String? position,
    String? processingState,
    bool? playing,
  }) {
    if (!enabled) return;
    if (duration != null) this.duration = duration;
    if (position != null) this.position = position;
    if (processingState != null) this.processingState = processingState;
    if (playing != null) this.playing = playing;
    _touch();
  }

  void markStarted(String detail) {
    if (!enabled) return;
    playbackStarted = 'YES ($detail)';
    _touch();
  }

  void markNotStarted(String detail) {
    if (!enabled) return;
    if (!playbackStarted.startsWith('YES')) {
      playbackStarted = 'NO ($detail)';
    }
    _touch();
  }

  void setError(String error) {
    if (!enabled) return;
    lastError = _sanitize(error);
    _touch();
  }

  /// Removes anything URL-like or token-like from free text.
  static String _sanitize(String input) {
    var out = input.replaceAll(RegExp(r'https?://[^\s"\)\]]+'), '<url>');
    out = out.replaceAll(RegExp(r'blob:[^\s"\)\]]+'), '<blob>');
    out = out.replaceAll(
      RegExp(
        r'(token|apikey|authorization|bearer)[=:\s]+[^\s&"]+',
        caseSensitive: false,
      ),
      r'$1=<hidden>',
    );
    out = out.replaceAll(RegExp(r'eyJ[A-Za-z0-9_\-\.]{10,}'), '<jwt>');
    return out.length > 400 ? '${out.substring(0, 400)}...' : out;
  }

  /// Plain-text report for the "Copy Diagnostics" button.
  String buildReport() {
    final b = StringBuffer()
      ..writeln('TOUROPS AUDIO DIAGNOSTICS (TEST)')
      ..writeln('time: ${DateTime.now().toIso8601String()}')
      ..writeln('1. Browser/OS: $environment')
      ..writeln('2. MediaRecorder support:');
    recordingSupport.forEach((k, v) => b.writeln('   $k = $v'));
    b
      ..writeln('3. Recording MIME: $recordingMime')
      ..writeln('   Encoder: $recordingEncoder')
      ..writeln('4. File extension: $recordingExtension')
      ..writeln('5. HTTP status: $httpStatus')
      ..writeln('6. Content-Type: $contentType')
      ..writeln('   Probe note: $probeNote')
      ..writeln('7. Player init: $playerInit')
      ..writeln('8. Duration: $duration')
      ..writeln('9. Position: $position')
      ..writeln('10. Processing state: $processingState (playing=$playing)')
      ..writeln('11. Error: $lastError')
      ..writeln('12. Playback started: $playbackStarted')
      ..writeln('message: $lastMessageId')
      ..writeln('--- TIMELINE (${_events.length} events) ---');
    for (final e in _events) {
      b.writeln(e);
    }
    return b.toString();
  }
}
