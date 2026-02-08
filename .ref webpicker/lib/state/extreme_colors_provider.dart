import 'package:flutter/material.dart';
import '../models/extreme_color_item.dart';

// Provider for mixer extreme colors (left and right)
//
// Manages the two extreme colors used for color mixing/interpolation.
// These colors behave like grid boxes (can be selected and edited),
// but with fixed IDs ('left' and 'right').
class ExtremeColorsProvider extends ChangeNotifier {
  late ExtremeColorItem _leftExtreme;
  late ExtremeColorItem _rightExtreme;
  String? _selectedExtremeId;

  // Initialize with default extreme colors
  ExtremeColorsProvider() {
    // Default left extreme: Warm color
    _leftExtreme = ExtremeColorItem.fromOklch(
      id: 'left',
      lightness: 0.7,
      chroma: 0.15,
      hue: 30.0,
      alpha: 1.0,
    );

    // Default right extreme: Cool color
    _rightExtreme = ExtremeColorItem.fromOklch(
      id: 'right',
      lightness: 0.7,
      chroma: 0.15,
      hue: 240.0,
      alpha: 1.0,
    );
  }

  // Getters
  ExtremeColorItem get leftExtreme => _leftExtreme;
  ExtremeColorItem get rightExtreme => _rightExtreme;
  String? get selectedExtremeId => _selectedExtremeId;
  bool get hasSelection => _selectedExtremeId != null;

  // Get currently selected extreme (if any)
  ExtremeColorItem? get selectedExtreme {
    if (_selectedExtremeId == null) return null;
    return _selectedExtremeId == 'left' ? _leftExtreme : _rightExtreme;
  }

  // Select a specific extreme ('left' or 'right')
  void selectExtreme(String extremeId) {
    if (extremeId != 'left' && extremeId != 'right') {
      throw ArgumentError('extremeId must be "left" or "right"');
    }

    _selectedExtremeId = extremeId;
    _leftExtreme = _leftExtreme.copyWith(isSelected: extremeId == 'left');
    _rightExtreme = _rightExtreme.copyWith(isSelected: extremeId == 'right');
    notifyListeners();
  }

  // Deselect both extremes
  void deselectAll() {
    if (_selectedExtremeId != null) {
      _selectedExtremeId = null;
      _leftExtreme = _leftExtreme.copyWith(isSelected: false);
      _rightExtreme = _rightExtreme.copyWith(isSelected: false);
      notifyListeners();
    }
  }

  // Update OKLCH values of the left extreme
  void updateLeftOklch({
    required double lightness,
    required double chroma,
    required double hue,
    double? alpha,
  }) {
    _leftExtreme = ExtremeColorItem.fromOklch(
      id: 'left',
      lightness: lightness,
      chroma: chroma,
      hue: hue,
      alpha: alpha ?? 1.0,
      isSelected: _leftExtreme.isSelected,
    );
    notifyListeners();
  }

  // Update OKLCH values of the right extreme
  void updateRightOklch({
    required double lightness,
    required double chroma,
    required double hue,
    double? alpha,
  }) {
    _rightExtreme = ExtremeColorItem.fromOklch(
      id: 'right',
      lightness: lightness,
      chroma: chroma,
      hue: hue,
      alpha: alpha ?? 1.0,
      isSelected: _rightExtreme.isSelected,
    );
    notifyListeners();
  }

  // Update the extreme that matches the given ID
  void updateExtremeOklch({
    required String extremeId,
    required double lightness,
    required double chroma,
    required double hue,
    double? alpha,
  }) {
    if (extremeId == 'left') {
      updateLeftOklch(
        lightness: lightness,
        chroma: chroma,
        hue: hue,
        alpha: alpha,
      );
    } else if (extremeId == 'right') {
      updateRightOklch(
        lightness: lightness,
        chroma: chroma,
        hue: hue,
        alpha: alpha,
      );
    }
  }

  // Sync from snapshot (for undo/redo)
  void syncFromSnapshot({
    required ExtremeColorItem leftExtreme,
    required ExtremeColorItem rightExtreme,
    String? selectedExtremeId,
  }) {
    bool changed = false;

    if (_leftExtreme != leftExtreme) {
      _leftExtreme = leftExtreme;
      changed = true;
    }
    if (_rightExtreme != rightExtreme) {
      _rightExtreme = rightExtreme;
      changed = true;
    }
    if (_selectedExtremeId != selectedExtremeId) {
      _selectedExtremeId = selectedExtremeId;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  // Set both extremes at once (useful for bulk updates)
  void setExtremes({
    required ExtremeColorItem leftExtreme,
    required ExtremeColorItem rightExtreme,
  }) {
    _leftExtreme = leftExtreme;
    _rightExtreme = rightExtreme;
    notifyListeners();
  }
}
