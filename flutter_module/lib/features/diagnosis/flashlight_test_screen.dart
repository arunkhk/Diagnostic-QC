import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:torch_light/torch_light.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_text_input.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_toggle.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

class FlashlightTestScreen extends ConsumerStatefulWidget {
  const FlashlightTestScreen({super.key});

  @override
  ConsumerState<FlashlightTestScreen> createState() => _FlashlightTestScreenState();
}

class _FlashlightTestScreenState extends ConsumerState<FlashlightTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('flashlight'); // Dynamic progress for screen 17
  final TextEditingController _countController = TextEditingController();
  bool _toggleValue = false;
  bool _showInputScreen = false;
  bool _isCountValid = false;
  int _randomFlashCount = 0;
  final Random _random = Random();

  @override
  void dispose() {
    _countController.dispose();
    // Turn off flashlight when leaving screen
    _setFlashlight(false);
    super.dispose();
  }

  void _onCountValidationChanged(bool isValid) {
    final enteredCount = _countController.text.trim();
    print('🔍 Count validation changed: isValid=$isValid, text=$enteredCount');
    
    setState(() {
      _isCountValid = isValid;
    });

    // Show toast when valid count is entered
    if (isValid && enteredCount.isNotEmpty && _randomFlashCount > 0) {
      final enteredInt = int.tryParse(enteredCount);
      if (enteredInt != null) {
        if (enteredInt == _randomFlashCount) {
          // Success - show pass toast
          print('✅ Flash count matches! Showing success toast');
          CommonToast.showSuccess(
            context,
            message: AppStrings.flashlightWorkingToast,
          );
          
          // Auto-save result as pass (correct count entered)
          TestResultHelper.savePass(ref, TestConfig.testIdFlashlight);
          
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
          print('❌ Flash count does not match: entered=$enteredInt, expected=$_randomFlashCount');
          CommonToast.showError(
            context,
            message: AppStrings.flashlightNotWorkingToast,
          );
        }
      }
    }
  }

  void _onToggleChanged(bool isOn) {
    setState(() {
      _toggleValue = isOn;
    });
    print('🔦 Toggle changed: $isOn');
  }

  void _onToggleTurnedOn() {
    print('🔦 Toggle turned ON - starting flashlight cycle');
    _startFlashlightCycle();
  }

  Future<void> _setFlashlight(bool isOn) async {
    try {
      if (isOn) {
        await TorchLight.enableTorch();
      } else {
        await TorchLight.disableTorch();
      }
      print('🔦 Flashlight set to: $isOn');
    } catch (e) {
      print('❌ Error setting flashlight: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error controlling flashlight: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startFlashlightCycle() async {
    // Generate random number between 1-5
    _randomFlashCount = _random.nextInt(5) + 1; // 1-5
    print('🔦 Starting flashlight cycle: $_randomFlashCount flashes');

    // Turn off initially
    await _setFlashlight(false);
    await Future.delayed(const Duration(milliseconds: 300));

    // Flash the flashlight _randomFlashCount times
    for (int i = 0; i < _randomFlashCount; i++) {
      if (!mounted) break;
      
      // Turn on
      await _setFlashlight(true);
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Turn off
      await _setFlashlight(false);
      
      // Pause between flashes (except after last one)
      if (i < _randomFlashCount - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    // Ensure flashlight is off after cycle
    await _setFlashlight(false);

    // Show input screen after cycle completes
    if (mounted) {
      setState(() {
        _showInputScreen = true;
        _toggleValue = false; // Reset toggle to OFF
      });
    }
  }

  Future<void> _navigateToNextTest() async {
    // Turn off flashlight before navigating
    _setFlashlight(false);
    
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
        TestConfig.testIdFlashlight,
      );
    } else {
      debugPrint('❌ FlashlightTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleSubmit() {
    final enteredCount = _countController.text.trim();
    
    if (enteredCount.isEmpty || !_isCountValid) {
      return;
    }

    // Determine if test passed or failed based on count match
    final enteredInt = int.tryParse(enteredCount);
    final testPassed = enteredInt != null && enteredInt == _randomFlashCount;
    
    // Save Flashlight test result (if not already saved by auto-navigation)
    if (testPassed) {
      TestResultHelper.savePass(ref, TestConfig.testIdFlashlight);
    } else {
      TestResultHelper.saveFail(ref, TestConfig.testIdFlashlight);
    }
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleSkip() {
    // Turn off flashlight before navigating
    _setFlashlight(false);
    TestResultHelper.saveSkip(ref, TestConfig.testIdFlashlight);
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
                onBack: () {
                  _setFlashlight(false);
                  Navigator.of(context).pop();
                },
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
                            screenName: TestConfig.testIdFlashlight,
                            isPassed: true,
                            localFallbackPath: AppStrings.image87Path,
                            fallbackIcon: Icons.flashlight_on,
                            width: 120,
                            height: 120,
                          ),
                          heading: AppStrings.testingFlashlight,
                          subheading: _showInputScreen
                              ? AppStrings.flashlightTestInstructionWithInput
                              : AppStrings.flashlightTestInstruction,
                        ),

                        const SizedBox(height: 60),

                        // Toggle Switch (shown in initial state)
                        if (!_showInputScreen)
                          Center(
                            child: CommonToggle(
                              text: '',
                              value: _toggleValue,
                              onChanged: _onToggleChanged,
                              onTurnedOn: _onToggleTurnedOn,
                            ),
                          ),


                        // Input field (shown in second screen)
                        if (_showInputScreen) ...[
                          CommonTextInput(
                            editTextTitle: AppStrings.flashlightNumberLabel,
                            editTextPlaceholder:
                                AppStrings.flashlightNumberPlaceholder,
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

