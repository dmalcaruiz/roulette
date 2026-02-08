import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/ui_color_utils.dart';
import '../../state/sheet_state_provider.dart';

// Sheet grabbing handle widget with pin functionality and chips
class SheetGrabbingHandle extends StatelessWidget {
  final Color? bgColor;

  const SheetGrabbingHandle({
    super.key,
    this.bgColor,
  });
  
  @override
  Widget build(BuildContext context) {
    final sheetState = context.watch<SheetStateProvider>();
    final chipStates = sheetState.chipStates;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(
            color: getTextColor(bgColor ?? Colors.white).withOpacity(0.15),
            width: 1.5,
          ),
          left: BorderSide(
            color: getTextColor(bgColor ?? Colors.white).withOpacity(0.15),
            width: 1.5,
          ),
          right: BorderSide(
            color: getTextColor(bgColor ?? Colors.white).withOpacity(0.15),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),

          // Drag handle indicator
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: getTextColor(bgColor ?? Colors.white).withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Toggleable chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(SheetStateProvider.chipLabels.length, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => sheetState.selectChip(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: chipStates[index]
                          ? getTextColor(bgColor ?? Colors.white)
                          : (bgColor ?? Colors.white).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: chipStates[index]
                            ? getTextColor(bgColor ?? Colors.white)
                            : getTextColor(bgColor ?? Colors.white).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        SheetStateProvider.chipLabels[index],
                        style: TextStyle(
                          color: chipStates[index]
                              ? (getTextColor(bgColor ?? Colors.white) == Colors.black ? Colors.white : Colors.black)
                              : getTextColor(bgColor ?? Colors.white).withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

