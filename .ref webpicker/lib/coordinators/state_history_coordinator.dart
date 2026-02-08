import '../models/app_state_snapshot.dart';
import '../state/color_editor_provider.dart';
import '../state/color_grid_provider.dart';
import '../state/extreme_colors_provider.dart';
import '../state/bg_color_provider.dart';
import '../state/settings_provider.dart';
import '../services/undo_redo_service.dart';

// Coordinates state across all providers for undo/redo operations
//
// This class acts as the single point of coordination for capturing and
// restoring state snapshots across all application providers. It ensures
// that undo/redo operations are atomic and consistent across the entire
// application state.
class StateHistoryCoordinator {
  final ColorEditorProvider colorEditor;
  final ColorGridProvider grid;
  final ExtremeColorsProvider extremes;
  final BgColorProvider bgColor;
  final SettingsProvider settings;
  final UndoRedoService undoRedo;

  StateHistoryCoordinator({
    required this.colorEditor,
    required this.grid,
    required this.extremes,
    required this.bgColor,
    required this.settings,
    required this.undoRedo,
  });

  // Capture current state across all providers
  AppStateSnapshot captureSnapshot(String description) {
    return AppStateSnapshot(
      // Grid state
      gridItems: List.from(grid.items),
      selectedGridItemId: grid.selectedItem?.id,

      // Current editing color
      currentColor: colorEditor.currentColor,

      // Extreme colors state
      leftExtreme: extremes.leftExtreme,
      rightExtreme: extremes.rightExtreme,
      selectedExtremeId: extremes.selectedExtremeId,

      // Background color state
      bgColor: bgColor.color,
      bgLightness: bgColor.lightness,
      bgChroma: bgColor.chroma,
      bgHue: bgColor.hue,
      bgAlpha: bgColor.alpha,
      isBgColorSelected: bgColor.isSelected,

      // Metadata
      timestamp: DateTime.now(),
      actionDescription: description,
    );
  }

  // Restore state to all providers from a snapshot
  //
  // This method updates all providers in a coordinated manner to ensure
  // the entire application state is consistent with the snapshot.
  void restoreSnapshot(AppStateSnapshot snapshot) {
    // 1. Restore grid provider
    grid.syncFromSnapshot(snapshot.gridItems);

    // Handle grid selection
    if (snapshot.selectedGridItemId != null) {
      grid.selectItem(snapshot.selectedGridItemId!);
    } else {
      grid.deselectAll();
    }

    // 2. Restore color editor provider
    if (snapshot.currentColor != null) {
      colorEditor.syncFromSnapshot(
        lightness: snapshot.bgLightness,
        chroma: snapshot.bgChroma,
        hue: snapshot.bgHue,
        alpha: snapshot.bgAlpha,
      );
    }

    // 3. Restore extremes provider
    if (snapshot.leftExtreme != null && snapshot.rightExtreme != null) {
      extremes.syncFromSnapshot(
        leftExtreme: snapshot.leftExtreme!,
        rightExtreme: snapshot.rightExtreme!,
        selectedExtremeId: snapshot.selectedExtremeId,
      );
    }

    // 4. Restore background color provider
    bgColor.syncFromSnapshot(
      color: snapshot.bgColor,
      lightness: snapshot.bgLightness,
      chroma: snapshot.bgChroma,
      hue: snapshot.bgHue,
      alpha: snapshot.bgAlpha,
      isSelected: snapshot.isBgColorSelected,
    );
  }

  // Save current state to undo history
  //
  // Captures a snapshot of the current state across all providers
  // and pushes it to the undo stack.
  void saveState(String description) {
    final snapshot = captureSnapshot(description);
    undoRedo.pushState(snapshot);
  }

  // Undo the last action
  //
  // Returns true if undo was successful, false if no undo is available.
  bool undo() {
    if (!undoRedo.canUndo) return false;

    final snapshot = undoRedo.undo();
    if (snapshot != null) {
      restoreSnapshot(snapshot);
      return true;
    }
    return false;
  }

  // Redo the last undone action
  //
  // Returns true if redo was successful, false if no redo is available.
  bool redo() {
    if (!undoRedo.canRedo) return false;

    final snapshot = undoRedo.redo();
    if (snapshot != null) {
      restoreSnapshot(snapshot);
      return true;
    }
    return false;
  }

  // Check if undo is available
  bool get canUndo => undoRedo.canUndo;

  // Check if redo is available
  bool get canRedo => undoRedo.canRedo;

  // Get preview of what would be undone
  String? get undoPreview => undoRedo.getUndoPreview();

  // Get preview of what would be redone
  String? get redoPreview => undoRedo.getRedoPreview();

  // Get current state description
  String? get currentActionDescription => undoRedo.lastActionDescription;

  // Clear all undo/redo history
  void clearHistory() {
    undoRedo.clear();
  }
}
