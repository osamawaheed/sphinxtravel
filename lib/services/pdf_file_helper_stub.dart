import 'dart:typed_data';

/// Fallback implementation (never used at runtime on supported platforms).
Future<bool> openPdf(Uint8List bytes, String filename) async => false;

Future<bool> downloadPdf(Uint8List bytes, String filename) async => false;

Future<bool> sharePdf(Uint8List bytes, String filename, String text) async =>
    false;

Future<bool> printPdf(Uint8List bytes, String filename) async => false;
