/// Web: the browser keeps recordings as in-memory blob URLs. There is no
/// local file system, so no path is generated and nothing is deleted.
Future<String?> newRecordingPath() async => null;

Future<bool> recordingFileExists(String path) async => path.isNotEmpty;

Future<int> recordingFileSize(String path) async => 1;

Future<void> deleteRecordingFile(String path) async {}

Future<String> persistRecording(String path) async => path;
