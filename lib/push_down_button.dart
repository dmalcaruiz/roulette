import 'package:flutter/material.dart';

class PushDownButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final double borderRadius;
  final double height;
  final double bottomBorderWidth;
  final Color? bottomBorderColor;

  const PushDownButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    this.borderRadius = 50,
    this.height = 59,
    this.bottomBorderWidth = 5,
    this.bottomBorderColor,
  });

  @override
  State<PushDownButton> createState() => _PushDownButtonState();
}

class _PushDownButtonState extends State<PushDownButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.forward();
    widget.onTap();
    await _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bottomColor = widget.bottomBorderColor ??
        Colors.black.withValues(alpha: 0.25);
    final faceHeight = widget.height - widget.bottomBorderWidth;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final travel = _controller.value * widget.bottomBorderWidth;
            return Stack(
              children: [
                // Bottom layer — fixed at bottom, never moves
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: faceHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: bottomColor,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                  ),
                ),
                // Top layer — non-positioned so Stack gets width from it
                Padding(
                  padding: EdgeInsets.only(top: travel),
                  child: SizedBox(
                    height: faceHeight,
                    child: child,
                  ),
                ),
              ],
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
