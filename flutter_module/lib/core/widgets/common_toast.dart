import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Toast type enum
enum ToastType {
  success,
  error,
  warning,
  info,
}

/// A common toast widget for displaying notification messages
/// 
/// Features:
/// - Circular icon on the left (success, error, warning, info)
/// - Message text on the right
/// - White background with rounded corners
/// - Subtle shadow
/// - Auto-dismiss after duration
/// 
/// Example usage:
/// ```dart
/// CommonToast.show(
///   context,
///   message: 'Call has been connected!',
///   type: ToastType.success,
/// )
/// ```
class CommonToast extends StatelessWidget {
  /// Message text to display
  final String message;
  
  /// Toast type (success, error, warning, info)
  final ToastType type;
  
  /// Duration to show the toast (default: 3 seconds)
  final Duration duration;
  
  /// Icon size (default: 24)
  final double iconSize;
  
  /// Icon container size (default: 40)
  final double iconContainerSize;
  
  /// Border radius (default: 12)
  final double borderRadius;
  
  /// Custom icon widget (optional, overrides default icon)
  final Widget? customIcon;
  
  /// Custom background color (optional)
  final Color? backgroundColor;
  
  /// Custom text style (optional)
  final TextStyle? textStyle;

  const CommonToast({
    super.key,
    required this.message,
    this.type = ToastType.success,
    this.duration = const Duration(seconds: 3),
    this.iconSize = 24,
    this.iconContainerSize = 40,
    this.borderRadius = 12,
    this.customIcon,
    this.backgroundColor,
    this.textStyle,
  });

  /// Show toast with success message
  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      type: ToastType.success,
      duration: duration,
    );
  }

  /// Show toast with error message
  static void showError(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      type: ToastType.error,
      duration: duration,
    );
  }

  /// Show toast with warning message
  static void showWarning(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      type: ToastType.warning,
      duration: duration,
    );
  }

  /// Show toast with info message
  static void showInfo(
    BuildContext context, {
    required String message,
    Duration? duration,
  }) {
    show(
      context,
      message: message,
      type: ToastType.info,
      duration: duration,
    );
  }

  /// Show toast with custom parameters
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.success,
    Duration? duration,
    double? iconSize,
    double? iconContainerSize,
    double? borderRadius,
    Widget? customIcon,
    Color? backgroundColor,
    TextStyle? textStyle,
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => _ToastOverlay(
        message: message,
        type: type,
        duration: duration ?? const Duration(seconds: 3),
        iconSize: iconSize ?? 24,
        iconContainerSize: iconContainerSize ?? 40,
        borderRadius: borderRadius ?? 12,
        customIcon: customIcon,
        backgroundColor: backgroundColor,
        textStyle: textStyle,
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remove after duration
    Future.delayed(duration ?? const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Container
          Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: BoxDecoration(
              color: _getIconBackgroundColor(),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: customIcon ?? _getIcon(),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Message Text
          Flexible(
            child: Text(
              message,
              style: textStyle ??
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        color: AppColors.text,
                        fontWeight: FontWeight.w500,
                      ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getIconBackgroundColor() {
    switch (type) {
      case ToastType.success:
        return AppColors.primaryLight;
      case ToastType.error:
        return AppColors.errorLight;
      case ToastType.warning:
        return AppColors.warningLight;
      case ToastType.info:
        return AppColors.infoLight;
    }
  }

  Color _getIconColor() {
    switch (type) {
      case ToastType.success:
        return AppColors.primary;
      case ToastType.error:
        return AppColors.error;
      case ToastType.warning:
        return AppColors.warning;
      case ToastType.info:
        return AppColors.info;
    }
  }

  Widget _getIcon() {
    IconData iconData;
    switch (type) {
      case ToastType.success:
        iconData = Icons.check;
        break;
      case ToastType.error:
        iconData = Icons.close;
        break;
      case ToastType.warning:
        iconData = Icons.warning;
        break;
      case ToastType.info:
        iconData = Icons.info;
        break;
    }

    return Icon(
      iconData,
      color: _getIconColor(),
      size: iconSize,
    );
  }
}

/// Overlay widget for displaying toast
class _ToastOverlay extends StatefulWidget {
  final String message;
  final ToastType type;
  final Duration duration;
  final double iconSize;
  final double iconContainerSize;
  final double borderRadius;
  final Widget? customIcon;
  final Color? backgroundColor;
  final TextStyle? textStyle;

  const _ToastOverlay({
    required this.message,
    required this.type,
    required this.duration,
    required this.iconSize,
    required this.iconContainerSize,
    required this.borderRadius,
    this.customIcon,
    this.backgroundColor,
    this.textStyle,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: CommonToast(
              message: widget.message,
              type: widget.type,
              duration: widget.duration,
              iconSize: widget.iconSize,
              iconContainerSize: widget.iconContainerSize,
              borderRadius: widget.borderRadius,
              customIcon: widget.customIcon,
              backgroundColor: widget.backgroundColor,
              textStyle: widget.textStyle,
            ),
          ),
        ),
      ),
    );
  }
}

