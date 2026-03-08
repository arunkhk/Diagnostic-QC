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
import '../../core/widgets/common_test_image.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

class SarLevelTestScreen extends ConsumerStatefulWidget {
  const SarLevelTestScreen({super.key});

  @override
  ConsumerState<SarLevelTestScreen> createState() => _SarLevelTestScreenState();
}

class _SarLevelTestScreenState extends ConsumerState<SarLevelTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('sar'); // Dynamic progress for screen 29
  final TextEditingController _ussdController = TextEditingController(text: '*#07#');
  bool _isUssdValid = false;
  bool _showCheckButton = true;
  bool _showTwoButtons = false;
  bool _testComplete = false;
  bool _testPassed = false;

  @override
  void initState() {
    super.initState();
    // USSD code is pre-filled, so mark as valid
    _isUssdValid = true;
  }

  @override
  void dispose() {
    _ussdController.dispose();
    super.dispose();
  }

  void _onUssdValidationChanged(bool isValid) {
    setState(() {
      _isUssdValid = isValid;
    });
  }

  Future<void> _handleCheckSarLevel() async {
    final ussdCode = _ussdController.text.trim();
    if (ussdCode.isEmpty || !_isUssdValid) {
      return;
    }

    // Open phone dialer with prefilled USSD code
    bool dialerOpened = false;
    
    try {
      // Try method 1: Using tel: scheme directly
      final Uri ussdUri = Uri.parse('tel:$ussdCode');
      try {
        await launchUrl(
          ussdUri,
          mode: LaunchMode.externalApplication,
        );
        dialerOpened = true;
      } catch (e) {
        print('Method 1 failed: $e');
      }

      // Try method 2: Using Uri constructor
      if (!dialerOpened) {
        try {
          final Uri ussdUri2 = Uri(scheme: 'tel', path: ussdCode);
          await launchUrl(
            ussdUri2,
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
          final result = await platform.invokeMethod('openDialer', {'phoneNumber': ussdCode});
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

    // After 2 seconds, hide Check button and show two buttons
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showCheckButton = false;
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
      // If still loading, wait a bit and try again
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
        TestConfig.testIdSar,
      );
    } else {
      debugPrint('❌ SarLevelTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handlePass() {
    setState(() {
      _testComplete = true;
      _testPassed = true;
      _showTwoButtons = false;
    });

    // Save SAR Level test result as pass (uses API paramValue and catIcon)
    TestResultHelper.savePass(ref, TestConfig.testIdSar);

    // Show success toast
    CommonToast.showSuccess(
      context,
      message: AppStrings.sarLevelCheckedToast,
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
    
    // Save SAR Level test result as fail (uses API paramValue and catIcon)
    TestResultHelper.saveFail(ref, TestConfig.testIdSar);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleSkip() {
    // Mark SAR Level test as skipped (uses API paramValue and catIcon)
    TestResultHelper.saveSkip(ref, TestConfig.testIdSar);
    
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
                                screenName: TestConfig.testIdSar,
                                isPassed: true,
                                localFallbackPath: AppStrings.image122Path,
                                fallbackIcon: Icons.science,
                                width: 120,
                                height: 120,
                              ),
                              status: ScanStatus.passed,
                              title: AppStrings.sarLevelCheckedSuccess,
                              subheadingLines: [
                                AppStrings.sarLevelCheckedSuccess,
                              ],
                            )
                          : // Failure state - ScanResultCard
                          ScanResultCard(
                              customImageWidget: CommonTestImage(
                                screenName: TestConfig.testIdSar,
                                isPassed: false,
                                localFallbackPath: AppStrings.image122Path,
                                fallbackIcon: Icons.science,
                                width: 120,
                                height: 120,
                              ),
                              status: ScanStatus.failed,
                              title: AppStrings.sarLevelCheckedFailed,
                              subheadingLines: [
                                AppStrings.sarLevelCheckedFailed,
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
                                  screenName: TestConfig.testIdSar,
                                  isPassed: true,
                                  localFallbackPath: AppStrings.image122Path,
                                  fallbackIcon: Icons.science,
                                  width: 120,
                                  height: 120,
                                ),
                                heading: AppStrings.checkingSarLevel,
                                subheading: AppStrings.sarLevelInstruction,
                              ),

                              const SizedBox(height: 32),

                              // USSD Code Input
                              CommonTextInput(
                                editTextTitle: AppStrings.ussdCode,
                                editTextPlaceholder: AppStrings.enterUssdCode,
                                keyboardType: TextInputType.text,
                                regex: r'^[*#0-9]+$',
                                controller: _ussdController,
                                onValidationChanged: _onUssdValidationChanged,
                                maxLength: 20,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[*#0-9]')),
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
                    // Check SAR Level Button (shown initially)
                    if (_showCheckButton)
                      CommonButton(
                        text: AppStrings.checkSarLevelButton,
                        onPressed: _isUssdValid ? _handleCheckSarLevel : null,
                        enabled: _isUssdValid,
                      ),

                    // Two Buttons (shown after 2 seconds)
                    if (_showTwoButtons)
                      CommonTwoButtons(
                        leftButtonText: AppStrings.failButton,
                        rightButtonText: AppStrings.passButton,
                        onLeftButtonPressed:_handleFail ,
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

