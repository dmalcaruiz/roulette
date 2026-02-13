import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'wheel_item.dart';
import 'icon_map.dart';

class WheelPainter extends CustomPainter {
  // Immutable config (new painter created when these change)
  final List<WheelItem> items;
  final TextStyle textStyle;
  final double cornerRadius;
  final double strokeWidth;
  final bool showBackgroundCircle;
  final double imageSize;
  final Map<String, ui.Image> imageCache; // shared mutable reference
  final Color overlayColor;
  final double textVerticalOffset;

  // Mutable fields updated by animation listeners between paints
  double rotation;
  double overlayOpacity;
  int winningIndex;
  double loadingAngle;

  // Segment transition support
  List<WheelItem>? fromItems;
  double transition = 1.0;
  int _cacheVersion = 0;

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
    super.repaint,
  });

  // ── Cached layout data (rebuilt lazily when size changes) ──
  static const double _centerInset = 50.0;
  List<Path>? _pathCache;
  List<TextPainter>? _textCache;
  List<TextPainter?>? _iconCache;
  List<double>? _startAngles;
  List<double>? _segmentSizes;
  Size? _lastSize;

  // Reusable paint objects to avoid per-frame allocation
  final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = Colors.white;

  int _lastCacheVersion = -1;

  void invalidateCache() {
    _cacheVersion++;
  }

  void _ensureCache(Size size) {
    if (_lastSize == size && _pathCache != null && _lastCacheVersion == _cacheVersion) return;
    _lastSize = size;
    _lastCacheVersion = _cacheVersion;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Use interpolated weights when transitioning
    final effectiveWeights = <double>[];
    for (int i = 0; i < items.length; i++) {
      if (fromItems != null && i < fromItems!.length && transition < 1.0) {
        effectiveWeights.add(fromItems![i].weight + (items[i].weight - fromItems![i].weight) * transition);
      } else {
        effectiveWeights.add(items[i].weight);
      }
    }

    final totalWeight = effectiveWeights.fold<double>(0.0, (sum, w) => sum + w);
    final arcSize = (2 * pi) / totalWeight;

    _pathCache = [];
    _textCache = [];
    _iconCache = [];
    _startAngles = [];
    _segmentSizes = [];

    double startAngle = 0;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final segmentSize = arcSize * effectiveWeights[i];
      final endAngle = startAngle + segmentSize;

      _startAngles!.add(startAngle);
      _segmentSizes!.add(segmentSize);
      _pathCache!.add(_buildSegmentPath(center, radius, startAngle, endAngle));

      // Cache laid-out text painter
      final tp = TextPainter(
        text: TextSpan(text: item.text, style: textStyle),
        textAlign: TextAlign.right,
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      tp.layout();
      _textCache!.add(tp);

      // Cache laid-out icon painter
      if (item.iconName != null && item.imagePath == null) {
        final iconData = lucideIconMap[item.iconName];
        if (iconData != null) {
          final ip = TextPainter(
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
          ip.layout();
          _iconCache!.add(ip);
        } else {
          _iconCache!.add(null);
        }
      } else {
        _iconCache!.add(null);
      }

      startAngle = endAngle;
    }
  }

  Path _buildSegmentPath(Offset center, double radius, double startAngle, double endAngle) {
    final segmentSize = endAngle - startAngle;

    final outerStartX = center.dx + radius * cos(startAngle);
    final outerStartY = center.dy + radius * sin(startAngle);
    final outerEndX = center.dx + radius * cos(endAngle);
    final outerEndY = center.dy + radius * sin(endAngle);
    final innerStartX = center.dx + _centerInset * cos(startAngle);
    final innerStartY = center.dy + _centerInset * sin(startAngle);
    final innerEndX = center.dx + _centerInset * cos(endAngle);
    final innerEndY = center.dy + _centerInset * sin(endAngle);

    final path = Path();
    path.moveTo(innerStartX, innerStartY);

    path.lineTo(
      center.dx + (radius - cornerRadius) * cos(startAngle),
      center.dy + (radius - cornerRadius) * sin(startAngle),
    );

    path.quadraticBezierTo(
      outerStartX, outerStartY,
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
      outerEndX, outerEndY,
      center.dx + (radius - cornerRadius) * cos(endAngle),
      center.dy + (radius - cornerRadius) * sin(endAngle),
    );

    path.lineTo(innerEndX, innerEndY);

    path.arcTo(
      Rect.fromCircle(center: center, radius: _centerInset),
      endAngle,
      -(segmentSize),
      false,
    );

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _ensureCache(size);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final scale = radius / 350.0;

    // Background circle (not rotated)
    if (showBackgroundCircle) {
      _fillPaint.color = Colors.white;
      canvas.drawCircle(center, radius, _fillPaint);
      if (strokeWidth > 0) {
        _strokePaint.strokeWidth = strokeWidth;
        canvas.drawCircle(center, radius, _strokePaint);
      }
    }

    // Apply rotation for all segments via canvas transform
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final path = _pathCache![i];

      // Segment fill — lerp color during transition
      final effectiveColor = (fromItems != null && i < fromItems!.length && transition < 1.0)
          ? Color.lerp(fromItems![i].color, item.color, transition)!
          : item.color;
      _fillPaint.color = effectiveColor;
      canvas.drawPath(path, _fillPaint);

      // Segment stroke
      if (strokeWidth > 0) {
        _strokePaint.strokeWidth = strokeWidth;
        canvas.drawPath(path, _strokePaint);
      }

      // Text, icon, image
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(_startAngles![i] + _segmentSizes![i] / 2);
      canvas.clipRect(Rect.fromLTRB(_centerInset, -radius, radius, radius));

      // Icon (cached)
      if (_iconCache![i] != null) {
        final ip = _iconCache![i]!;
        ip.paint(canvas, Offset(radius - ip.width - 20 * scale, -ip.height / 2));
      }

      // Image (not cacheable — loaded dynamically)
      if (item.imagePath != null) {
        _drawImage(canvas, item, radius, scale);
      }

      // Text (cached)
      final tp = _textCache![i];
      final hasVisual = (item.imagePath != null) || (_iconCache![i] != null);
      final textOffset = hasVisual
          ? Offset(radius - tp.width - imageSize - 30 * scale, -tp.height / 2 - textVerticalOffset)
          : Offset(radius - tp.width - 20 * scale, -tp.height / 2 - textVerticalOffset);
      tp.paint(canvas, textOffset);

      canvas.restore();
    }

    canvas.restore(); // remove rotation

    // ── Overlay: dark tint + winning segment highlight ──
    if (overlayOpacity > 0 && winningIndex >= 0 && winningIndex < items.length) {
      final overlayRadius = showBackgroundCircle ? radius + (strokeWidth / 2) + 0.5 : radius + 0.5;
      canvas.drawCircle(
        center, overlayRadius,
        Paint()..color = overlayColor.withValues(alpha: overlayOpacity * 0.7),
      );

      // Re-apply rotation for the winning segment redraw
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      canvas.translate(-center.dx, -center.dy);

      final layerBounds = Rect.fromCircle(center: center, radius: radius);
      canvas.saveLayer(layerBounds, Paint()..color = Colors.white.withValues(alpha: overlayOpacity));

      final winItem = items[winningIndex];
      _fillPaint.color = winItem.color;
      canvas.drawPath(_pathCache![winningIndex], _fillPaint);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(_startAngles![winningIndex] + _segmentSizes![winningIndex] / 2);
      canvas.clipRect(Rect.fromLTRB(_centerInset, -radius, radius, radius));

      // Icon (cached)
      if (_iconCache![winningIndex] != null) {
        final ip = _iconCache![winningIndex]!;
        ip.paint(canvas, Offset(radius - ip.width - 20 * scale, -ip.height / 2));
      }

      // Image
      if (winItem.imagePath != null) {
        _drawImage(canvas, winItem, radius, scale);
      }

      // Text (cached)
      final tp = _textCache![winningIndex];
      final hasVisual = (winItem.imagePath != null) || (_iconCache![winningIndex] != null);
      final textOffset = hasVisual
          ? Offset(radius - tp.width - imageSize - 30 * scale, -tp.height / 2 - textVerticalOffset)
          : Offset(radius - tp.width - 20 * scale, -tp.height / 2 - textVerticalOffset);
      tp.paint(canvas, textOffset);

      canvas.restore(); // clip
      canvas.restore(); // saveLayer
      canvas.restore(); // rotation
    }
  }

  void _drawImage(Canvas canvas, WheelItem item, double radius, double scale) {
    final imageX = radius - imageSize - 20 * scale;
    final imageY = -imageSize / 2;
    final imageRect = Rect.fromLTWH(imageX, imageY, imageSize, imageSize);
    final imageRoundedRect = RRect.fromRectAndRadius(imageRect, Radius.circular(cornerRadius));

    if (imageCache.containsKey(item.imagePath)) {
      final image = imageCache[item.imagePath!]!;
      canvas.save();
      canvas.clipRRect(imageRoundedRect);
      paintImage(canvas: canvas, rect: imageRect, image: image, fit: BoxFit.cover);
      canvas.restore();
    } else {
      // Spinning loading indicator
      final indicatorSize = imageSize * 0.3;
      final indicatorCenter = Offset(imageX + imageSize / 2, imageY + imageSize / 2);
      canvas.drawArc(
        Rect.fromCenter(center: indicatorCenter, width: indicatorSize, height: indicatorSize),
        loadingAngle, pi * 1.2, false,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(WheelPainter oldDelegate) {
    // With the repaint Listenable approach, shouldRepaint is only called when
    // the painter reference changes (i.e. items/config changed). Always repaint.
    return true;
  }
}
