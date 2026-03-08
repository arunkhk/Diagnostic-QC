import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class CommonHeader extends StatelessWidget {
  final String title;
  final String version;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String? skipText;
  final VoidCallback? onLogout;
  final bool showLogout;

  const CommonHeader({
    super.key,
    required this.title,
    required this.version,
    this.onBack,
    this.onSkip,
    this.skipText,
    this.onLogout,
    this.showLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Only show back button if onBack is provided
          if (onBack != null)
            InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: AppColors.text,
                ),
              ),
            ),
          if (onBack != null) const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title (v. $version)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
            ),
          ),
          if (showLogout && onLogout != null)
            InkWell(
              onTap: onLogout,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.logout,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Logout',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          if (onSkip != null && !showLogout)
            InkWell(
              onTap: onSkip,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  skipText ?? 'Skip >>',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

