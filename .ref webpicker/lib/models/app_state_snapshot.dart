import 'package:flutter/material.dart';
import 'color_grid_item.dart';
import 'extreme_color_item.dart';

// Represents a complete snapshot of the app state for undo/redo
class AppStateSnapshot {
  // List of color grid items
  final List<ColorGridItem> gridItems;

  // Current color being edited
  final Color? currentColor;

  // Background color
  final Color? bgColor;

  // Background color OKLCH values
  final double? bgLightness;
  final double? bgChroma;
  final double? bgHue;
  final double? bgAlpha;

  // Whether background color box is selected
  final bool isBgColorSelected;

  // ID of the selected grid item
  final String? selectedGridItemId;

  // ID of the selected extreme ('left', 'right', or null)
  final String? selectedExtremeId;

  // Left extreme color state
  final ExtremeColorItem? leftExtreme;

  // Right extreme color state
  final ExtremeColorItem? rightExtreme;

  // Timestamp when this snapshot was created
  final DateTime timestamp;

  // Description of the action that created this snapshot
  final String actionDescription;
  
  const AppStateSnapshot({
    required this.gridItems,
    required this.currentColor,
    required this.bgColor,
    this.bgLightness,
    this.bgChroma,
    this.bgHue,
    this.bgAlpha,
    this.isBgColorSelected = false,
    this.selectedGridItemId,
    this.selectedExtremeId,
    this.leftExtreme,
    this.rightExtreme,
    required this.timestamp,
    required this.actionDescription,
  });
  
  // Create a deep copy of this snapshot
  AppStateSnapshot copyWith({
    List<ColorGridItem>? gridItems,
    Color? currentColor,
    Color? bgColor,
    double? bgLightness,
    double? bgChroma,
    double? bgHue,
    double? bgAlpha,
    bool? isBgColorSelected,
    String? selectedGridItemId,
    String? selectedExtremeId,
    ExtremeColorItem? leftExtreme,
    ExtremeColorItem? rightExtreme,
    DateTime? timestamp,
    String? actionDescription,
  }) {
    return AppStateSnapshot(
      gridItems: gridItems ?? this.gridItems.map((item) => item).toList(),
      currentColor: currentColor ?? this.currentColor,
      bgColor: bgColor ?? this.bgColor,
      bgLightness: bgLightness ?? this.bgLightness,
      bgChroma: bgChroma ?? this.bgChroma,
      bgHue: bgHue ?? this.bgHue,
      bgAlpha: bgAlpha ?? this.bgAlpha,
      isBgColorSelected: isBgColorSelected ?? this.isBgColorSelected,
      selectedGridItemId: selectedGridItemId ?? this.selectedGridItemId,
      selectedExtremeId: selectedExtremeId ?? this.selectedExtremeId,
      leftExtreme: leftExtreme ?? this.leftExtreme,
      rightExtreme: rightExtreme ?? this.rightExtreme,
      timestamp: timestamp ?? this.timestamp,
      actionDescription: actionDescription ?? this.actionDescription,
    );
  }
  
  @override
  String toString() {
    return 'AppStateSnapshot($actionDescription, ${gridItems.length} items, ${timestamp.toIso8601String()})';
  }
}
