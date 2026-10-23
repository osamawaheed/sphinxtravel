import 'package:flutter/material.dart';

/// Official TourOps logo, rendered exactly as provided (no recolor, no distortion).
class TourOpsLogo extends StatelessWidget {
  final double? height;
  final double? width;

  const TourOpsLogo({super.key, this.height = 56, this.width});

  static const String assetPath = 'assets/images/Tourops-1792708653198.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      height: height,
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'TourOps Tour Operations logo',
    );
  }
}
