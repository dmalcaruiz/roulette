import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../utils/global_pointer_tracker.dart';

// Invisible slider that handles touch interactions but doesn't render a visible thumb
class InvisibleSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final Function(double) onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;
  final double trackHeight;
  final double hitAreaExtension;

  const InvisibleSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.trackHeight = 50.0,
    this.hitAreaExtension = 13.5,
  });

  @override
  State<InvisibleSlider> createState() => _InvisibleSliderState();
}

class _InvisibleSliderState extends State<InvisibleSlider> {
  GlobalPointerTrackerState? _globalTracker;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _globalTracker = GlobalPointerTracker.of(context);
  }
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.trackHeight,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        // Local listener only handles initial touch down
        // After that, global tracker takes over for unlimited range tracking
        onPointerDown: (event) {
          if (kDebugMode) {
            print('🎯 TOUCH DOWN at ${event.localPosition}');
          }
          widget.onChangeStart?.call();
          _handlePositionChange(event.localPosition);
          
          // Register with global tracker to handle movement everywhere
          _globalTracker?.registerSlider(
            pointerId: event.pointer,
            onMove: (moveEvent) {
              // Convert global position to local slider position
              _handleGlobalPositionChange(moveEvent.position);
            },
            onUp: (upEvent) {
              if (kDebugMode) {
                print('🎯 TOUCH RELEASED (global) at ${upEvent.position}');
              }
              _handleGlobalPositionChange(upEvent.position);
              widget.onChangeEnd?.call();
            },
            onCancel: (cancelEvent) {
              if (kDebugMode) {
                print('🚨 TOUCH CANCELLED (global) - Lost tracking!');
              }
              widget.onChangeEnd?.call();
            },
          );
        },
        child: Container(
          height: widget.trackHeight,
          color: Colors.transparent,
        ),
      ),
    );
  }
  
  void _handlePositionChange(Offset localPosition) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final width = renderBox.size.width;
      
      // Clamp percentage to 0.0-1.0 to keep value within slider bounds
      // even if finger moves outside the slider area
      final percentage = (localPosition.dx / width).clamp(0.0, 1.0);
      final newValue = widget.min + (percentage * (widget.max - widget.min));
      
      widget.onChanged(newValue.clamp(widget.min, widget.max));
    }
  }
  
  void _handleGlobalPositionChange(Offset globalPosition) {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      // Convert global position to local position
      final localPosition = renderBox.globalToLocal(globalPosition);
      final width = renderBox.size.width;
      
      // Clamp percentage to 0.0-1.0 to keep value within slider bounds
      // even if finger moves way outside the slider area
      final percentage = (localPosition.dx / width).clamp(0.0, 1.0);
      final newValue = widget.min + (percentage * (widget.max - widget.min));
      
      widget.onChanged(newValue.clamp(widget.min, widget.max));
    }
  }
}

// External thumb that positions itself based on slider value
class ExternalThumb extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final Color color;
  final bool showCheckerboard;
  final double thumbSize;
  final double availableScreenWidth;
  final double halfThumbSize;

  const ExternalThumb({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.availableScreenWidth,
    this.showCheckerboard = false,
    this.thumbSize = 27.0,
    this.halfThumbSize = 13.5,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate thumb position within the visible gradient area
    final trackPositionPercent = (value - min) / (max - min);
    final actualTrackWidth = availableScreenWidth;
    final thumbPosition = (trackPositionPercent * actualTrackWidth) - halfThumbSize;
    
    return Positioned(
      left: thumbPosition,
      top: (50.0 - thumbSize) / 2, // Center vertically in 50px track
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(thumbSize, thumbSize),
          painter: DiamondThumbPainter(
            color: color,
            showCheckerboard: showCheckerboard,
          ),
        ),
      ),
    );
  }
}

// Custom painter for the diamond thumb
class DiamondThumbPainter extends CustomPainter {
  final Color color;
  final bool showCheckerboard;
  
  const DiamondThumbPainter({
    required this.color,
    this.showCheckerboard = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final double thumbSize = size.width;
    final double halfSize = thumbSize / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Path diamondPath = _createDiamondPath(center, halfSize);
    
    // Draw checkerboard background if enabled
    if (showCheckerboard) {
      canvas.save();
      canvas.clipPath(diamondPath);
      _drawCheckerboard(canvas, center, thumbSize);
      canvas.restore();
    }
    
    // Draw color fill
    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(diamondPath, fillPaint);
    
    // Draw white border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawPath(diamondPath, borderPaint);
    
    // Draw shadow
    canvas.drawShadow(
      diamondPath,
      Colors.black.withValues(alpha: 0.12),
      3.0,
      true,
    );
  }
  
  Path _createDiamondPath(Offset center, double halfSize) {
    return Path()
      ..moveTo(center.dx, center.dy - halfSize)
      ..lineTo(center.dx + halfSize, center.dy)
      ..lineTo(center.dx, center.dy + halfSize)
      ..lineTo(center.dx - halfSize, center.dy)
      ..close();
  }
  
  void _drawCheckerboard(Canvas canvas, Offset center, double size) {
    final double squareSize = 2.75;
    final int gridCount = (size / squareSize).ceil();
    
    for (int row = 0; row < gridCount; row++) {
      for (int col = 0; col < gridCount; col++) {
        if ((row + col) % 2 == 0) {
          final Paint checkerPaint = Paint()
            ..color = const Color(0xFFCCCCCC);
          
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
  
  @override
  bool shouldRepaint(DiamondThumbPainter oldDelegate) {
    return color != oldDelegate.color || 
           showCheckerboard != oldDelegate.showCheckerboard;
  }
}

// Combined widget that uses invisible slider + external thumb
class InvisibleSliderWithExternalThumb extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final Function(double) onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;
  final Widget background;
  final Color thumbColor;
  final bool showCheckerboard;
  final double trackHeight;
  final double hitAreaExtension;
  final double thumbSize;
  final double thumbOffset;

  const InvisibleSliderWithExternalThumb({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.background,
    required this.thumbColor,
    this.onChangeStart,
    this.onChangeEnd,
    this.showCheckerboard = false,
    this.trackHeight = 50.0,
    this.hitAreaExtension = 13.5,
    this.thumbSize = 27.0,
    this.thumbOffset = 8.0,
  });

  @override
  State<InvisibleSliderWithExternalThumb> createState() => _InvisibleSliderWithExternalThumbState();
}

class _InvisibleSliderWithExternalThumbState extends State<InvisibleSliderWithExternalThumb> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.trackHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Background gradient/image
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.background,
                ),
              ),
              
              // Invisible slider for touch handling
              InvisibleSlider(
                value: widget.value,
                min: widget.min,
                max: widget.max,
                onChanged: widget.onChanged,
                onChangeStart: widget.onChangeStart,
                onChangeEnd: widget.onChangeEnd,
                trackHeight: widget.trackHeight,
                hitAreaExtension: widget.hitAreaExtension,
              ),

              // Thumb positioned on top
              ExternalThumb(
                value: widget.value,
                min: widget.min,
                max: widget.max,
                color: widget.thumbColor,
                showCheckerboard: widget.showCheckerboard,
                thumbSize: widget.thumbSize,
                availableScreenWidth: constraints.maxWidth,
                halfThumbSize: widget.hitAreaExtension,
              ),
            ],
          );
        },
      ),
    );
  }
}
