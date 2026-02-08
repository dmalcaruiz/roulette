import 'package:flutter/material.dart';
import '../models/color_grid_item.dart';
import 'color_operations.dart';

// Manages color grid operations
// 
// Handles:
// - Adding/removing colors
// - Reordering items
// - Selection management
// - Validation
class ColorGridManager {
  // Add a new color to the grid
  static List<ColorGridItem> addColor({
    required List<ColorGridItem> currentGrid,
    required Color color,
    String? name,
    bool selectNew = true,
  }) {
    // Deselect all if we're selecting the new one
    final updatedGrid = selectNew
        ? currentGrid.map((item) => item.copyWith(isSelected: false)).toList()
        : List<ColorGridItem>.from(currentGrid);
    
    // Create and add new item
    final newItem = ColorGridItem.fromColor(color, name: name)
        .copyWith(isSelected: selectNew);
    
    updatedGrid.add(newItem);
    
    return updatedGrid;
  }
  
  // Remove a color from the grid
  static List<ColorGridItem> removeColor({
    required List<ColorGridItem> currentGrid,
    required String itemId,
  }) {
    return currentGrid.where((item) => item.id != itemId).toList();
  }
  
  // Reorder items in the grid
  static List<ColorGridItem> reorderItems({
    required List<ColorGridItem> currentGrid,
    required int oldIndex,
    required int newIndex,
  }) {
    debugPrint('REORDER: ColorGridManager.reorderItems - oldIndex=$oldIndex, newIndex=$newIndex, gridLength=${currentGrid.length}');

    final grid = List<ColorGridItem>.from(currentGrid);
    debugPrint('REORDER: Order before: ${grid.map((e) => e.name).join(", ")}');

    final item = grid.removeAt(oldIndex);
    debugPrint('REORDER: Removed item "${item.name}" (id: ${item.id}) from index $oldIndex');

    grid.insert(newIndex, item);
    debugPrint('REORDER: Inserted item "${item.name}" at index $newIndex');
    debugPrint('REORDER: Order after: ${grid.map((e) => e.name).join(", ")}');

    return grid;
  }
  
  // Select a specific item (deselects all others)
  static List<ColorGridItem> selectItem({
    required List<ColorGridItem> currentGrid,
    required String itemId,
  }) {
    return currentGrid.map((item) => 
      item.copyWith(isSelected: item.id == itemId)
    ).toList();
  }
  
  // Deselect all items
  static List<ColorGridItem> deselectAll({
    required List<ColorGridItem> currentGrid,
  }) {
    return currentGrid.map((item) => 
      item.copyWith(isSelected: false)
    ).toList();
  }
  
  // Update color of a specific item (from sRGB Color)
  static List<ColorGridItem> updateItemColor({
    required List<ColorGridItem> currentGrid,
    required String itemId,
    required Color color,
  }) {
    // Convert to OKLCH - this is the source of truth
    final oklch = srgbToOklch(color);
    final oklchValues = OklchValues(
      lightness: oklch.l,
      chroma: oklch.c,
      hue: oklch.h,
      alpha: oklch.alpha,
    );

    return currentGrid.map((item) {
      if (item.id == itemId) {
        return item.copyWith(
          color: color,
          oklchValues: oklchValues,
          lastModified: DateTime.now(),
          isSelected: item.isSelected, // Preserve selection
        );
      }
      return item;
    }).toList();
  }

  // Update color of a specific item (from OKLCH values - preferred)
  static List<ColorGridItem> updateItemOklch({
    required List<ColorGridItem> currentGrid,
    required String itemId,
    required double lightness,
    required double chroma,
    required double hue,
    double alpha = 1.0,
  }) {
    final oklchValues = OklchValues(
      lightness: lightness,
      chroma: chroma,
      hue: hue,
      alpha: alpha,
    );

    // Convert to Color for display
    final color = colorFromOklch(lightness, chroma, hue, alpha);

    return currentGrid.map((item) {
      if (item.id == itemId) {
        return item.copyWith(
          color: color,
          oklchValues: oklchValues,
          lastModified: DateTime.now(),
          isSelected: item.isSelected, // Preserve selection
        );
      }
      return item;
    }).toList();
  }
  
  // Get the currently selected item
  static ColorGridItem? getSelectedItem(List<ColorGridItem> grid) {
    try {
      return grid.firstWhere((item) => item.isSelected);
    } catch (e) {
      return null;
    }
  }
  
  // Get item by ID
  static ColorGridItem? getItemById({
    required List<ColorGridItem> grid,
    required String itemId,
  }) {
    try {
      return grid.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }
  
  // Check if an item is selected
  static bool hasSelection(List<ColorGridItem> grid) {
    return grid.any((item) => item.isSelected);
  }
  
  // Get index of item by ID
  static int getIndexById({
    required List<ColorGridItem> grid,
    required String itemId,
  }) {
    return grid.indexWhere((item) => item.id == itemId);
  }
  
  // Validate grid doesn't have duplicate IDs
  static bool validateNoDuplicateIds(List<ColorGridItem> grid) {
    final ids = grid.map((item) => item.id).toSet();
    return ids.length == grid.length;
  }
  
  // Ensure only one item is selected (fix inconsistent state)
  static List<ColorGridItem> ensureSingleSelection({
    required List<ColorGridItem> currentGrid,
  }) {
    final selectedItems = currentGrid.where((item) => item.isSelected).toList();

    if (selectedItems.length <= 1) {
      return currentGrid; // Already consistent
    }

    // Keep only the first selected item
    final firstSelectedId = selectedItems.first.id;
    return currentGrid.map((item) =>
      item.copyWith(isSelected: item.id == firstSelectedId)
    ).toList();
  }

  // Add an empty slot to the grid
  static List<ColorGridItem> addEmptySlot({
    required List<ColorGridItem> currentGrid,
    int? index,
  }) {
    final grid = List<ColorGridItem>.from(currentGrid);
    final emptySlot = ColorGridItem.empty();

    if (index == null || index >= grid.length) {
      grid.add(emptySlot);
    } else {
      grid.insert(index, emptySlot);
    }

    return grid;
  }

  // Replace an empty slot with a color
  static List<ColorGridItem> replaceEmptySlot({
    required List<ColorGridItem> currentGrid,
    required String slotId,
    required Color color,
    String? name,
    bool selectNew = true,
  }) {
    // Deselect all if we're selecting the new one
    final grid = selectNew
        ? currentGrid.map((item) => item.copyWith(isSelected: false)).toList()
        : List<ColorGridItem>.from(currentGrid);

    // Find the empty slot and replace it with a color
    final index = grid.indexWhere((item) => item.id == slotId);
    if (index == -1) {
      debugPrint('WARNING: Empty slot with id $slotId not found');
      return currentGrid;
    }

    final item = grid[index];
    if (!item.isEmpty) {
      debugPrint('WARNING: Item with id $slotId is not an empty slot');
      return currentGrid;
    }

    // Create new color item and replace the empty slot
    final newItem = ColorGridItem.fromColor(color, name: name)
        .copyWith(isSelected: selectNew);
    grid[index] = newItem;

    return grid;
  }

  // Clean up empty rows
  // Removes:
  // 1. All trailing empty slots after the last color
  // 2. Complete rows where ALL boxes are empty (even in the middle)
  static List<ColorGridItem> cleanupTrailingEmptyRows({
    required List<ColorGridItem> currentGrid,
    required int columns,
  }) {
    debugPrint('CLEANUP: Called with ${currentGrid.length} items, $columns columns');

    if (currentGrid.isEmpty || columns <= 0) {
      debugPrint('CLEANUP: Early return - empty grid or invalid columns');
      return currentGrid;
    }

    var grid = List<ColorGridItem>.from(currentGrid);

    // Step 1: Remove trailing empty slots
    final lastColorIndex = grid.lastIndexWhere((item) => !item.isEmpty);
    debugPrint('CLEANUP: Last color index = $lastColorIndex, grid length = ${grid.length}');

    // If no colors exist, return empty grid
    if (lastColorIndex == -1) {
      debugPrint('CLEANUP: Removing all ${grid.length} items (no colors found)');
      return [];
    }

    if (lastColorIndex < grid.length - 1) {
      final itemsToRemove = grid.length - lastColorIndex - 1;
      debugPrint('CLEANUP: Removing $itemsToRemove trailing empty slots');
      grid = grid.sublist(0, lastColorIndex + 1);
    }

    // Step 2: Remove complete empty rows anywhere in the grid
    final totalRows = (grid.length / columns).ceil();
    List<ColorGridItem> cleanedGrid = [];
    int removedRows = 0;

    for (int row = 0; row < totalRows; row++) {
      final rowStart = row * columns;
      final rowEnd = (rowStart + columns).clamp(0, grid.length);
      final rowItems = grid.sublist(rowStart, rowEnd);

      // Only remove if it's a complete row (has exactly `columns` items) and all are empty
      final isCompleteRow = rowItems.length == columns;
      final isRowCompletelyEmpty = rowItems.every((item) => item.isEmpty);

      if (isCompleteRow && isRowCompletelyEmpty) {
        debugPrint('CLEANUP: Removing complete empty row $row (indices $rowStart-${rowEnd - 1})');
        removedRows++;
      } else {
        cleanedGrid.addAll(rowItems);
      }
    }

    if (removedRows > 0) {
      debugPrint('CLEANUP: Removed $removedRows complete empty row(s)');
    }

    debugPrint('CLEANUP: Final grid size: ${cleanedGrid.length} (was ${currentGrid.length})');
    return cleanedGrid;
  }

  // Get count of trailing empty slots (for debugging/UI)
  static int getTrailingEmptyCount(List<ColorGridItem> grid) {
    if (grid.isEmpty) return 0;

    int count = 0;
    for (int i = grid.length - 1; i >= 0; i--) {
      if (grid[i].isEmpty) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }
}