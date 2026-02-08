import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../custom_reorderable_grid/reorderable_grid_view.dart';
import '../../models/color_grid_item.dart';
import '../../state/color_grid_provider.dart';
import '../../state/settings_provider.dart';
import '../../utils/ui_color_utils.dart';
import '../../utils/color_operations.dart';
import 'color_item_widget.dart';

// A reorderable grid view for displaying and managing color grids
//
// Features:
// - Drag and drop reordering
// - Add/remove colors
// - Selection management
// - Responsive grid layout
// - Empty state handling
//
// Uses GridProvider for accessing the color grid items.
class ReorderableColorGridView extends StatefulWidget {
  // Grid layout constants - single source of truth
  static const double defaultSpacing = 8.0;
  static const double horizontalPadding = 8.0;
  static const double topPadding = 0.0;
  static const double bottomPadding = 12.0;
  static const double verticalPadding = topPadding + bottomPadding; // Total: 12.0

  // Callback when items are reordered
  final Function(int oldIndex, int newIndex) onReorder;
  
  // Callback when an item is tapped
  final Function(ColorGridItem) onItemTap;

  // Callback when an empty slot is tapped
  final Function(ColorGridItem)? onEmptySlotTap;

  // Callback when an item is long pressed
  final Function(ColorGridItem) onItemLongPress;

  // Callback when an item should be deleted
  final Function(ColorGridItem) onItemDelete;

  // Callback when add button is pressed
  final VoidCallback onAddColor;
  
  // Callback when drag starts (for showing delete zone)
  final Function(ColorGridItem)? onDragStarted;
  
  // Callback when drag ends (for hiding delete zone)
  // Returns true if item was deleted, false otherwise
  final bool Function()? onDragEnded;
  
  // Number of columns in the grid (used by responsive layout mode)
  final int crossAxisCount;

  // Spacing between grid items (defaults to defaultSpacing constant)
  final double spacing;

  // Width of each color item (used for fixed size grid calculation)
  final double itemWidth;

  // Height of each color item (used for fixed height mode - default 140px)
  final double itemHeight;
  
  // Whether to show the add button
  final bool showAddButton;
  
  // Empty state message
  final String emptyStateMessage;

  // Optional color filter for display (e.g., ICC profile filtering)
  // Takes the grid item and returns the display color
  final Color Function(ColorGridItem)? colorFilter;

  // Grid layout mode
  final GridLayoutMode layoutMode;

  // Box height mode
  final BoxHeightMode heightMode;

  // Available height for fillContainer mode (optional, calculated from screen - header - sheet)
  final double? availableHeight;

  // Background color for determining text/icon colors
  final Color bgColor;

  // Row modifier for dynamic resizing (used in fillContainer mode)
  final double? rowModifier;

  const ReorderableColorGridView({
    super.key,
    required this.onReorder,
    required this.onItemTap,
    this.onEmptySlotTap,
    required this.onItemLongPress,
    required this.onItemDelete,
    required this.onAddColor,
    this.onDragStarted,
    this.onDragEnded,
    this.crossAxisCount = 4,
    this.spacing = defaultSpacing,
    this.itemWidth = 70.0,
    this.itemHeight = 140.0,
    this.showAddButton = true,
    this.emptyStateMessage = 'No colors in grid\nTap + to add your first color',
    this.colorFilter,
    this.layoutMode = GridLayoutMode.responsive,
    this.heightMode = BoxHeightMode.proportional,
    this.availableHeight,
    required this.bgColor,
    this.rowModifier,
  });
  
  @override
  State<ReorderableColorGridView> createState() => _ReorderableColorGridViewState();
}

class _ReorderableColorGridViewState extends State<ReorderableColorGridView> {
  @override
  Widget build(BuildContext context) {
    // Get items from GridProvider
    final items = context.watch<ColorGridProvider>().items;

    if (items.isEmpty) {
      return _buildEmptyState();
    }

    return _buildGridView(items);
  }
  
  // Build the main grid view with drag-and-drop support
  Widget _buildGridView(List<ColorGridItem> items) {
    return switch (widget.layoutMode) {
      GridLayoutMode.responsive => _buildResponsiveGrid(items),
      GridLayoutMode.fixedSize => _buildFixedSizeGrid(items),
    };
  }

  // Calculate how many add buttons to render in footer
  // Returns 1 by default, or all at once when dragging
  int _calculateAddButtonCount({
    required int colorCount,
    required int columns,
  }) {
    if (widget.heightMode != BoxHeightMode.fillContainer) {
      return 1; // Only show multiple buttons in fillContainer mode
    }

    final modifier = widget.rowModifier ?? 0.0;
    if (modifier <= 0) {
      return 1; // At rest, show only 1 add button
    }

    // When dragging (modifier > 0), show all possible add buttons for max revealed rows
    final totalItems = colorCount + 1; // colors + 1 add button
    final rows = (totalItems / columns).ceil();
    final isAddButtonAloneOnLastRow = colorCount % columns == 0;

    final rowsForHeight = isAddButtonAloneOnLastRow
        ? (rows - 1).clamp(1, rows)
        : rows;

    // Use maximum effective rows to show all add buttons at once
    final maxEffectiveRows = rowsForHeight.toDouble() + 1.0;
    final totalSlots = (maxEffectiveRows * columns).ceil();
    final emptySlots = totalSlots - colorCount;

    // Render one add button per empty slot (minimum 1)
    return emptySlots.clamp(1, totalSlots);
  }

  // Calculate aspect ratio based on height mode
  double _calculateAspectRatio({
    required double boxWidth,
    required double availableHeight,
    required int totalItems,
    required int columns,
    required int colorCount,
  }) {
    switch (widget.heightMode) {
      case BoxHeightMode.proportional:
        return 1.0; // Square boxes (width = height)

      case BoxHeightMode.fillContainer:
        // Calculate base rows using stable color count + 1 add button
        // This ensures rows doesn't jump when dragging reveals more add buttons
        final baseRows = ((colorCount + 1) / columns).ceil();
        if (baseRows <= 0) return 1.0;

        // Detect if add button is alone on last row based on COLOR items only
        // This ensures consistent sizing even when multiple add buttons appear
        final isAddButtonAloneOnLastRow = colorCount % columns == 0;

        // Use conditional sizing based on last row contents:
        // - If add button is alone: use (baseRows - 1) for larger boxes (keeps add button hidden)
        // - If add button shares row with colors: use baseRows exactly to fit all actual content on screen
        final rowsForHeight = isAddButtonAloneOnLastRow
            ? (baseRows - 1).clamp(1, baseRows)
            : baseRows;

        // Apply row modifier for dynamic resizing effect
        // Drag down (positive modifier) = more rows = smaller boxes
        // Drag up (negative from rest) should make boxes even larger
        // Allow up to 1 extra row beyond starting position for drag-to-add UX
        final modifier = widget.rowModifier ?? 0.0;
        final maxEffectiveRows = rowsForHeight.toDouble() + 1.0;
        final effectiveRowsForHeight = (rowsForHeight.toDouble() + modifier).clamp(1.0, maxEffectiveRows);

        // Calculate height per row to fill container
        // Note: spacing comes from item padding, not mainAxisSpacing (which is 0)
        final boxHeight = availableHeight / effectiveRowsForHeight;

        // Guard against invalid values - fallback to proportional if calculations fail
        if (boxHeight <= 0 || boxWidth <= 0 || !boxHeight.isFinite || !availableHeight.isFinite) {
          return 1.0;
        }

        return boxWidth / boxHeight;

      case BoxHeightMode.fixed:
        return boxWidth / widget.itemHeight; // Fixed height = itemHeight
    }
  }

  // Build grid with fixed box sizes
  // Uses LayoutBuilder to calculate how many columns fit at the specified itemWidth
  Widget _buildFixedSizeGrid(List<ColorGridItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate how many columns can fit based on itemWidth
        final availableWidth = constraints.maxWidth;
        final columnWidth = widget.itemWidth + widget.spacing;
        final calculatedColumns = (availableWidth / columnWidth).floor().clamp(1, 10);
        final boxWidth = (availableWidth - (calculatedColumns - 1) * widget.spacing) / calculatedColumns;

        // Use provided availableHeight if given, otherwise use constraints
        // Note: Subtract 16 (8px top + 8px bottom padding) from provided height
        final heightForCalculation = widget.availableHeight != null
            ? widget.availableHeight!
            : constraints.maxHeight;

        // Calculate how many add buttons to show
        final addButtonCount = widget.showAddButton
            ? _calculateAddButtonCount(colorCount: items.length, columns: calculatedColumns)
            : 0;

        final aspectRatio = _calculateAspectRatio(
          boxWidth: boxWidth,
          availableHeight: heightForCalculation,
          totalItems: items.length + addButtonCount,
          columns: calculatedColumns,
          colorCount: items.length,
        );

        // Build all children: color items (or empty slots) + add buttons
        final allChildren = <Widget>[
          ...items.map((item) => item.isEmpty ? _buildEmptySlot(item) : _buildColorItem(item, calculatedColumns)),
          ...List.generate(addButtonCount, (index) => _buildAddButton(index, false)),
        ];

        return Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 0),
          child: ReorderableGridView.count(
            crossAxisCount: calculatedColumns,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            childAspectRatio: aspectRatio,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            dragStartDelay: const Duration(milliseconds: 200),
            restrictDragScope: false,
            onReorder: _handleReorder,
            dragWidgetBuilderV2: _buildDragWidget(items),
            children: allChildren,
          ),
        );
      },
    );
  }

  // Build grid with responsive sizing using count
  Widget _buildResponsiveGrid(List<ColorGridItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final boxWidth = (availableWidth - (widget.crossAxisCount - 1) * widget.spacing) / widget.crossAxisCount;

        // Use provided availableHeight directly when given, otherwise use constraints minus padding
        final heightForCalculation = widget.availableHeight ?? (constraints.maxHeight);

        // Calculate how many add buttons to show
        final addButtonCount = widget.showAddButton
            ? _calculateAddButtonCount(colorCount: items.length, columns: widget.crossAxisCount)
            : 0;

        final aspectRatio = _calculateAspectRatio(
          boxWidth: boxWidth,
          availableHeight: heightForCalculation,
          totalItems: items.length + addButtonCount,
          columns: widget.crossAxisCount,
          colorCount: items.length,
        );

        // Build all children: color items (or empty slots) + add buttons
        final allChildren = <Widget>[
          ...items.map((item) => item.isEmpty ? _buildEmptySlot(item) : _buildColorItem(item, widget.crossAxisCount)),
          ...List.generate(addButtonCount, (index) => _buildAddButton(index, false)),
        ];

        return Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 0),
          child: ReorderableGridView.count(
            crossAxisCount: widget.crossAxisCount,
            crossAxisSpacing: 0,
            mainAxisSpacing: 0,
            childAspectRatio: aspectRatio,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            dragStartDelay: const Duration(milliseconds: 200),
            restrictDragScope: false,
            onReorder: _handleReorder,
            dragWidgetBuilderV2: _buildDragWidget(items),
            children: allChildren,
          ),
        );
      },
    );
  }

  // Handle reorder callback
  void _handleReorder(int oldIndex, int newIndex) {
    debugPrint('REORDER: _handleReorder called - oldIndex=$oldIndex, newIndex=$newIndex');

    // Get the number of actual items (color items + empty slots, not including add buttons)
    final gridProvider = context.read<ColorGridProvider>();
    final items = gridProvider.items;
    final itemCount = items.length;

    // Call the drag ended callback before reordering
    final wasDeleted = widget.onDragEnded?.call() ?? false;
    debugPrint('REORDER: wasDeleted=$wasDeleted');

    // Only perform operations if item wasn't deleted
    if (!wasDeleted) {
      // Check if dragging to add button position (newIndex >= itemCount)
      if (oldIndex < itemCount && newIndex >= itemCount) {
        // Dragging a color/empty slot to add button position
        // Create an empty slot at the old position
        final draggedItem = items[oldIndex];
        if (!draggedItem.isEmpty) {
          debugPrint('REORDER: Dragging color to add button position - creating empty slot at $oldIndex');
          gridProvider.addEmptySlot(index: oldIndex);
        } else {
          debugPrint('REORDER: Dragging empty slot to add button position - no action needed');
        }
      } else if (oldIndex < itemCount && newIndex < itemCount) {
        // Normal reorder within grid items (both colors and empty slots)
        debugPrint('REORDER: Calling widget.onReorder($oldIndex, $newIndex)');
        widget.onReorder(oldIndex, newIndex);
      } else {
        debugPrint('REORDER: Skipping reorder - invalid indices (itemCount=$itemCount)');
      }
    } else {
      debugPrint('REORDER: Skipping reorder because item was deleted');
    }
  }

  // Build drag widget
  DragWidgetBuilderV2 _buildDragWidget(List<ColorGridItem> items) {
    return DragWidgetBuilderV2(
      builder: (index, child, screenshot) {
        // Notify that drag has started
        if (widget.onDragStarted != null && index < items.length) {
          // Use post-frame callback to avoid calling setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onDragStarted!(items[index]);
          });
        }

        // Use the child directly for smooth dragging experience
        return Transform.scale(
          scale: 1.1,
          child: Opacity(
            opacity: 0.9,
            child: child,
          ),
        );
      },
    );
  }

  // Build a single color item
  Widget _buildColorItem(ColorGridItem item, int columnCount) {
    final gridProvider = context.read<ColorGridProvider>();

    // Precalculate interpolated preview color for duplicate action
    final interpolatedPreview = _calculateInterpolatedPreview(item, gridProvider.items);

    return ColorItemWidget(
      key: ValueKey(item.id),
      item: item,
      displayColor: widget.colorFilter != null ? widget.colorFilter!(item) : null,
      interpolatedPreviewColor: interpolatedPreview,
      size: widget.itemWidth,
      onTap: () => widget.onItemTap(item),
      onLongPress: () => widget.onItemLongPress(item),
      onDelete: () => widget.onItemDelete(item),
      onToggleLock: () => gridProvider.toggleLock(item.id),
      onDragToDeleteStart: widget.onDragStarted != null
          ? () => widget.onDragStarted!(item)
          : null,
      onDragToDeleteEnd: widget.onDragEnded,
      onAddInterpolated: interpolatedPreview != null
          ? () => gridProvider.addInterpolatedColor(item.id, interpolatedPreview)
          : () => gridProvider.duplicateColorExact(item.id), // Fallback if no preview
      onDuplicate: () => gridProvider.duplicateColorExact(item.id),
      onEdit: () {
        // Edit action: Select the item for editing
        widget.onItemTap(item);
      },
      layoutMode: widget.layoutMode,
      crossAxisCount: columnCount,
    );
  }

  // Calculate the interpolated preview color (50-50 between current and item below)
  Color? _calculateInterpolatedPreview(ColorGridItem item, List<ColorGridItem> items) {
    final itemIndex = items.indexWhere((i) => i.id == item.id);

    // Not found - no preview
    if (itemIndex == -1) return null;

    // Last item - return its own color
    if (itemIndex == items.length - 1) return item.color;

    // Get item below
    final itemBelow = items[itemIndex + 1];

    // Check if both items have valid OKLCH values
    if (item.oklchValues == null || itemBelow.oklchValues == null) return null;

    // Interpolate 50-50 between current item and item below
    final currentOklch = item.oklchValues!;
    final belowOklch = itemBelow.oklchValues!;
    const t = 0.5; // 50-50 mix

    // Interpolate each OKLCH component
    final l = currentOklch.lightness + (belowOklch.lightness - currentOklch.lightness) * t;
    final c = currentOklch.chroma + (belowOklch.chroma - currentOklch.chroma) * t;
    final a = currentOklch.alpha + (belowOklch.alpha - currentOklch.alpha) * t;

    // Interpolate hue with wraparound (shortest path)
    double h1 = currentOklch.hue % 360;
    double h2 = belowOklch.hue % 360;
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

    // Convert to color
    return colorFromOklch(l, c, h, a);
  }

  // Build an empty slot
  Widget _buildEmptySlot(ColorGridItem item) {
    // Get appropriate color based on background
    final iconColor = getTextColor(widget.bgColor);

    return Padding(
      key: ValueKey(item.id),
      padding: const EdgeInsets.all(4.0),
      child: GestureDetector(
        onTap: widget.onEmptySlotTap != null ? () => widget.onEmptySlotTap!(item) : null,
        onLongPress: () {}, // Block long press to prevent drag from starting
        child: Container(
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.3),
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Icon(
            Icons.add,
            color: iconColor.withValues(alpha: 0.7),
            size: 32,
          ),
        ),
      ),
    );
  }

  // Build the add button
  Widget _buildAddButton([int index = 0, bool isDraggable = true]) {
    // Get appropriate color based on background
    final iconColor = getTextColor(widget.bgColor);

    final button = Container(
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Icon(
        Icons.add,
        color: iconColor.withValues(alpha: 0.7),
        size: 32,
      ),
    );

    // If not draggable, absorb long press gestures to prevent drag initiation
    // but still allow tap and allow being a reorder target
    final content = isDraggable
        ? button
        : GestureDetector(
            onLongPress: () {}, // Absorb long press to prevent drag
            child: button,
          );

    return Padding(
      key: ValueKey('add_button_$index'),
      padding: const EdgeInsets.all(4.0),
      child: GestureDetector(
        onTap: widget.onAddColor,
        child: content,
      ),
    );
  }
  
  // Build empty state when no colors are present
  Widget _buildEmptyState() {
    // Get appropriate color based on background
    final textColor = getTextColor(widget.bgColor);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.palette_outlined,
            size: 64,
            color: textColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            widget.emptyStateMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onAddColor,
            icon: const Icon(Icons.add),
            label: const Text('Add Color'),
            style: ElevatedButton.styleFrom(
              backgroundColor: textColor.withValues(alpha: 0.2),
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}