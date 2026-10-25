import 'dart:io';
import 'dart:typed_data';

/// Android / iOS: the recording is a local .m4a file.
Future<Uint8List?> readRecordedBytes(String source) async {
  try {
    final f = File(source);
    if (!await f.exists()) return null;
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}
