import 'package:flutter/material.dart';
import '../../screens/menu_screen.dart';
import '../../utils/ui_color_utils.dart';

// App bar for the home screen
class HomeAppBar extends StatelessWidget {
  static const double height = 56.0; // Standard AppBar height (kToolbarHeight)

  final Color bgColor;
  final VoidCallback? onBgEditMode;
  final bool isBgColorSelected;
  final void Function(DragStartDetails)? onBgColorPanStart;
  final Color Function(Color color, {double? lightness, double? chroma, double? hue, double? alpha})? colorFilter;
  final VoidCallback? onMenuPressed;

  const HomeAppBar({
    super.key,
    required this.bgColor,
    this.onBgEditMode,
    this.isBgColorSelected = false,
    this.onBgColorPanStart,
    this.colorFilter,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      padding: const EdgeInsets.fromLTRB(40, 8, 40, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Show BG color box when in BG edit mode, otherwise show star dropdown
          isBgColorSelected
              ? GestureDetector(
                  onTap: onBgEditMode,
                  onPanStart: onBgColorPanStart,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorFilter != null ? colorFilter!(bgColor) : bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: getTextColor(bgColor),
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.format_paint,
                      color: getTextColor(bgColor).withOpacity(0.9),
                      size: 24,
                    ),
                  ),
                )
              : PopupMenuButton<String>(
                  icon: Icon(
                    Icons.star_border,
                    color: getTextColor(bgColor),
                  ),
                  color: bgColor,
                  onSelected: (value) {
                    if (value == 'bg_edit' && onBgEditMode != null) {
                      onBgEditMode!();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'bg_edit',
                      child: Text(
                        'BG Edit Mode',
                        style: TextStyle(
                          color: getTextColor(bgColor),
                        ),
                      ),
                    ),
                  ],
                ),
          Text(
            'Palletator',
            style: TextStyle(
              color: getTextColor(bgColor),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Hero(
            tag: 'menuButton',
            child: IconButton(
              icon: Icon(
                Icons.menu,
                color: getTextColor(bgColor),
              ),
              onPressed: () {
                // Trigger save callback before navigating
                onMenuPressed?.call();

                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const MenuScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0); // Start from right
                      const end = Offset.zero;
                      const curve = Curves.ease;

                      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
