import 'package:flutter/material.dart';
import '../models/color_grid_item.dart';
import '../utils/color_operations.dart';

// Provider for background color state
//
// Manages the background color and its OKLCH values, as well as
// its selection state. The background color serves as the canvas
// on which grid colors are displayed.
class BgColorProvider extends ChangeNotifier {
  Color _bgColor = const Color(0xFFFFFFFF);
  double _lightness = 1.0;
  double _chroma = 0.05;
  double _hue = 0.0;
  double _alpha = 1.0;
  bool _isSelected = false;

  // Getters
  Color get color => _bgColor;
  double get lightness => _lightness;
  double get chroma => _chroma;
  double get hue => _hue;
  double get alpha => _alpha;
  bool get isSelected => _isSelected;

  // Get current OKLCH as OklchValues object
  OklchValues get oklchValues => OklchValues(
        lightness: _lightness,
        chroma: _chroma,
        hue: _hue,
        alpha: _alpha,
      );

  // Update OKLCH values and derive the color
  void updateOklch({
    required double lightness,
    required double chroma,
    required double hue,
    double? alpha,
  }) {
    _lightness = lightness;
    _chroma = chroma;
    _hue = hue;
    _alpha = alpha ?? 1.0;
    _bgColor = colorFromOklch(_lightness, _chroma, _hue, _alpha);
    notifyListeners();
  }

  // Set background color and derive OKLCH values
  void setColor(Color color) {
    _bgColor = color;
    final oklch = srgbToOklch(color);
    _lightness = oklch.l;
    _chroma = oklch.c;
    _hue = oklch.h;
    _alpha = oklch.alpha;
    notifyListeners();
  }

  // Set selection state
  void setSelected(bool selected) {
    if (_isSelected != selected) {
      _isSelected = selected;
      notifyListeners();
    }
  }

  // Set from OklchValues object
  void setFromOklchValues(OklchValues values) {
    _lightness = values.lightness;
    _chroma = values.chroma;
    _hue = values.hue;
    _alpha = values.alpha;
    _bgColor = colorFromOklch(_lightness, _chroma, _hue, _alpha);
    notifyListeners();
  }

  // Sync from snapshot (for undo/redo) - optimized to avoid unnecessary rebuilds
  void syncFromSnapshot({
    Color? color,
    double? lightness,
    double? chroma,
    double? hue,
    double? alpha,
    bool? isSelected,
  }) {
    bool changed = false;

    if (color != null && _bgColor != color) {
      _bgColor = color;
      changed = true;
    }
    if (lightness != null && _lightness != lightness) {
      _lightness = lightness;
      changed = true;
    }
    if (chroma != null && _chroma != chroma) {
      _chroma = chroma;
      changed = true;
    }
    if (hue != null && _hue != hue) {
      _hue = hue;
      changed = true;
    }
    if (alpha != null && _alpha != alpha) {
      _alpha = alpha;
      changed = true;
    }
    if (isSelected != null && _isSelected != isSelected) {
      _isSelected = isSelected;
      changed = true;
    }

    // Only notify if something actually changed
    if (changed) {
      notifyListeners();
    }
  }
}
