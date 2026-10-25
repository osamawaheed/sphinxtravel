import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wraps [child] (an icon) and overlays a small red unread badge at its
/// top-right corner. The badge is positioned outside the icon's bounds so it
/// never obscures it, and takes no layout space (the child keeps its size).
/// Hidden completely when [count] <= 0; shows "99+" above 99.
class UnreadBadge extends StatelessWidget {
  final int count;
  final Widget child;

  const UnreadBadge({super.key, required this.count, required this.child});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    final text = count > 99 ? '99+' : '$count';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -6,
          right: -9,
          child: IgnorePointer(
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 3.5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                text,
                maxLines: 1,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
