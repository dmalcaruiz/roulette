import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/color_operations.dart';
import '../../utils/mixbox.dart';
import '../../models/extreme_color_item.dart';
import '../../state/color_editor_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/sheet_state_provider.dart';
import '../../services/clipboard_service.dart';
import 'oklch_gradient_slider.dart';
import 'mixer_slider.dart' show MixedChannelSlider;

// A widget containing all the color picker slider controls
//
// Reads OKLCH from ColorEditorProvider but uses callback for coordination.
// HomeScreen handles updating Provider + selected items.
class PerceptualSliderControls extends StatefulWidget {
  // Callback when OKLCH values change (HomeScreen coordinates Provider updates)
  final Function({
    required double lightness,
    required double chroma,
    required double hue,
    double alpha,
  }) onOklchChanged;

  final Function(bool)? onSliderInteractionChanged;

  // Mixer extreme colors (managed by parent)
  final ExtremeColorItem leftExtreme;
  final ExtremeColorItem rightExtreme;

  // Callback when an extreme is tapped
  final Function(String extremeId) onExtremeTap;

  // Callback when mixer slider is touched (to deselect extremes)
  final VoidCallback? onMixerSliderTouched;

  // Whether to constrain colors to real pigment gamut (ICC profile)
  final bool useRealPigmentsOnly;

  // Optional color filter for extreme colors (ICC profile display)
  final Color Function(ExtremeColorItem)? extremeColorFilter;

  // Optional color filter for gradient colors (ICC profile display)
  final Color Function(Color color, double l, double c, double h, double a)? gradientColorFilter;

  final Color? bgColor;

  final Function(String extremeId, DragStartDetails details)? onPanStartExtreme;

  const PerceptualSliderControls({
    super.key,
    required this.onOklchChanged,
    this.onSliderInteractionChanged,
    required this.leftExtreme,
    required this.rightExtreme,
    required this.onExtremeTap,
    this.onMixerSliderTouched,
    this.useRealPigmentsOnly = false,
    this.extremeColorFilter,
    this.gradientColorFilter,
    this.bgColor,
    this.onPanStartExtreme,
  });

  @override
  State<PerceptualSliderControls> createState() => _PerceptualSliderControlsState();
}

class _PerceptualSliderControlsState extends State<PerceptualSliderControls> {
  // OKLCH values
  double lightness = 0.7;  // 0.0 to 1.0
  double chroma = 0.15;    // 0.0 to 0.4 (0.37 is max for sRGB)
  double hue = 240.0;      // 0 to 360 degrees

  // Mixer state is now managed by SheetStateProvider (shared between chips)
  // Access via: context.read<SheetStateProvider>().mixValue
  // Access via: context.read<SheetStateProvider>().sliderIsActive

  // Flag to prevent feedback loop when we update the color internally
  bool _isInternalUpdate = false;

  // Slider order (for reorderable list)
  List<String> _sliderOrder = ['hue', 'chroma', 'lightness', 'mixer'];

  // Converted color
  Color? currentColor;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Values will be loaded from Provider in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get OKLCH values from Provider
    final colorEditor = context.watch<ColorEditorProvider>();

    // Update local state if Provider has values and we're not the source of the change
    if (colorEditor.hasValues && !_isInternalUpdate) {
      lightness = colorEditor.lightness!;
      chroma = colorEditor.chroma!;
      hue = colorEditor.hue!;

      // Update display color
      currentColor = colorEditor.currentColor;

      // Reset slider state when values change from Provider
      final sheetState = context.read<SheetStateProvider>();
      sheetState.setSliderIsActive(false);
    }

    // Reset the flag
    _isInternalUpdate = false;
  }

  // Linear interpolation for double values
  double _lerpDouble(double a, double b, double t) {
    return a + (b - a) * t;
  }

  // Hue interpolation with wraparound (shortest path around color wheel)
  double _lerpHue(double h1, double h2, double t) {
    // Normalize hues to [0, 360)
    h1 = h1 % 360;
    h2 = h2 % 360;
    if (h1 < 0) h1 += 360;
    if (h2 < 0) h2 += 360;

    // Calculate the shortest distance between hues
    double diff = h2 - h1;

    // If difference is more than 180°, go the other way around the wheel
    if (diff > 180) {
      diff -= 360;
    } else if (diff < -180) {
      diff += 360;
    }

    // Interpolate and normalize result
    double result = h1 + diff * t;
    if (result < 0) result += 360;
    if (result >= 360) result -= 360;

    return result;
  }

  void _updateColor() {
    try {
      setState(() {
        // Set flag to prevent feedback loop
        _isInternalUpdate = true;

        // Get current global OKLCH color
        final globalColor = colorFromOklch(lightness, chroma, hue);

        // Get pigment mixing setting from provider
        final settings = context.read<SettingsProvider>();
        final usePigmentMixing = settings.usePigmentMixing;

        // Get mixer state from SheetStateProvider
        final sheetState = context.read<SheetStateProvider>();
        final mixValue = sheetState.mixValue;
        final sliderIsActive = sheetState.sliderIsActive;

        // Calculate final values
        if (sliderIsActive) {
          // Slider is controlling: interpolate between extremes

          if (usePigmentMixing) {
            // Use Kubelka-Munk (Mixbox) for realistic pigment mixing
            final mixedColor = lerpMixbox(
              widget.leftExtreme.color,
              widget.rightExtreme.color,
              mixValue,
            );

            // Extract OKLCH values from the mixed color
            final mixedOklch = srgbToOklch(mixedColor);
            lightness = mixedOklch.l;
            chroma = mixedOklch.c;
            hue = mixedOklch.h;
            currentColor = mixedColor;
          } else {
            // Use OKLCH interpolation (perceptually uniform)

            // Step 1: Convert extremes to OKLCH
            final leftOklch = srgbToOklch(widget.leftExtreme.color);
            final rightOklch = srgbToOklch(widget.rightExtreme.color);

            // Step 2: Interpolate each OKLCH component separately
            lightness = _lerpDouble(leftOklch.l, rightOklch.l, mixValue);
            chroma = _lerpDouble(leftOklch.c, rightOklch.c, mixValue);

            // Step 3: Interpolate hue with wraparound (shortest path around color wheel)
            hue = _lerpHue(leftOklch.h, rightOklch.h, mixValue);

            // Step 4: Convert back to sRGB for display
            currentColor = colorFromOklch(lightness, chroma, hue);
          }
        } else {
          // Slider is not controlling: just display global color
          currentColor = globalColor;
        }

        // Call callback to let HomeScreen coordinate Provider updates
        widget.onOklchChanged(
          lightness: lightness,
          chroma: chroma,
          hue: hue,
          alpha: 1.0,
        );
        errorMessage = '';
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error: $e';
      });
    }
  }

  void _handleSliderTouchStart() {
    // Notify parent to deselect extremes when mixer slider is touched
    widget.onMixerSliderTouched?.call();

    // Update shared state
    final sheetState = context.read<SheetStateProvider>();
    sheetState.setSliderIsActive(true);

    setState(() {
      _updateColor();
    });
  }

  void _handleSliderTouchEnd() {
    debugPrint('_handleSliderTouchEnd - Mixer slider released');

    // Update shared state
    final sheetState = context.read<SheetStateProvider>();
    sheetState.setSliderIsActive(false);

    setState(() {
      // Slider position stays fixed, global disconnects
      _updateColor();
    });

    // Copy to clipboard if auto-copy is enabled
    _copyToClipboardIfEnabled();
  }

  // Copy current color to clipboard if auto-copy setting is enabled
  void _copyToClipboardIfEnabled() {
    final settings = context.read<SettingsProvider>();
    debugPrint('_copyToClipboardIfEnabled - autoCopyEnabled: ${settings.autoCopyEnabled}, currentColor: $currentColor');
    if (settings.autoCopyEnabled && currentColor != null) {
      ClipboardService.copyColorToClipboard(currentColor!);
      final hexString = '#${currentColor!.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
      debugPrint('Copied to clipboard: $hexString');
    }
  }

  // Wrapper for slider interaction that adds clipboard copying
  void _handleSliderInteraction(bool isInteracting) {
    debugPrint('_handleSliderInteraction - isInteracting: $isInteracting');

    // Call parent callback
    widget.onSliderInteractionChanged?.call(isInteracting);

    // Copy to clipboard when interaction ends
    if (!isInteracting) {
      debugPrint('Slider interaction ended, triggering clipboard copy');
      _copyToClipboardIfEnabled();
    }
  }

  Widget _buildLightnessSlider() {
    return OklchGradientSlider(
      value: lightness,
      min: 0.0,
      max: 1.0,
      label: 'Lightness (L)',
      description: '',
      step: 0.01,
      decimalPlaces: 2,
      onChanged: (value) {
        final sheetState = context.read<SheetStateProvider>();
        sheetState.setSliderIsActive(false);
        setState(() {
          lightness = value;
          _updateColor();
        });
      },
      generateGradient: () => generateLightnessGradient(
        chroma,
        hue,
        300,
        useRealPigmentsOnly: widget.useRealPigmentsOnly,
      ),
      showSplitView: true,
      onInteractionChanged: _handleSliderInteraction,
      bgColor: widget.bgColor, // Pass bgColor
    );
  }

  Widget _buildChromaSlider() {
    return OklchGradientSlider(
      value: chroma,
      min: 0.0,
      max: 0.4,
      label: 'Chroma (C)',
      description: '',
      step: 0.01,
      decimalPlaces: 2,
      onChanged: (value) {
        final sheetState = context.read<SheetStateProvider>();
        sheetState.setSliderIsActive(false);
        setState(() {
          chroma = value;
          _updateColor();
        });
      },
      generateGradient: () => generateChromaGradient(
        lightness,
        hue,
        300,
        useRealPigmentsOnly: widget.useRealPigmentsOnly,
      ),
      showSplitView: true,
      onInteractionChanged: _handleSliderInteraction,
      bgColor: widget.bgColor, // Pass bgColor
    );
  }

  Widget _buildHueSlider() {
    return OklchGradientSlider(
      value: hue,
      min: 0.0,
      max: 360.0,
      label: 'Hue (H)',
      description: '',
      step: 1.0,
      decimalPlaces: 0,
      onChanged: (value) {
        final sheetState = context.read<SheetStateProvider>();
        sheetState.setSliderIsActive(false);
        setState(() {
          hue = value;
          _updateColor();
        });
      },
      generateGradient: () => generateHueGradient(
        lightness,
        chroma,
        300,
        useRealPigmentsOnly: widget.useRealPigmentsOnly,
      ),
      showSplitView: true,
      onInteractionChanged: _handleSliderInteraction,
      bgColor: widget.bgColor, // Pass bgColor
    );
  }

  Widget _buildMixerSlider() {
    // Read pigment mixing setting from provider
    final settings = context.watch<SettingsProvider>();

    // Read mixer state from SheetStateProvider
    final sheetState = context.watch<SheetStateProvider>();

    return MixedChannelSlider(
      value: sheetState.mixValue,
      currentColor: colorFromOklch(lightness, chroma, hue),
      leftExtreme: widget.leftExtreme,
      rightExtreme: widget.rightExtreme,
      sliderIsActive: sheetState.sliderIsActive,
      usePigmentMixing: settings.usePigmentMixing,
      useRealPigmentsOnly: widget.useRealPigmentsOnly,
      extremeColorFilter: widget.extremeColorFilter,
      gradientColorFilter: widget.gradientColorFilter,
      onChanged: (value) {
        sheetState.setMixValue(value.clamp(0.0, 1.0));
        setState(() {
          if (sheetState.sliderIsActive) {
            _updateColor();
          }
        });
      },
      onExtremeTap: widget.onExtremeTap,
      onSliderTouchStart: _handleSliderTouchStart,
      onSliderTouchEnd: _handleSliderTouchEnd,
      onInteractionChanged: _handleSliderInteraction,
      bgColor: widget.bgColor, // Pass bgColor
      onPanStartExtreme: widget.onPanStartExtreme, // Pass to MixedChannelSlider
    );
  }

  Widget _buildSliderByType(String type) {
    switch (type) {
      case 'lightness':
        return _buildLightnessSlider();
      case 'chroma':
        return _buildChromaSlider();
      case 'hue':
        return _buildHueSlider();
      case 'mixer':
        return _buildMixerSlider();
      default:
        return const SizedBox.shrink();
    }
  }

  void _decrementSlider(String sliderType) {
    final sheetState = context.read<SheetStateProvider>();

    setState(() {
      switch (sliderType) {
        case 'lightness':
          lightness = (lightness - 0.01).clamp(0.0, 1.0);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'chroma':
          chroma = (chroma - 0.002).clamp(0.0, 0.4);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'hue':
          hue = (hue - 1.0).clamp(0.0, 360.0);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'mixer':
          sheetState.setMixValue((sheetState.mixValue - 0.01).clamp(0.0, 1.0));
          if (sheetState.sliderIsActive) {
            _updateColor();
          }
          break;
      }
    });
  }

  void _incrementSlider(String sliderType) {
    final sheetState = context.read<SheetStateProvider>();

    setState(() {
      switch (sliderType) {
        case 'lightness':
          lightness = (lightness + 0.01).clamp(0.0, 1.0);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'chroma':
          chroma = (chroma + 0.002).clamp(0.0, 0.4);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'hue':
          hue = (hue + 1.0).clamp(0.0, 360.0);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'mixer':
          sheetState.setMixValue((sheetState.mixValue + 0.01).clamp(0.0, 1.0));
          if (sheetState.sliderIsActive) {
            _updateColor();
          }
          break;
      }
    });
  }

  Widget _wrapWithDragHandle(Widget slider, int index, String sliderType) {
    return Row(
      children: [
        // Left side - Minus button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _decrementSlider(sliderType),
          child: Container(
            width: 20,
            height: 50.0,
            color: Colors.transparent,
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              slider,
              // Long-press drag handle positioned ONLY over the title text (left side)
              // Positioned(
              //   top: 12,
              //   left: 13.5,
              //   width: 90, // Only covers the title text area, not the buttons
              //   height: 35,
              //   child: ReorderableDragStartListener(
              //     index: index,
              //     child: Container(
              //       color: Colors.transparent,
              //       // This transparent container only covers the title text
              //       // Long-pressing on "Lightness (L)" etc will trigger reordering
              //       // Plus/minus buttons remain clickable
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
        // Right side - Plus button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _incrementSlider(sliderType),
          child: Container(
            width: 20,
            height: 50.0,
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final item = _sliderOrder.removeAt(oldIndex);
          _sliderOrder.insert(newIndex, item);
        });
      },
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return Material(
          color: widget.bgColor ?? Colors.transparent, // Use the provided background color
          borderRadius: BorderRadius.circular(10),
          child: child,
        );
      },
      children: [
        for (int index = 0; index < _sliderOrder.length; index++)
          Container(
            key: ValueKey(_sliderOrder[index]),
            child: _wrapWithDragHandle(
              _buildSliderByType(_sliderOrder[index]),
              index,
              _sliderOrder[index],
            ),
          ),
      ],
    );
  }
}
