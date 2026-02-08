import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../utils/color_operations.dart';
import 'gradient_painter.dart';
import 'invisible_slider.dart';

// HSB gradient slider widget with live color gradient background
//
// This widget displays a slider with a gradient showing the range of colors
// available for the current HSB parameters. HSB colors are always in gamut
// for sRGB, so no split-view is needed.
class HsbGradientSlider extends StatefulWidget {
  // Current slider value
  final double value;

  // Minimum slider value
  final double min;

  // Maximum slider value
  final double max;

  // Slider label text
  final String label;

  // Description text shown below the label
  final String description;

  // Callback when value changes
  final Function(double) onChanged;

  // Function to generate gradient stops for this slider
  final List<GradientStop> Function() generateGradient;

  // Number of color samples for smooth gradient (default 300)
  final int samples;

  // Step size for +/- buttons
  final double step;

  // Number of decimal places to display
  final int decimalPlaces;

  // Callback when interaction with slider starts/ends
  final Function(bool)? onInteractionChanged;

  // Background color for text styling
  final Color? bgColor;

  const HsbGradientSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.description,
    required this.onChanged,
    required this.generateGradient,
    required this.step,
    required this.decimalPlaces,
    this.samples = 300,
    this.onInteractionChanged,
    this.bgColor,
  });

  @override
  State<HsbGradientSlider> createState() => _HsbGradientSliderState();
}

class _HsbGradientSliderState extends State<HsbGradientSlider> {
  // Cached gradient stops to avoid regenerating on every build
  List<GradientStop>? _cachedGradient;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slider with gradient background and external thumb
          GestureDetector(
            // Add mobile web gesture detection
            onPanStart: kIsWeb ? (_) => widget.onInteractionChanged?.call(true) : null,
            onPanEnd: kIsWeb ? (_) => widget.onInteractionChanged?.call(false) : null,
            onPanCancel: kIsWeb ? () => widget.onInteractionChanged?.call(false) : null,
            child: InvisibleSliderWithExternalThumb(
              value: widget.value,
              min: widget.min,
              max: widget.max,
              onChanged: (newValue) {
                setState(() {
                  _cachedGradient = null;
                });
                widget.onChanged(newValue.clamp(widget.min, widget.max));
              },
              onChangeStart: () => widget.onInteractionChanged?.call(true),
              onChangeEnd: () => widget.onInteractionChanged?.call(false),
              background: CustomPaint(
                painter: GradientPainter(
                  stops: _getGradientStops(),
                  showSplitView: false, // HSB is always in gamut for sRGB
                  borderRadius: 8.0,
                  useRealPigmentsOnly: false,
                ),
              ),
              thumbColor: _getCurrentThumbColor(),
              showCheckerboard: false,
              trackHeight: 46.0,
              hitAreaExtension: 13.5,
              thumbSize: 27.0,
              thumbOffset: 8.0,
            ),
          ),
        ],
      ),
    );
  }

  // Get or generate gradient stops with caching
  List<GradientStop> _getGradientStops() {
    // Return cached gradient if available
    if (_cachedGradient != null) {
      return _cachedGradient!;
    }

    // Generate new gradient and cache it
    _cachedGradient = widget.generateGradient();
    return _cachedGradient!;
  }

  // Get current color for the thumb based on slider value
  //
  // Interpolates between gradient stops to find the color at current position
  Color _getCurrentThumbColor() {
    final stops = _getGradientStops();
    if (stops.isEmpty) return Colors.white;

    // Normalize value to 0-1 range
    final normalizedValue = (widget.value - widget.min) / (widget.max - widget.min);

    // Find position in gradient stops array
    final stopIndex = (normalizedValue * (stops.length - 1)).clamp(0, stops.length - 1).toDouble();
    final lowerIndex = stopIndex.floor();
    final upperIndex = stopIndex.ceil();

    // Interpolate between two nearest stops
    if (lowerIndex == upperIndex) {
      return stops[lowerIndex].fallbackColor;
    }

    final t = stopIndex - lowerIndex;
    return Color.lerp(
      stops[lowerIndex].fallbackColor,
      stops[upperIndex].fallbackColor,
      t,
    )!;
  }

  @override
  void didUpdateWidget(HsbGradientSlider oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Clear cache if gradient generator changed
    // (This happens when other HSB parameters change)
    if (oldWidget.generateGradient != widget.generateGradient) {
      _cachedGradient = null;
    }
  }
}
