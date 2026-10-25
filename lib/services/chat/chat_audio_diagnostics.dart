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

  /// Master switch. Enabled only by the chat screen for the TEST booking and
  /// never in release builds.
  bool _enabled = false;
  bool get enabled => _enabled && !kReleaseMode;

  void setEnabled(bool value) {
    final v = value && !kReleaseMode;
    if (_enabled == v) return;
    _enabled = v;
    if (v && recordingSupport.isEmpty) {
      recordingSupport = probeRecordingSupport();
      environment = describeBrowserAndOs();
    }
    // Defer: this can be called from initState/dispose, where notifying
    // listeners synchronously would rebuild widgets mid-lifecycle.
    Future<void>.microtask(notifyListeners);
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
      ..writeln('message: $lastMessageId');
    return b.toString();
  }
}
