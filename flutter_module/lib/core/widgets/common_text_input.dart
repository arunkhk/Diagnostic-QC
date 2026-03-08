import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// A common text input widget with title, placeholder, and regex validation
/// 
/// Features:
/// - Title/label at the top
/// - Placeholder text
/// - Support for different keyboard types (number, text, email, etc.)
/// - Regex validation with callback on text change
/// - Customizable styling
/// 
/// Example usage:
/// ```dart
/// // For 10-digit mobile number
/// CommonTextInput(
///   editTextTitle: 'Calling Number',
///   editTextPlaceholder: 'Enter 10-digit mobile number',
///   keyboardType: TextInputType.number,
///   regex: r'^\d{10}$',
///   onValidationChanged: (isValid) {
///     print('Validation status: $isValid');
///   },
/// )
/// 
/// // For email validation
/// CommonTextInput(
///   editTextTitle: 'Email Address',
///   editTextPlaceholder: 'Enter your email',
///   keyboardType: TextInputType.emailAddress,
///   regex: r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
///   onValidationChanged: (isValid) {
///     setState(() => _isEmailValid = isValid);
///   },
/// )
/// 
/// // For text with minimum length
/// CommonTextInput(
///   editTextTitle: 'Name',
///   editTextPlaceholder: 'Enter your name',
///   keyboardType: TextInputType.text,
///   regex: r'^.{3,}$', // Minimum 3 characters
///   onValidationChanged: (isValid) {
///     print('Name is valid: $isValid');
///   },
/// )
/// ```
class CommonTextInput extends StatefulWidget {
  /// Title/label text displayed at the top of the input field
  final String editTextTitle;
  
  /// Placeholder/hint text displayed inside the input field
  final String editTextPlaceholder;
  
  /// Keyboard type (number, text, email, phone, etc.)
  final TextInputType keyboardType;
  
  /// Regex pattern for validation (e.g., r'^\d{10}$' for 10 digits, r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' for email)
  final String? regex;
  
  /// Callback function that returns true/false based on regex match
  /// Called whenever the text changes and validation is performed
  final ValueChanged<bool>? onValidationChanged;
  
  /// Optional text controller (if not provided, one will be created internally)
  final TextEditingController? controller;
  
  /// Optional focus node
  final FocusNode? focusNode;
  
  /// Maximum length of input (optional)
  final int? maxLength;
  
  /// Input formatters (optional, e.g., for digits only, etc.)
  final List<TextInputFormatter>? inputFormatters;
  
  /// Custom border color (default: AppColors.border, changes to AppColors.primary on focus)
  final Color? borderColor;
  
  /// Custom title text style
  final TextStyle? titleStyle;
  
  /// Custom placeholder/hint text style
  final TextStyle? placeholderStyle;
  
  /// Custom input text style
  final TextStyle? textStyle;
  
  /// Border radius (default: 12)
  final double? borderRadius;
  
  /// Padding inside the container
  final EdgeInsets? padding;
  
  /// Whether the field is enabled (default: true)
  final bool enabled;
  
  /// Whether to show validation status visually (default: false)
  final bool showValidationStatus;
  
  /// Callback when text changes (optional)
  final ValueChanged<String>? onChanged;

  const CommonTextInput({
    super.key,
    required this.editTextTitle,
    required this.editTextPlaceholder,
    this.keyboardType = TextInputType.text,
    this.regex,
    this.onValidationChanged,
    this.controller,
    this.focusNode,
    this.maxLength,
    this.inputFormatters,
    this.borderColor,
    this.titleStyle,
    this.placeholderStyle,
    this.textStyle,
    this.borderRadius,
    this.padding,
    this.enabled = true,
    this.showValidationStatus = false,
    this.onChanged,
  });

  @override
  State<CommonTextInput> createState() => _CommonTextInputState();
}

class _CommonTextInputState extends State<CommonTextInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isValid = false;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    
    // Listen to focus changes
    _focusNode.addListener(() {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    });
    
    // Listen to text changes for validation
    _controller.addListener(_validateInput);
  }

  @override
  void dispose() {
    // Only dispose if we created the controller/focus node
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _validateInput() {
    final text = _controller.text;
    bool isValid = false;

    if (widget.regex != null && text.isNotEmpty) {
      try {
        final regExp = RegExp(widget.regex!);
        isValid = regExp.hasMatch(text);
      } catch (e) {
        // Invalid regex pattern
        isValid = false;
      }
    } else if (text.isEmpty) {
      // Empty text is considered invalid if regex is provided
      isValid = false;
    } else if (widget.regex == null) {
      // No regex provided, consider any non-empty text as valid
      isValid = true;
    }

    if (_isValid != isValid) {
      setState(() {
        _isValid = isValid;
      });
      // Notify parent about validation status change
      widget.onValidationChanged?.call(isValid);
    } else if (text.isEmpty && widget.regex != null) {
      // Explicitly notify false for empty text when regex is provided
      widget.onValidationChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine border color based on focus and validation status
    Color borderColor = widget.borderColor ?? AppColors.border;
    if (_hasFocus) {
      borderColor = AppColors.primary;
    } else if (widget.showValidationStatus && _controller.text.isNotEmpty) {
      borderColor = _isValid ? AppColors.success : AppColors.error;
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 4),
        color: AppColors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title/Label
          Padding(
            padding: widget.padding ??
                const EdgeInsets.only(
                  left: 16,
                  top: 8,
                  right: 16,
                ),
            child: Text(
              widget.editTextTitle,
              style: widget.titleStyle ??
                  Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color: AppColors.text,
                        fontWeight: FontWeight.w500,
                      ),
            ),
          ),
          
          // Text Input Field
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            enabled: widget.enabled,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            style: widget.textStyle ??
                Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 16,
                      color: AppColors.text,
                    ),
            decoration: InputDecoration(
              hintText: widget.editTextPlaceholder,
              hintStyle: widget.placeholderStyle ??
                  Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 16,
                        color: AppColors.textTertiary,
                      ),
              border: InputBorder.none,
              contentPadding: widget.padding ??
                  const EdgeInsets.symmetric(
                    horizontal: 16,

                  ),
              counterText: '', // Hide character counter if maxLength is set
            ),
            onChanged: (value) {
              widget.onChanged?.call(value);
            },
          ),
        ],
      ),
    );
  }
}

