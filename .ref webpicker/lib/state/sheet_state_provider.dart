import 'package:flutter/material.dart';

// Provider for sheet content state
//
// Manages which content view is active based on chip selection:
// - 0: My Picks (default color grid view)
// - 1: Perceptual (OKLCH sliders)
// - 2: Digital (RGB/HSB sliders)
// - 3: Add (CMYK/additional controls)
//
// Also manages shared UI state across chips:
// - Mixer slider position (shared between Perceptual and Digital)
// - Mixer slider active state (whether mixer is controlling color)
class SheetStateProvider extends ChangeNotifier {
  int _selectedChipIndex = 1; // Default to 'Perceptual' (index 1)

  // Mixer slider state (shared across chips)
  double _mixValue = 0.0; // 0.0 to 1.0
  bool _sliderIsActive = false; // Whether mixer slider is controlling the color

  // Getter for current selected chip index
  int get selectedChipIndex => _selectedChipIndex;

  // Mixer state getters
  double get mixValue => _mixValue;
  bool get sliderIsActive => _sliderIsActive;

  // Chip labels for reference
  static const List<String> chipLabels = [
    'My Picks',
    'Perceptual',
    'Digital',
    'Add',
  ];

  // Get the current chip label
  String get currentChipLabel => chipLabels[_selectedChipIndex];

  // Select a specific chip by index
  void selectChip(int index) {
    if (index >= 0 && index < chipLabels.length && _selectedChipIndex != index) {
      _selectedChipIndex = index;
      notifyListeners();
    }
  }

  // Check if a specific chip is selected
  bool isChipSelected(int index) => _selectedChipIndex == index;

  // Get list of boolean states for all chips (for compatibility with existing UI)
  List<bool> get chipStates {
    return List.generate(
      chipLabels.length,
      (index) => index == _selectedChipIndex,
    );
  }

  // Update mixer slider value
  void setMixValue(double value) {
    if (_mixValue != value) {
      _mixValue = value.clamp(0.0, 1.0);
      notifyListeners();
    }
  }

  // Update mixer slider active state
  void setSliderIsActive(bool isActive) {
    if (_sliderIsActive != isActive) {
      _sliderIsActive = isActive;
      notifyListeners();
    }
  }
}
