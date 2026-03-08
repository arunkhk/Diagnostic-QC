import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// A simple text field widget designed for login screens
/// Features:
/// - Label above the input field
/// - Clean border design
/// - Placeholder text inside the field
/// - Optional suffix icon (for password visibility toggle)
class CommonTextField extends StatelessWidget {
  /// Label text displayed above the input field
  final String label;
  
  /// Placeholder/hint text displayed inside the input field
  final String placeholder;
  
  /// Text editing controller
  final TextEditingController? controller;
  
  /// Focus node
  final FocusNode? focusNode;
  
  /// Whether the field is a password field (obscures text)
  final bool obscureText;
  
  /// Keyboard type
  final TextInputType keyboardType;
  
  /// Suffix icon widget (e.g., password visibility toggle)
  final Widget? suffixIcon;
  
  /// Callback when text changes
  final ValueChanged<String>? onChanged;
  
  /// Whether the field is enabled
  final bool enabled;
  
  /// Text input formatters
  final List<TextInputFormatter>? inputFormatters;
  
  /// Maximum length
  final int? maxLength;

  const CommonTextField({
    super.key,
    required this.label,
    required this.placeholder,
    this.controller,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.onChanged,
    this.enabled = true,
    this.inputFormatters,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
        ),
        const SizedBox(height: 8),
        
        // Text Field
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          enabled: enabled,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: AppColors.text,
              ),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  color: AppColors.textTertiary,
                ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: AppColors.border,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: AppColors.border,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: AppColors.border,
                width: 1,
              ),
            ),
            suffixIcon: suffixIcon,
            counterText: '', // Hide character counter if maxLength is set
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

