import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_config.dart';
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

enum HomeTestState {
  readyToTest,
  testing,
  resultReady,
}

class HomeButtonScreen extends ConsumerStatefulWidget {
  const HomeButtonScreen({super.key});

  @override
  ConsumerState<HomeButtonScreen> createState() => _HomeButtonScreenState();
}

class _HomeButtonScreenState extends ConsumerState<HomeButtonScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('home'); // Dynamic progress for screen 10
  HomeTestState _currentState = HomeTestState.readyToTest;
  bool _homeButtonPressed = false;
  bool _testComplete = false;
  bool _showProceedButton = false;
  bool _buttonWorking = false;
  
  StreamSubscription<dynamic>? _buttonSubscription;
  static const EventChannel _buttonChannel = EventChannel(AppConfig.buttonEventChannel);
  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdHome)) return;
    if (_currentState != HomeTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == HomeTestState.readyToTest) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdHome);
  }

  @override
  void dispose() {
    _buttonSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startTest() async {
    setState(() {
      _currentState = HomeTestState.testing;
      _homeButtonPressed = false;
      _testComplete = false;
      _showProceedButton = false;
    });
    
    // Start listening for button events
    try {
      _buttonSubscription = _buttonChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event == 'home' && _currentState == HomeTestState.testing) {
            _handleHomeButtonPress();
          }
        },
        onError: (error) {
          print('❌ Button channel error: $error');
        },
      );
    } catch (e) {
      print('❌ Error listening to button channel: $e');
    }
    
    // After 2 seconds, show pass/fail buttons regardless of button press
    Future.delayed(const Duration(seconds: 2), () {
      if (_currentState == HomeTestState.testing) {
        if (mounted) {
          setState(() {

            _testComplete = true;
            _currentState = HomeTestState.resultReady;
            _showProceedButton = true;
          });
        }
      }
    });
  }

  void _handleHomeButtonPress() {
    if (mounted && _currentState == HomeTestState.testing && !_homeButtonPressed) {
      setState(() {
        _homeButtonPressed = true;
        _buttonWorking = true;
        _testComplete = true;
        _currentState = HomeTestState.resultReady;
      });
      
      // Stop listening
      _buttonSubscription?.cancel();
      
      // Save Home Button test result as pass when button is detected (uses API paramValue and catIcon)
      TestResultHelper.savePass(ref, TestConfig.testIdHome);
      
      // Show proceed button immediately if test is complete
        if (mounted) {
          setState(() {
            _showProceedButton = true;
          });
        }
    }
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
        TestConfig.testIdHome,
      );
    } else {
      debugPrint('❌ HomeButtonScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handlePass() {
    TestResultHelper.savePass(ref, TestConfig.testIdHome);
    _navigateToNextTest();
  }

  void _handleFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdHome);
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
                onSkip: () {
                  // Mark Home Button test as skipped (uses API paramValue and catIcon)
                  TestResultHelper.saveSkip(ref, TestConfig.testIdHome);
                  
                  // Navigate to next test based on API order
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

              /// Begin Test Button (only when ready to test, and not auto mode)
              if (_shouldShowStartTestButton() && _currentState == HomeTestState.readyToTest)
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
    );
  }

  Widget _buildContent() {
    switch (_currentState) {
      case HomeTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdHome,
            isPassed: true,
            localFallbackPath: AppStrings.image79Path,
            fallbackIcon: Icons.home,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingHomeButton,
          subtitleLines: [
            AppStrings.homeButtonInstruction,
            'Press the Home button to test.',
          ],
        );
        
      case HomeTestState.testing:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdHome,
            isPassed: true,
            localFallbackPath: AppStrings.image79Path,
            fallbackIcon: Icons.home,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingHomeButton,
          subtitleLines: [
            'Press the Home button now.',
            '⏳ Waiting for Home button press...',
            'Note: This will minimize the app.',
          ],
        );
        
      case HomeTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdHome,
            isPassed: _homeButtonPressed && _buttonWorking,
            localFallbackPath: AppStrings.image79Path,
            fallbackIcon: Icons.home,
            width: 120,
            height: 120,
          ),
          status: _homeButtonPressed && _buttonWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _homeButtonPressed && _buttonWorking
              ? AppStrings.homeButtonWorking 
              : 'Home Button Test',
          subheadingLines: _homeButtonPressed && _buttonWorking
              ? [AppStrings.homeButtonWorkingCorrectly]
              : ['Please mark the test as Pass or Fail based on your testing.'],
          showStatusIcon: _homeButtonPressed && _buttonWorking,
        );
    }
  }
}
