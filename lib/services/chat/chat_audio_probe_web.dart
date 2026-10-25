import 'dart:js_interop';

import 'package:web/web.dart' as web;

const List<String> _types = <String>[
  'audio/mp4',
  'audio/mp4;codecs=mp4a.40.2',
  'audio/webm;codecs=opus',
  'audio/ogg;codecs=opus',
];

/// `MediaRecorder.isTypeSupported` for the four requested MIME types.
Map<String, bool> probeRecordingSupport() {
  final out = <String, bool>{};
  for (final t in _types) {
    try {
      out[t] = web.MediaRecorder.isTypeSupported(t);
    } catch (_) {
      out[t] = false;
    }
  }
  return out;
}

/// Browser + OS from the user agent / platform. No personal data.
String describeBrowserAndOs() {
  try {
    final ua = web.window.navigator.userAgent;
    final platform = web.window.navigator.platform;
    return 'ua=$ua | platform=$platform';
  } catch (e) {
    return 'env_error=$e';
  }
}

/// Probes the audio URL with a 1-byte ranged GET and reads ONLY the response
/// status and Content-Type headers. The URL itself is never returned/stored.
Future<({String status, String contentType, String note})> probeAudioUrl(
  String url,
) async {
  try {
    final headers = web.Headers()..append('Range', 'bytes=0-1');
    final init = web.RequestInit(method: 'GET', headers: headers);
    final res = await web.window.fetch(url.toJS, init).toDart;
    final type = res.headers.get('content-type') ?? '(none)';
    final range = res.headers.get('content-range');
    final acceptRanges = res.headers.get('accept-ranges');
    return (
      status: '${res.status} ${res.statusText}'.trim(),
      contentType: type,
      note:
          'content-range=${range ?? "(none)"} '
          'accept-ranges=${acceptRanges ?? "(none)"}',
    );
  } catch (e) {
    return (status: 'fetch failed', contentType: '-', note: 'probe error: $e');
  }
}
