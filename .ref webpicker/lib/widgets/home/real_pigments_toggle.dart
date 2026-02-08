import 'package:flutter/material.dart';

// Toggle button for "Only Real Pigments" ICC filter
class RealPigmentsToggle extends StatelessWidget {
  final bool isEnabled;
  final ValueChanged<bool> onChanged;

  const RealPigmentsToggle({
    super.key,
    required this.isEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 0.0),
      child: GestureDetector(
        onTap: () => onChanged(!isEnabled),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isEnabled
                ? Colors.blue.shade700.withOpacity(0.9)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEnabled ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: isEnabled ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(width: 10),
              Text(
                'Only Real Pigments',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
