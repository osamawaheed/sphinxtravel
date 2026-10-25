import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Web: the recording is a browser blob URL. Fetch its bytes (same-origin
/// blob URLs are readable by XHR).
Future<Uint8List?> readRecordedBytes(String source) async {
  try {
    final res = await Dio().get<List<int>>(
      source,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = res.data;
    if (data == null || data.isEmpty) return null;
    return Uint8List.fromList(data);
  } catch (_) {
    return null;
  }
}
