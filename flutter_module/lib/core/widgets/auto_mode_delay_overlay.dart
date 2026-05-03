import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Centered circular progress overlay shown for [duration] (default 1 second)
/// when auto mode is on. Use on screens that auto-start the test after a short delay.
class AutoModeDelayOverlay extends StatelessWidget {
  const AutoModeDelayOverlay({
    super.key,
    this.duration = const Duration(seconds: 1),
  });

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: TweenAnimationBuilder<double>(
            key: ValueKey('auto_mode_delay_${duration.inMilliseconds}'),
            tween: Tween<double>(begin: 0, end: 1),
            duration: duration,
            builder: (context, value, child) {
              return SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 5,
                  backgroundColor: AppColors.greyLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
