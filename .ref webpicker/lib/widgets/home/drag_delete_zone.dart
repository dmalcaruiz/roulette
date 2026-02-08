import 'package:flutter/material.dart';
import 'home_app_bar.dart';

// A drag target zone that appears when dragging grid items
// Provides visual feedback for drag-to-delete functionality
class DragDeleteZone extends StatefulWidget {
  // Whether the zone is currently visible
  final bool isVisible;
  
  // Callback when an item is dropped on the delete zone
  final VoidCallback onItemDropped;
  
  // The item being dragged (for type checking)
  final String? draggingItemId;
  
  // Callback for pointer position updates
  final Function(Offset)? onPointerMove;
  
  // Callback for pointer up
  final VoidCallback? onPointerUp;
  
  const DragDeleteZone({
    super.key,
    required this.isVisible,
    required this.onItemDropped,
    this.draggingItemId,
    this.onPointerMove,
    this.onPointerUp,
  });
  
  @override
  State<DragDeleteZone> createState() => _DragDeleteZoneState();
}

class _DragDeleteZoneState extends State<DragDeleteZone> 
    with SingleTickerProviderStateMixin {
  bool _isHoveringOver = false;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  final GlobalKey _zoneKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }
  
  void _checkHover(Offset globalPosition) {
    final RenderBox? box = _zoneKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final localPosition = box.globalToLocal(globalPosition);
      final size = box.size;
      final isInside = localPosition.dx >= 0 && 
                      localPosition.dx <= size.width &&
                      localPosition.dy >= 0 && 
                      localPosition.dy <= size.height;
      
      if (isInside && !_isHoveringOver) {
        setState(() {
          _isHoveringOver = true;
        });
        _scaleController.forward();
      } else if (!isInside && _isHoveringOver) {
        setState(() {
          _isHoveringOver = false;
        });
        _scaleController.reverse();
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }
    
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: widget.isVisible ? 1.0 : 0.0,
      child: Listener(
        onPointerMove: (event) {
          _checkHover(event.position);
          widget.onPointerMove?.call(event.position);
        },
        onPointerUp: (event) {
          if (_isHoveringOver) {
            widget.onItemDropped();
          }
          setState(() {
            _isHoveringOver = false;
          });
          _scaleController.reverse();
          widget.onPointerUp?.call();
        },
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                key: _zoneKey,
                  height: HomeAppBar.height - 16,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  decoration: BoxDecoration(
                    color: _isHoveringOver
                        ? Colors.red.shade700.withOpacity(0.9)
                        : Colors.red.shade600.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isHoveringOver ? Icons.delete : Icons.delete_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isHoveringOver ? 'Release to Delete' : 'Drag Here to Delete',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
  }
}

