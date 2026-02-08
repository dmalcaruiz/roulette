import 'package:flutter/material.dart';
import 'global_action_buttons.dart';
import 'undo_redo_buttons.dart';
import '../../services/undo_redo_service.dart';
import '../../models/extreme_color_item.dart';

// Row containing global copy, paste and undo/redo controls
class ActionButtonsRow extends StatelessWidget {
  // Current color for copy/paste operations
  final Color? currentColor;

  // Selected extreme ID ('left', 'right', or null)
  final String? selectedExtremeId;

  // Left extreme
  final ExtremeColorItem leftExtreme;

  // Right extreme
  final ExtremeColorItem rightExtreme;

  // Callback when a color is selected via eyedropper or paste
  final Function(Color) onColorSelected;

  // Undo/redo manager instance
  final UndoRedoService undoRedoManager;

  // Callback for undo action
  final VoidCallback onUndo;

  // Callback for redo action
  final VoidCallback onRedo;

  // Callback for generate colors action
  final VoidCallback? onGenerateColors;

  // Optional color filter to apply before copying (e.g., ICC profile filter)
  final Color Function(Color)? colorFilter;

  final Color? bgColor;

  const ActionButtonsRow({
    super.key,
    required this.currentColor,
    this.selectedExtremeId,
    required this.leftExtreme,
    required this.rightExtreme,
    required this.onColorSelected,
    required this.undoRedoManager,
    required this.onUndo,
    required this.onRedo,
    this.onGenerateColors,
    this.colorFilter,
    this.bgColor,
  });
  
  @override
  Widget build(BuildContext context) {
    // Determine which color to use for copy/paste
    // If an extreme is selected, use that extreme's color
    // Otherwise, use the current color
    Color? colorToUse = currentColor;
    if (selectedExtremeId == 'left') {
      colorToUse = leftExtreme.color;
    } else if (selectedExtremeId == 'right') {
      colorToUse = rightExtreme.color;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Undo/Redo buttons
        UndoRedoButtons(
          undoRedoManager: undoRedoManager,
          onUndo: onUndo,
          onRedo: onRedo,
          bgColor: bgColor,
        ),
        
        // Copy/Paste/Eyedropper buttons
        Expanded(
          child: GlobalActionButtons(
            currentColor: colorToUse,
            onColorSelected: onColorSelected,
            onGenerateColors: onGenerateColors,
            colorFilter: colorFilter,
            bgColor: bgColor,
          ),
        ),
      ],
    );
  }
}

