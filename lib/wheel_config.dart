import 'dart:convert';
import 'package:flutter/material.dart';
import 'wheel_item.dart';

class WheelConfig {
  final String id;
  final String name;
  final List<WheelItem> items;
  final double textSize; // Segment text size
  final double headerTextSize; // Header text size
  final double imageSize; // Image size for segment images
  final double cornerRadius;
  final double imageCornerRadius; // Corner radius for images
  final double strokeWidth;
  final bool showBackgroundCircle;
  final double centerMarkerSize;

  WheelConfig({
    required this.id,
    required this.name,
    required this.items,
    this.textSize = 1.0,
    this.headerTextSize = 1.0,
    this.imageSize = 60.0,
    this.cornerRadius = 8.0,
    this.imageCornerRadius = 8.0,
    this.strokeWidth = 3.0,
    this.showBackgroundCircle = true,
    this.centerMarkerSize = 200.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'items': items.map((item) => {
        'text': item.text,
        'color': item.color.toARGB32(),
        'weight': item.weight,
        'imagePath': item.imagePath,
        'iconName': item.iconName,
      }).toList(),
      'textSize': textSize,
      'headerTextSize': headerTextSize,
      'imageSize': imageSize,
      'cornerRadius': cornerRadius,
      'imageCornerRadius': imageCornerRadius,
      'strokeWidth': strokeWidth,
      'showBackgroundCircle': showBackgroundCircle,
      'centerMarkerSize': centerMarkerSize,
    };
  }

  factory WheelConfig.fromJson(Map<String, dynamic> json) {
    return WheelConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      items: (json['items'] as List).map((item) => WheelItem(
        text: item['text'] as String,
        color: Color(item['color'] as int),
        weight: (item['weight'] as num).toDouble(),
        imagePath: item['imagePath'] as String?,
        iconName: item['iconName'] as String?,
      )).toList(),
      textSize: (json['textSize'] as num?)?.toDouble() ?? 1.0,
      headerTextSize: (json['headerTextSize'] as num?)?.toDouble() ?? 1.0,
      imageSize: (json['imageSize'] as num?)?.toDouble() ?? 60.0,
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 8.0,
      imageCornerRadius: (json['imageCornerRadius'] as num?)?.toDouble() ?? 8.0,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      showBackgroundCircle: (json['showBackgroundCircle'] as bool?) ?? true,
      centerMarkerSize: (json['centerMarkerSize'] as num?)?.toDouble() ?? 200.0,
    );
  }

  String toJsonString() => json.encode(toJson());

  factory WheelConfig.fromJsonString(String jsonString) {
    return WheelConfig.fromJson(json.decode(jsonString) as Map<String, dynamic>);
  }

  WheelConfig copyWith({
    String? id,
    String? name,
    List<WheelItem>? items,
    double? textSize,
    double? headerTextSize,
    double? imageSize,
    double? cornerRadius,
    double? imageCornerRadius,
    double? strokeWidth,
    bool? showBackgroundCircle,
    double? centerMarkerSize,
  }) {
    return WheelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      textSize: textSize ?? this.textSize,
      headerTextSize: headerTextSize ?? this.headerTextSize,
      imageSize: imageSize ?? this.imageSize,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      imageCornerRadius: imageCornerRadius ?? this.imageCornerRadius,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      showBackgroundCircle: showBackgroundCircle ?? this.showBackgroundCircle,
      centerMarkerSize: centerMarkerSize ?? this.centerMarkerSize,
    );
  }
}
