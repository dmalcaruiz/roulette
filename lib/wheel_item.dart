import 'dart:ui';

class WheelItem {
  final String text;
  final Color color;
  final double weight;

  const WheelItem({
    required this.text,
    required this.color,
    this.weight = 1.0,
  });
}
