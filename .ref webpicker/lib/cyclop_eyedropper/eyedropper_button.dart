// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import 'eye_dropper_layer.dart';

// an eyeDropper standalone button
// should be used with a context [EyeDrop] available
class EyedropperButton extends StatelessWidget {
  // customisable icon ( default : [Icons.colorize] )
  final IconData icon;

  // icon color, default : [Colors.blueGrey]
  final Color iconColor;

  // color selection callback
  final ValueChanged<Color> onColor;

  // hover, and the color changed callback
  final ValueChanged<Color>? onColorChanged;

  // Background color of the button
  final Color? backgroundColor;

  // Border color of the button
  final Color? borderColor;

  // Foreground color (for icon and text if any) of the button
  final Color? foregroundColor;

  const EyedropperButton({
    required this.onColor,
    this.onColorChanged,
    this.icon = Icons.colorize,
    this.iconColor = Colors.black54,
    this.backgroundColor,
    this.borderColor,
    this.foregroundColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.black.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: IconButton(
          icon: Icon(icon),
          color: foregroundColor ?? iconColor,
          onPressed:
              // cf. https://github.com/flutter/flutter/issues/22308
              () => Future.delayed(
            const Duration(milliseconds: 50),
            () => _onEyeDropperRequest(context),
          ),
        ),
      );

  void _onEyeDropperRequest(BuildContext context) {
    try {
      EyeDrop.of(context).capture(context, onColor, onColorChanged);
    } catch (err) {
      throw Exception('EyeDrop capture error : $err');
    }
  }
}
