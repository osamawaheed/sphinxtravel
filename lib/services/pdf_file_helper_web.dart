import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

String _blobUrl(Uint8List bytes) {
  final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
  return html.Url.createObjectUrlFromBlob(blob);
}

/// Opens the original PDF in a new browser tab.
Future<bool> openPdf(Uint8List bytes, String filename) async {
  final url = _blobUrl(bytes);
  html.window.open(url, '_blank');
  return true;
}

/// Triggers a browser download of the original PDF.
Future<bool> downloadPdf(Uint8List bytes, String filename) async {
  final url = _blobUrl(bytes);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return anchor.href != null;
}

/// Web has no native share sheet for files: open WhatsApp Web with the text
/// and download the PDF so the user can attach it.
Future<bool> sharePdf(Uint8List bytes, String filename, String text) async {
  await downloadPdf(bytes, filename);
  html.window.open(
    'https://wa.me/?text=${Uri.encodeComponent(text)}',
    '_blank',
  );
  return true;
}

/// Opens the PDF in a new tab where the browser viewer offers printing.
Future<bool> printPdf(Uint8List bytes, String filename) async {
  final url = _blobUrl(bytes);
  html.window.open(url, '_blank');
  return true;
}
