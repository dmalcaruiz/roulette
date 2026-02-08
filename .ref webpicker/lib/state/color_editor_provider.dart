import 'package:flutter/material.dart';
import '../models/color_grid_item.dart';
import '../utils/color_operations.dart';

// Provider for current OKLCH editing values
//
// This provider holds the OKLCH values (Lightness, Chroma, Hue, Alpha)
// that are currently being edited in the color picker controls.
// It serves as the single source of truth for the current editing state.
class ColorEditorProvider extends ChangeNotifier {
  double? _lightness;
  double? _chroma;
  double? _hue;
  double? _alpha;

  // Getters
  double? get lightness => _lightness;
  double? get chroma => _chroma;
  double? get hue => _hue;
  double? get alpha => _alpha;

  // Returns true if OKLCH values are set
  bool get hasValues => _lightness != null &&
                        _chroma != null &&
                        _hue != null;

  // Get the current color derived from OKLCH values
  Color? get currentColor {
    if (!hasValues) return null;
    return colorFromOklch(
      _lightness!,
      _chroma!,
      _hue!,
      _alpha ?? 1.0,
    );
  }

  // Get current OKLCH as OklchValues object
  OklchValues? get oklchValues {
    if (!hasValues) return null;
    return OklchValues(
      lightness: _lightness!,
      chroma: _chroma!,
      hue: _hue!,
      alpha: _alpha ?? 1.0,
    );
  }

  // Update OKLCH values
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
    notifyListeners();
  }

  // Set values from OklchValues object
  void setFromOklchValues(OklchValues values) {
    _lightness = values.lightness;
    _chroma = values.chroma;
    _hue = values.hue;
    _alpha = values.alpha;
    notifyListeners();
  }

  // Clear all OKLCH values
  void clear() {
    _lightness = null;
    _chroma = null;
    _hue = null;
    _alpha = null;
    notifyListeners();
  }

  // Sync from snapshot (for undo/redo) - optimized to avoid unnecessary rebuilds
  void syncFromSnapshot({
    double? lightness,
    double? chroma,
    double? hue,
    double? alpha,
  }) {
    bool changed = false;

    if (_lightness != lightness) {
      _lightness = lightness;
      changed = true;
    }
    if (_chroma != chroma) {
      _chroma = chroma;
      changed = true;
    }
    if (_hue != hue) {
      _hue = hue;
      changed = true;
    }
    if (_alpha != alpha) {
      _alpha = alpha;
      changed = true;
    }

    // Only notify if something actually changed
    if (changed) {
      notifyListeners();
    }
  }
}
