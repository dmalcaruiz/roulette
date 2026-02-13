import 'package:flutter/material.dart';
import 'push_down_button.dart';

/// Action definition for swipeable cell
class SwipeableAction {
  final Color color;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Function(VoidCallback unlock)? onTapWithUnlock;
  final bool expandOnFullSwipe;

  const SwipeableAction({
    required this.color,
    required this.icon,
    this.iconColor,
    this.onTap,
    this.onTapWithUnlock,
    this.expandOnFullSwipe = false,
  });
}

/// Controller that ensures only one swipeable cell is open at a time.
class SwipeGroupController extends ChangeNotifier {
  _SwipeableActionCellState? _openCell;

  void _onCellOpened(_SwipeableActionCellState cell) {
    if (_openCell != null && _openCell != cell && _openCell!.mounted) {
      _openCell!.close();
    }
    _openCell = cell;
  }

  void _onCellClosed(_SwipeableActionCellState cell) {
    if (_openCell == cell) _openCell = null;
  }

  /// Close the currently open cell (if any).
  void closeAll() {
    if (_openCell != null && _openCell!.mounted) {
      _openCell!.close();
    }
    _openCell = null;
  }
}

/// Custom swipeable cell with full control over actions and animations
class SwipeableActionCell extends StatefulWidget {
  final Widget child;
  final List<SwipeableAction> leadingActions;
  final List<SwipeableAction> trailingActions;
  final double fullSwipeThreshold;
  final double snapPositionPixels;
  final SwipeGroupController? groupController;

  const SwipeableActionCell({
    super.key,
    required this.child,
    this.leadingActions = const [],
    this.trailingActions = const [],
    this.fullSwipeThreshold = 0.55,
    this.snapPositionPixels = 120.0,
    this.groupController,
  });

  @override
  State<SwipeableActionCell> createState() => _SwipeableActionCellState();
}

class _SwipeableActionCellState extends State<SwipeableActionCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0;
  double _maxDragExtent = 0;
  bool _isCommitting = false;
  bool _isLocked = false;
  bool _wasExpanded = false;
  DateTime? _expansionStartTime;

  /// Animate this cell back to closed.
  void close() {
    if (!mounted || _isCommitting) return;
    _animateToOffset(0);
    widget.groupController?._onCellClosed(this);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(() {
        setState(() {
          _dragOffset = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    if (_isCommitting) return;
    _controller.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!mounted || _isCommitting) return;

    setState(() {
      _dragOffset += details.primaryDelta ?? 0;

      // Prevent dragging in a direction with no actions
      final maxRight = widget.leadingActions.isNotEmpty ? _maxDragExtent : 0.0;
      final maxLeft = widget.trailingActions.isNotEmpty ? _maxDragExtent : 0.0;
      _dragOffset = _dragOffset.clamp(-maxLeft, maxRight);
    });
  }

  void _handleDragEnd(DragEndDetails details) async {
    if (!mounted || _isCommitting || _isLocked) return;

    final absOffset = _dragOffset.abs();
    final fullSwipeThreshold = _maxDragExtent * widget.fullSwipeThreshold;

    // Calculate snap position based on number of actions (each button is 60px + 8px margin = 68px)
    final actions = _dragOffset > 0 ? widget.leadingActions : widget.trailingActions;
    final snapPosition = actions.length * 68.0 + 12.0;
    final snapThreshold = snapPosition * 0.5; // Half of snap position for threshold

    // Check if we should trigger full-swipe action
    if (absOffset >= fullSwipeThreshold) {
      setState(() {
        _isCommitting = true;
      });

      final actions = _dragOffset > 0 ? widget.leadingActions : widget.trailingActions;
      final expandingAction = actions.firstWhere(
        (a) => a.expandOnFullSwipe,
        orElse: () => actions.first,
      );

      // Animate to full expansion
      final fullExpansion = _dragOffset > 0 ? _maxDragExtent : -_maxDragExtent;
      _animateToOffset(fullExpansion);

      // Wait for expansion animation to complete
      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;

      // Hold at full expansion for 50ms before executing
      await Future.delayed(const Duration(milliseconds: 50));

      if (!mounted) return;

      // Trigger the action
      if (expandingAction.onTapWithUnlock != null) {
        expandingAction.onTapWithUnlock!(() {
          if (mounted) {
            setState(() {
              _isLocked = false;
            });
            _animateToOffset(0);
          }
        });
      } else if (expandingAction.onTap != null) {
        expandingAction.onTap!();
      }

      // Animate back to center
      _animateToOffset(0);

      // Reset committing flag after animation completes
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _isCommitting = false;
        });
      }
    } else if (absOffset >= snapThreshold) {
      // Snap to reveal actions at calculated pixel position
      final targetSnap = _dragOffset > 0 ? snapPosition : -snapPosition;
      _animateToOffset(targetSnap);
      widget.groupController?._onCellOpened(this);
    } else {
      // Spring back to center
      _animateToOffset(0);
      widget.groupController?._onCellClosed(this);
    }
  }

  void _animateToOffset(double target) {
    _animation = Tween<double>(
      begin: _dragOffset,
      end: target,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward(from: 0);
  }

  void _handleActionTap(SwipeableAction action) {
    if (action.onTapWithUnlock != null) {
      setState(() {
        _isLocked = true;
      });
      action.onTapWithUnlock!(() {
        if (mounted) {
          setState(() {
            _isLocked = false;
          });
          _animateToOffset(0);
        }
      });
    } else if (action.onTap != null) {
      action.onTap!();
      _animateToOffset(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxDragExtent = constraints.maxWidth; // Allow full-width swipe
        final isSnapped = _dragOffset.abs() > 10; // Consider snapped if offset > 10

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _handleDragStart,
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          child: Stack(
            children: [
              // Background actions (left swipe - trailing actions)
              if (_dragOffset < 0 && widget.trailingActions.isNotEmpty)
                Positioned.fill(
                  child: _buildActionsBackground(
                    widget.trailingActions,
                    isLeading: false,
                  ),
                ),

              // Background actions (right swipe - leading actions)
              if (_dragOffset > 0 && widget.leadingActions.isNotEmpty)
                Positioned.fill(
                  child: _buildActionsBackground(
                    widget.leadingActions,
                    isLeading: true,
                  ),
                ),

              // Main content
              GestureDetector(
                onTap: isSnapped ? () => _animateToOffset(0) : null,
                child: Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: widget.child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionsBackground(List<SwipeableAction> actions, {required bool isLeading}) {
    final absOffset = _dragOffset.abs();
    final threshold = _maxDragExtent * widget.fullSwipeThreshold;
    final isNearThreshold = absOffset >= threshold;

    // Find expanding action
    final expandingActionIndex = actions.indexWhere((a) => a.expandOnFullSwipe);
    final hasExpandingAction = expandingActionIndex != -1;
    final shouldAnyExpand = hasExpandingAction && isNearThreshold;

    // Animate only during state transitions, not while staying in same state
    final isTransitioning = shouldAnyExpand != _wasExpanded;

    // Update state and track expansion timing
    if (isTransitioning) {
      _wasExpanded = shouldAnyExpand;
      if (shouldAnyExpand) {
        // Starting expansion - record the time
        _expansionStartTime = DateTime.now();
      } else {
        // Starting collapse - clear the time
        _expansionStartTime = null;
      }
    }

    // Check if we're still in the initial 100ms of expansion
    final isInInitialExpansion = shouldAnyExpand &&
        _expansionStartTime != null &&
        DateTime.now().difference(_expansionStartTime!) <= const Duration(milliseconds: 100);

    // Animate during: 1) initial 100ms of expansion, 2) collapse transitions
    final animationDuration = (isInInitialExpansion || (isTransitioning && !shouldAnyExpand))
        ? const Duration(milliseconds: 100)
        : Duration.zero;

    return Row(
      mainAxisAlignment: isLeading ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (!isLeading) const Spacer(),

        ...List.generate(actions.length, (index) {
          final action = actions[index];
          final shouldExpand = hasExpandingAction &&
                               index == expandingActionIndex &&
                               isNearThreshold;

          // Calculate margins - outer edge gets 8px to match box spacing, inner edges 4px
          final isOuterEdge = isLeading ? index == 0 : index == actions.length - 1;
          var leftMargin = (isLeading && isOuterEdge) ? 8.0 : 4.0;
          var rightMargin = (!isLeading && isOuterEdge) ? 8.0 : 4.0;

          // When expanded, set margin on the side facing the sliding box
          if (shouldExpand) {
            if (isLeading) {
              rightMargin = 4.0; // Right side faces the box for leading actions
            } else {
              leftMargin = 4.0; // Left side faces the box for trailing actions
            }
          }

          return GestureDetector(
            onTap: () => _handleActionTap(action),
            child: AnimatedContainer(
              duration: animationDuration,
              width: shouldExpand ? absOffset - 8 : 60,
              height: double.infinity,
              margin: shouldExpand
                ? EdgeInsets.only(
                    top: 4.0,
                    bottom: 4.0,
                    left: leftMargin,
                    right: rightMargin,
                  )
                : EdgeInsets.only(
                    left: leftMargin,
                    right: rightMargin,
                    top: 4.0,
                    bottom: 4.0,
                  ),
              child: SunkenPushDownButton(
                color: action.color,
                child: Icon(
                  action.icon,
                  color: action.iconColor ?? Colors.white,
                  size: 24,
                ),
              ),
            ),
          );
        }),

        if (isLeading) const Spacer(),
      ],
    );
  }
}
