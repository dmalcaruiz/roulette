import 'color_grid_item.dart';

// Encapsulates the complete color grid state
// 
// Immutable state object that can be easily snapshotted for undo/redo
class ColorGridState {
  // List of all grid items
  final List<ColorGridItem> items;
  
  // ID of the currently selected item (if any)
  final String? selectedItemId;
  
  const ColorGridState({
    required this.items,
    this.selectedItemId,
  });
  
  // Create an empty grid state
  factory ColorGridState.empty() {
    return const ColorGridState(items: []);
  }
  
  // Create from a list of items
  factory ColorGridState.fromItems(List<ColorGridItem> items) {
    final selectedItem = items.where((item) => item.isSelected).firstOrNull;
    return ColorGridState(
      items: items,
      selectedItemId: selectedItem?.id,
    );
  }
  
  // Get the selected item
  ColorGridItem? get selectedItem {
    if (selectedItemId == null) return null;
    try {
      return items.firstWhere((item) => item.id == selectedItemId);
    } catch (e) {
      return null;
    }
  }
  
  // Check if there's a selection
  bool get hasSelection => selectedItemId != null;
  
  // Get the number of items
  int get itemCount => items.length;
  
  // Check if grid is empty
  bool get isEmpty => items.isEmpty;
  
  // Check if grid is not empty
  bool get isNotEmpty => items.isNotEmpty;
  
  // Create a copy with updated values
  ColorGridState copyWith({
    List<ColorGridItem>? items,
    String? selectedItemId,
    bool clearSelection = false,
  }) {
    return ColorGridState(
      items: items ?? this.items,
      selectedItemId: clearSelection ? null : (selectedItemId ?? this.selectedItemId),
    );
  }
  
  // Create a copy with a new list of items
  ColorGridState withItems(List<ColorGridItem> items) {
    // Automatically update selectedItemId based on items
    final selectedItem = items.where((item) => item.isSelected).firstOrNull;
    return ColorGridState(
      items: items,
      selectedItemId: selectedItem?.id,
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ColorGridState) return false;
    
    return other.selectedItemId == selectedItemId &&
           other.items.length == items.length &&
           _listsEqual(other.items, items);
  }
  
  bool _listsEqual(List<ColorGridItem> a, List<ColorGridItem> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
  
  @override
  int get hashCode => Object.hash(
    selectedItemId,
    items.length,
    items.isEmpty ? 0 : items.first.id,
  );
  
  @override
  String toString() {
    return 'ColorGridState(items: ${items.length}, selectedId: $selectedItemId)';
  }
}

// Extension for null safety
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}

