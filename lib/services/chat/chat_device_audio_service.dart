import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import './chat_audio_storage.dart';
import './chat_audio_diagnostics.dart';
import './chat_audio_probe.dart';
import './chat_audio_unlock.dart';
import './chat_recording_format.dart';
import './chat_services.dart';

/// Real, fully local audio service for Smart Chat.
///
/// * Recording: `record` package -> AAC (.m4a) file in the app documents
///   directory on Android / iOS. On web the browser records to a blob URL
///   (only works if the page is allowed to use the microphone).
/// * Playback: `just_audio` with position / duration streams.
/// * No network, no Supabase, no Odoo.
class DeviceChatAudioService implements ChatAudioService {
  DeviceChatAudioService();

  /// Recordings shorter than this are treated as accidental taps.
  static const Duration minRecording = Duration(seconds: 1);

  AudioRecorder? _recorder;
  AudioPlayer? _player;
  final StreamController<ChatPlaybackState> _state =
      StreamController<ChatPlaybackState>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];

  ChatPlaybackState _current = const ChatPlaybackState();
  String? _activeId;
  String? _activeSource;

  /// Stable identity of the loaded audio (storage path / message audio key).
  /// Signed URLs change on every request, so they must never be used to decide
  /// whether the loaded audio is the same one.
  String? _activeKey;
  String? _recordingPath;
  DateTime? _startedAt;
  bool _isRecording = false;
  bool _disposed = false;

  /// Monotonic playback request id. Every `play()` call takes a new value so
  /// that a slower, older request (async `setUrl`) can never start audio or
  /// publish state after a newer message has been selected.
  int _playToken = 0;

  /// True once the active source finished playing (ProcessingState.completed)
  /// and has not been restarted yet. Lets `play()` take the replay path
  /// instead of the plain same-source resume path.
  bool _completedActive = false;

  bool _envLogged = false;

  @override
  bool get isAvailable => true;

  @override
  Stream<ChatPlaybackState> get playbackState => _state.stream;

  @override
  ChatPlaybackState get currentPlayback => _current;

  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  // ---------------------------------------------------------------- recording

  @override
  Future<bool> requestMicrophonePermission() async {
    try {
      // `record` asks the OS for the microphone permission itself
      // (Android RECORD_AUDIO / iOS NSMicrophoneUsageDescription / browser).
      final granted = await _rec.hasPermission();
      if (!granted) {
        throw const ChatAudioException(ChatAudioFailure.permissionDenied);
      }
      return true;
    } on ChatAudioException {
      rethrow;
    } catch (_) {
      throw const ChatAudioException(ChatAudioFailure.permissionDenied);
    }
  }

  @override
  Future<void> startRecording() async {
    if (_isRecording) {
      throw const ChatAudioException(ChatAudioFailure.recorderBusy);
    }
    await requestMicrophonePermission();

    // Never record while a voice message is playing.
    await _releasePlaybackForRecording();

    try {
      final String path;
      RecordConfig config;
      if (kIsWeb) {
        path = '';
        // Prefer MP4/AAC (plays on iOS WebKit, Android and desktop Chrome).
        // Only choose it when the browser's MediaRecorder confirms support;
        // otherwise keep the previous behaviour (Opus, then WAV).
        final aacOk =
            mediaRecorderSupports('audio/mp4;codecs=mp4a.40.2') ||
            mediaRecorderSupports('audio/mp4');
        var encoder = AudioEncoder.opus;
        try {
          if (aacOk && await _rec.isEncoderSupported(AudioEncoder.aacLc)) {
            encoder = AudioEncoder.aacLc;
          } else if (!await _rec.isEncoderSupported(AudioEncoder.opus)) {
            encoder = await _rec.isEncoderSupported(AudioEncoder.aacLc)
                ? AudioEncoder.aacLc
                : AudioEncoder.wav;
          }
        } catch (_) {
          encoder = aacOk ? AudioEncoder.aacLc : AudioEncoder.wav;
        }
        debugPrint(
          '[chat] record format chosen=$encoder aacOk=$aacOk '
          '${describeWebRecordingSupport()}',
        );
        ChatAudioDiagnostics.instance.setRecordingEncoder(encoder.name);
        config = RecordConfig(encoder: encoder);
      } else {
        path = (await newRecordingPath()) ?? '';
        if (path.isEmpty) {
          throw const ChatAudioException(ChatAudioFailure.startFailed);
        }
        config = const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
        );
      }
      await _rec.start(config, path: path);
      _recordingPath = path;
      _startedAt = DateTime.now();
      _isRecording = true;
    } on ChatAudioException {
      rethrow;
    } catch (_) {
      _isRecording = false;
      _recordingPath = null;
      throw const ChatAudioException(ChatAudioFailure.startFailed);
    }
  }

  @override
  Future<ChatRecordedAudio?> stopRecording() async {
    if (!_isRecording) return null;
    final startedAt = _startedAt;
    _isRecording = false;
    _startedAt = null;

    String? path;
    try {
      path = await _rec.stop();
    } catch (_) {
      await _discard(_recordingPath);
      _recordingPath = null;
      throw const ChatAudioException(ChatAudioFailure.startFailed);
    }
    _recordingPath = null;

    final elapsed = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);

    if (path == null || path.isEmpty) {
      throw const ChatAudioException(ChatAudioFailure.emptyFile);
    }
    if (elapsed < minRecording) {
      await _discard(path);
      throw const ChatAudioException(ChatAudioFailure.tooShort);
    }
    if (!kIsWeb && await recordingFileSize(path) <= 0) {
      await _discard(path);
      throw const ChatAudioException(ChatAudioFailure.emptyFile);
    }

    final persisted = await persistRecording(path);
    final seconds = (elapsed.inMilliseconds / 1000).round().clamp(1, 3600);
    return ChatRecordedAudio(path: persisted, durationSeconds: seconds);
  }

  @override
  Future<void> cancelRecording() async {
    final path = _recordingPath;
    final wasRecording = _isRecording;
    _isRecording = false;
    _startedAt = null;
    _recordingPath = null;
    if (!wasRecording) return;
    try {
      await _rec.cancel();
    } catch (_) {
      try {
        final p = await _rec.stop();
        await _discard(p ?? path);
      } catch (_) {}
    }
    await _discard(path);
  }

  Future<void> _discard(String? path) async {
    if (path == null || path.isEmpty || kIsWeb) return;
    await deleteRecordingFile(path);
  }

  /// Fully stops the playback player (not just pause) so its audio focus /
  /// session is released before the microphone opens. Invalidates any pending
  /// `play()` so a late load cannot start audio during or after recording.
  Future<void> _releasePlaybackForRecording() async {
    _playToken++;
    final p = _player;
    if (p == null) return;
    ChatAudioDiagnostics.instance.logEvent(
      'STOP_INVOKED',
      'release-for-recording caller=${ChatAudioDiagnostics.callerOf()}',
    );
    try {
      await p.stop();
    } catch (_) {}
    if (_activeId != null) {
      _activeId = null;
      _activeSource = null;
      _activeKey = null;
      _completedActive = false;
      _emit(playing: false, position: Duration.zero);
    }
  }

  // ----------------------------------------------------------------- playback

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _player = p;
    ChatAudioDiagnostics.instance.setPlayerInit('AudioPlayer created');
    _subs.add(
      p.positionStream.listen((pos) {
        ChatAudioDiagnostics.instance.setPlayerValues(
          position: '${pos.inMilliseconds} ms',
        );
        ChatAudioDiagnostics.instance.logPosition(pos);
        if (_activeId == null) return;
        _emit(position: pos);
      }),
    );
    _subs.add(
      p.durationStream.listen((d) {
        ChatAudioDiagnostics.instance.setPlayerValues(
          duration: d == null ? 'null' : '${d.inMilliseconds} ms',
        );
        if (d != null && _activeId != null) _emit(duration: d);
      }),
    );
    _subs.add(
      p.playerStateStream.listen((s) {
        ChatAudioDiagnostics.instance.setPlayerValues(
          processingState: s.processingState.name,
          playing: s.playing,
        );
        ChatAudioDiagnostics.instance.logEvent(
          'STATE',
          'processing=${s.processingState.name} playing=${s.playing} '
              'pos=${p.position.inMilliseconds}ms activeId=${_activeId != null} '
              'token=$_playToken',
        );
        if (_activeId == null) return;
        if (s.processingState == ProcessingState.completed) {
          // Idempotent: the player can re-emit `completed` for one finish.
          // Handle it once until the source is restarted or reloaded.
          if (_completedActive) return;
          // Release verification / playback locks for this run and remember
          // that the source ended, so the next tap takes the replay path.
          ChatAudioDiagnostics.instance.logEvent(
            'COMPLETED',
            'handler: pause()+seek(0) token->${_playToken + 1}',
          );
          _completedActive = true;
          _playToken++;
          final token = _playToken;
          () async {
            try {
              await p.pause();
              // A newer message was selected meanwhile: do not touch it.
              if (token != _playToken) return;
              await p.seek(Duration.zero);
            } catch (_) {}
          }();
          _emit(playing: false, position: Duration.zero);
        } else {
          // Never report "playing" while the media is still loading or
          // buffering: the browser has not started audio yet.
          final started =
              s.playing && s.processingState == ProcessingState.ready;
          _emit(playing: started);
        }
      }),
    );
    return p;
  }

  /// Emits a playback failure for [messageId] (UI shows a clear error and the
  /// bubble returns to Play).
  final StreamController<ChatAudioFailure> _errors =
      StreamController<ChatAudioFailure>.broadcast();

  @override
  Stream<ChatAudioFailure> get playbackErrors => _errors.stream;

  /// Resets the player to a clean, retryable state after a failure: the
  /// source is dropped so the next tap reloads it from scratch.
  Future<void> _resetAfterFailure(
    AudioPlayer player,
    int token,
    String messageId,
    String reason,
  ) async {
    if (_disposed || token != _playToken || _activeId != messageId) return;
    debugPrint('[chat] play step=RESET message=$messageId reason=$reason');
    ChatAudioDiagnostics.instance
      ..logEvent(
        'SOURCE_CLEARED+STOP',
        'reason=$reason pos=${player.position.inMilliseconds}ms '
            'processing=${player.processingState.name} '
            'playing=${player.playing} token=$token',
      )
      ..setError('reset: $reason')
      ..markNotStarted(reason);
    _playToken++;
    _activeId = null;
    _activeSource = null;
    _activeKey = null;
    _completedActive = false;
    try {
      await player.stop();
    } catch (_) {}
    _current = const ChatPlaybackState();
    if (!_disposed) {
      _state.add(_current);
      _errors.add(ChatAudioFailure.playbackFailed);
    }
  }

  void _emit({bool? playing, Duration? position, Duration? duration}) {
    if (_disposed) return;
    _current = ChatPlaybackState(
      messageId: _activeId,
      playing: playing ?? _current.playing,
      position: position ?? _current.position,
      duration: duration ?? _current.duration,
    );
    _state.add(_current);
  }

  @override
  bool isLoaded(String messageId, {String? sourceKey}) {
    if (_activeId != messageId || _player == null) return false;
    // Stable identity when available; otherwise the loaded audio of this
    // message id is considered the same (legacy callers without a key).
    return sourceKey == null || _activeKey == sourceKey;
  }

  @override
  Future<void> play(
    String messageId,
    String originalSource, {
    String? sourceKey,
  }) async {
    final playStartedAt = DateTime.now();
    // An empty source means "resume what is already loaded": reuse the kept
    // source (needed for replay-after-completion without a new signed URL).
    final source = (originalSource.isEmpty && _activeId == messageId)
        ? (_activeSource ?? '')
        : originalSource;
    if (source.isEmpty) {
      throw const ChatAudioException(ChatAudioFailure.playbackFailed);
    }
    // Stable identity: storage key when given, else the source itself
    // (local paths / blob URLs / TTS urls are already stable per message).
    final key = sourceKey ?? source;
    final sameKey = _activeKey == key;
    ChatAudioDiagnostics.instance.logEvent(
      'PLAY_REQUESTED',
      'sameId=${_activeId == messageId} sameKey=$sameKey '
          'sameSrc=${_activeSource == source} '
          'completedFlag=$_completedActive '
          'processing=${_player?.processingState.name ?? 'none'} '
          'playing=${_player?.playing} token=$_playToken',
    );
    if (_isRecording) {
      throw const ChatAudioException(ChatAudioFailure.recorderBusy);
    }
    final player = _ensurePlayer();
    try {
      if (_activeId == messageId &&
          sameKey &&
          (_completedActive ||
              player.processingState == ProcessingState.completed)) {
        // Replay after completion. Same message and source, but the media
        // element is in an "ended" state which iOS WebKit may refuse to
        // restart with a bare play(). Reset, rewind and, if needed, reload
        // the SAME source (no new player, no new listeners).
        final token = ++_playToken;
        _completedActive = false;
        ChatAudioDiagnostics.instance.logEvent(
          'BRANCH_REPLAY',
          'token=$token pause+seek(0)+setUrl+play',
        );
        _emit(playing: false, position: Duration.zero);
        try {
          try {
            await player.pause();
          } catch (_) {}
          try {
            await player.seek(Duration.zero);
          } catch (_) {}
          if (token != _playToken) return;
          // Reinitialize the existing source so the element leaves the
          // ended state (safe on desktop / Android too: same URL, same
          // player).
          final isRemoteReplay =
              source.startsWith('http://') || source.startsWith('https://');
          final Duration? d = (kIsWeb || isRemoteReplay)
              ? await player.setUrl(source)
              : await player.setFilePath(source);
          if (token != _playToken) return;
          _emit(duration: d, position: Duration.zero);
          await player.seek(Duration.zero);
          if (token != _playToken) return;
          final replayFuture = player.play();
          unawaited(
            replayFuture.catchError((Object e) {
              debugPrint(
                '[chat] play step=replay threw message=$messageId: $e',
              );
              ChatAudioDiagnostics.instance.setError('replay rejected: $e');
              _resetAfterFailure(player, token, messageId, 'replay_threw');
            }),
          );
          unawaited(_verifyPlaybackStarted(player, token, messageId));
        } catch (e) {
          debugPrint('[chat] play step=replay failed message=$messageId: $e');
          ChatAudioDiagnostics.instance
            ..setError('replay: ${e.runtimeType}: $e')
            ..markNotStarted('replay failed');
          if (token == _playToken) {
            _activeId = null;
            _activeSource = null;
            _activeKey = null;
            _completedActive = false;
            try {
              await player.stop();
            } catch (_) {}
            _emit(playing: false, position: Duration.zero);
          }
          throw const ChatAudioException(ChatAudioFailure.playbackFailed);
        }
        return;
      }

      if (_activeId == messageId && sameKey) {
        // Same message and same stable audio identity: resume directly. No
        // stop(), no setUrl(), no seek - the loaded source and the paused
        // position are kept. A different signed URL for the same audio is
        // intentionally ignored here.
        final token = ++_playToken;
        ChatAudioDiagnostics.instance.logEvent(
          'BRANCH_RESUME',
          'token=$token resumePos=${player.position.inMilliseconds}ms '
              'setUrlCalled=false srcChanged=${_activeSource != source}',
        );
        _resumeLatency(player, playStartedAt, token);
        final p = player.play();
        unawaited(
          p.catchError((Object e) {
            debugPrint('[chat] play step=resume threw message=$messageId: $e');
            _resetAfterFailure(player, token, messageId, 'resume_threw');
          }),
        );
        unawaited(_verifyPlaybackStarted(player, token, messageId));
        return;
      }

      // Different message (or different source for the same message, e.g.
      // original vs translated). Invalidate every pending request, stop the
      // previous audio completely and drop its source before loading.
      final token = ++_playToken;
      _completedActive = false;
      _diagBegin(messageId, source);
      ChatAudioDiagnostics.instance.logEvent(
        'BRANCH_NEW_LOAD',
        'token=$token -> stop() then setUrl()',
      );
      try {
        await player.stop();
      } catch (_) {}
      if (token != _playToken) return;

      _activeId = messageId;
      _activeSource = source;
      _activeKey = key;
      _current = ChatPlaybackState(messageId: messageId);
      _state.add(_current);

      // A signed Storage URL is remote: File(url).exists() is ALWAYS false on
      // native, which previously made every received voice message fail with
      // "could not be played". Only verify existence for local file paths.
      final isRemote =
          source.startsWith('http://') || source.startsWith('https://');
      if (!kIsWeb && !isRemote && !await recordingFileExists(source)) {
        debugPrint('[chat] play step=local_file_missing source=$source');
        _activeId = null;
        _activeSource = null;
        _activeKey = null;
        throw const ChatAudioException(ChatAudioFailure.playbackFailed);
      }

      final Duration? d = (kIsWeb || isRemote)
          ? await player.setUrl(source)
          : await player.setFilePath(source);
      ChatAudioDiagnostics.instance.setPlayerInit(
        'setUrl OK (duration=${d?.inMilliseconds ?? 'null'} ms)',
      );
      // A newer play() started while this one was loading: abandon silently.
      if (token != _playToken) {
        debugPrint('[chat] play superseded message=$messageId');
        return;
      }
      debugPrint(
        '[chat] play step=loaded message=$messageId token=$token web=$kIsWeb '
        'remote=$isRemote duration=$d '
        'src=${isRemote ? (Uri.tryParse(source)?.replace(query: '').toString() ?? '') : (source.startsWith('blob:') ? 'blob' : 'file')}',
      );
      _emit(duration: d, position: Duration.zero);
      await player.seek(Duration.zero);
      if (token != _playToken) return;
      ChatAudioDiagnostics.instance.logEvent(
        'PLAYBACK_CALL',
        'player.play() token=$token setUrlCalled=true',
      );
      if (kIsWeb && !_envLogged) {
        _envLogged = true;
        debugPrint('[chat] audio env ${describeWebAudioEnvironment()}');
      }
      _resumeLatency(player, playStartedAt, token, label: 'NEW_LOAD');
      // just_audio's play() future only completes when playback ENDS, so it
      // is not awaited here. On web the browser's play() promise rejection
      // (NotAllowedError / NotSupportedError) must reset the player to Play.
      final playFuture = player.play();
      unawaited(
        playFuture.catchError((Object e) {
          debugPrint('[chat] play step=play() threw message=$messageId: $e');
          ChatAudioDiagnostics.instance.setError('play() rejected: $e');
          _resetAfterFailure(player, token, messageId, 'play_threw');
        }),
      );
      unawaited(_verifyPlaybackStarted(player, token, messageId));
    } on ChatAudioException {
      rethrow;
    } catch (e) {
      // Real player error (HTTP status / codec) instead of a silent failure.
      debugPrint('[chat] play step=player failed message=$messageId: $e');
      ChatAudioDiagnostics.instance
        ..setPlayerInit('setUrl/load FAILED')
        ..setError('${e.runtimeType}: $e')
        ..markNotStarted('load failed');
      _activeId = null;
      _activeSource = null;
      _activeKey = null;
      _completedActive = false;
      _emit(playing: false, position: Duration.zero);
      throw const ChatAudioException(ChatAudioFailure.playbackFailed);
    }
  }

  @override
  Future<void> pause() async {
    final p = _player;
    if (p == null) return;
    final t0 = DateTime.now();
    ChatAudioDiagnostics.instance.logEvent(
      'PAUSE_INVOKED',
      'pos=${p.position.inMilliseconds}ms playing=${p.playing} '
          'caller=${ChatAudioDiagnostics.callerOf()}',
    );
    // Optimistic UI: reflect Pause -> Play immediately; the player state
    // stream confirms it right after. Source and position are retained.
    if (_activeId != null && _current.playing) {
      _emit(playing: false);
    }
    try {
      await p.pause();
      ChatAudioDiagnostics.instance.logEvent(
        'PAUSE_LATENCY',
        '${DateTime.now().difference(t0).inMilliseconds}ms '
            'keptPos=${p.position.inMilliseconds}ms',
      );
    } catch (_) {}
  }

  /// TEST diagnostics: measures play() -> audible start (position advancing
  /// while ready/playing). Passive; never affects playback.
  void _resumeLatency(
    AudioPlayer player,
    DateTime t0,
    int token, {
    String label = 'RESUME',
  }) {
    final diag = ChatAudioDiagnostics.instance;
    if (!diag.enabled) return;
    final startPos = player.position;
    () async {
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (_disposed || token != _playToken) return;
        if (player.playing &&
            player.processingState == ProcessingState.ready &&
            player.position > startPos) {
          diag.logEvent(
            'PLAY_TO_AUDIBLE_LATENCY',
            '$label ${DateTime.now().difference(t0).inMilliseconds}ms '
                'startPos=${startPos.inMilliseconds}ms',
          );
          return;
        }
      }
    }();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _player?.dispose();
    _player = null;
    final r = _recorder;
    _recorder = null;
    if (r != null) {
      // Fire-and-forget: release the microphone if the screen is closed
      // mid-recording and drop the unsent file.
      final path = _recordingPath;
      () async {
        try {
          if (_isRecording) await r.cancel();
        } catch (_) {}
        try {
          await r.dispose();
        } catch (_) {}
        await _discard(path);
      }();
    }
    _state.close();
    _errors.close();
  }

  /// Diagnostics only (TEST mode): resets per-attempt values and probes the
  /// audio URL's HTTP status / Content-Type. Fire-and-forget; never affects
  /// playback and never stores the URL.
  void _diagBegin(String messageId, String source) {
    final diag = ChatAudioDiagnostics.instance;
    if (!diag.enabled) return;
    diag.beginPlayback(messageId);
    final isRemote =
        source.startsWith('http://') || source.startsWith('https://');
    if (!kIsWeb || !isRemote) {
      diag.setProbe(
        status: 'n/a',
        type: 'n/a',
        note: kIsWeb ? 'non-http source' : 'native/local source',
      );
      return;
    }
    probeAudioUrl(source).then(
      (r) => diag.setProbe(status: r.status, type: r.contentType, note: r.note),
      onError: (Object e) => diag.setProbe(
        status: 'probe error',
        note: ChatAudioDiagnostics.instance.lastError,
      ),
    );
  }

  Future<void> _verifyPlaybackStarted(
    AudioPlayer player,
    int token,
    String messageId,
  ) async {
    ChatAudioDiagnostics.instance.logEvent('VERIFY_BEGIN', 'token=$token');
    // Poll for up to ~6 s: playback counts as started only when the position
    // actually advances (or the media completed). Covers a player stuck in
    // loading/buffering as well as a rejected play() promise.
    const step = Duration(milliseconds: 250);
    const maxWait = Duration(seconds: 6);
    var waited = Duration.zero;
    var retried = false;
    while (waited < maxWait) {
      await Future<void>.delayed(step);
      waited += step;
      if (_disposed || token != _playToken || _activeId != messageId) {
        ChatAudioDiagnostics.instance.logEvent(
          'VERIFY_ABORT',
          'token=$token current=$_playToken activeId=${_activeId != null}',
        );
        return;
      }
      final st = player.processingState;
      if (st == ProcessingState.completed) return;
      if (!player.playing) {
        ChatAudioDiagnostics.instance.logEvent(
          'VERIFY_EXIT_NOT_PLAYING',
          'processing=${st.name} pos=${player.position.inMilliseconds}ms',
        );
        // User paused, or the player was stopped: nothing to verify.
        return;
      }
      if (player.position > Duration.zero && st == ProcessingState.ready) {
        ChatAudioDiagnostics.instance.logEvent(
          'PLAYBACK_STARTED',
          'pos=${player.position.inMilliseconds}ms token=$token',
        );
        debugPrint(
          '[chat] play step=STARTED message=$messageId '
          'position=${player.position.inMilliseconds}ms',
        );
        ChatAudioDiagnostics.instance.markStarted(
          'position=${player.position.inMilliseconds} ms',
        );
        return;
      }
      // One silent retry of play() after 1.5 s for a rejected promise.
      if (!retried &&
          waited >= const Duration(milliseconds: 1500) &&
          st == ProcessingState.ready &&
          player.position == Duration.zero) {
        retried = true;
        ChatAudioDiagnostics.instance.logEvent(
          'SILENT_RETRY',
          'pause+seek(0)+play() pos=${player.position.inMilliseconds}ms',
        );
        debugPrint('[chat] play step=retry message=$messageId');
        try {
          await player.pause();
          if (token != _playToken) return;
          await player.seek(Duration.zero);
          unawaited(
            player.play().catchError((Object e) {
              debugPrint('[chat] play step=retry threw: $e');
              _resetAfterFailure(player, token, messageId, 'retry_threw');
            }),
          );
        } catch (e) {
          debugPrint('[chat] play step=retry error: $e');
        }
      }
    }
    if (_disposed || token != _playToken || _activeId != messageId) return;
    ChatAudioDiagnostics.instance.logEvent(
      'VERIFY_TIMEOUT',
      'state=${player.processingState.name} playing=${player.playing} '
          'pos=${player.position.inMilliseconds}ms',
    );
    debugPrint(
      '[chat] play step=TIMEOUT message=$messageId '
      'state=${player.processingState} playing=${player.playing} '
      'position=${player.position.inMilliseconds}ms',
    );
    await _resetAfterFailure(player, token, messageId, 'timeout');
  }
}
