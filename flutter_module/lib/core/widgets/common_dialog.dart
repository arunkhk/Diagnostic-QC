import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Common dialog widget for showing feature enablement messages
class CommonDialog extends StatelessWidget {
  const CommonDialog({
    super.key,
    required this.message,
    this.title,
    this.isDismissible = true,
    this.onCancel,
    this.onProceed,
    this.cancelText,
    this.proceedText,
  });

  final String message;
  final String? title;
  final bool isDismissible;
  final VoidCallback? onCancel;
  final VoidCallback? onProceed;
  final String? cancelText;
  final String? proceedText;

  /// Show dialog with custom message
  static Future<bool?> show(
    BuildContext context, {
    required String message,
    String? title,
    bool isDismissible = true,
    VoidCallback? onCancel,
    VoidCallback? onProceed,
    String? cancelText,
    String? proceedText,
  }) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (context) => CommonDialog(
        message: message,
        title: title,
        isDismissible: isDismissible,
        onCancel: onCancel,
        onProceed: onProceed,
        cancelText: cancelText,
        proceedText: proceedText,
      ),
    );
  }

  /// Show device diagnosis dialog
  static Future<bool?> showDeviceDiagnosisDialog(
    BuildContext context, {
    required String message,
    String? title,
    bool isDismissible = true,
    VoidCallback? onCancel,
    VoidCallback? onProceed,
    String? cancelText,
    String? proceedText,
  }) async {
    return await show(
      context,
      message: message,
      title: title,
      isDismissible: isDismissible,
      onCancel: onCancel,
      onProceed: onProceed,
      cancelText: cancelText,
      proceedText: proceedText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title != null ? Text(title!) : null,
      content: Text(message),
      actions: [
        if (cancelText != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              onCancel?.call();
            },
            child: Text(cancelText!),
          ),
        if (proceedText != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(true);
              onProceed?.call();
            },
            child: Text(proceedText!),
          ),
      ],
    );
  }
}

