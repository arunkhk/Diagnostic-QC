import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A common widget for displaying two buttons side by side
/// 
/// Features:
/// - Two buttons with individual callbacks
/// - Dynamic text for each button
/// - Enable/disable flag for each button
/// - Rounded corners with purple border
/// - Purple text on white background
/// - Customizable spacing and styling
/// 
/// Example usage:
/// ```dart
/// CommonTwoButtons(
///   leftButtonText: 'Go To Setting',
///   rightButtonText: 'No Facelock',
///   onLeftButtonPressed: () {
///     print('Left button clicked');
///   },
///   onRightButtonPressed: () {
///     print('Right button clicked');
///   },
///   leftButtonEnabled: true,
///   rightButtonEnabled: true,
/// )
/// ```
class CommonTwoButtons extends StatelessWidget {
  /// Text for the left button
  final String leftButtonText;
  
  /// Text for the right button
  final String rightButtonText;
  
  /// Callback when left button is clicked
  final VoidCallback? onLeftButtonPressed;
  
  /// Callback when right button is clicked
  final VoidCallback? onRightButtonPressed;
  
  /// Whether the left button is enabled (default: true)
  final bool leftButtonEnabled;
  
  /// Whether the right button is enabled (default: true)
  final bool rightButtonEnabled;
  
  /// Spacing between the two buttons (default: 16)
  final double spacing;
  
  /// Button height (default: 48)
  final double buttonHeight;
  
  /// Border radius for buttons (default: 12)
  final double borderRadius;
  
  /// Border width (default: 1.5)
  final double borderWidth;
  
  /// Text style for buttons
  final TextStyle? textStyle;
  
  /// Border color when enabled (default: AppColors.primary)
  final Color? enabledBorderColor;
  
  /// Border color when disabled (default: AppColors.border)
  final Color? disabledBorderColor;
  
  /// Text color when enabled (default: AppColors.primary)
  final Color? enabledTextColor;
  
  /// Text color when disabled (default: AppColors.textDisabled)
  final Color? disabledTextColor;
  
  /// Background color (default: AppColors.white)
  final Color? backgroundColor;

  const CommonTwoButtons({
    super.key,
    required this.leftButtonText,
    required this.rightButtonText,
    this.onLeftButtonPressed,
    this.onRightButtonPressed,
    this.leftButtonEnabled = true,
    this.rightButtonEnabled = true,
    this.spacing = 16,
    this.buttonHeight = 48,
    this.borderRadius = 12,
    this.borderWidth = 1.5,
    this.textStyle,
    this.enabledBorderColor,
    this.disabledBorderColor,
    this.enabledTextColor,
    this.disabledTextColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left Button
        Expanded(
          child: _buildButton(
            text: leftButtonText,
            onPressed: leftButtonEnabled ? onLeftButtonPressed : null,
            isEnabled: leftButtonEnabled,
          ),
        ),
        
        SizedBox(width: spacing),
        
        // Right Button
        Expanded(
          child: _buildButton(
            text: rightButtonText,
            onPressed: rightButtonEnabled ? onRightButtonPressed : null,
            isEnabled: rightButtonEnabled,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isEnabled,
  }) {
    final borderColor = isEnabled
        ? (enabledBorderColor ?? AppColors.primary)
        : (disabledBorderColor ?? AppColors.border);
    
    final textColor = isEnabled
        ? (enabledTextColor ?? AppColors.primary)
        : (disabledTextColor ?? AppColors.textDisabled);

    return SizedBox(
      height: buttonHeight,
      child: OutlinedButton(
        onPressed: onPressed != null ? () {
          debugPrint('🔘 Button pressed: $text');
          debugPrint('🔘 onPressed callback: $onPressed');
          onPressed();
        } : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.white,
          foregroundColor: textColor,
          side: BorderSide(
            color: borderColor,
            width: borderWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: 0,
        ),
        child: Center(
          child: Text(
            text,
            style: textStyle ??
                TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

