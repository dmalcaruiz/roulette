import 'package:flutter/material.dart';
import '../utils/color_operations.dart';
import 'color_grid_item.dart';

// Represents a mixer extreme color (left or right)
//
// Behaves exactly like a grid box for selection and editing,
// but with a fixed ID ('left' or 'right') and used for mixer interpolation.
class ExtremeColorItem {
  // Unique identifier ('left' or 'right')
  final String id;

  // The actual color value
  final Color color;

  // Whether this extreme is currently selected
  final bool isSelected;

  // OKLCH values for this color (source of truth)
  final OklchValues oklchValues;

  const ExtremeColorItem({
    required this.id,
    required this.color,
    this.isSelected = false,
    required this.oklchValues,
  });

  // Create a copy of this item with updated values
  ExtremeColorItem copyWith({
    String? id,
    Color? color,
    bool? isSelected,
    OklchValues? oklchValues,
  }) {
    return ExtremeColorItem(
      id: id ?? this.id,
      color: color ?? this.color,
      isSelected: isSelected ?? this.isSelected,
      oklchValues: oklchValues ?? this.oklchValues,
    );
  }

  // Create a new extreme from OKLCH values (preferred method)
  factory ExtremeColorItem.fromOklch({
    required String id,
    required double lightness,
    required double chroma,
    required double hue,
    double alpha = 1.0,
    bool isSelected = false,
  }) {
    final oklch = OklchValues(
      lightness: lightness,
      chroma: chroma,
      hue: hue,
      alpha: alpha,
    );
    // Convert OKLCH to Color for display
    final color = colorFromOklch(
      oklch.lightness,
      oklch.chroma,
      oklch.hue,
      oklch.alpha,
    );
    return ExtremeColorItem(
      id: id,
      color: color,
      isSelected: isSelected,
      oklchValues: oklch,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExtremeColorItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ExtremeColorItem(id: $id, color: $color, isSelected: $isSelected)';
  }
}
