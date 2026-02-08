import 'package:flutter/material.dart';

// Determines if a given color is light or dark based on its luminance.
//
// This is a simplified check based on perceived lightness (luminance).
bool isLightColor(Color color) {
  // Calculate luminance (perceived lightness) using a common formula
  final double luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
  return luminance > 0.5; // Adjust threshold as needed
}

// Returns either black or white text color based on the background color's luminance.
Color getTextColor(Color backgroundColor) {
  return isLightColor(backgroundColor) ? Colors.black : Colors.white;
}
