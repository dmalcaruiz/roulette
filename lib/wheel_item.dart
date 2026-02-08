import 'dart:ui';

class WheelItem {
  final String text;
  final Color color;
  final double weight;
  final String? imagePath;
  final String? iconName; // Lucide icon name

  const WheelItem({
    required this.text,
    required this.color,
    this.weight = 1.0,
    this.imagePath,
    this.iconName,
  });

  WheelItem copyWith({
    String? text,
    Color? color,
    double? weight,
    String? imagePath,
    String? iconName,
  }) {
    return WheelItem(
      text: text ?? this.text,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      imagePath: imagePath ?? this.imagePath,
      iconName: iconName ?? this.iconName,
    );
  }
}
