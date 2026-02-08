import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../models/color_grid_item.dart';
import '../../utils/ui_color_utils.dart';
import '../../state/settings_provider.dart';
import '../common/swipeable_action_cell.dart';

// Individual color item widget for the reorderable grid
//
// Features:
// - Color preview with hex code
// - Drag handle for reordering
// - Selection state indication
// - Tap to select/edit
// - Long press for context menu
class ColorItemWidget extends StatelessWidget {
  // The color grid item to display
  final ColorGridItem item;

  // Optional display color (e.g., ICC filtered)
  // If provided, this is used instead of item.color for display only
  final Color? displayColor;

  // Optional interpolated preview color for duplicate action
  // Shows the result of 50-50 interpolation with item above
  final Color? interpolatedPreviewColor;

  // Callback when this item is tapped
  final VoidCallback? onTap;

  // Callback when this item is long pressed
  final VoidCallback? onLongPress;

  // Callback when this item should be deleted
  final VoidCallback? onDelete;

  // Callback when lock icon is tapped
  final VoidCallback? onToggleLock;

  // Callback when drag to delete starts
  final VoidCallback? onDragToDeleteStart;

  // Callback when drag to delete ends
  // Returns true if deleted, false otherwise
  final bool Function()? onDragToDeleteEnd;

  // Callback when add interpolated action is triggered
  final VoidCallback? onAddInterpolated;

  // Callback when duplicate action is triggered
  final VoidCallback? onDuplicate;

  // Callback when edit action is triggered
  final VoidCallback? onEdit;

  // Whether this item is currently being dragged
  final bool isDragging;

  // Size of the color item
  final double size;

  // Whether to show the drag handle
  final bool showDragHandle;

  // Grid layout mode (for lock button positioning)
  final GridLayoutMode layoutMode;

  // Number of columns (for lock button positioning)
  final int crossAxisCount;

  const ColorItemWidget({
    super.key,
    required this.item,
    this.displayColor,
    this.interpolatedPreviewColor,
    this.onTap,
    this.onLongPress,
    this.onDelete,
    this.onToggleLock,
    this.onDragToDeleteStart,
    this.onDragToDeleteEnd,
    this.onAddInterpolated,
    this.onDuplicate,
    this.onEdit,
    this.isDragging = false,
    this.size = 80.0,
    this.showDragHandle = true,
    this.layoutMode = GridLayoutMode.responsive,
    this.crossAxisCount = 1,
  });
  
  @override
  Widget build(BuildContext context) {
    final bgColor = displayColor ?? item.color!;

    final colorWidget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: isDragging
            ? (Matrix4.identity()..scale(1.05))
            : Matrix4.identity(),
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.isSelected ? Colors.black : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: isDragging ? 8 : 0,
                  offset: Offset(0, isDragging ? 4 : 0),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Main color content
                _buildColorContent(),

                // Drag handle
                if (showDragHandle) _buildDragHandle(),

                // Selection indicator
                if (item.isSelected) _buildSelectionIndicator(),

                // Lock icon (always visible)
                _buildLockIcon(),
              ],
            ),
          ),
        ),
      ),
    );

    // Build the content based on whether drag-to-delete is enabled
    Widget content;
    if (onDragToDeleteStart != null && onDragToDeleteEnd != null) {
      content = LongPressDraggable<String>(
        data: item.id,
        delay: const Duration(milliseconds: 500),
        feedback: Transform.scale(
          scale: 1.1,
          child: Opacity(
            opacity: 0.8,
            child: Material(
              color: Colors.transparent,
              child: colorWidget,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: colorWidget,
        ),
        onDragStarted: onDragToDeleteStart,
        onDragEnd: (_) {
          onDragToDeleteEnd?.call();
        },
        onDraggableCanceled: (_, __) {
          onDragToDeleteEnd?.call();
        },
        child: colorWidget,
      );
    } else {
      content = colorWidget;
    }

    // Wrap everything with SwipeableActionCell for swipe gestures
    return SwipeableActionCell(
      key: ObjectKey(item.id),
      snapPositionPixels: 130.0, // Reveal ~2 action buttons
      // Leading actions (right swipe) - Delete and More
      leadingActions: [
        if (onDelete != null)
          SwipeableAction(
            color: Colors.red,
            icon: Icons.delete,
            onTap: onDelete!,
            expandOnFullSwipe: true,
          ),
        if (onEdit != null || onDuplicate != null)
          SwipeableAction(
            color: Colors.grey.withValues(alpha: 0.32),
            icon: Icons.more_horiz,
            iconColor: Colors.black,
            onTapWithUnlock: (unlock) => _showMoreMenu(context, unlock),
            expandOnFullSwipe: false,
          ),
      ],
      // Trailing actions (left swipe) - Add only
      trailingActions: [
        if (onAddInterpolated != null)
          SwipeableAction(
            color: interpolatedPreviewColor ?? Colors.green,
            icon: Icons.add,
            onTap: onAddInterpolated!,
            expandOnFullSwipe: true,
          ),
      ],
      child: content,
    );
  }

  // Show more options menu
  void _showMoreMenu(BuildContext context, VoidCallback unlock) {
    final bgColor = displayColor ?? item.color!;
    final textColor = getTextColor(bgColor);

    // Find the position of the widget to anchor the menu
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;

    if (renderBox != null && overlay != null) {
      final position = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
      final size = renderBox.size;

      showMenu(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx + 80, // Position near left edge where button is
          position.dy + size.height / 2, // Center vertically
          position.dx + size.width,
          position.dy,
        ),
        color: bgColor,
        items: [
          if (onDuplicate != null)
            PopupMenuItem(
              value: 'duplicate',
              child: Row(
                children: [
                  Icon(Icons.content_copy, color: textColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Duplicate',
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ),
          if (onEdit != null)
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, color: textColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Edit',
                    style: TextStyle(color: textColor),
                  ),
                ],
              ),
            ),
        ],
      ).then((value) {
        if (value == 'duplicate' && onDuplicate != null) {
          onDuplicate!();
        } else if (value == 'edit' && onEdit != null) {
          onEdit!();
        }
        // Unlock and close the swipe sheet after menu action or dismissal
        unlock();
      });
    } else {
      unlock();
    }
  }

  // Build the main color content area
  Widget _buildColorContent() {
    // Just pure color - no text or labels
    return const SizedBox.expand();
  }
  
  // Build the drag handle
  Widget _buildDragHandle() {
    // No visible drag handle - drag anywhere on the box
    return const SizedBox.shrink();
  }
  
  // Build the selection indicator
  Widget _buildSelectionIndicator() {
    // No visible selection indicator - selection shown via border in main container
    return const SizedBox.shrink();
  }

  // Build the lock icon overlay
  Widget _buildLockIcon() {
    // Use the same color determination method as action buttons
    final bgColor = displayColor ?? item.color!;
    final iconColor = getTextColor(bgColor);

    // Check if we should center vertically (responsive mode with 1 column)
    final shouldCenterVertically = layoutMode == GridLayoutMode.responsive && crossAxisCount == 1;

    return Positioned(
      bottom: shouldCenterVertically ? 0 : 16,
      top: shouldCenterVertically ? 0 : null,
      right: 16,
      child: shouldCenterVertically
        ? Center(
            child: GestureDetector(
              onTap: onToggleLock,
              child: SvgPicture.asset(
                item.isLocked ? 'assets/icons/locked.svg' : 'assets/icons/unlocked.svg',
                width: 26,
                height: 18,
                colorFilter: ColorFilter.mode(
                  iconColor.withValues(alpha: item.isLocked ? 0.5 : 0.2),
                  BlendMode.srcIn,
                ),
              ),
            ),
          )
        : GestureDetector(
            onTap: onToggleLock,
            child: SvgPicture.asset(
              item.isLocked ? 'assets/icons/locked.svg' : 'assets/icons/unlocked.svg',
              width: 26,
              height: 18,
              colorFilter: ColorFilter.mode(
                iconColor.withValues(alpha: item.isLocked ? 0.5 : 0.2),
                BlendMode.srcIn,
              ),
            ),
          ),
    );
  }
}
