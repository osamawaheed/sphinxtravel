import 'package:web/web.dart' as web;

/// True when the browser's MediaRecorder reports it can record [mimeType]
/// (`MediaRecorder.isTypeSupported`). Returns false on any error.
bool mediaRecorderSupports(String mimeType) {
  try {
    return web.MediaRecorder.isTypeSupported(mimeType);
  } catch (_) {
    return false;
  }
}

/// One-line report of which recording containers this browser supports.
String describeWebRecordingSupport() {
  const types = <String>[
    'audio/mp4;codecs=mp4a.40.2',
    'audio/mp4',
    'audio/aac',
    'audio/webm;codecs=opus',
    'audio/webm',
    'audio/ogg;codecs=opus',
  ];
  try {
    return types.map((t) => '$t=${mediaRecorderSupports(t)}').join(' ');
  } catch (e) {
    return 'recording_support_error=$e';
  }
}
