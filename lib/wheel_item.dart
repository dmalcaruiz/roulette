import 'dart:ui';

class WheelItem {
  final String text;
  final Color color;
  final double weight;
  final String? imagePath; // Optional image path for the segment

  const WheelItem({
    required this.text,
    required this.color,
    this.weight = 1.0,
    this.imagePath,
  });

  WheelItem copyWith({
    String? text,
    Color? color,
    double? weight,
    String? imagePath,
  }) {
    return WheelItem(
      text: text ?? this.text,
      color: color ?? this.color,
      weight: weight ?? this.weight,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
