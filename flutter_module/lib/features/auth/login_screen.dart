import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_text_field.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/providers/api_loading_provider.dart';
import 'forgot_password_screen.dart';
import 'privacy_policy_screen.dart';
import 'user_agreement_screen.dart';
import 'providers/auth_provider.dart';
import '../permissions/permissions_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Organization and office IDs (these may need to be configurable in the future)
  static const int orgId = 101;
  static const int officeId = 2;
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _employeeIdFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  
  bool _isPasswordVisible = false;
  bool _isPrivacyPolicyChecked = false;
  bool _isEmployeeIdValid = false;
  bool _isPasswordValid = false;
  bool _isSignInEnabled = false;

  @override
  void initState() {
    super.initState();
    _employeeIdController.addListener(_updateSignInButton);
    _passwordController.addListener(_updateSignInButton);
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    _employeeIdFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _updateSignInButton() {
    setState(() {
      _isSignInEnabled = _isEmployeeIdValid && 
                        _isPasswordValid && 
                        _isPrivacyPolicyChecked;
    });
  }

  Future<void> _handleSignIn() async {
    if (!_isSignInEnabled) return;

    // Get dynamic values from text fields
    final username = _employeeIdController.text.trim();
    final password = _passwordController.text.trim();

    // Validate that fields are not empty
    if (username.isEmpty || password.isEmpty) {
      CommonToast.showError(
        context,
        message: 'Please enter both username and password',
      );
      return;
    }

    // Show loading
    final authNotifier = ref.read(authProvider.notifier);
    
    // Call login API with dynamic values
    final response = await authNotifier.login(
      username: username,
      password: password,
      orgId: orgId,
      officeId: officeId,
    );

    if (!mounted) return;

    if (response.success && response.data != null) {
      // Success - navigate to permissions screen
      CommonToast.showSuccess(
        context,
        message: 'Login successful',
      );
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const PermissionsScreen(),
        ),
      );
    } else {
      // Error - show error message
      final errorMessage = response.errorMessage ?? 'Login failed';
      CommonToast.showError(
        context,
        message: errorMessage,
      );
    }
  }

  void _handleForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );
  }

  void _handlePrivacyPolicyClick() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  void _handleUserAgreementClick() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UserAgreementScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      resizeToAvoidBottomInset: false, // Don't resize when keyboard appears
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
                    const SizedBox(height: 40),
                    
                    // Title: Smart Diagnosis (Centered with Shadow)
                    Center(
                      child: Text(
                        AppStrings.smartDiagnosisTitle,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              shadows: [
                                Shadow(
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                  color: AppColors.primary.withOpacity(0.3),
                                ),
                              ],
                            ),
                      ),
                    ),
                    
                    const SizedBox(height: 50),
                    // Subtitle: Sign in to your account
                    Text(
                      AppStrings.signInToAccount,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Employee ID Input
                    CommonTextField(
                      label: AppStrings.employeeId,
                      placeholder: AppStrings.enterEmployeeId,
                      keyboardType: TextInputType.text,
                      controller: _employeeIdController,
                      focusNode: _employeeIdFocus,
                      onChanged: (value) {
                        setState(() {
                          _isEmployeeIdValid = value.isNotEmpty;
                        });
                        _updateSignInButton();
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Password Input
                    CommonTextField(
                      label: AppStrings.password,
                      placeholder: AppStrings.enterPassword,
                      keyboardType: TextInputType.text,
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                      onChanged: (value) {
                        setState(() {
                          _isPasswordValid = value.isNotEmpty;
                        });
                        _updateSignInButton();
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Forgot Password Link
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _handleForgotPassword,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          AppStrings.forgotPassword,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 14,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Privacy Policy Checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _isPrivacyPolicyChecked,
                          onChanged: (value) {
                            setState(() {
                              _isPrivacyPolicyChecked = value ?? false;
                            });
                            _updateSignInButton();
                          },
                          activeColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 14,
                                      color: AppColors.text,
                                      height: 1.4,
                                    ),
                                children: [
                                  const TextSpan(text: "I've read and agreed to "),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: _handleUserAgreementClick,
                                      child: Text(
                                        AppStrings.userAgreement,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontSize: 14,
                                              color: AppColors.primaryDark,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const TextSpan(text: ' and '),
                                  WidgetSpan(
                                    child: GestureDetector(
                                      onTap: _handlePrivacyPolicyClick,
                                      child: Text(
                                        AppStrings.privacyPolicy,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              fontSize: 14,
                                              color: AppColors.primaryDark,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Sign In Button (Fixed at bottom)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Consumer(
                builder: (context, ref, child) {
                  // Use global API loading state instead of auth provider loading
                  final apiLoadingState = ref.watch(apiLoadingProvider);
                  final isLoading = apiLoadingState.isLoading;
                  
                  return CommonButton(
                    text: AppStrings.signIn,
                    enabled: _isSignInEnabled && !isLoading,
                    isLoading: isLoading,
                    onPressed: (_isSignInEnabled && !isLoading) ? _handleSignIn : null,
                    height: 52,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

