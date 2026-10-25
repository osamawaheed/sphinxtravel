import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Native (Android / iOS): recordings are stored in the app's private
/// documents directory under `chat_voice/` so they survive app restarts
/// and are not visible to other apps.
Future<Directory> _dir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}chat_voice');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<String?> newRecordingPath() async {
  final dir = await _dir();
  final ts = DateTime.now().millisecondsSinceEpoch;
  return '${dir.path}${Platform.pathSeparator}voice_$ts.m4a';
}

Future<bool> recordingFileExists(String path) => File(path).exists();

Future<int> recordingFileSize(String path) async {
  final f = File(path);
  return await f.exists() ? await f.length() : 0;
}

Future<void> deleteRecordingFile(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

Future<String> persistRecording(String path) async => path;
