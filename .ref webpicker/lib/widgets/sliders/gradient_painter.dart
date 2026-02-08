import 'package:flutter/material.dart';
import '../../utils/color_operations.dart';

// Custom painter that renders a color gradient with optional split-view
// for out-of-gamut colors
// 
// When showSplitView is true and colors are out of sRGB gamut:
// - Top half: Shows the requested color (may be out of gamut)
// - Bottom half: Shows the gamut-mapped fallback color
class GradientPainter extends CustomPainter {
  // Gradient stops containing color information
  final List<GradientStop> stops;
  
  // Whether to show split-view for out-of-gamut colors
  final bool showSplitView;
  
  // Border radius for the gradient rectangle
  final double borderRadius;
  
  // Whether to constrain colors to real pigment gamut (ICC profile)
  final bool useRealPigmentsOnly;
  
  // Constructor
  // 
  // Step 1: Initialize painter with gradient stops and options
  const GradientPainter({
    required this.stops,
    this.showSplitView = true,
    this.borderRadius = 8.0,
    this.useRealPigmentsOnly = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Step 2: Early return if no stops provided
    if (stops.isEmpty) return;
    
    // Step 3: Calculate dimensions
    final double width = size.width;
    final double height = size.height;
    final double halfHeight = height / 2;
    
    // Step 4: Calculate width per color sample
    final double rectWidth = width / stops.length;
    
    // Step 5: Track out-of-gamut regions for edge indicators
    final List<Rect> outOfGamutRegions = [];
    double? outOfGamutStart;
    
    // Step 6: Iterate through each gradient stop and paint
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final double x = i * rectWidth;
      
      // Step 6a: Track out-of-gamut regions for edge indicators
      if (!stop.isInGamut && outOfGamutStart == null) {
        // Starting an out-of-gamut region
        outOfGamutStart = x;
      } else if (stop.isInGamut && outOfGamutStart != null) {
        // Ending an out-of-gamut region
        outOfGamutRegions.add(Rect.fromLTWH(outOfGamutStart, 0, x - outOfGamutStart, height));
        outOfGamutStart = null;
      }
      
      
      // Step 7: Check if this color is out of gamut and split-view is enabled
      if (showSplitView && !stop.isInGamut && useRealPigmentsOnly) {
        // Step 7a: Paint top half with requested color
        final topPaint = Paint()
          ..color = stop.requestedColor
          ..style = PaintingStyle.fill;
        
        canvas.drawRect(
          Rect.fromLTWH(x, 0, rectWidth + 1, halfHeight),
          topPaint,
        );
        
        // Step 7b: Paint bottom half with fallback color
        final bottomPaint = Paint()
          ..color = stop.fallbackColor
          ..style = PaintingStyle.fill;
        
        canvas.drawRect(
          Rect.fromLTWH(x, halfHeight, rectWidth + 1, halfHeight),
          bottomPaint,
        );
      } else {
        // Step 8: Paint full height with single color (in gamut)
        final paint = Paint()
          ..color = stop.requestedColor
          ..style = PaintingStyle.fill;
        
        canvas.drawRect(
          Rect.fromLTWH(x, 0, rectWidth + 1, height),
          paint,
        );
      }
    }
    
    // Step 8a: Handle case where out-of-gamut region extends to the end
    if (outOfGamutStart != null) {
      outOfGamutRegions.add(Rect.fromLTWH(outOfGamutStart, 0, width - outOfGamutStart, height));
    }
    
    // Step 9: Draw edge indicators only on out-of-gamut regions
    // final edgeIndicatorPaint = Paint()
    //   ..color = Colors.black.withValues(alpha: 0.4)
    //   ..style = PaintingStyle.fill;
    //
    // for (final region in outOfGamutRegions) {
    //   // Top edge indicator (4px)
    //   canvas.drawRect(
    //     Rect.fromLTWH(region.left, 0, region.width, 4),
    //     edgeIndicatorPaint,
    //   );
    //
    //   // Bottom edge indicator (4px)
    //   canvas.drawRect(
    //     Rect.fromLTWH(region.left, height - 4, region.width, 4),
    //     edgeIndicatorPaint,
    //   );
    // }
    
    // Step 10: Draw border around the gradient
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(borderRadius),
      ),
      borderPaint,
    );
  }
  
  @override
  bool shouldRepaint(GradientPainter oldDelegate) {
    // Step 9: Repaint if stops or settings changed
    return stops != oldDelegate.stops ||
           showSplitView != oldDelegate.showSplitView ||
           borderRadius != oldDelegate.borderRadius ||
           useRealPigmentsOnly != oldDelegate.useRealPigmentsOnly;
  }
}

// Custom painter for alpha slider with checkered background
class AlphaGradientPainter extends CustomPainter {
  // Alpha gradient colors from transparent to opaque
  final List<Color> gradientColors;
  
  // Background color for checkered pattern
  final Color backgroundColor;
  
  // Size of each checkered square in pixels
  final double checkerSize;
  
  // Border radius for the gradient rectangle
  final double borderRadius;
  
  // Constructor
  // 
  // Step 1: Initialize painter with gradient and background settings
  const AlphaGradientPainter({
    required this.gradientColors,
    required this.backgroundColor,
    this.checkerSize = 8.0,
    this.borderRadius = 8.0,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Step 2: Early return if no colors provided
    if (gradientColors.isEmpty) return;
    
    final double width = size.width;
    final double height = size.height;
    
    // Step 3: Create clipping path for rounded corners
    final clipPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(borderRadius),
      ));
    
    canvas.clipPath(clipPath);
    
    // Step 4: Paint checkered background pattern
    _paintCheckeredBackground(canvas, size);
    
    // Step 5: Paint alpha gradient on top
    _paintAlphaGradient(canvas, size);
    
    // Step 6: Restore canvas and draw border
    canvas.restore();
    canvas.save();
    
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(borderRadius),
      ),
      borderPaint,
    );
  }

  // Step 7: Helper function to paint checkered background
  void _paintCheckeredBackground(Canvas canvas, Size size) {
    // Step 7a: Calculate lighter and darker shades
    final lightColor = backgroundColor;
    final darkColor = Color.lerp(backgroundColor, Colors.black, 0.15) ?? backgroundColor;
    
    // Step 7b: Calculate number of squares needed
    final int cols = (size.width / checkerSize).ceil() + 1;
    final int rows = (size.height / checkerSize).ceil() + 1;
    
    // Step 7c: Paint each square in checkerboard pattern
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        // Step 7d: Alternate colors based on position
        final bool isLight = (row + col) % 2 == 0;
        final paint = Paint()
          ..color = isLight ? lightColor : darkColor
          ..style = PaintingStyle.fill;
        
        canvas.drawRect(
          Rect.fromLTWH(
            col * checkerSize,
            row * checkerSize,
            checkerSize,
            checkerSize,
          ),
          paint,
        );
      }
    }
  }
  
  // Step 8: Helper function to paint alpha gradient
  void _paintAlphaGradient(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    
    // Step 8a: Calculate width per color sample
    final double rectWidth = width / gradientColors.length;
    
    // Step 8b: Paint each gradient stop
    for (int i = 0; i < gradientColors.length; i++) {
      final color = gradientColors[i];
      final double x = i * rectWidth;
      
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(
        Rect.fromLTWH(x, 0, rectWidth + 1, height),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(AlphaGradientPainter oldDelegate) {
    // Step 9: Repaint if any settings changed
    return gradientColors != oldDelegate.gradientColors ||
           backgroundColor != oldDelegate.backgroundColor ||
           checkerSize != oldDelegate.checkerSize ||
           borderRadius != oldDelegate.borderRadius;
  }
}

