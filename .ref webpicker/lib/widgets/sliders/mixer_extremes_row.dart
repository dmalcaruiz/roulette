import 'package:flutter/material.dart';
import '../../models/extreme_color_item.dart';
import '../color grid/extreme_color_circle.dart';

// Container for the two mixer extreme circles
//
// Displays left and right extreme circles below the mixer slider
// in a horizontal layout aligned with the slider endpoints.
class MixerExtremesRow extends StatelessWidget {
  // Left extreme color
  final ExtremeColorItem leftExtreme;

  // Right extreme color
  final ExtremeColorItem rightExtreme;

  // Callback when an extreme is tapped (receives extreme id: 'left' or 'right')
  final Function(String extremeId) onExtremeTap;

  // Optional color filter for ICC profile display
  final Color Function(ExtremeColorItem)? colorFilter;

  final Color? bgColor;

  final Function(String extremeId, DragStartDetails details)? onPanStart; // Change this line

  const MixerExtremesRow({
    super.key,
    required this.leftExtreme,
    required this.rightExtreme,
    required this.onExtremeTap,
    this.colorFilter,
    this.bgColor,
    this.onPanStart, // Change this line
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left extreme circle
          ExtremeColorCircle(
            extreme: leftExtreme,
            onTap: () => onExtremeTap(leftExtreme.id),
            colorFilter: colorFilter,
            bgColor: bgColor, // Pass bgColor
            onPanStart: onPanStart != null ? (details) => onPanStart!(leftExtreme.id, details) : null, // Pass to ExtremeColorCircle
          ),

          // Right extreme circle
          ExtremeColorCircle(
            extreme: rightExtreme,
            onTap: () => onExtremeTap(rightExtreme.id),
            colorFilter: colorFilter,
            bgColor: bgColor, // Pass bgColor
            onPanStart: onPanStart != null ? (details) => onPanStart!(rightExtreme.id, details) : null, // Pass to ExtremeColorCircle
          ),
        ],
      ),
    );
  }
}
