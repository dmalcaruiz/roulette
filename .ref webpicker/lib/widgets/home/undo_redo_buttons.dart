import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/undo_redo_service.dart';
import '../../utils/ui_color_utils.dart'; // Import the new utility file

// Undo/Redo buttons with keyboard shortcuts
class UndoRedoButtons extends StatelessWidget {
  // Undo/Redo manager instance
  final UndoRedoService undoRedoManager;
  
  // Callback when undo is triggered
  final VoidCallback onUndo;
  
  // Callback when redo is triggered
  final VoidCallback onRedo;
  
  final Color? bgColor;
  
  const UndoRedoButtons({
    super.key,
    required this.undoRedoManager,
    required this.onUndo,
    required this.onRedo,
    this.bgColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: undoRedoManager,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Undo button
            _buildButton(
              icon: Icons.undo,
              tooltip: undoRedoManager.canUndo 
                  ? 'Undo: ${undoRedoManager.getUndoPreview()}'
                  : 'Nothing to undo',
              isEnabled: undoRedoManager.canUndo,
              onPressed: onUndo,
              shortcut: 'Ctrl+Z',
            ),
            
            const SizedBox(width: 8),
            
            // Redo button
            _buildButton(
              icon: Icons.redo,
              tooltip: undoRedoManager.canRedo 
                  ? 'Redo: ${undoRedoManager.getRedoPreview()}'
                  : 'Nothing to redo',
              isEnabled: undoRedoManager.canRedo,
              onPressed: onRedo,
              shortcut: 'Ctrl+Y',
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildButton({
    required IconData icon,
    required String tooltip,
    required bool isEnabled,
    required VoidCallback onPressed,
    required String shortcut,
  }) {
    Color effectiveBgColor = bgColor ?? Colors.transparent;
    Color textColor = getTextColor(effectiveBgColor);

    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (TapGestureRecognizer instance) {
            instance.onTap = () {
              if (isEnabled) {
                onPressed();
              }
            };
          },
        ),
        LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(),
          (LongPressGestureRecognizer instance) {
            instance.onLongPress = () {
              if (isEnabled) {
                onPressed();
              }
            };
          },
        ),
      },
      child: IgnorePointer(
        ignoring: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? onPressed : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isEnabled
                    ? effectiveBgColor.withOpacity(0.15)
                    : effectiveBgColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isEnabled
                      ? effectiveBgColor.withOpacity(0.3)
                      : effectiveBgColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: isEnabled ? textColor : textColor.withOpacity(0.3),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Keyboard shortcuts handler for undo/redo
class UndoRedoShortcuts extends StatelessWidget {
  final Widget child;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  
  const UndoRedoShortcuts({
    super.key,
    required this.child,
    required this.onUndo,
    required this.onRedo,
  });
  
  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Ctrl+Z for undo
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): onUndo,
        
        // Ctrl+Y for redo
        const SingleActivator(LogicalKeyboardKey.keyY, control: true): onRedo,
        
        // Ctrl+Shift+Z for redo (alternative)
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): onRedo,
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
