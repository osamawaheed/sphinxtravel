import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Diagonal green corner ribbon (PAID style) shown at the top-right corner.
class DriverCornerRibbon extends StatelessWidget {
  final String label;
  final Color color;

  const DriverCornerRibbon({
    super.key,
    required this.label,
    this.color = const Color(0xFF1FA45B),
  });

  @override
  Widget build(BuildContext context) {
    const double size = 96;
    // Midpoint of the ribbon band centre line (from (0.46w,0) to (w,0.54w)).
    const double cx = size * 0.73;
    const double cy = size * 0.27;
    const double textBoxW = 84;
    const double textBoxH = 20;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RibbonPainter(color: color),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: cx - textBoxW / 2,
              top: cy - textBoxH / 2,
              width: textBoxW,
              height: textBoxH,
              child: Transform.rotate(
                angle: 0.785398,
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  final Color color;
  _RibbonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.30, 0)
      ..lineTo(w * 0.62, 0)
      ..lineTo(w, w * 0.38)
      ..lineTo(w, w * 0.70)
      ..close();
    canvas.drawShadow(path, Colors.black.withAlpha(60), 2, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter old) => old.color != color;
}
