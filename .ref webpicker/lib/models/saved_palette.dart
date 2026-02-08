import 'dart:convert';
import 'package:flutter/material.dart';
import 'color_grid_item.dart';

/// Represents a saved palette with all its colors and metadata
class SavedPalette {
  final String id;
  final String name;
  final List<ColorGridItem> colors;
  final DateTime createdAt;
  final DateTime lastModified;

  const SavedPalette({
    required this.id,
    required this.name,
    required this.colors,
    required this.createdAt,
    required this.lastModified,
  });

  /// Create a new palette from current color grid
  factory SavedPalette.create({
    required String name,
    required List<ColorGridItem> colors,
  }) {
    final now = DateTime.now();
    return SavedPalette(
      id: _generateId(),
      name: name,
      colors: colors,
      createdAt: now,
      lastModified: now,
    );
  }

  /// Create a copy with updated fields
  SavedPalette copyWith({
    String? id,
    String? name,
    List<ColorGridItem>? colors,
    DateTime? createdAt,
    DateTime? lastModified,
  }) {
    return SavedPalette(
      id: id ?? this.id,
      name: name ?? this.name,
      colors: colors ?? this.colors,
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'colors': colors.map((item) => _colorGridItemToJson(item)).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastModified': lastModified.toIso8601String(),
    };
  }

  /// Create from JSON
  factory SavedPalette.fromJson(Map<String, dynamic> json) {
    return SavedPalette(
      id: json['id'] as String,
      name: json['name'] as String,
      colors: (json['colors'] as List)
          .map((item) => _colorGridItemFromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
    );
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Create from JSON string
  factory SavedPalette.fromJsonString(String jsonString) {
    return SavedPalette.fromJson(jsonDecode(jsonString));
  }

  // Helper methods for ColorGridItem serialization
  static Map<String, dynamic> _colorGridItemToJson(ColorGridItem item) {
    return {
      'id': item.id,
      'color': item.color?.value,
      'name': item.name,
      'createdAt': item.createdAt.toIso8601String(),
      'lastModified': item.lastModified.toIso8601String(),
      'isSelected': item.isSelected,
      'isLocked': item.isLocked,
      'isEmpty': item.isEmpty,
      'oklchValues': item.oklchValues != null
          ? {
              'lightness': item.oklchValues!.lightness,
              'chroma': item.oklchValues!.chroma,
              'hue': item.oklchValues!.hue,
              'alpha': item.oklchValues!.alpha,
            }
          : null,
    };
  }

  static ColorGridItem _colorGridItemFromJson(Map<String, dynamic> json) {
    final colorValue = json['color'] as int?;
    final oklchJson = json['oklchValues'] as Map<String, dynamic>?;

    return ColorGridItem(
      id: json['id'] as String,
      color: colorValue != null ? Color(colorValue) : null,
      name: json['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModified: DateTime.parse(json['lastModified'] as String),
      isSelected: json['isSelected'] as bool? ?? false,
      isLocked: json['isLocked'] as bool? ?? false,
      isEmpty: json['isEmpty'] as bool? ?? false,
      oklchValues: oklchJson != null
          ? OklchValues(
              lightness: oklchJson['lightness'] as double,
              chroma: oklchJson['chroma'] as double,
              hue: oklchJson['hue'] as double,
              alpha: oklchJson['alpha'] as double? ?? 1.0,
            )
          : null,
    );
  }

  static int _idCounter = 0;

  static String _generateId() {
    _idCounter++;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'palette_${timestamp}_$_idCounter';
  }

  @override
  String toString() => 'SavedPalette(id: $id, name: $name, ${colors.length} colors)';
}
