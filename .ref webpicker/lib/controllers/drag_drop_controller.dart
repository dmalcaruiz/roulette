import 'package:flutter/material.dart';
import '../models/color_grid_item.dart';
import '../state/color_grid_provider.dart';
import '../state/settings_provider.dart';
import '../coordinators/state_history_coordinator.dart';
import '../widgets/home/home_app_bar.dart';

// Controller for drag and drop operations
//
// Handles:
// - Drag state tracking
// - Delete zone detection
// - Drag lifecycle (start, update, end)
class DragDropController extends ChangeNotifier {
  final ColorGridProvider gridProvider;
  final SettingsProvider settingsProvider;
  final StateHistoryCoordinator coordinator;

  DragDropController({
    required this.gridProvider,
    required this.settingsProvider,
    required this.coordinator,
  });

  // ========== Drag State ==========

  // Currently dragging item (for delete zone)
  ColorGridItem? _draggingItem;

  // Current pointer Y position during drag
  double _dragPointerY = double.infinity;

  // Last known pointer Y before drag ended
  double _lastDragPointerY = double.infinity;

  // Threshold for delete zone (pixels from top) - matches app bar height
  static const double _deleteZoneThreshold = HomeAppBar.height;

  // ========== Getters ==========

  ColorGridItem? get draggingItem => _draggingItem;
  bool get isInDeleteZone => _dragPointerY < _deleteZoneThreshold;
  bool get isDragging => _draggingItem != null;

  // ========== Drag Lifecycle ==========

  // Handle drag start
  void onDragStarted(ColorGridItem item) {
    // Only reset if this is a NEW drag (not already dragging)
    if (_draggingItem == null) {
      _draggingItem = item;
      _dragPointerY = double.infinity; // Start with a safe value
      _lastDragPointerY = double.infinity;
      notifyListeners();
      debugPrint('Drag started for item: ${item.id}');
    }
  }

  // Handle drag update
  void onDragUpdate(Offset globalPosition) {
    if (_draggingItem != null) {
      _dragPointerY = globalPosition.dy;
      _lastDragPointerY = _dragPointerY; // Save it
      notifyListeners();
      // Debug: print position
      debugPrint('Drag Y: $_dragPointerY, Threshold: $_deleteZoneThreshold, InZone: $isInDeleteZone');
    }
  }

  // Handle drag end
  //
  // Returns true if item was deleted (should skip reorder)
  bool onDragEnded() {
    // Use the LAST known position since current might have been reset
    final shouldDelete = _draggingItem != null && _lastDragPointerY < _deleteZoneThreshold;
    final gridSizeBefore = gridProvider.items.length;

    debugPrint('Drag ended - Last Y: $_lastDragPointerY, Current Y: $_dragPointerY, InZone: $isInDeleteZone, Should delete: $shouldDelete, Grid size before: $gridSizeBefore');

    if (shouldDelete) {
      _deleteItem();
      final gridSizeAfter = gridProvider.items.length;
      debugPrint('Grid size after delete: $gridSizeAfter');
    }

    _draggingItem = null;
    _dragPointerY = double.infinity;
    _lastDragPointerY = double.infinity;
    notifyListeners();

    debugPrint('Returning shouldDelete=$shouldDelete to skip reorder');
    // Return whether we deleted to signal reorder should be skipped
    return shouldDelete;
  }

  // Delete the currently dragging item
  void _deleteItem() {
    if (_draggingItem != null) {
      final itemToDelete = _draggingItem!;
      debugPrint('Deleting item: ${itemToDelete.id}');

      // Remove item from grid
      gridProvider.removeColor(itemToDelete.id);

      // Clean up trailing empty rows after deletion
      gridProvider.cleanupEmptyRows(settingsProvider.responsiveColumnCount);

      coordinator.saveState('Deleted ${itemToDelete.name ?? "color"} via drag');
    }
  }

}
