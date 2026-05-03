import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_config.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_text_input.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/scan_result_card.dart';
import '../../core/widgets/common_toast.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';
import '../../core/widgets/common_test_image.dart';

class NetworkConnectivityScreen extends ConsumerStatefulWidget {
  const NetworkConnectivityScreen({super.key});

  @override
  ConsumerState<NetworkConnectivityScreen> createState() => _NetworkConnectivityScreenState();
}

class _NetworkConnectivityScreenState extends ConsumerState<NetworkConnectivityScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('networks'); // Dynamic progress for screen 15
  final TextEditingController _phoneController = TextEditingController(text: '9217365564');
  bool _isPhoneValid = true; // Set to true since we have a valid prefilled number
  bool _showCallButton = true;
  bool _showTwoButtons = false;
  bool _testComplete = false;
  bool _testPassed = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneValidationChanged(bool isValid) {
    setState(() {
      _isPhoneValid = isValid;
    });
  }

  Future<void> _handleCall() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty || !_isPhoneValid) {
      return;
    }

    // Open phone dialer with prefilled number
    bool dialerOpened = false;
    
    try {
      // Try method 1: Using tel: scheme directly
      final Uri phoneUri = Uri.parse('tel:$phoneNumber');
      try {
        await launchUrl(
          phoneUri,
          mode: LaunchMode.externalApplication,
        );
        dialerOpened = true;
      } catch (e) {
        print('Method 1 failed: $e');
      }

      // Try method 2: Using Uri constructor
      if (!dialerOpened) {
        try {
          final Uri phoneUri2 = Uri(scheme: 'tel', path: phoneNumber);
          await launchUrl(
            phoneUri2,
            mode: LaunchMode.externalApplication,
          );
          dialerOpened = true;
        } catch (e) {
          print('Method 2 failed: $e');
        }
      }

      // Try method 3: Using platform channel as fallback
      if (!dialerOpened) {
        try {
          const platform = MethodChannel(AppConfig.phoneChannel);
          final result = await platform.invokeMethod('openDialer', {'phoneNumber': phoneNumber});
          if (result == true) {
            dialerOpened = true;
          }
        } catch (e) {
          print('Method 3 (platform channel) failed: $e');
        }
      }

      if (!dialerOpened) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open phone dialer. Please dial manually.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      print('Error launching phone dialer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    // After 2 seconds, hide Call button and show two buttons
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showCallButton = false;
          _showTwoButtons = true;
        });
      }
    });
  }

  Future<void> _navigateToNextTest() async {
    final testParametersAsyncValue = ref.read(testParametersProvider);
    List<TestParameterItem>? testParameters;

    if (testParametersAsyncValue.hasValue) {
      testParameters = testParametersAsyncValue.value;
    } else {
      await Future.delayed(const Duration(milliseconds: 200));
      final updatedValue = ref.read(testParametersProvider);
      if (updatedValue.hasValue) {
        testParameters = updatedValue.value;
      }
    }

    if (testParameters != null) {
      TestNavigationService.navigateToNextTest(
        context,
        testParameters,
        TestConfig.testIdNetworks,
      );
    } else {
      debugPrint('❌ NetworkConnectivityScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handlePass() {
    setState(() {
      _testComplete = true;
      _testPassed = true;
      _showTwoButtons = false;
    });

    // Save Network Connectivity test result as pass (uses API paramValue and catIcon)
    TestResultHelper.savePass(ref, TestConfig.testIdNetworks);

    // Show success toast
    CommonToast.showSuccess(
      context,
      message: AppStrings.callConnectedToast,
    );
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleFail() {
    setState(() {
      _testComplete = true;
      _testPassed = false;
      _showTwoButtons = false;
    });
    
    // Save Network Connectivity test result as fail (uses API paramValue and catIcon)
    TestResultHelper.saveFail(ref, TestConfig.testIdNetworks);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleSkip() {
    // Mark Network Connectivity test as skipped (uses API paramValue and catIcon)
    TestResultHelper.saveSkip(ref, TestConfig.testIdNetworks);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
          child: Stack(
        children: [
          Column(
            children: [
              /// Common Header with Skip button
              CommonHeader(
                title: AppStrings.welcomeTitle,
                version: AppStrings.appVersion,
                onBack: () => Navigator.of(context).pop(),
                onSkip: _handleSkip,
                skipText: AppStrings.skipButton,
              ),

              /// Progress Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(_screenProgress * 100).toInt()}% complete',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _screenProgress,
                        backgroundColor: AppColors.surface,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              /// Main Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _testComplete
                      ? _testPassed
                          ? // Success state - ScanResultCard
                          ScanResultCard(
                              customImageWidget: CommonTestImage(
                                screenName: TestConfig.testIdNetworks,
                                isPassed: true,
                                localFallbackPath: AppStrings.image80Path,
                                fallbackIcon: Icons.signal_cellular_alt,
                                width: 120,
                                height: 120,
                              ),
                              status: ScanStatus.passed,
                              title: AppStrings.networkConnectivitySuccess,
                              subheadingLines: [
                                AppStrings.networkConnectivitySuccess,
                              ],
                            )
                          : // Failure state - ScanResultCard
                          ScanResultCard(
                              customImageWidget: CommonTestImage(
                                screenName: TestConfig.testIdNetworks,
                                isPassed: false,
                                localFallbackPath: AppStrings.image80Path,
                                fallbackIcon: Icons.signal_cellular_alt,
                                width: 120,
                                height: 120,
                              ),
                              status: ScanStatus.failed,
                              title: AppStrings.networkConnectivityFailed,
                              subheadingLines: [
                                AppStrings.networkConnectivityFailed,
                              ],
                            )
                      : // Initial state
                      SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Image, Heading, Subheading
                              CommonContentWidget(
                                customImageWidget: CommonTestImage(
                                  screenName: TestConfig.testIdNetworks,
                                  isPassed: true,
                                  localFallbackPath: AppStrings.image80Path,
                                  fallbackIcon: Icons.signal_cellular_alt,
                                  width: 120,
                                  height: 120,
                                ),
                                heading: AppStrings.checkingNetworkConnectivity,
                                subheading: AppStrings.networkConnectivityInstruction,
                              ),

                              const SizedBox(height: 32),

                              // Phone Number Input
                              CommonTextInput(
                                editTextTitle: AppStrings.callingNumber,
                                editTextPlaceholder: AppStrings.enterMobileNumber,
                                keyboardType: TextInputType.number,
                                regex: r'^\d{10}$',
                                controller: _phoneController,
                                onValidationChanged: _onPhoneValidationChanged,
                                maxLength: 10,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                ),
              ),

              /// Bottom Buttons
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Call Button (shown initially)
                    if (_showCallButton)
                      CommonButton(
                        text: AppStrings.callButton,
                        onPressed: _isPhoneValid ? _handleCall : null,
                        enabled: _isPhoneValid,
                      ),

                    // Two Buttons (shown after 2 seconds)
                    if (_showTwoButtons)
                      CommonTwoButtons(
                        leftButtonText: AppStrings.failButton ,
                        rightButtonText: AppStrings.passButton,
                        onLeftButtonPressed: _handleFail ,
                        onRightButtonPressed: _handlePass,
                      ),

                    // Proceed Button (shown on success)
                    if (_testComplete && _testPassed)
                      CommonButton(
                        text: AppStrings.proceedButton,
                        onPressed: () {
                          // Navigate to next test based on API order
                          _navigateToNextTest();
                        },
                      ),

                    // Proceed Anyway Button (shown on failure)
                    if (_testComplete && !_testPassed)
                      CommonButton(
                        text: AppStrings.proceedAnywayButton,
                        onPressed: () {
                          // Navigate to next test based on API order
                          _navigateToNextTest();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),

          /// Common Footer (shown during test)
          if (!_testComplete && _showTwoButtons)
            const CommonFooter(),
        ],
        ),
      ),
    );
  }
}

