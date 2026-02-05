import 'dart:convert';
import 'package:flutter/material.dart';
import 'wheel_item.dart';

class WheelConfig {
  final String id;
  final String name;
  final List<WheelItem> items;
  final double textSize;
  final double cornerRadius;
  final double strokeWidth;
  final bool showBackgroundCircle;
  final double centerMarkerSize;

  WheelConfig({
    required this.id,
    required this.name,
    required this.items,
    this.textSize = 1.0,
    this.cornerRadius = 8.0,
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
      }).toList(),
      'textSize': textSize,
      'cornerRadius': cornerRadius,
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
      )).toList(),
      textSize: (json['textSize'] as num?)?.toDouble() ?? 1.0,
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 8.0,
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
    double? cornerRadius,
    double? strokeWidth,
    bool? showBackgroundCircle,
    double? centerMarkerSize,
  }) {
    return WheelConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      textSize: textSize ?? this.textSize,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      showBackgroundCircle: showBackgroundCircle ?? this.showBackgroundCircle,
      centerMarkerSize: centerMarkerSize ?? this.centerMarkerSize,
    );
  }
}
