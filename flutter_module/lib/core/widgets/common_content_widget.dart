import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A common widget for displaying image, heading, and subheading
/// 
/// Features:
/// - Centered image at the top
/// - Heading text with ellipsis if too long
/// - Subheading text with ellipsis if too long
/// - Responsive layout
/// 
/// Example usage:
/// ```dart
/// CommonContentWidget(
///   imagePath: 'assets/images/network_icon.png',
///   heading: 'Checking Network Connectivity...',
///   subheading: 'Enter the test number and initiate call to verify network connectivity..',
/// )
/// ```
class CommonContentWidget extends StatelessWidget {
  /// Image asset path to display in center
  final String? imagePath;
  
  /// Image width (default: 120)
  final double? imageWidth;
  
  /// Image height (default: 120)
  final double? imageHeight;
  
  /// Heading text (will truncate with "..." if too long)
  final String? heading;
  
  /// Subheading text (will truncate with "..." if too long)
  final String? subheading;
  
  /// Custom widget to display instead of image
  final Widget? customImageWidget;
  
  /// Padding around the content
  final EdgeInsets? padding;
  
  /// Spacing between image and heading (default: 32)
  final double? imageToHeadingSpacing;
  
  /// Spacing between heading and subheading (default: 16)
  final double? headingToSubheadingSpacing;
  
  /// Heading text style
  final TextStyle? headingStyle;
  
  /// Subheading text style
  final TextStyle? subheadingStyle;
  
  /// Maximum lines for heading (default: 2)
  final int? headingMaxLines;
  
  /// Maximum lines for subheading (default: 3)
  final int? subheadingMaxLines;

  const CommonContentWidget({
    super.key,
    this.imagePath,
    this.imageWidth,
    this.imageHeight,
    this.heading,
    this.subheading,
    this.customImageWidget,
    this.padding,
    this.imageToHeadingSpacing,
    this.headingToSubheadingSpacing,
    this.headingStyle,
    this.subheadingStyle,
    this.headingMaxLines,
    this.subheadingMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Center Image
          if (customImageWidget != null || imagePath != null)
            Center(
              child: customImageWidget ??
                  Image.asset(
                    imagePath!,
                    width: imageWidth ?? 120,
                    height: imageHeight ?? 120,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => SizedBox(
                      width: imageWidth ?? 120,
                      height: imageHeight ?? 120,
                      child: const Icon(
                        Icons.image,
                        size: 60,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
            ),

          // Spacing after image
          if (customImageWidget != null || imagePath != null)
            SizedBox(height: imageToHeadingSpacing ?? 32),

          // Heading (with text overflow - ellipsis at end)
          if (heading != null)
            Text(
              heading!,
              style: headingStyle ??
                  Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
              textAlign: TextAlign.left,
              maxLines: headingMaxLines ?? 2,
              overflow: TextOverflow.ellipsis,
            ),

          // Spacing after heading
          if (heading != null && subheading != null)
            SizedBox(height: headingToSubheadingSpacing ?? 16),

          // Subheading (with text overflow - ellipsis at end)
          if (subheading != null)
            Text(
              subheading!,
              style: subheadingStyle ??
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
              textAlign: TextAlign.left,
              maxLines: subheadingMaxLines ?? 3,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }
}

