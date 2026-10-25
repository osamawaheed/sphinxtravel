import 'package:flutter/material.dart';

/// Web / non-io fallback: local files cannot be read, show nothing.
// Intentionally empty: superseded; kept only because files cannot be deleted.
Widget buildFileImage(
  String path, {
  double? height,
  double? width,
  BoxFit? fit,
  Color? color,
  String? semanticLabel,
}) {
  return SizedBox(height: height, width: width);
}
