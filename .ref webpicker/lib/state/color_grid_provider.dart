import 'dart:math';
import 'package:flutter/material.dart';
import '../models/color_grid_item.dart';
import '../utils/color_grid_operations.dart';

// Provider for the color grid
//
// Manages the list of color items in the grid along with selection state.
// All grid operations (add, delete, reorder, select) go through this provider.
class ColorGridProvider extends ChangeNotifier {
  List<ColorGridItem> _items = [];

  // Getters
  List<ColorGridItem> get items => _items;
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  // Get the currently selected item (if any)
  ColorGridItem? get selectedItem => ColorGridManager.getSelectedItem(_items);

  // Get the ID of the selected item (if any)
  String? get selectedItemId => selectedItem?.id;

  // Check if there's a selected item
  bool get hasSelection => ColorGridManager.hasSelection(_items);

  // Add a new color to the grid
  void addColor(Color color, {String? name, bool selectNew = true}) {
    _items = ColorGridManager.addColor(
      currentGrid: _items,
      color: color,
      name: name,
      selectNew: selectNew,
    );
    notifyListeners();
  }

  // Remove a color from the grid by ID
  void removeColor(String itemId) {
    _items = ColorGridManager.removeColor(
      currentGrid: _items,
      itemId: itemId,
    );
    notifyListeners();
  }

  // Duplicate a color and insert it right before the original
  // If not the first item, creates a 50-50 interpolation with the item above
  void duplicateColor(String itemId) {
    final itemIndex = _items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) return;

    final originalItem = _items[itemIndex];
    if (originalItem.color == null || originalItem.oklchValues == null) return;

    ColorGridItem duplicateItem;

    // If first item (index 0), just duplicate as-is
    if (itemIndex == 0) {
      duplicateItem = ColorGridItem.fromColor(
        originalItem.color!,
        name: originalItem.name,
      );
    } else {
      // Get the item above (previous item)
      final itemAbove = _items[itemIndex - 1];
      if (itemAbove.color == null || itemAbove.oklchValues == null) {
        // If item above is empty, just duplicate as-is
        duplicateItem = ColorGridItem.fromColor(
          originalItem.color!,
          name: originalItem.name,
        );
      } else {
        // Interpolate 50-50 between item above and current item
        final aboveOklch = itemAbove.oklchValues!;
        final currentOklch = originalItem.oklchValues!;
        const t = 0.5; // 50-50 mix

        // Interpolate each OKLCH component
        final l = aboveOklch.lightness + (currentOklch.lightness - aboveOklch.lightness) * t;
        final c = aboveOklch.chroma + (currentOklch.chroma - aboveOklch.chroma) * t;
        final a = aboveOklch.alpha + (currentOklch.alpha - aboveOklch.alpha) * t;

        // Interpolate hue with wraparound (shortest path)
        double h1 = aboveOklch.hue % 360;
        double h2 = currentOklch.hue % 360;
        if (h1 < 0) h1 += 360;
        if (h2 < 0) h2 += 360;

        double diff = h2 - h1;
        if (diff > 180) {
          diff -= 360;
        } else if (diff < -180) {
          diff += 360;
        }

        double h = h1 + diff * t;
        if (h < 0) h += 360;
        if (h >= 360) h -= 360;

        // Create duplicate with interpolated OKLCH values
        duplicateItem = ColorGridItem.fromOklch(
          lightness: l,
          chroma: c,
          hue: h,
          alpha: a,
          name: originalItem.name,
        );
      }
    }

    // Insert right before the original
    _items.insert(itemIndex, duplicateItem);
    notifyListeners();
  }

  // Duplicate a color exactly (no interpolation) and insert it right before the original
  void duplicateColorExact(String itemId) {
    final itemIndex = _items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) return;

    final originalItem = _items[itemIndex];
    if (originalItem.color == null) return;

    // Create exact duplicate with a new ID
    final duplicateItem = ColorGridItem.fromColor(
      originalItem.color!,
      name: originalItem.name,
    );

    // Insert right before the original
    _items.insert(itemIndex, duplicateItem);
    notifyListeners();
  }

  // Add an interpolated color (precalculated) after the specified item
  void addInterpolatedColor(String itemId, Color interpolatedColor) {
    final itemIndex = _items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1) return;

    final originalItem = _items[itemIndex];

    // Create item from precalculated color (no recalculation needed!)
    final newItem = ColorGridItem.fromColor(
      interpolatedColor,
      name: originalItem.name,
    );

    // Insert right after the original
    _items.insert(itemIndex + 1, newItem);
    notifyListeners();
  }

  // Reorder items in the grid
  void reorderItems(int oldIndex, int newIndex) {
    debugPrint('REORDER: ColorGridProvider.reorderItems called - oldIndex=$oldIndex, newIndex=$newIndex');
    debugPrint('REORDER: Grid size before: ${_items.length}');
    if (oldIndex < _items.length && newIndex <= _items.length) {
      debugPrint('REORDER: Moving item "${_items[oldIndex].name}" (id: ${_items[oldIndex].id}) from $oldIndex to $newIndex');
    }

    _items = ColorGridManager.reorderItems(
      currentGrid: _items,
      oldIndex: oldIndex,
      newIndex: newIndex,
    );

    debugPrint('REORDER: Grid size after: ${_items.length}');
    debugPrint('REORDER: New order: ${_items.map((e) => e.name).join(", ")}');
    notifyListeners();
  }

  // Select a specific item (deselects all others)
  void selectItem(String itemId) {
    _items = ColorGridManager.selectItem(
      currentGrid: _items,
      itemId: itemId,
    );
    notifyListeners();
  }

  // Deselect all items
  void deselectAll() {
    _items = ColorGridManager.deselectAll(
      currentGrid: _items,
    );
    notifyListeners();
  }

  // Toggle lock state of an item
  void toggleLock(String itemId) {
    _items = _items.map((item) {
      if (item.id == itemId) {
        return item.copyWith(isLocked: !item.isLocked);
      }
      return item;
    }).toList();
    notifyListeners();
  }

  // Update the OKLCH values of a specific item
  void updateItemOklch({
    required String itemId,
    required double lightness,
    required double chroma,
    required double hue,
    double? alpha,
  }) {
    _items = ColorGridManager.updateItemOklch(
      currentGrid: _items,
      itemId: itemId,
      lightness: lightness,
      chroma: chroma,
      hue: hue,
      alpha: alpha ?? 1.0,
    );
    notifyListeners();
  }

  // Update the color of a specific item (from Color)
  void updateItemColor({
    required String itemId,
    required Color color,
  }) {
    _items = ColorGridManager.updateItemColor(
      currentGrid: _items,
      itemId: itemId,
      color: color,
    );
    notifyListeners();
  }

  // Get item by ID
  ColorGridItem? getItemById(String itemId) {
    return ColorGridManager.getItemById(
      grid: _items,
      itemId: itemId,
    );
  }

  // Sync from snapshot (for undo/redo) - replaces entire grid
  void syncFromSnapshot(List<ColorGridItem> snapshot) {
    // Only notify if the grid actually changed
    if (_items != snapshot) {
      _items = List<ColorGridItem>.from(snapshot);
      notifyListeners();
    }
  }

  // Replace entire grid (used during restore/load operations)
  void setGrid(List<ColorGridItem> newGrid) {
    _items = List<ColorGridItem>.from(newGrid);
    notifyListeners();
  }

  // Clear the entire grid
  void clear() {
    if (_items.isNotEmpty) {
      _items = [];
      notifyListeners();
    }
  }

  // Randomize colors for all grid items
  void randomizeAllColors() {
    final random = Random();
    _items = _items.map((item) {
      // Skip locked items and empty slots
      if (item.isLocked || item.isEmpty) {
        return item;
      }

      // Generate random OKLCH values
      // Lightness: 0.3 to 0.9 (avoid very dark and very light colors)
      final lightness = 0.3 + random.nextDouble() * 0.6;
      // Chroma: 0 to 0.37 (full gamut range)
      final chroma = random.nextDouble() * 0.37;
      // Hue: 0 to 360 degrees
      final hue = random.nextDouble() * 360;

      // Create new item with randomized OKLCH values
      final newItem = ColorGridItem.fromOklch(
        lightness: lightness,
        chroma: chroma,
        hue: hue,
        alpha: item.oklchValues!.alpha, // Preserve alpha
        name: item.name, // Preserve name
      );

      // Preserve selection state, lock state, and ID
      return newItem.copyWith(
        id: item.id, // Keep the same ID
        isSelected: item.isSelected, // Keep selection state
        isLocked: item.isLocked, // Keep lock state
      );
    }).toList();

    notifyListeners();
  }

  // Add an empty slot to the grid
  void addEmptySlot({int? index}) {
    _items = ColorGridManager.addEmptySlot(
      currentGrid: _items,
      index: index,
    );
    notifyListeners();
  }

  // Replace an empty slot with a color
  void replaceEmptySlot({
    required String slotId,
    required Color color,
    String? name,
    bool selectNew = true,
  }) {
    _items = ColorGridManager.replaceEmptySlot(
      currentGrid: _items,
      slotId: slotId,
      color: color,
      name: name,
      selectNew: selectNew,
    );
    notifyListeners();
  }

  // Clean up trailing empty rows
  void cleanupEmptyRows(int columns) {
    final originalLength = _items.length;
    _items = ColorGridManager.cleanupTrailingEmptyRows(
      currentGrid: _items,
      columns: columns,
    );

    // Only notify if something was actually removed
    if (_items.length != originalLength) {
      notifyListeners();
    }
  }

  // Get count of trailing empty slots (for debugging/UI)
  int get trailingEmptyCount => ColorGridManager.getTrailingEmptyCount(_items);
}
