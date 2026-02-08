import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../models/extreme_color_item.dart';
import '../../utils/color_operations.dart';
import '../../utils/mixbox.dart';
import '../color grid/extreme_color_circle.dart';
import 'invisible_slider.dart';

// Mixed channel slider widget with extreme circle controls
//
// Features:
// 1. LCH sliders (always control global or selected extreme/box)
// 2. Mixed channel slider (controls global only while touched)
// 3. Extreme circles (tap to select, behave like grid boxes)
class MixedChannelSlider extends StatefulWidget {
  // Current slider value (0.0 to 1.0)
  final double value;

  // Current global OKLCH color (for display reference)
  final Color currentColor;

  // Left extreme
  final ExtremeColorItem leftExtreme;

  // Right extreme
  final ExtremeColorItem rightExtreme;

  // Is slider currently active (being touched)
  final bool sliderIsActive;

  // Callback when slider value changes
  final Function(double) onChanged;

  // Callback when an extreme is tapped
  final Function(String extremeId) onExtremeTap;

  // Callback when slider is touched
  final VoidCallback onSliderTouchStart;

  // Callback when slider is released
  final VoidCallback onSliderTouchEnd;

  // Number of color samples for smooth gradient (default 300)
  final int samples;

  // Callback when interaction with slider starts/ends
  final Function(bool)? onInteractionChanged;

  // Whether to use pigment mixing (Mixbox) instead of OKLCH
  final bool usePigmentMixing;

  // Whether to use ICC profile filtering (real pigments only)
  final bool useRealPigmentsOnly;

  // Optional color filter for extreme colors (ICC profile display)
  final Color Function(ExtremeColorItem)? extremeColorFilter;

  // Optional color filter for gradient colors (ICC profile display)
  // Takes color and OKLCH values, returns filtered color
  final Color Function(Color color, double l, double c, double h, double a)? gradientColorFilter;

  final Color? bgColor;

  final Function(String extremeId, DragStartDetails details)? onPanStartExtreme; // Add this line

  const MixedChannelSlider({
    super.key,
    required this.value,
    required this.currentColor,
    required this.leftExtreme,
    required this.rightExtreme,
    required this.sliderIsActive,
    required this.onChanged,
    required this.onExtremeTap,
    required this.onSliderTouchStart,
    required this.onSliderTouchEnd,
    this.samples = 300,
    this.onInteractionChanged,
    this.usePigmentMixing = false,
    this.useRealPigmentsOnly = false,
    this.extremeColorFilter,
    this.gradientColorFilter,
    this.bgColor,
    this.onPanStartExtreme, // Add this line
  });
  
  @override
  State<MixedChannelSlider> createState() => _MixedChannelSliderState();
}

class _MixedChannelSliderState extends State<MixedChannelSlider> {
  @override
  void didUpdateWidget(MixedChannelSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.usePigmentMixing != oldWidget.usePigmentMixing) {
      debugPrint('MixedChannelSlider didUpdateWidget - usePigmentMixing: ${widget.usePigmentMixing}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Left extreme circle
          ExtremeColorCircle(
            extreme: widget.leftExtreme,
            size: 46.0,
            onTap: () => widget.onExtremeTap(widget.leftExtreme.id),
            colorFilter: widget.extremeColorFilter,
            bgColor: widget.bgColor,
            onPanStart: widget.onPanStartExtreme != null
                ? (details) => widget.onPanStartExtreme!(widget.leftExtreme.id, details)
                : null,
          ),

          const SizedBox(width: 4),

          // Main content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Slider with gradient and external thumb
                GestureDetector(
                  // Add mobile web gesture detection
                  onPanStart: kIsWeb ? (_) => widget.onInteractionChanged?.call(true) : null,
                  onPanEnd: kIsWeb ? (_) => widget.onInteractionChanged?.call(false) : null,
                  onPanCancel: kIsWeb ? () => widget.onInteractionChanged?.call(false) : null,
                  child: InvisibleSliderWithExternalThumb(
                    value: widget.value,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) {
                      widget.onChanged(value.clamp(0.0, 1.0));
                    },
                    onChangeStart: () {
                      widget.onSliderTouchStart();
                      widget.onInteractionChanged?.call(true);
                    },
                    onChangeEnd: () {
                      widget.onSliderTouchEnd();
                      widget.onInteractionChanged?.call(false);
                    },
                    background: CustomPaint(
                      painter: MixedChannelGradientPainter(
                        gradientColors: _generateMixGradient(),
                        borderRadius: 8.0,
                        useRealPigmentsOnly: widget.useRealPigmentsOnly,
                      ),
                    ),
                    thumbColor: _getCurrentThumbColor(),
                    showCheckerboard: true,
                    trackHeight: 46.0,
                    hitAreaExtension: 13.5,
                    thumbSize: 27.0,
                    thumbOffset: 8.0,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // Right extreme circle
          ExtremeColorCircle(
            extreme: widget.rightExtreme,
            size: 46.0,
            onTap: () => widget.onExtremeTap(widget.rightExtreme.id),
            colorFilter: widget.extremeColorFilter,
            bgColor: widget.bgColor,
            onPanStart: widget.onPanStartExtreme != null
                ? (details) => widget.onPanStartExtreme!(widget.rightExtreme.id, details)
                : null,
          ),
        ],
      ),
    );
  }

  // Interpolates between left and right extreme colors
  // Uses either OKLCH or Mixbox pigment mixing based on toggle
  Color _getCurrentThumbColor() {
    Color color;
    double l, c, h, a;

    if (widget.usePigmentMixing) {
      // For pigment mixing, first filter the extremes if ICC is enabled, then interpolate
      Color leftColor = widget.leftExtreme.color;
      Color rightColor = widget.rightExtreme.color;

      // Apply ICC filter to extremes if enabled
      if (widget.useRealPigmentsOnly && widget.gradientColorFilter != null) {
        final leftOklch = widget.leftExtreme.oklchValues;
        leftColor = widget.gradientColorFilter!(
          leftColor,
          leftOklch.lightness,
          leftOklch.chroma,
          leftOklch.hue,
          leftOklch.alpha,
        );

        final rightOklch = widget.rightExtreme.oklchValues;
        rightColor = widget.gradientColorFilter!(
          rightColor,
          rightOklch.lightness,
          rightOklch.chroma,
          rightOklch.hue,
          rightOklch.alpha,
        );
      }

      // Now do Mixbox interpolation with the (possibly filtered) colors
      color = lerpMixbox(leftColor, rightColor, widget.value);

      // Extract OKLCH for consistency (won't be filtered again)
      final oklch = srgbToOklch(color);
      l = oklch.l;
      c = oklch.c;
      h = oklch.h;
      a = oklch.alpha;
    } else {
      // For OKLCH, interpolate using stored OKLCH values directly to avoid rounding errors
      final leftOklch = widget.leftExtreme.oklchValues;
      final rightOklch = widget.rightExtreme.oklchValues;
      final t = widget.value;

      // Interpolate each OKLCH component
      l = leftOklch.lightness + (rightOklch.lightness - leftOklch.lightness) * t;
      c = leftOklch.chroma + (rightOklch.chroma - leftOklch.chroma) * t;
      a = leftOklch.alpha + (rightOklch.alpha - leftOklch.alpha) * t;

      // Interpolate hue with wraparound (shortest path)
      double h1 = leftOklch.hue % 360;
      double h2 = rightOklch.hue % 360;
      if (h1 < 0) h1 += 360;
      if (h2 < 0) h2 += 360;

      double diff = h2 - h1;
      if (diff > 180) {
        diff -= 360;
      } else if (diff < -180) {
        diff += 360;
      }

      h = h1 + diff * t;
      if (h < 0) h += 360;
      if (h >= 360) h -= 360;

      // Convert to color
      color = colorFromOklch(l, c, h, a);
    }

    // Apply ICC filter if enabled (using the computed OKLCH values)
    if (widget.useRealPigmentsOnly && widget.gradientColorFilter != null) {
      color = widget.gradientColorFilter!(color, l, c, h, a);
    }

    return color;
  }

  List<Color> _generateMixGradient() {
    final List<Color> colors = [];

    // Pre-filter the extremes if ICC is enabled (for pigment mixing)
    Color leftColor = widget.leftExtreme.color;
    Color rightColor = widget.rightExtreme.color;

    if (widget.usePigmentMixing && widget.useRealPigmentsOnly && widget.gradientColorFilter != null) {
      final leftOklch = widget.leftExtreme.oklchValues;
      leftColor = widget.gradientColorFilter!(
        leftColor,
        leftOklch.lightness,
        leftOklch.chroma,
        leftOklch.hue,
        leftOklch.alpha,
      );

      final rightOklch = widget.rightExtreme.oklchValues;
      rightColor = widget.gradientColorFilter!(
        rightColor,
        rightOklch.lightness,
        rightOklch.chroma,
        rightOklch.hue,
        rightOklch.alpha,
      );
    }

    for (int i = 0; i < widget.samples; i++) {
      final double t = i / (widget.samples - 1);
      Color color;
      double l, c, h, a;

      if (widget.usePigmentMixing) {
        // For pigment mixing, interpolate with the (possibly filtered) colors
        color = lerpMixbox(leftColor, rightColor, t);
        final oklch = srgbToOklch(color);
        l = oklch.l;
        c = oklch.c;
        h = oklch.h;
        a = oklch.alpha;
      } else {
        // For OKLCH, interpolate using stored OKLCH values directly to avoid rounding errors
        final leftOklch = widget.leftExtreme.oklchValues;
        final rightOklch = widget.rightExtreme.oklchValues;

        // Interpolate each OKLCH component
        l = leftOklch.lightness + (rightOklch.lightness - leftOklch.lightness) * t;
        c = leftOklch.chroma + (rightOklch.chroma - leftOklch.chroma) * t;
        a = leftOklch.alpha + (rightOklch.alpha - leftOklch.alpha) * t;

        // Interpolate hue with wraparound (shortest path)
        double h1 = leftOklch.hue % 360;
        double h2 = rightOklch.hue % 360;
        if (h1 < 0) h1 += 360;
        if (h2 < 0) h2 += 360;

        double diff = h2 - h1;
        if (diff > 180) {
          diff -= 360;
        } else if (diff < -180) {
          diff += 360;
        }

        h = h1 + diff * t;
        if (h < 0) h += 360;
        if (h >= 360) h -= 360;

        // Convert to color
        color = colorFromOklch(l, c, h, a);
      }

      // Apply ICC filter if enabled (using the computed OKLCH values)
      if (widget.useRealPigmentsOnly && widget.gradientColorFilter != null) {
        color = widget.gradientColorFilter!(color, l, c, h, a);
      }

      colors.add(color);
    }

    return colors;
  }
}

// Custom painter for mixed channel gradient
class MixedChannelGradientPainter extends CustomPainter {
  final List<Color> gradientColors;
  final double borderRadius;
  final bool useRealPigmentsOnly;

  const MixedChannelGradientPainter({
    required this.gradientColors,
    this.borderRadius = 8.0,
    this.useRealPigmentsOnly = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final rectWidth = width / gradientColors.length;
    
    for (int i = 0; i < gradientColors.length; i++) {
      final double x = i * rectWidth;
      final paint = Paint()..color = gradientColors[i];
      
      canvas.drawRect(
        Rect.fromLTWH(x, 0, rectWidth + 1, height),
        paint,
      );
    }
    
    // Border
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
  bool shouldRepaint(MixedChannelGradientPainter oldDelegate) {
    return gradientColors != oldDelegate.gradientColors ||
           borderRadius != oldDelegate.borderRadius ||
           useRealPigmentsOnly != oldDelegate.useRealPigmentsOnly;
  }
}
