import 'package:flutter/material.dart';

// Step 1: Custom slider thumb that looks like a diamond (rotated square)
// 
// This replicates the reference project's slider design with:
// - 27x27px diamond-shaped thumb
// - Checkerboard pattern background
// - 4px white border
// - Shadow effects for depth
class DiamondSliderThumb extends SliderComponentShape {
  final double thumbSize;
  final Color color;
  final bool showCheckerboard;
  
  const DiamondSliderThumb({
    this.thumbSize = 27.0,
    required this.color,
    this.showCheckerboard = true,
  });
  
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    // Step 2: Return the size of the thumb for layout calculations
    return Size(thumbSize, thumbSize);
  }
  
  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final double halfSize = thumbSize / 2;
    final Path diamondPath = _createDiamondPath(center, halfSize);
    
    // Step 3: Draw checkerboard FIRST (background layer) with clipping
    if (showCheckerboard) {
      // Step 3a: Save canvas state before clipping
      canvas.save();
      // Step 3b: Clip to diamond shape so checkerboard doesn't bleed outside
      canvas.clipPath(diamondPath);
      // Step 3c: Draw checkerboard pattern
      _drawCheckerboard(canvas, center, thumbSize);
      // Step 3d: Restore canvas state
      canvas.restore();
    }
    
    // Step 4: Draw the color fill ON TOP (foreground layer)
    // This will completely cover checkerboard for opaque colors
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(diamondPath, fillPaint);
    
    // Step 5: Draw white border LAST (top layer)
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawPath(diamondPath, borderPaint);
    
    // Step 6: Draw shadow for depth
    canvas.drawShadow(
      diamondPath,
      Colors.black.withValues(alpha: 0.12),
      3.0,
      true,
    );
  }
  
  // Step 7: Create diamond path by defining 4 points
  // 
  // Creates a diamond shape (square rotated 45 degrees)
  Path _createDiamondPath(Offset center, double halfSize) {
    return Path()
      ..moveTo(center.dx, center.dy - halfSize)  // Top point
      ..lineTo(center.dx + halfSize, center.dy)  // Right point
      ..lineTo(center.dx, center.dy + halfSize)  // Bottom point
      ..lineTo(center.dx - halfSize, center.dy)  // Left point
      ..close();
  }
  
  // Step 8: Draw checkerboard pattern like the reference project
  // 
  // Creates a small checkerboard with 2.75px squares (5.5px / 2)
  void _drawCheckerboard(Canvas canvas, Offset center, double size) {
    final double squareSize = 2.75; // 5.5px / 2 (matches reference)
    final int gridCount = (size / squareSize).ceil();
    
    // Step 9: Draw alternating squares in a grid pattern
    for (int row = 0; row < gridCount; row++) {
      for (int col = 0; col < gridCount; col++) {
        // Step 10: Only draw every other square (checkerboard pattern)
        if ((row + col) % 2 == 0) {
          final Paint checkerPaint = Paint()
            ..color = const Color(0xFFCCCCCC);
          
          // Step 11: Calculate position relative to center
          final double x = center.dx - size / 2 + col * squareSize;
          final double y = center.dy - size / 2 + row * squareSize;
          
          canvas.drawRect(
            Rect.fromLTWH(x, y, squareSize, squareSize),
            checkerPaint,
          );
        }
      }
    }
  }
}

