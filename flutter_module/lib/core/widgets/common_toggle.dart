import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A common toggle switch widget
/// 
/// Features:
/// - Toggle switch with ON/OFF states
/// - Purple background when ON
/// - Grey background when OFF
/// - Callback when toggled
/// - Customizable text
/// 
/// Example usage:
/// ```dart
/// CommonToggle(
///   text: 'Flashlight',
///   value: _isOn,
///   onChanged: (isOn) {
///     setState(() => _isOn = isOn);
///   },
/// )
/// ```
class CommonToggle extends StatelessWidget {
  /// Text label for the toggle
  final String text;
  
  /// Current toggle state (true = ON, false = OFF)
  final bool value;
  
  /// Callback when toggle state changes
  final ValueChanged<bool>? onChanged;
  
  /// Callback when toggle is turned ON
  final VoidCallback? onTurnedOn;
  
  /// Toggle width (default: 100)
  final double width;
  
  /// Toggle height (default: 40)
  final double height;
  
  /// Text style
  final TextStyle? textStyle;

  const CommonToggle({
    super.key,
    required this.text,
    required this.value,
    this.onChanged,
    this.onTurnedOn,
    this.width = 100,
    this.height = 40,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Toggle Switch
        GestureDetector(
          onTap: () {
            if (onChanged != null) {
              final newValue = !value;
              onChanged!(newValue);
              // Call onTurnedOn if turning on
              if (newValue && onTurnedOn != null) {
                onTurnedOn!();
              }
            }
          },
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: value ? AppColors.primary : AppColors.greyLight,
              borderRadius: BorderRadius.circular(height / 2),
            ),
            child: Stack(
              children: [
                // ON/OFF Text - Centered
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ON',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: value ? AppColors.white : AppColors.grey,
                        ),
                      ),
                      SizedBox(width: width * 0.3), // Space between ON and OFF
                      Text(
                        'OFF',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: !value ? AppColors.white : AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sliding indicator
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: value ? width - height + 2 : 2,
                  top: 2,
                  child: Container(
                    width: height - 4,
                    height: height - 4,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

