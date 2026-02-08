import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../utils/color_operations.dart';
import 'gradient_painter.dart';
import 'invisible_slider.dart';

// OKLCH gradient slider widget with live color gradient background
// 
// This widget displays a slider with a gradient showing the range of colors
// available for the current OKLCH parameters. When colors are out of sRGB
// gamut, it shows a split-view with the requested color on top and the
// gamut-mapped fallback on bottom.
class OklchGradientSlider extends StatefulWidget {
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
  
  // Whether to show split-view for out-of-gamut colors
  final bool showSplitView;
  
  // Number of color samples for smooth gradient (default 300)
  final int samples;
  
  // Step size for +/- buttons
  final double step;
  
  // Number of decimal places to display
  final int decimalPlaces;
  
  // Callback when interaction with slider starts/ends
  final Function(bool)? onInteractionChanged;
  
  // Whether to constrain colors to real pigment gamut (ICC profile)
  final bool useRealPigmentsOnly;
  
  // Constructor
  // 
  // Step 1: Initialize slider with all required parameters
  const OklchGradientSlider({
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
    this.showSplitView = true,
    this.samples = 300,
    this.onInteractionChanged,
    this.useRealPigmentsOnly = false,
    this.bgColor,
  });

  final Color? bgColor;
  
  @override
  State<OklchGradientSlider> createState() => _OklchGradientSliderState();
}

class _OklchGradientSliderState extends State<OklchGradientSlider> {
  // Cached gradient stops to avoid regenerating on every build
  List<GradientStop>? _cachedGradient;
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step 2: Display label and value adjuster
          // Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     children: [
          //       Text(
          //         widget.label,
          //         style: TextStyle(
          //           fontSize: 16,
          //           fontWeight: FontWeight.w600,
          //           color: getTextColor(widget.bgColor ?? Colors.black),
          //         ),
          //       ),
          //       ValueAdjuster(
          //         value: widget.value,
          //         min: widget.min,
          //         max: widget.max,
          //         step: widget.step,
          //         decimalPlaces: widget.decimalPlaces,
          //         onChanged: widget.onChanged,
          //         onInteractionChanged: widget.onInteractionChanged,
          //         bgColor: widget.bgColor, // Pass bgColor to ValueAdjuster
          //       ),
          //     ],
          // ),

          // Step 3: Display description (if not empty)
          // if (widget.description.isNotEmpty) ...[
          //   Padding(
          //     padding: const EdgeInsets.symmetric(vertical: 4.0),
          //     child: Text(
          //       widget.description,
          //       style: TextStyle(
          //         fontSize: 12,
          //         color: getTextColor(widget.bgColor ?? Colors.black).withOpacity(0.7),
          //       ),
          //     ),
          //   ),
          //   const SizedBox(height: 8),
          // ],

          // Step 4: Slider with gradient background and external thumb
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
                  showSplitView: widget.showSplitView,
                  borderRadius: 8.0,
                  useRealPigmentsOnly: widget.useRealPigmentsOnly,
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
  
  // Step 8: Get or generate gradient stops with caching
  List<GradientStop> _getGradientStops() {
    // Step 8a: Return cached gradient if available
    if (_cachedGradient != null) {
      return _cachedGradient!;
    }
    
    // Step 8b: Generate new gradient and cache it
    _cachedGradient = widget.generateGradient();
    return _cachedGradient!;
  }
  
  // Step 9: Get current color for the thumb based on slider value
  // 
  // Interpolates between gradient stops to find the color at current position
  Color _getCurrentThumbColor() {
    final stops = _getGradientStops();
    if (stops.isEmpty) return Colors.white;
    
    // Step 9a: Normalize value to 0-1 range
    final normalizedValue = (widget.value - widget.min) / (widget.max - widget.min);
    
    // Step 9b: Find position in gradient stops array
    final stopIndex = (normalizedValue * (stops.length - 1)).clamp(0, stops.length - 1).toDouble();
    final lowerIndex = stopIndex.floor();
    final upperIndex = stopIndex.ceil();
    
    // Step 9c: Interpolate between two nearest stops
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
  void didUpdateWidget(OklchGradientSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Step 9: Clear cache if gradient generator changed
    // (This happens when other OKLCH parameters change)
    if (oldWidget.generateGradient != widget.generateGradient ||
        oldWidget.useRealPigmentsOnly != widget.useRealPigmentsOnly) {
      _cachedGradient = null;
    }
  }
}

