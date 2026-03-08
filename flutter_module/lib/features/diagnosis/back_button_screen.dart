import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/responsive_card.dart';
import '../../core/widgets/scan_result_card.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_images_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

enum BackTestState {
  initial,
  readyToTest,
  testing,
  resultReady,
}

class BackButtonScreen extends ConsumerStatefulWidget {
  const BackButtonScreen({super.key});

  @override
  ConsumerState<BackButtonScreen> createState() => _BackButtonScreenState();
}

class _BackButtonScreenState extends ConsumerState<BackButtonScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('back'); // Dynamic progress for screen 8
  BackTestState _currentState = BackTestState.initial;
  bool _backButtonPressed = false;
  bool _testComplete = false;
  bool _showProceedButton = false;
  bool _buttonWorking = false;
  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    // Transition to readyToTest state after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentState = BackTestState.readyToTest;
        });
        _scheduleAutoStartIfNeeded();
      }
    });
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdBack)) return;
    if (_currentState != BackTestState.initial && _currentState != BackTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && (_currentState == BackTestState.initial || _currentState == BackTestState.readyToTest)) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdBack);
  }

  Future<void> _startTest() async {
    setState(() {
      _currentState = BackTestState.testing;
      _backButtonPressed = false;
      _testComplete = false;
      _showProceedButton = false;
    });
  }

  Future<bool> _handleBackButton() async {
    if (_currentState == BackTestState.testing && !_backButtonPressed) {
      setState(() {
        _backButtonPressed = true;
        _buttonWorking = true;
        _testComplete = true;
        _currentState = BackTestState.resultReady;
      });
      
      // Auto-save result as pass (back button was detected)
      TestResultHelper.savePass(ref, TestConfig.testIdBack);
      
      // Auto-navigate after brief delay when test passes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _navigateToNextTest();
          }
        });
      });
      
      // Prevent default back navigation during test
      return false;
    }
    
    // Allow normal back navigation if not testing
    return true;
  }

  Future<void> _navigateToNextTest() async {
    // Reset back button to initial state before navigating
    _resetToInitialState();
    
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
        TestConfig.testIdBack,
      );
    } else {
      debugPrint('❌ BackButtonScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _resetToInitialState() {
    // Reset all state variables to initial values
    setState(() {
      _currentState = BackTestState.initial;
      _backButtonPressed = false;
      _testComplete = false;
      _showProceedButton = false;
      _buttonWorking = false;
    });
    
    // Transition to readyToTest state after reset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentState = BackTestState.readyToTest;
        });
      }
    });
  }

  void _handlePass() {
    TestResultHelper.savePass(ref, TestConfig.testIdBack);
    _navigateToNextTest();
  }

  void _handleFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdBack);
    _navigateToNextTest();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentState != BackTestState.testing,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop && _currentState == BackTestState.testing) {
          _handleBackButton();
        }
      },
      child: Scaffold(
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
                  onSkip: () {
                    TestResultHelper.saveSkip(ref, TestConfig.testIdBack);
                    _navigateToNextTest();
                  },
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

                const SizedBox(height: 24),

                /// Main Content Card
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: 24,
                        right: 24,
                        bottom: _testComplete ? 24 : 180,
                      ),
                      child: _buildContent(),
                    ),
                  ),
                ),

                /// Begin Test Button (only when ready to test or initial, and not auto mode)
                if (_shouldShowStartTestButton() &&
                    (_currentState == BackTestState.readyToTest ||
                        _currentState == BackTestState.initial))
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: CommonButton(
                      text: AppStrings.beginTestButton,
                      onPressed: _startTest,
                    ),
                  ),

                /// Pass/Fail Buttons (only after test completes)
                if (_showProceedButton)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: CommonTwoButtons(
                      leftButtonText: AppStrings.failButton,
                      rightButtonText: AppStrings.passButton,
                      onLeftButtonPressed: _handleFail,
                      onRightButtonPressed: _handlePass,
                    ),
                  ),

                const SizedBox(height: 24),
              ],
            ),

              /// Common Footer with ellipse images - ignorePointer to allow button clicks
              CommonFooter(
                leftEllipsePath: !_testComplete ? AppStrings.ellipse229Path : null,
                rightEllipsePath: !_testComplete ? AppStrings.ellipse230Path : null,
                ignorePointer: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentState) {
      case BackTestState.initial:
      case BackTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdBack,
            isPassed: true,
            localFallbackPath: AppStrings.image53Path,
            fallbackIcon: Icons.arrow_back,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingBackButton,
          subtitleLines: [
            AppStrings.backButtonInstruction,
            'Press the Back button to test.',
          ],
        );
        
      case BackTestState.testing:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdBack,
            isPassed: true,
            localFallbackPath: AppStrings.image53Path,
            fallbackIcon: Icons.arrow_back,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingBackButton,
          subtitleLines: [
            'Press the Back button now.',
            '⏳ Waiting for Back button press...',
          ],
        );
        
      case BackTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdBack,
            isPassed: _buttonWorking,
            localFallbackPath: AppStrings.image53Path,
            fallbackIcon: Icons.arrow_back,
            width: 120,
            height: 120,
          ),
          status: _buttonWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _buttonWorking 
              ? AppStrings.backButtonWorking 
              : 'Back Button Not Working',
          subheadingLines: _buttonWorking
              ? [AppStrings.backButtonWorkingCorrectly]
              : ['Back button was not detected. Please try again.'],
          showStatusIcon: true,
        );
    }
  }
}
