import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Status enum for scan results
enum ScanStatus {
  passed,
  failed,
}

/// A widget for displaying scan results with status indicator
/// 
/// Features:
/// - Center image with status circle at bottom-right
/// - Status circle shows green checkmark for passed, red exclamation for failed
/// - Title with ellipsis if text is too long
/// - Array of subheadings with bullet points (left-aligned)
/// - Responsive design
/// 
/// Example usage:
/// ```dart
/// ScanResultCard(
///   imagePath: 'assets/images/image21.png',
///   status: ScanStatus.failed,
///   title: 'SD Card Not Detected',
///   subheadingLines: [
///     'No SD card was found in your device.',
///     'Please insert one to proceed.',
///   ],
/// )
/// ```
class ScanResultCard extends StatelessWidget {
  /// Image asset path to display in center
  final String? imagePath;
  
  /// Image width (default: 120)
  final double? imageWidth;
  
  /// Image height (default: 120)
  final double? imageHeight;
  
  /// Scan status (passed or failed)
  final ScanStatus status;
  
  /// Title text (will truncate with "..." if too long)
  final String? title;
  
  /// Subheading lines (array of strings for bullet points)
  final List<String>? subheadingLines;
  
  /// Padding around the card content
  final EdgeInsets? padding;
  
  /// Custom widget to display instead of image
  final Widget? customImageWidget;
  
  /// Optional button to show below subheading lines
  final Widget? optionalButton;
  
  /// Whether to show the status icon (default: true)
  final bool showStatusIcon;

  const ScanResultCard({
    super.key,
    this.imagePath,
    this.imageWidth,
    this.imageHeight,
    required this.status,
    this.title,
    this.subheadingLines,
    this.padding,
    this.customImageWidget,
    this.optionalButton,
    this.showStatusIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Center Image with Status Circle
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // Main Image
                customImageWidget ??
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
                
                // Status Circle at bottom-right of image (only show if showStatusIcon is true)
                if (showStatusIcon)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.white,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        status == ScanStatus.passed
                            ? Icons.check
                            : Icons.error_outline,
                        color: AppColors.white,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Title with ellipsis if too long
          if (title != null)
            Text(
              title!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

          // Spacing after title
          if (title != null) const SizedBox(height: 16),

          // Subheading lines with bullet points
          if (subheadingLines != null && subheadingLines!.isNotEmpty)
            ...subheadingLines!.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bullet point
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Text
                    Expanded(
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Optional button
          if (optionalButton != null) ...[
            const SizedBox(height: 24),
            optionalButton!,
          ],
          ],
        ),
      ),
    );
  }
}

