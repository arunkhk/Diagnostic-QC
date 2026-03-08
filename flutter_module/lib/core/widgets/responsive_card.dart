import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A responsive card widget that can be used across all screens
/// 
/// Features:
/// - Responsive design (height/width adjusts to content)
/// - Center image
/// - Heading with text overflow handling
/// - Subtitle supporting array of strings (multiple lines)
/// - Optional progress bar with dynamic value (time or %)
/// - Callback when progress reaches 100%
/// 
/// Example usage:
/// ```dart
/// ResponsiveCard(
///   imagePath: 'assets/images/image20.png',
///   heading: 'Scanning SD Card...',
///   subtitleLines: [
///     'Checking card health and integrity.',
///     'Please wait.',
///   ],
///   showProgressBar: true,
///   progressDuration: Duration(seconds: 3),
///   onProgressComplete: () {
///     print('Progress completed!');
///   },
/// )
/// ```
class ResponsiveCard extends StatefulWidget {
  /// Image asset path to display in center
  final String? imagePath;
  
  /// Image width (default: 120)
  final double? imageWidth;
  
  /// Image height (default: 120)
  final double? imageHeight;
  
  /// Heading text (will truncate with "..." if too long)
  final String? heading;
  
  /// Subtitle lines (array of strings for multiple lines)
  final List<String>? subtitleLines;
  
  /// Whether to show progress bar (optional)
  final bool showProgressBar;
  
  /// Progress value (0.0 to 1.0) or null if using time-based
  final double? progressValue;
  
  /// Duration for time-based progress (if progressValue is null)
  final Duration? progressDuration;
  
  /// Callback when progress reaches 100%
  final VoidCallback? onProgressComplete;
  
  /// Padding around the card content
  final EdgeInsets? padding;
  
  /// Custom widget to display instead of image
  final Widget? customImageWidget;
  
  /// Additional widgets to display below subtitle
  final List<Widget>? additionalWidgets;

  const ResponsiveCard({
    super.key,
    this.imagePath,
    this.imageWidth,
    this.imageHeight,
    this.heading,
    this.subtitleLines,
    this.showProgressBar = false,
    this.progressValue,
    this.progressDuration,
    this.onProgressComplete,
    this.padding,
    this.customImageWidget,
    this.additionalWidgets,
  }) : assert(
          !showProgressBar || progressValue != null || progressDuration != null,
          'Either progressValue or progressDuration must be provided when showProgressBar is true',
        );

  @override
  State<ResponsiveCard> createState() => _ResponsiveCardState();
}

class _ResponsiveCardState extends State<ResponsiveCard> {
  double _animatedProgress = 0.0;
  bool _progressComplete = false;

  @override
  void initState() {
    super.initState();
    if (widget.showProgressBar && widget.progressDuration != null) {
      _startProgressAnimation();
    } else if (widget.showProgressBar && widget.progressValue != null) {
      _animatedProgress = widget.progressValue!;
      if (_animatedProgress >= 1.0 && !_progressComplete) {
        _onProgressComplete();
      }
    }
  }

  @override
  void didUpdateWidget(ResponsiveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showProgressBar) {
      if (widget.progressValue != null && widget.progressValue != oldWidget.progressValue) {
        setState(() {
          _animatedProgress = widget.progressValue!;
          if (_animatedProgress >= 1.0 && !_progressComplete) {
            _onProgressComplete();
          }
        });
      } else if (widget.progressDuration != null &&
          widget.progressDuration != oldWidget.progressDuration) {
        _startProgressAnimation();
      }
    }
  }

  void _startProgressAnimation() {
    if (widget.progressDuration == null) return;

    final duration = widget.progressDuration!;
    const steps = 100;
    final stepDuration = Duration(
      milliseconds: duration.inMilliseconds ~/ steps,
    );

    _animatedProgress = 0.0;
    _progressComplete = false;

    Future.doWhile(() async {
      if (!mounted || _progressComplete) return false;

      await Future.delayed(stepDuration);
      if (!mounted) return false;

      setState(() {
        _animatedProgress += (1.0 / steps);
        if (_animatedProgress >= 1.0) {
          _animatedProgress = 1.0;
        }
      });

      // Check if progress is complete and call callback outside setState
      if (_animatedProgress >= 1.0 && !_progressComplete) {
        _onProgressComplete();
      }

      return !_progressComplete;
    });
  }

  void _onProgressComplete() {
    if (_progressComplete) return;
    _progressComplete = true;
    // Call the callback
    widget.onProgressComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: widget.padding ?? const EdgeInsets.all(32),
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
          // Center Image
          if (widget.customImageWidget != null || widget.imagePath != null)
            Center(
              child: widget.customImageWidget ??
                  Image.asset(
                    widget.imagePath!,
                    width: widget.imageWidth ?? 120,
                    height: widget.imageHeight ?? 120,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => SizedBox(
                      width: widget.imageWidth ?? 120,
                      height: widget.imageHeight ?? 120,
                      child: const Icon(
                        Icons.image,
                        size: 60,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
            ),

          // Spacing after image
          if (widget.customImageWidget != null || widget.imagePath != null)
            const SizedBox(height: 32),

          // Heading (with text overflow)
          if (widget.heading != null)
            Text(
              widget.heading!,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

          // Spacing after heading
          if (widget.heading != null) const SizedBox(height: 16),

          // Subtitle lines (array of strings)
          if (widget.subtitleLines != null && widget.subtitleLines!.isNotEmpty)
            ...widget.subtitleLines!.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),

          // Spacing before progress bar or additional widgets
          if ((widget.showProgressBar || (widget.additionalWidgets != null && widget.additionalWidgets!.isNotEmpty)) &&
              (widget.heading != null || (widget.subtitleLines != null && widget.subtitleLines!.isNotEmpty)))
            const SizedBox(height: 32),

          // Progress Bar (optional)
          if (widget.showProgressBar)
            SizedBox(
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _animatedProgress,
                  backgroundColor: AppColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
            ),

          // Additional widgets
          if (widget.additionalWidgets != null)
            ...widget.additionalWidgets!,
          ],
        ),
      ),
    );
  }
}

