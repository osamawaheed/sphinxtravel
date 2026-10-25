import 'package:flutter/foundation.dart';

/// Non-web: no browser MediaRecorder; report the platform only.
Map<String, bool> probeRecordingSupport() => const {
  'audio/mp4': false,
  'audio/mp4;codecs=mp4a.40.2': false,
  'audio/webm;codecs=opus': false,
  'audio/ogg;codecs=opus': false,
};

String describeBrowserAndOs() => 'native ${defaultTargetPlatform.name}';

/// Non-web: nothing to probe.
Future<({String status, String contentType, String note})> probeAudioUrl(
  String url,
) async => (status: 'n/a', contentType: 'n/a', note: 'native platform');
