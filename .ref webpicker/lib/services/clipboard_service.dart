import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Service for handling color clipboard operations
class ClipboardService {
  // Copy a color to the clipboard as hex string
  static Future<void> copyColorToClipboard(Color color) async {
    final hexString = '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    debugPrint('ClipboardService: Copying "$hexString" to clipboard');
    await Clipboard.setData(ClipboardData(text: hexString));
    debugPrint('ClipboardService: Copy complete');
  }
  
  // Get color from clipboard if valid hex string exists
  static Future<Color?> getColorFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null) {
        return parseHexColor(clipboardData!.text!);
      }
    } catch (e) {
      debugPrint('Error reading from clipboard: $e');
    }
    return null;
  }
  
  // Check if clipboard contains a valid color
  static Future<bool> hasColorInClipboard() async {
    final color = await getColorFromClipboard();
    return color != null;
  }
  
  // Parse hex color string to Color object
  static Color? parseHexColor(String hexString) {
    try {
      // Remove any whitespace
      hexString = hexString.trim();
      
      // Remove # if present
      if (hexString.startsWith('#')) {
        hexString = hexString.substring(1);
      }
      
      // Remove 0x prefix if present
      if (hexString.toLowerCase().startsWith('0x')) {
        hexString = hexString.substring(2);
      }
      
      // Validate length (3, 4, 6, or 8 characters)
      if (hexString.length != 3 && hexString.length != 4 && 
          hexString.length != 6 && hexString.length != 8) {
        return null;
      }
      
      // Expand shorthand notation (e.g., "abc" to "aabbcc")
      if (hexString.length == 3 || hexString.length == 4) {
        hexString = hexString.split('').map((char) => char + char).join('');
      }
      
      // Add alpha channel if not present
      if (hexString.length == 6) {
        hexString = 'FF$hexString';
      }
      
      // Parse the hex string
      final intValue = int.tryParse(hexString, radix: 16);
      if (intValue == null) {
        return null;
      }
      
      return Color(intValue);
    } catch (e) {
      debugPrint('Error parsing hex color: $e');
      return null;
    }
  }
  
  // Convert Color to hex string
  static String colorToHex(Color color, {bool includeAlpha = false}) {
    if (includeAlpha) {
      return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
    } else {
      return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    }
  }
}
