import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A reusable loading progress bar widget with optional message
/// Shows an indeterminate linear progress indicator with a label
class CommonLoadingBar extends StatelessWidget {
  /// The message to display above the progress bar
  final String message;
  
  /// Horizontal padding around the widget (default: 24)
  final double horizontalPadding;
  
  /// Height of the progress bar (default: 3)
  final double barHeight;
  
  /// Font size of the message (default: 11)
  final double fontSize;
  
  /// Background color of the progress bar
  final Color? backgroundColor;
  
  /// Color of the progress indicator
  final Color? progressColor;
  
  /// Color of the message text
  final Color? textColor;

  const CommonLoadingBar({
    super.key,
    required this.message,
    this.horizontalPadding = 24,
    this.barHeight = 3,
    this.fontSize = 11,
    this.backgroundColor,
    this.progressColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: fontSize,
                  color: textColor ?? AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: backgroundColor ?? AppColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                progressColor ?? AppColors.primary,
              ),
              minHeight: barHeight,
            ),
          ),
        ],
      ),
    );
  }
}
