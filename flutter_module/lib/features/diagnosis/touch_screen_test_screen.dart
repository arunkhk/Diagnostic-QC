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
import '../../core/widgets/common_test_image.dart';
import '../../core/widgets/responsive_card.dart';
import '../../core/widgets/scan_result_card.dart';
import '../../core/widgets/touch_grid_view.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_images_provider.dart';
import 'models/test_parameter_item.dart';

class TouchScreenTestScreen extends ConsumerStatefulWidget {
  const TouchScreenTestScreen({super.key});

  @override
  ConsumerState<TouchScreenTestScreen> createState() => _TouchScreenTestScreenState();
}
class _TouchScreenTestScreenState extends ConsumerState<TouchScreenTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('touch');
  bool _testStarted = false;
  bool _testComplete = false;
  bool? _touchScreenWorking;
  int _backButtonPressCount = 0;
  // Grid test state
  int _filledBoxesCount = 0;
  int _totalBoxes = 0;
  Timer? _inactivityTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 3;
  bool _showTimer = true;
  final GlobalKey<TouchGridViewState> _gridKey = GlobalKey<TouchGridViewState>();

  // Grid configuration
  static const int _gridRows = 12;
  static const int _gridColumns = 10;

  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    _totalBoxes = _gridRows * _gridColumns;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled || _testStarted) return;
    final state = ref.read(testImagesProvider);
    if (!state.hasLoaded) return;
    final notifier = ref.read(testImagesProvider.notifier);
    final isAutoMode = notifier.getIsAutoMode(TestConfig.testIdTouch);
    if (!isAutoMode) return;
    _autoStartScheduled = true;
    // Touch screen: do not show the circular progress overlay (auto-start still runs after delay)
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && !_testStarted) _startTest();
    });
  }

  bool _shouldShowStartTestButton() {
    final notifier = ref.read(testImagesProvider.notifier);
    return !notifier.getIsAutoMode(TestConfig.testIdTouch);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
  void _startTest() {
    setState(() {
      _testStarted = true;
      _testComplete = false;
      _touchScreenWorking = null;
      _backButtonPressCount = 0;
      _filledBoxesCount = 0;
      _remainingSeconds = 3;
      _showTimer = true;
    });
    
    // Clear the grid
    _gridKey.currentState?.clear();
    
    // Start initial countdown timer - visible to user
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _remainingSeconds = 3;
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_testStarted || _testComplete) {
        timer.cancel();
        return;
      }
      
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        // Timer expired – show Fail/Skip choice instead of auto-failing
        timer.cancel();
        if (mounted) {
          _showTimeoutDialog();
        }
      }
    });
  }

  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
  }

  void _onTouchStart() {
    // Hide timer and stop countdown when user touches the screen
    setState(() {
      _showTimer = false;
    });
    _stopCountdownTimer();
  }

  void _onTouchEnd() {
    // Show timer and restart countdown when user lifts finger
    if (_testStarted && !_testComplete) {
      setState(() {
        _showTimer = true;
        _remainingSeconds = 3;
      });
      _startCountdownTimer();
    }
  }

  void _onBoxesFilledChanged(int count) {
    if (!mounted || !_testStarted || _testComplete) return;
    
    setState(() {
      _filledBoxesCount = count;
    });
    
    // Check if all boxes are filled
    if (_filledBoxesCount == _totalBoxes) {
      _endTest(true);
    }
  }

  /// When the timeout is reached, show a dialog with Fail/Skip instead of auto-failing.
  void _showTimeoutDialog() {
    // Stop timers and hide the timer UI
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _testComplete = true;
      _touchScreenWorking = false;
      _showTimer = false;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Touch Test Time Over'),
          content: const Text(
            'Time is over for the touch test. You can mark this test as Fail or Skip it.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleSkip();
              },
              child: Text(AppStrings.skipButton),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleFail();
              },
              child: Text(AppStrings.failButton),
            ),
          ],
        );
      },
    );
  }

  void _endTest(bool passed) {
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    
    if (!mounted) return;
    
    setState(() {
      _testComplete = true;
      _touchScreenWorking = passed;
      _showTimer = false;
    });
    
    // Auto-save result based on test outcome
    if (passed) {
      TestResultHelper.savePass(ref, TestConfig.testIdTouch);
    } else {
      TestResultHelper.saveFail(ref, TestConfig.testIdTouch);
    }
    
    // Auto-navigate after brief delay - ensure UI has updated first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _navigateToNextTest();
        }
      });
    });
  }

  // Handle back button during test
  Future<bool> _handleWillPop() async {
    if (_testStarted && !_testComplete) {
      _backButtonPressCount++;
      
      if (_backButtonPressCount == 1) {
        // First back press - show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Click one more time back button to skip!'),
            duration: Duration(seconds: 2),
          ),
        );
        return true; // Prevent navigation
      } else {
        // Second back press - mark as failed
        _inactivityTimer?.cancel();
        _countdownTimer?.cancel();
        _endTest(false);
        return true; // Prevent navigation, show result
      }
    }
    return false; // Allow normal back navigation
  }

  Future<void> _navigateToNextTest() async {
    // Cancel any timers before navigation
    _inactivityTimer?.cancel();
    _countdownTimer?.cancel();
    
    if (!mounted) return;
    
    // Get test parameters from provider
    final testParametersAsync = ref.read(testParametersProvider);
    if (testParametersAsync.hasValue) {
      final testParameters = testParametersAsync.value!;
      TestNavigationService.navigateToNextTest(
        context,
        testParameters,
        TestConfig.testIdTouch,
      );
    }
  }

  void _handlePass() {
    // Save Touch test result as pass
    TestResultHelper.savePass(ref, TestConfig.testIdTouch);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleSkip() {
    // Save Touch test result as skipped
    TestResultHelper.saveSkip(ref, TestConfig.testIdTouch);
    _navigateToNextTest();
  }

  void _handleFail() {
    // Save Touch test result as fail
    TestResultHelper.saveFail(ref, TestConfig.testIdTouch);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  @override
  Widget build(BuildContext context) {
    // Show grid test screen when test is started
    if (_testStarted && !_testComplete) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            final shouldPop = await _handleWillPop();
            if (shouldPop && mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.white,
          body: SafeArea(
            child: Stack(
              children: [
                // Grid view - takes full space
                TouchGridView(
                  key: _gridKey,
                  rows: _gridRows,
                  columns: _gridColumns,
                  backgroundColor: AppColors.white,
                  borderColor: AppColors.black,
                  fillColor: AppColors.primary,
                  enabled: true,
                  counterText: '${_filledBoxesCount}/${_totalBoxes}',
                  onBoxesFilledChanged: _onBoxesFilledChanged,
                  onTouchStart: _onTouchStart,
                  onTouchEnd: _onTouchEnd,
                ),
                
                // Timer overlay - centered, small, visible
                if (_showTimer)
                  Center(
                    child: Container(
                      width: 120, // Fixed width to prevent layout shift
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _remainingSeconds <= 5 
                            ? AppColors.error.withOpacity(0.9)
                            : AppColors.success.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer,
                            color: AppColors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_remainingSeconds',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'sec...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Normal UI mode (before test or after completion)
    return PopScope(
      canPop: true,
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

                const SizedBox(height: 24),

                /// Main Content Card - ResponsiveCard for initial state, ScanResultCard when test completes
                Expanded(
                  child: SingleChildScrollView(
                  child: Padding(
                      padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                        bottom: _testComplete ? 24 : 180, // Less padding when complete (no footer)
                    ),
                    child: _testComplete && _touchScreenWorking != null
                        ? ScanResultCard(
                            // Use network image with local fallback
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdTouch,
                              isPassed: _touchScreenWorking!,
                              localFallbackPath: AppStrings.image142Path,
                              fallbackIcon: Icons.touch_app,
                              width: 120,
                              height: 120,
                            ),
                            status: _touchScreenWorking == true
                                ? ScanStatus.passed
                                : ScanStatus.failed,
                            title: _touchScreenWorking == true
                                ? AppStrings.touchScreenWorking
                                : AppStrings.touchScreenNotWorking,
                            subheadingLines: _touchScreenWorking == true
                                ? [
                                    AppStrings.touchScreenWorkingCorrectly,
                                  ]
                                : [
                                    AppStrings.touchScreenIssueDetected,
                                  ],
                          )
                        : ResponsiveCard(
                            // Use network image with local fallback
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdTouch,
                              isPassed: true,
                              localFallbackPath: AppStrings.image142Path,
                              fallbackIcon: Icons.touch_app,
                              width: 120,
                              height: 120,
                            ),
                            heading: AppStrings.touchScreenTest,
                            subtitleLines: [
                              AppStrings.touchScreenInstruction,
                              '',
                              'Instructions:',
                              '• Drag your finger across the entire screen',
                              '• Fill all boxes in the grid by touching them',
                              '• The grid will cover the full screen area',
                              '• Complete the test within the time limit',
                            ],
                            showProgressBar: false,
                            progressDuration: const Duration(seconds: 0),
                            onProgressComplete: () {},
                            ),
                          ),
                  ),
                ),

                /// Begin Test Button (only when not auto mode, before test starts, not after completion)
                if (!_testComplete && _shouldShowStartTestButton())
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: CommonButton(
                      text: AppStrings.beginTestButton,
                      onPressed: _startTest,
                    ),
                  ),

                /// Pass/Fail Buttons (only after test completes)
                if (_testComplete && _touchScreenWorking != null)
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
            /// Common Footer with ellipse images (only show when not testing) - ignorePointer to allow button clicks
            if (!_testStarted || _testComplete)
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
}

