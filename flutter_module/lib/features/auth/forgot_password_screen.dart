import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailOrPhoneController = TextEditingController();
  final FocusNode _emailOrPhoneFocus = FocusNode();
  bool _isEmailOrPhoneValid = false;

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _emailOrPhoneFocus.dispose();
    super.dispose();
  }

  bool _validateEmailOrPhone(String value) {
    // Email validation regex
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    // Phone validation regex (supports various formats: 10 digits, with/without country code, with/without dashes/spaces)
    final phoneRegex = RegExp(r'^[\d\s\-\(\)\+]{10,}$');
    
    // Remove spaces, dashes, parentheses, and + for phone validation
    final cleanedPhone = value.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    final isPhone = cleanedPhone.length >= 10 && RegExp(r'^\d+$').hasMatch(cleanedPhone);
    
    return emailRegex.hasMatch(value) || isPhone;
  }

  void _handleResetPassword() {
    if (_isEmailOrPhoneValid) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.passwordResetSent),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.forgotPassword,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Content Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    
                    // Description
                    Text(
                      AppStrings.forgotPasswordDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Email or Phone Input
                    CommonTextField(
                      label: AppStrings.emailOrPhone,
                      placeholder: AppStrings.enterEmailOrPhone,
                      keyboardType: TextInputType.emailAddress,
                      controller: _emailOrPhoneController,
                      focusNode: _emailOrPhoneFocus,
                      onChanged: (value) {
                        setState(() {
                          _isEmailOrPhoneValid = _validateEmailOrPhone(value);
                        });
                      },
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Reset Password Button (Fixed at bottom)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: CommonButton(
                text: AppStrings.resetPassword,
                enabled: _isEmailOrPhoneValid,
                onPressed: _isEmailOrPhoneValid ? _handleResetPassword : null,
                height: 52,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

