import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vibration/vibration.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_text_input.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

class VibrationTestScreen extends ConsumerStatefulWidget {
  const VibrationTestScreen({super.key});

  @override
  ConsumerState<VibrationTestScreen> createState() => _VibrationTestScreenState();
}

class _VibrationTestScreenState extends ConsumerState<VibrationTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('vibration'); // Dynamic progress for screen 18
  final TextEditingController _countController = TextEditingController();
  bool _showInputScreen = false;
  bool _isCountValid = false;
  int _randomVibrationCount = 0;
  final Random _random = Random();

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  void _onCountValidationChanged(bool isValid) {
    final enteredCount = _countController.text.trim();
    print('🔍 Count validation changed: isValid=$isValid, text=$enteredCount');
    
    setState(() {
      _isCountValid = isValid;
    });

    // Show toast when valid count is entered
    if (isValid && enteredCount.isNotEmpty && _randomVibrationCount > 0) {
      final enteredInt = int.tryParse(enteredCount);
      if (enteredInt != null) {
        if (enteredInt == _randomVibrationCount) {
          // Success - show pass toast
          print('✅ Vibration count matches! Showing success toast');
          CommonToast.showSuccess(
            context,
            message: AppStrings.vibrationWorkingToast,
          );
          
          // Auto-save result as pass (correct count entered)
          TestResultHelper.savePass(ref, TestConfig.testIdVibration);
          
          // Auto-navigate after brief delay when test passes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _navigateToNextTest();
              }
            });
          });
        } else {
          // Failure - show fail toast (no auto-navigation on fail)
          print('❌ Vibration count does not match: entered=$enteredInt, expected=$_randomVibrationCount');
          CommonToast.showError(
            context,
            message: AppStrings.vibrationNotWorkingToast,
          );
        }
      }
    }
  }

  Future<void> _vibrate() async {
    try {
      // Check if device has vibration capability
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Device does not support vibration'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Vibrate for 1 second (1000ms) using the new API
      Vibration.vibrate(duration: 1000);
    } catch (e) {
      print('❌ Error vibrating: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error vibrating: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startVibrationCycle() async {
    // Generate random number between 1-5
    _randomVibrationCount = _random.nextInt(5) + 1; // 1-5
    print('📳 Starting vibration cycle: $_randomVibrationCount vibrations');

    // Vibrate _randomVibrationCount times
    for (int i = 0; i < _randomVibrationCount; i++) {
      if (!mounted) break;
      
      // Vibrate for 1 second
      _vibrate();
      
      // Wait for vibration to complete (1 second)
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Pause between vibrations (except after last one)
      if (i < _randomVibrationCount - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Show input screen after cycle completes
    if (mounted) {
      setState(() {
        _showInputScreen = true;
      });
    }
  }

  void _handleSubmit() {
    final enteredCount = _countController.text.trim();
    
    if (enteredCount.isEmpty || !_isCountValid) {
      return;
    }

    // Determine if test passed or failed based on count match
    final enteredInt = int.tryParse(enteredCount);
    final testPassed = enteredInt != null && enteredInt == _randomVibrationCount;
    
    // Save Vibration test result (if not already saved by auto-navigation)
    if (testPassed) {
      TestResultHelper.savePass(ref, TestConfig.testIdVibration);
    } else {
      TestResultHelper.saveFail(ref, TestConfig.testIdVibration);
    }

    // Navigate to camera test screen
    _navigateToNextTest();
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
        TestConfig.testIdVibration,
      );
    } else {
      debugPrint('❌ VibrationTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdVibration);
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
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image, Heading, Subheading
                        CommonContentWidget(
                          customImageWidget: CommonTestImage(
                            screenName: TestConfig.testIdVibration,
                            isPassed: true,
                            localFallbackPath: AppStrings.image104Path,
                            fallbackIcon: Icons.vibration,
                            width: 120,
                            height: 120,
                          ),
                          heading: AppStrings.testingVibration,
                          subheading: _showInputScreen
                              ? AppStrings.vibrationTestInstructionWithInput
                              : AppStrings.vibrationTestInstruction,
                        ),

                        const SizedBox(height: 60),

                        // Input field (shown in second screen)
                        if (_showInputScreen) ...[
                          CommonTextInput(
                            editTextTitle: AppStrings.vibrationNumberLabel,
                            editTextPlaceholder:
                                AppStrings.vibrationNumberPlaceholder,
                            keyboardType: TextInputType.number,
                            regex: r'^[1-5]$', // Single digit 1-5
                            controller: _countController,
                            onValidationChanged: _onCountValidationChanged,
                            maxLength: 1,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[1-5]')),
                            ],
                          ),
                        ],
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
                    // Start Vibration Button (initial state)
                    if (!_showInputScreen)
                      CommonButton(
                        text: AppStrings.startVibrationButton,
                        onPressed: _startVibrationCycle,
                      ),

                    // Submit Button (shown in input screen)
                    if (_showInputScreen)
                      CommonButton(
                        text: AppStrings.submitButton,
                        onPressed: _isCountValid ? _handleSubmit : null,
                        enabled: _isCountValid,
                      ),
                  ],
                ),
              ),
            ],
          ),

          /// Common Footer (shown during test)
          if (_showInputScreen)
            const CommonFooter(),
        ],
        ),
      ),
    );
  }
}

