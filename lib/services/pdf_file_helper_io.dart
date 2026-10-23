import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<File> _writeTemp(Uint8List bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

Future<File> _writeDocuments(Uint8List bytes, String filename) async {
  Directory dir;
  try {
    if (Platform.isAndroid) {
      dir =
          (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

/// Opens the original PDF in the device PDF viewer (via the share sheet
/// fallback when no viewer is registered).
Future<bool> openPdf(Uint8List bytes, String filename) async {
  final file = await _writeTemp(bytes, filename);
  final opened = await launchUrl(
    Uri.file(file.path),
    mode: LaunchMode.externalApplication,
  );
  if (opened) return true;
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
  );
  return true;
}

/// Saves the original PDF to the app documents folder and lets the user
/// pick a destination through the system sheet.
Future<bool> downloadPdf(Uint8List bytes, String filename) async {
  final file = await _writeDocuments(bytes, filename);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
  );
  return true;
}

/// Shares the original PDF through the system share sheet (WhatsApp is
/// available there).
Future<bool> sharePdf(Uint8List bytes, String filename, String text) async {
  final file = await _writeTemp(bytes, filename);
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      files: [XFile(file.path, mimeType: 'application/pdf')],
    ),
  );
  return true;
}

/// Opens the PDF in the system viewer, which exposes the native Print action.
Future<bool> printPdf(Uint8List bytes, String filename) async {
  return openPdf(bytes, filename);
}
