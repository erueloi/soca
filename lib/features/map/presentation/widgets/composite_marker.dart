import 'package:flutter/material.dart';

class CompositeMarker extends StatelessWidget {
  final Color color;
  final IconData? iconData;
  final String label;
  final double size;

  const CompositeMarker({
    super.key,
    required this.color,
    this.iconData,
    required this.label,
    this.size = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.2), // Taller for the text tag
      painter: _MarkerPainter(color: color, iconData: iconData, label: label),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final Color color;
  final IconData? iconData;
  final String label;

  _MarkerPainter({required this.color, this.iconData, required this.label});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw Icon (Colored, with Shadow for contrast)
    if (iconData != null) {
      // Create a style with shadow to ensure visibility on map
      final textStyle = TextStyle(
        fontSize: w * 0.8, // Make icon larger (80% of width)
        fontFamily: iconData!.fontFamily,
        package: iconData!.fontPackage,
        color: color, // Species Color
        shadows: const [
          Shadow(
            offset: Offset(0, 0),
            blurRadius: 3.0,
            color: Colors.white, // White Glow/Halo
          ),
          Shadow(
            offset: Offset(1, 1),
            blurRadius: 4.0,
            color: Colors.black54, // Drop Shadow
          ),
        ],
      );

      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData!.codePoint),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      iconPainter.layout();

      // Center icon horizontally, place somewhat up
      iconPainter.paint(canvas, Offset((w - iconPainter.width) / 2, h * 0.1));
    }

    // 2. Draw Label Tag (Reference) at the bottom
    if (label.isNotEmpty) {
      final tagBgPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final tagW = textPainter.width + 8;
      final tagH = textPainter.height + 4;
      final tagX = (w - tagW) / 2;
      final tagY = h - tagH; // At the very bottom

      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagX, tagY, tagW, tagH),
        const Radius.circular(4),
      );

      canvas.drawRRect(tagRect, tagBgPaint);
      canvas.drawRRect(tagRect, borderPaint);

      textPainter.paint(canvas, Offset(tagX + 4, tagY + 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
