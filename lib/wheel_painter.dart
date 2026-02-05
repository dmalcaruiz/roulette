import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'wheel_item.dart';

class WheelPainter extends CustomPainter {
  final List<WheelItem> items;
  final double rotation;
  final TextStyle textStyle;
  final double cornerRadius;
  final double strokeWidth;
  final bool showBackgroundCircle;
  final double imageSize;
  final Map<String, ui.Image> imageCache;

  WheelPainter({
    required this.items,
    required this.rotation,
    required this.textStyle,
    this.cornerRadius = 8.0,
    this.strokeWidth = 3.0,
    this.showBackgroundCircle = true,
    this.imageSize = 60.0,
    this.imageCache = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Draw background circle if enabled
    if (showBackgroundCircle) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );

      // Draw stroke around background circle if strokeWidth > 0
      if (strokeWidth > 0) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth,
        );
      }
    }

    final totalWeight = items.fold<double>(0.0, (sum, item) => sum + item.weight);
    final arcSize = (2 * pi) / totalWeight;

    double startAngle = rotation;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final segmentSize = arcSize * item.weight;
      final endAngle = startAngle + segmentSize;

      // Draw the segment with rounded corners
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      final centerInset = 50.0; // How far from center the rounded corner starts

      // Calculate key points
      final outerStartX = center.dx + radius * cos(startAngle);
      final outerStartY = center.dy + radius * sin(startAngle);
      final outerEndX = center.dx + radius * cos(endAngle);
      final outerEndY = center.dy + radius * sin(endAngle);

      final innerStartX = center.dx + centerInset * cos(startAngle);
      final innerStartY = center.dy + centerInset * sin(startAngle);
      final innerEndX = center.dx + centerInset * cos(endAngle);
      final innerEndY = center.dy + centerInset * sin(endAngle);

      final path = Path();

      // Start at inner point on start angle
      path.moveTo(innerStartX, innerStartY);

      // Line to outer edge (leaving room for corner)
      final outerStartInsetX = center.dx + (radius - cornerRadius) * cos(startAngle);
      final outerStartInsetY = center.dy + (radius - cornerRadius) * sin(startAngle);
      path.lineTo(outerStartInsetX, outerStartInsetY);

      // Rounded corner to arc
      path.quadraticBezierTo(
        outerStartX,
        outerStartY,
        center.dx + radius * cos(startAngle + cornerRadius / radius),
        center.dy + radius * sin(startAngle + cornerRadius / radius),
      );

      // Main outer arc
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + cornerRadius / radius,
        segmentSize - (2 * cornerRadius / radius),
        false,
      );

      // Rounded corner from arc
      path.quadraticBezierTo(
        outerEndX,
        outerEndY,
        center.dx + (radius - cornerRadius) * cos(endAngle),
        center.dy + (radius - cornerRadius) * sin(endAngle),
      );

      // Line back toward center
      path.lineTo(innerEndX, innerEndY);

      // Rounded corner at center
      path.quadraticBezierTo(
        center.dx,
        center.dy,
        innerStartX,
        innerStartY,
      );

      path.close();

      canvas.drawPath(path, paint);

      // Draw segment border only if strokeWidth > 0
      if (strokeWidth > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth,
        );
      }

      // Draw text and image
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(startAngle + segmentSize / 2);

      // Clip to segment boundaries to prevent text overflow
      canvas.clipRect(
        Rect.fromLTRB(
          centerInset,
          -radius,
          radius,
          radius,
        ),
      );

      // Draw image if available
      if (item.imagePath != null && imageCache.containsKey(item.imagePath)) {
        final image = imageCache[item.imagePath!]!;
        final imageWidth = imageSize;
        final imageHeight = imageSize;

        // Position image in the segment
        final imageX = radius - imageWidth - 20;
        final imageY = -imageHeight / 2;

        // Create rounded rectangle clip path for the image
        final imageRect = Rect.fromLTWH(imageX, imageY, imageWidth, imageHeight);
        final imageRoundedRect = RRect.fromRectAndRadius(
          imageRect,
          Radius.circular(cornerRadius),
        );

        canvas.save();
        canvas.clipRRect(imageRoundedRect);

        paintImage(
          canvas: canvas,
          rect: imageRect,
          image: image,
          fit: BoxFit.cover,
        );

        canvas.restore();
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: textStyle,
        ),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Adjust text position if image is present
      final textOffset = item.imagePath != null && imageCache.containsKey(item.imagePath)
          ? Offset(radius - textPainter.width - imageSize - 30, -textPainter.height / 2)
          : Offset(radius - textPainter.width - 20, -textPainter.height / 2);

      textPainter.paint(canvas, textOffset);

      canvas.restore();

      startAngle = endAngle;
    }
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) {
    // Check if image cache contents changed (not just reference)
    bool imageCacheChanged = oldDelegate.imageCache.length != imageCache.length ||
                             oldDelegate.imageCache.keys.any((key) => !imageCache.containsKey(key)) ||
                             imageCache.keys.any((key) => !oldDelegate.imageCache.containsKey(key));

    return oldDelegate.rotation != rotation ||
           oldDelegate.items != items ||
           oldDelegate.cornerRadius != cornerRadius ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.showBackgroundCircle != showBackgroundCircle ||
           oldDelegate.imageSize != imageSize ||
           imageCacheChanged;
  }
}
