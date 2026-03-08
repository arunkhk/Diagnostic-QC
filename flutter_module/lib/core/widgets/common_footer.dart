import 'package:flutter/material.dart';

/// A common footer widget for screens during testing/detection
/// 
/// Features:
/// - Ellipse images at bottom left and right
/// - Positioned at the bottom of the screen
/// - Can be used across all screens during detection/testing
class CommonFooter extends StatelessWidget {
  /// Left ellipse image path
  final String? leftEllipsePath;
  
  /// Right ellipse image path
  final String? rightEllipsePath;
  
  /// Width of ellipse images (default: 150)
  final double ellipseWidth;
  
  /// Height of ellipse images (default: 150)
  final double ellipseHeight;
  
  /// Opacity of ellipse images (default: 1.0)
  final double opacity;

  /// Whether to ignore pointer events (default: false)
  /// When true, touch events will pass through to widgets below
  final bool ignorePointer;

  const CommonFooter({
    super.key,
    this.leftEllipsePath,
    this.rightEllipsePath,
    this.ellipseWidth = 150,
    this.ellipseHeight = 150,
    this.opacity = 1.0,
    this.ignorePointer = false,
  });

  @override
  Widget build(BuildContext context) {
    print('🔍 CommonFooter: Building with leftEllipsePath=$leftEllipsePath, rightEllipsePath=$rightEllipsePath');
    
    Widget content = SizedBox(
      width: double.infinity,
      height: ellipseHeight,
      child: Stack(
        children: [
          // Left ellipse
          if (leftEllipsePath != null)
            Positioned(
              left: 0,
              bottom: 0,
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  leftEllipsePath!,
                  width: ellipseWidth,
                  height: ellipseHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ CommonFooter: Error loading left ellipse: $error');
                    return SizedBox(
                      width: ellipseWidth,
                      height: ellipseHeight,
                    );
                  },
                ),
              ),
            ),
          
          // Right ellipse
          if (rightEllipsePath != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  rightEllipsePath!,
                  width: ellipseWidth,
                  height: ellipseHeight,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ CommonFooter: Error loading right ellipse: $error');
                    return SizedBox(
                      width: ellipseWidth,
                      height: ellipseHeight,
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );

    // Apply IgnorePointer if needed (wrapping content, not Positioned)
    if (ignorePointer) {
      content = IgnorePointer(child: content);
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: content,
    );
  }
}

