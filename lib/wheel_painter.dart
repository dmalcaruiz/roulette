import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'wheel_item.dart';
import 'icon_map.dart';

class WheelPainter extends CustomPainter {
  final List<WheelItem> items;
  final double rotation;
  final TextStyle textStyle;
  final double cornerRadius;
  final double strokeWidth;
  final bool showBackgroundCircle;
  final double imageSize;
  final Map<String, ui.Image> imageCache;
  final double overlayOpacity;
  final int winningIndex;
  final Color overlayColor;
  final double textVerticalOffset;
  final double loadingAngle;

  WheelPainter({
    required this.items,
    required this.rotation,
    required this.textStyle,
    this.cornerRadius = 8.0,
    this.strokeWidth = 3.0,
    this.showBackgroundCircle = true,
    this.imageSize = 60.0,
    this.imageCache = const {},
    this.overlayOpacity = 0.0,
    this.winningIndex = -1,
    this.overlayColor = Colors.black,
    this.textVerticalOffset = 0.0,
    this.loadingAngle = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final scale = radius / 350.0; // Scale factor relative to base 700px wheel

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

      // Draw icon if available (and no image)
      if (item.iconName != null && item.imagePath == null) {
        final iconData = lucideIconMap[item.iconName];
        if (iconData != null) {
          final iconPainter = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(iconData.codePoint),
              style: TextStyle(
                fontSize: imageSize * 0.7,
                fontFamily: iconData.fontFamily,
                package: iconData.fontPackage,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          iconPainter.layout();
          final iconX = radius - iconPainter.width - 20 * scale;
          final iconY = -iconPainter.height / 2;
          iconPainter.paint(canvas, Offset(iconX, iconY));
        }
      }

      // Draw image if available, or placeholder if still loading
      if (item.imagePath != null) {
        final imageWidth = imageSize;
        final imageHeight = imageSize;
        final imageX = radius - imageWidth - 20 * scale;
        final imageY = -imageHeight / 2;
        final imageRect = Rect.fromLTWH(imageX, imageY, imageWidth, imageHeight);
        final imageRoundedRect = RRect.fromRectAndRadius(
          imageRect,
          Radius.circular(cornerRadius),
        );

        if (imageCache.containsKey(item.imagePath)) {
          final image = imageCache[item.imagePath!]!;

          canvas.save();
          canvas.clipRRect(imageRoundedRect);

          paintImage(
            canvas: canvas,
            rect: imageRect,
            image: image,
            fit: BoxFit.cover,
          );

          canvas.restore();
        } else {
          // Draw spinning loading arc
          final indicatorSize = imageSize * 0.3;
          final indicatorCenter = Offset(imageX + imageWidth / 2, imageY + imageHeight / 2);
          final indicatorRect = Rect.fromCenter(center: indicatorCenter, width: indicatorSize, height: indicatorSize);
          canvas.drawArc(
            indicatorRect,
            loadingAngle,
            pi * 1.2,
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round,
          );
        }
      }

      final hasVisual = (item.imagePath != null) || (item.iconName != null && lucideIconMap.containsKey(item.iconName));

      final textPainter = TextPainter(
        text: TextSpan(
          text: item.text,
          style: textStyle,
        ),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );

      textPainter.layout();

      final textOffset = hasVisual
          ? Offset(radius - textPainter.width - imageSize - 30 * scale, -textPainter.height / 2 - textVerticalOffset)
          : Offset(radius - textPainter.width - 20 * scale, -textPainter.height / 2 - textVerticalOffset);

      textPainter.paint(canvas, textOffset);

      canvas.restore();

      startAngle = endAngle;
    }

    // Draw uniform dark overlay on everything, then redraw the winning segment on top
    if (overlayOpacity > 0 && winningIndex >= 0 && winningIndex < items.length) {
      // Draw a single uniform circular overlay covering everything
      // Extend radius to cover the stroke (stroke extends strokeWidth/2 beyond the radius)
      final overlayRadius = showBackgroundCircle ? radius + (strokeWidth / 2) + 0.5 : radius + 0.5;
      canvas.drawCircle(
        center,
        overlayRadius,
        Paint()
          ..color = overlayColor.withValues(alpha: overlayOpacity * 0.7)
          ..style = PaintingStyle.fill,
      );

      // Now redraw the winning segment (fill, text, and image) without overlay
      final winningItem = items[winningIndex];
      startAngle = rotation;
      for (int i = 0; i < winningIndex; i++) {
        startAngle += arcSize * items[i].weight;
      }
      final segmentSize = arcSize * winningItem.weight;
      final endAngle = startAngle + segmentSize;

      final centerInset = 50.0;

      final outerStartX = center.dx + radius * cos(startAngle);
      final outerStartY = center.dy + radius * sin(startAngle);
      final outerEndX = center.dx + radius * cos(endAngle);
      final outerEndY = center.dy + radius * sin(endAngle);

      final innerStartX = center.dx + centerInset * cos(startAngle);
      final innerStartY = center.dy + centerInset * sin(startAngle);
      final innerEndX = center.dx + centerInset * cos(endAngle);
      final innerEndY = center.dy + centerInset * sin(endAngle);

      final path = Path();

      path.moveTo(innerStartX, innerStartY);

      final outerStartInsetX = center.dx + (radius - cornerRadius) * cos(startAngle);
      final outerStartInsetY = center.dy + (radius - cornerRadius) * sin(startAngle);
      path.lineTo(outerStartInsetX, outerStartInsetY);

      path.quadraticBezierTo(
        outerStartX,
        outerStartY,
        center.dx + radius * cos(startAngle + cornerRadius / radius),
        center.dy + radius * sin(startAngle + cornerRadius / radius),
      );

      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle + cornerRadius / radius,
        segmentSize - (2 * cornerRadius / radius),
        false,
      );

      path.quadraticBezierTo(
        outerEndX,
        outerEndY,
        center.dx + (radius - cornerRadius) * cos(endAngle),
        center.dy + (radius - cornerRadius) * sin(endAngle),
      );

      path.lineTo(innerEndX, innerEndY);

      path.quadraticBezierTo(
        center.dx,
        center.dy,
        innerStartX,
        innerStartY,
      );

      path.close();

      // Use saveLayer to draw all parts (fill, text, image) as a single group with unified opacity
      final layerBounds = Rect.fromCircle(center: center, radius: radius);
      final layerPaint = Paint()..color = Colors.white.withValues(alpha: overlayOpacity);
      canvas.saveLayer(layerBounds, layerPaint);

      // Draw winning segment fill (no opacity here - applied by saveLayer)
      canvas.drawPath(
        path,
        Paint()
          ..color = winningItem.color
          ..style = PaintingStyle.fill,
      );

      // Draw text and image for winning segment (no opacity here - applied by saveLayer)
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

      // Draw icon if available and no image (winning segment)
      if (winningItem.iconName != null && winningItem.imagePath == null) {
        final iconData = lucideIconMap[winningItem.iconName];
        if (iconData != null) {
          final iconPainter = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(iconData.codePoint),
              style: TextStyle(
                fontSize: imageSize * 0.7,
                fontFamily: iconData.fontFamily,
                package: iconData.fontPackage,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          iconPainter.layout();
          final iconX = radius - iconPainter.width - 20 * scale;
          final iconY = -iconPainter.height / 2;
          iconPainter.paint(canvas, Offset(iconX, iconY));
        }
      }

      // Draw image if available, or placeholder if still loading (no opacity here - applied by saveLayer)
      if (winningItem.imagePath != null) {
        final imageWidth = imageSize;
        final imageHeight = imageSize;
        final imageX = radius - imageWidth - 20 * scale;
        final imageY = -imageHeight / 2;
        final imageRect = Rect.fromLTWH(imageX, imageY, imageWidth, imageHeight);
        final imageRoundedRect = RRect.fromRectAndRadius(
          imageRect,
          Radius.circular(cornerRadius),
        );

        if (imageCache.containsKey(winningItem.imagePath)) {
          final image = imageCache[winningItem.imagePath!]!;

          canvas.save();
          canvas.clipRRect(imageRoundedRect);

          paintImage(
            canvas: canvas,
            rect: imageRect,
            image: image,
            fit: BoxFit.cover,
          );

          canvas.restore();
        } else {
          // Draw placeholder
          canvas.drawRRect(
            imageRoundedRect,
            Paint()..color = Colors.white.withValues(alpha: 0.25),
          );
          final indicatorSize = imageSize * 0.3;
          final indicatorCenter = Offset(imageX + imageWidth / 2, imageY + imageHeight / 2);
          final indicatorRect = Rect.fromCenter(center: indicatorCenter, width: indicatorSize, height: indicatorSize);
          canvas.drawArc(
            indicatorRect,
            loadingAngle,
            pi * 1.2,
            false,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round,
          );
        }
      }

      final hasVisual = (winningItem.imagePath != null) || (winningItem.iconName != null && lucideIconMap.containsKey(winningItem.iconName));

      final textPainter = TextPainter(
        text: TextSpan(
          text: winningItem.text,
          style: textStyle,
        ),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );

      textPainter.layout();

      final textOffset = hasVisual
          ? Offset(radius - textPainter.width - imageSize - 30 * scale, -textPainter.height / 2 - textVerticalOffset)
          : Offset(radius - textPainter.width - 20 * scale, -textPainter.height / 2 - textVerticalOffset);

      textPainter.paint(canvas, textOffset);

      canvas.restore();

      // Restore the saveLayer - this applies the opacity to everything drawn above as a group
      canvas.restore();
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
           oldDelegate.overlayOpacity != overlayOpacity ||
           oldDelegate.winningIndex != winningIndex ||
           oldDelegate.overlayColor != overlayColor ||
           oldDelegate.textVerticalOffset != textVerticalOffset ||
           oldDelegate.loadingAngle != loadingAngle ||
           imageCacheChanged;
  }
}
