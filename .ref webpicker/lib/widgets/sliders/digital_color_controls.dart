import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/color_operations.dart';
import '../../utils/mixbox.dart';
import '../../models/extreme_color_item.dart';
import '../../state/color_editor_provider.dart';
import '../../state/settings_provider.dart';
import '../../state/sheet_state_provider.dart';
import '../../services/clipboard_service.dart';
import 'hsb_gradient_slider.dart';
import 'mixer_slider.dart' show MixedChannelSlider;

// A widget containing all the HSB (Hue, Saturation, Brightness) slider controls
//
// Reads OKLCH from ColorEditorProvider, converts to HSB for display,
// then converts back to OKLCH when values change.
class DigitalColorControls extends StatefulWidget {
  // Callback when HSB values change (converted to OKLCH for coordination)
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

  const DigitalColorControls({
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
  State<DigitalColorControls> createState() => _DigitalColorControlsState();
}

class _DigitalColorControlsState extends State<DigitalColorControls> {
  // HSB values
  double hue = 0.0;        // 0 to 360 degrees
  double saturation = 50.0; // 0 to 100
  double brightness = 70.0; // 0 to 100

  // Mixer state is now managed by SheetStateProvider (shared between chips)
  // Access via: context.read<SheetStateProvider>().mixValue
  // Access via: context.read<SheetStateProvider>().sliderIsActive

  // Slider order (for reorderable list)
  List<String> _sliderOrder = ['hue', 'saturation', 'brightness', 'mixer'];

  // Converted color
  Color? currentColor;

  // Flag to prevent feedback loop when we update the color internally
  bool _isInternalUpdate = false;

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
      // Convert OKLCH to HSB
      final oklchColor = colorFromOklch(
        colorEditor.lightness!,
        colorEditor.chroma!,
        colorEditor.hue!,
        1.0,
      );

      final hsbColor = srgbToHsb(oklchColor);
      hue = hsbColor.h;
      saturation = hsbColor.s;
      brightness = hsbColor.b;

      currentColor = colorEditor.currentColor;
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

        // Get pigment mixing setting from provider
        final settings = context.read<SettingsProvider>();
        final usePigmentMixing = settings.usePigmentMixing;

        // Get mixer state from SheetStateProvider
        final sheetState = context.read<SheetStateProvider>();
        final mixValue = sheetState.mixValue;
        final sliderIsActive = sheetState.sliderIsActive;

        // Calculate final values
        if (sliderIsActive) {
          // Mixer slider is controlling: interpolate between extremes
          if (usePigmentMixing) {
            // Use Kubelka-Munk (Mixbox) for realistic pigment mixing
            final mixedColor = lerpMixbox(
              widget.leftExtreme.color,
              widget.rightExtreme.color,
              mixValue,
            );

            // Extract HSB values from the mixed color
            final mixedHsb = srgbToHsb(mixedColor);
            hue = mixedHsb.h;
            saturation = mixedHsb.s;
            brightness = mixedHsb.b;
            currentColor = mixedColor;
          } else {
            // Use HSB interpolation
            final leftHsb = srgbToHsb(widget.leftExtreme.color);
            final rightHsb = srgbToHsb(widget.rightExtreme.color);

            // Interpolate each HSB component separately
            hue = _lerpHue(leftHsb.h, rightHsb.h, mixValue);
            saturation = _lerpDouble(leftHsb.s, rightHsb.s, mixValue);
            brightness = _lerpDouble(leftHsb.b, rightHsb.b, mixValue);

            // Convert back to Color for display
            currentColor = colorFromHsb(hue, saturation, brightness);
          }
        } else {
          // Mixer slider is not controlling: use HSB sliders
          currentColor = colorFromHsb(hue, saturation, brightness);
        }

        // Convert to OKLCH for coordination with other parts of the app
        final oklchColor = srgbToOklch(currentColor!);

        // Call callback to let HomeScreen coordinate Provider updates
        widget.onOklchChanged(
          lightness: oklchColor.l,
          chroma: oklchColor.c,
          hue: oklchColor.h,
          alpha: 1.0,
        );
      });
    } catch (e) {
      debugPrint('Error updating color: $e');
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
    if (settings.autoCopyEnabled && currentColor != null) {
      ClipboardService.copyColorToClipboard(currentColor!);
    }
  }

  // Wrapper for slider interaction that adds clipboard copying
  void _handleSliderInteraction(bool isInteracting) {
    // Call parent callback
    widget.onSliderInteractionChanged?.call(isInteracting);

    // Copy to clipboard when interaction ends
    if (!isInteracting) {
      _copyToClipboardIfEnabled();
    }
  }

  Widget _buildHueSlider() {
    return HsbGradientSlider(
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
      generateGradient: () => generateHueGradientHsb(
        saturation,
        brightness,
        300,
      ),
      onInteractionChanged: _handleSliderInteraction,
      bgColor: widget.bgColor,
    );
  }

  Widget _buildSaturationSlider() {
    return HsbGradientSlider(
      value: saturation,
      min: 0.0,
      max: 100.0,
      label: 'Saturation (S)',
      description: '',
      step: 1.0,
      decimalPlaces: 0,
      onChanged: (value) {
        final sheetState = context.read<SheetStateProvider>();
        sheetState.setSliderIsActive(false);
        setState(() {
          saturation = value;
          _updateColor();
        });
      },
      generateGradient: () => generateSaturationGradientHsb(
        hue,
        brightness,
        300,
      ),
      onInteractionChanged: _handleSliderInteraction,
      bgColor: widget.bgColor,
    );
  }

  Widget _buildBrightnessSlider() {
    return HsbGradientSlider(
      value: brightness,
      min: 0.0,
      max: 100.0,
      label: 'Brightness (B)',
      description: '',
      step: 1.0,
      decimalPlaces: 0,
      onChanged: (value) {
        final sheetState = context.read<SheetStateProvider>();
        sheetState.setSliderIsActive(false);
        setState(() {
          brightness = value;
          _updateColor();
        });
      },
      generateGradient: () => generateBrightnessGradientHsb(
        hue,
        saturation,
        300,
      ),
      onInteractionChanged: _handleSliderInteraction,
      bgColor: widget.bgColor,
    );
  }

  Widget _buildMixerSlider() {
    // Read pigment mixing setting from provider
    final settings = context.watch<SettingsProvider>();

    // Read mixer state from SheetStateProvider
    final sheetState = context.watch<SheetStateProvider>();

    return MixedChannelSlider(
      value: sheetState.mixValue,
      currentColor: colorFromHsb(hue, saturation, brightness),
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
      bgColor: widget.bgColor,
      onPanStartExtreme: widget.onPanStartExtreme,
    );
  }

  Widget _buildSliderByType(String type) {
    switch (type) {
      case 'hue':
        return _buildHueSlider();
      case 'saturation':
        return _buildSaturationSlider();
      case 'brightness':
        return _buildBrightnessSlider();
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
        case 'hue':
          hue = (hue - 1.0).clamp(0.0, 360.0);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'saturation':
          saturation = (saturation - 1.0).clamp(0.0, 100.0);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'brightness':
          brightness = (brightness - 1.0).clamp(0.0, 100.0);
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
        case 'hue':
          hue = (hue + 1.0).clamp(0.0, 360.0);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'saturation':
          saturation = (saturation + 1.0).clamp(0.0, 100.0);
          sheetState.setSliderIsActive(false);
          _updateColor();
          break;
        case 'brightness':
          brightness = (brightness + 1.0).clamp(0.0, 100.0);
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
          child: slider,
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
          color: widget.bgColor ?? Colors.transparent,
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
