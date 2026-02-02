import 'package:flutter/material.dart';

class CompositeMarker extends StatelessWidget {
  final Color color;
  final IconData? iconData;
  final String label;
  final double size;
  final bool showLabel;
  final bool isPlanned;

  const CompositeMarker({
    super.key,
    required this.color,
    this.iconData,
    required this.label,
    this.size = 20.0,
    this.showLabel = false,
    this.isPlanned = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size), // Icon area square, text overflows
      painter: _MarkerPainter(
        color: color,
        iconData: iconData,
        label: label,
        showLabel: showLabel,
        isPlanned: isPlanned,
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final Color color;
  final IconData? iconData;
  final String label;
  final bool showLabel;
  final bool isPlanned;

  _MarkerPainter({
    required this.color,
    this.iconData,
    required this.label,
    required this.showLabel,
    this.isPlanned = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Note: The adult canopy circle is now drawn as a CircleLayer on the map
    // with real-world radius using useRadiusInMeter: true

    // Apply opacity for planned trees
    final effectiveColor = isPlanned ? color.withValues(alpha: 0.5) : color;

    // 1. Draw Icon (Colored, with Shadow for contrast)
    if (iconData != null) {
      // Create a style with shadow to ensure visibility on map
      final textStyle = TextStyle(
        fontSize: w * 0.9, // Make icon larger (90% of width)
        fontFamily: iconData!.fontFamily,
        package: iconData!.fontPackage,
        color: effectiveColor, // Species Color (with opacity for planned)
        shadows: [
          Shadow(
            offset: const Offset(0, 0),
            blurRadius: 2.0,
            color: Colors.white.withValues(alpha: 0.3), // White Glow/Halo
          ),
          const Shadow(
            offset: Offset(1, 1),
            blurRadius: 2.0,
            color: Colors.black45, // Drop Shadow
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
      iconPainter.paint(canvas, Offset((w - iconPainter.width) / 2, 0));
    }

    // 2. Draw Label Tag (Reference) at the bottom
    if (showLabel && label.isNotEmpty) {
      final tagBgPaint = Paint()
        ..color = Colors.white.withValues(alpha: isPlanned ? 0.6 : 0.9)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = isPlanned ? Colors.grey : Colors.black87
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isPlanned ? Colors.grey[700] : Colors.black,
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
      final tagY = h; // Below the icon

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
