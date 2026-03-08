import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A common button widget that can be used across all screens
/// 
/// Features:
/// - Purple background with rounded corners (when enabled)
/// - Light purple/gray background (when disabled)
/// - White text (when enabled)
/// - Gray text (when disabled)
/// - Full width button
/// - Customizable text and onClick callback
/// - Proper enabled/disabled styling
class CommonButton extends StatelessWidget {
  /// Button text to display
  final String text;
  
  /// Callback function when button is clicked
  final VoidCallback? onPressed;
  
  /// Button height (default: 52)
  final double height;
  
  /// Button background color (default: AppColors.primary)
  final Color? backgroundColor;
  
  /// Button text color (default: Colors.white)
  final Color? textColor;
  
  /// Button text style
  final TextStyle? textStyle;
  
  /// Whether the button is enabled (default: true)
  final bool enabled;
  
  /// Whether to show loading indicator (default: false)
  final bool isLoading;

  const CommonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.height = 52,
    this.backgroundColor,
    this.textColor,
    this.textStyle,
    this.enabled = true,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled
              ? (backgroundColor ?? AppColors.primary)
              : AppColors.disabledBackground,
          foregroundColor: enabled
              ? (textColor ?? Colors.white)
              : AppColors.disabledText,
          disabledBackgroundColor: AppColors.disabledBackground,
          disabledForegroundColor: AppColors.disabledText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          elevation: enabled ? 0 : 0,
          padding: EdgeInsets.zero, // Remove default padding
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      enabled
                          ? (textColor ?? Colors.white)
                          : AppColors.disabledText,
                    ),
                  ),
                )
              : Text(
                  text,
                  style: textStyle ??
                      TextStyle(
                        fontSize: 16,
                        color: enabled
                            ? (textColor ?? Colors.white)
                            : AppColors.disabledText,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
        ),
      ),
    );
  }
}

