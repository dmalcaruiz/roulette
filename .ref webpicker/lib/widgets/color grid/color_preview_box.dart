import 'package:flutter/material.dart';

// A simple widget that displays a color preview box with hex code
class ColorPreviewBox extends StatelessWidget {
  final Color? color;
  final double height;
  final EdgeInsetsGeometry? margin;

  const ColorPreviewBox({
    super.key,
    required this.color,
    this.height = 120,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF808080),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '#${(color?.toARGB32().toRadixString(16).substring(2).toUpperCase() ?? '808080')}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: (color?.computeLuminance() ?? 0.5) > 0.5 ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
