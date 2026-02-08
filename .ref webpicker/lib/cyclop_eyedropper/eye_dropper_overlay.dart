// ignore_for_file: unused_field, unused_local_variable

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'utils.dart';

const _gridSize = 135.0; // Increased for larger circle

class EyeDropOverlay extends StatelessWidget {
  final Offset? cursorPosition;
  final bool touchable;

  final List<Color> colors;

  const EyeDropOverlay({
    required this.colors,
    this.cursorPosition,
    this.touchable = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return cursorPosition != null
        ? Positioned(
            left: cursorPosition!.dx - (_gridSize / 2),
            top: cursorPosition!.dy -
                (_gridSize / 2) -
                (touchable ? _gridSize / 2 : 0),
            width: _gridSize,
            height: _gridSize,
            child: _buildZoom(),
          )
        : const SizedBox.shrink();
  }

  Widget _buildZoom() {
    return IgnorePointer(
      ignoring: true,
      child: Stack( // Wrap in Stack
        children: [
          // Original Container with the main colored border and pixel grid
          Container(
            foregroundDecoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  width: 14.0, // Main colored border
                  color: colors.isEmpty ? Colors.white : colors.center), // Restore color
            ),
            width: _gridSize,
            height: _gridSize,
            constraints: BoxConstraints.loose(const Size.square(_gridSize)),
            child: ClipOval(
              child: CustomPaint(
                size: const Size.square(_gridSize),
                painter: _PixelGridPainter(colors),
              ),
            ),
          ),
          // New Container for the 0.3px conditional stroke
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 0.3,
                  color: (colors.isEmpty || colors.center.computeLuminance() > 0.5)
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// paint a hovered pixel/colors preview
class _PixelGridPainter extends CustomPainter {
  final List<Color> colors;

  static const gridSize = 9;
  static const eyeRadius = 35.0;

  final blackStroke = Paint()
    ..color = Colors.black
    ..strokeWidth = 10
    ..style = PaintingStyle.stroke;

  _PixelGridPainter(this.colors);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke;

    final blackLine = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final selectedStroke = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final double cellDimension = size.width / gridSize; // Calculate dynamic cell size

    // fill pixels color square
    for (var i = 0; i < colors.length; i++) {
      final fill = Paint()..color = colors[i];
      final rect = Rect.fromLTWH(
        (i % gridSize).toDouble() * cellDimension,
        ((i ~/ gridSize) % gridSize).toDouble() * cellDimension,
        cellDimension * 1.1, // Increased overlap factor
        cellDimension * 1.1, // Increased overlap factor
      );
      canvas.drawRect(rect, fill);
    }

    // draw pixels borders after fills
    for (var i = 0; i < colors.length; i++) {
      final rect = Rect.fromLTWH(
        (i % gridSize).toDouble() * cellDimension,
        ((i ~/ gridSize) % gridSize).toDouble() * cellDimension,
        cellDimension * 1.1, // Use increased overlap factor for consistent rendering
        cellDimension * 1.1, // Use increased overlap factor for consistent rendering
      );
      if (i == colors.length ~/ 2) {
        canvas.drawRect(rect, selectedStroke); // Keep selected pixel border
        canvas.drawRect(rect.deflate(1), blackLine);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelGridPainter oldDelegate) =>
      !listEquals(oldDelegate.colors, colors);
}
