import 'package:flutter/material.dart';
import 'color_utils.dart';

class PushDownButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final double borderRadius;
  final double height;
  final double bottomBorderWidth;
  final Color? bottomBorderColor;
  final GestureLongPressStartCallback? onLongPressStart;
  final GestureLongPressEndCallback? onLongPressEnd;

  const PushDownButton({
    super.key,
    required this.child,
    this.onTap,
    required this.color,
    this.borderRadius = 21,
    this.height = 64,
    this.bottomBorderWidth = 6.5,
    this.bottomBorderColor,
    this.onLongPressStart,
    this.onLongPressEnd,
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
    widget.onTap?.call();
    await _controller.reverse();
  }

  static const double _outerStrokeWidth = 3.5;
  static const double _innerStrokeWidth = 2.5;

  @override
  Widget build(BuildContext context) {
    final bottomColor = widget.bottomBorderColor ??
        oklchShadow(widget.color);
    final faceHeight = widget.height - widget.bottomBorderWidth;
    final outerStrokeColor = bottomColor.withValues(alpha: 0.25);
    final innerStrokeColor = oklchShadow(widget.color, lightnessReduction: 0.06);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap != null ? _handleTap : null,
      onLongPressStart: widget.onLongPressStart,
      onLongPressEnd: widget.onLongPressEnd,
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final travel = _controller.value * widget.bottomBorderWidth;
            return Stack(
              clipBehavior: Clip.none,
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
                      // Outer stroke via boxShadow with zero blur + spread
                      boxShadow: [
                        BoxShadow(
                          color: outerStrokeColor,
                          spreadRadius: _outerStrokeWidth,
                          blurRadius: 0,
                        ),
                      ],
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
              border: Border.all(
                color: innerStrokeColor,
                width: _innerStrokeWidth,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A text field with an inset/sunken 3D appearance.
class InsetTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final TextStyle? style;
  final TextStyle? hintStyle;
  final ValueChanged<String>? onChanged;
  final Color color;
  final double borderRadius;
  final double depth;

  const InsetTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.style,
    this.hintStyle,
    this.onChanged,
    this.color = const Color(0xFFF8F8F9),
    this.borderRadius = 14,
    this.depth = 2.5,
  });

  static const double _innerStrokeWidth = 2.5;

  @override
  Widget build(BuildContext context) {
    final backColor = oklchShadow(color);
    final innerStrokeColor = oklchShadow(color, lightnessReduction: 0.06);

    return Stack(
      children: [
        // Back face — darker, full size (non-positioned, sets Stack size)
        Padding(
          padding: EdgeInsets.only(bottom: depth),
          child: Container(
            decoration: BoxDecoration(
              color: backColor,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 1,
              style: const TextStyle(color: Colors.transparent, fontSize: 16),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(color: Colors.transparent),
              ),
            ),
          ),
        ),
        // Front face — offset from top by depth
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          top: depth,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: innerStrokeColor,
                width: _innerStrokeWidth,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
          ),
        ),
        // Text field on top
        Padding(
          padding: EdgeInsets.only(top: depth),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 1,
            style: style,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintText: hintText,
              hintStyle: hintStyle,
              border: InputBorder.none,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class SunkenPushDownButton extends StatelessWidget {
  final Widget child;
  final Color color;
  final double borderRadius;
  final double depth;

  static const double _innerStrokeWidth = 2.5;

  const SunkenPushDownButton({
    super.key,
    required this.child,
    required this.color,
    this.borderRadius = 12,
    this.depth = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    final backColor = oklchShadow(color);
    final innerStrokeColor = oklchShadow(color, lightnessReduction: 0.06);

    return Stack(
      children: [
        // Back face — darker, full size (non-positioned, sets Stack size)
        Container(
          decoration: BoxDecoration(
            color: backColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        // Front face — lighter, positioned at bottom, offset from top by depth
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          top: depth,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: innerStrokeColor,
                width: _innerStrokeWidth,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ],
    );
  }
}
