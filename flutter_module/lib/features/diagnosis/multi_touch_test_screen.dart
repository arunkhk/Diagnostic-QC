import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/scan_result_card.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'providers/test_images_provider.dart';
import 'utils/test_navigation_service.dart';
import '../../core/widgets/common_test_image.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

enum MultiTouchTestState {
  initial,
  testing,
  resultReady,
}

class MultiTouchTestScreen extends ConsumerStatefulWidget {
  const MultiTouchTestScreen({super.key});

  @override
  ConsumerState<MultiTouchTestScreen> createState() => _MultiTouchTestScreenState();
}

class _MultiTouchTestScreenState extends ConsumerState<MultiTouchTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('multitouch'); // Dynamic progress for screen 28
  MultiTouchTestState _currentState = MultiTouchTestState.initial;
  
  // Track touch points
  final Map<int, Offset> _touchPoints = {};
  final Map<int, Color> _touchColors = {};
  
  // Colors for different touch points (2-5 fingers)
  final List<Color> _fingerColors = [
    AppColors.primary,      // Purple for first finger
    Colors.red,            // Red for second finger
    Colors.green,          // Green for third finger
    Colors.blue,           // Blue for fourth finger
    Colors.orange,         // Orange for fifth finger
  ];
  
  Timer? _testTimer;
  bool _testComplete = false;
  int _maxTouchesDetected = 0;
  ScanStatus _testResult = ScanStatus.passed; // Track test result
  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdMultitouch)) return;
    if (_currentState != MultiTouchTestState.initial) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == MultiTouchTestState.initial) _startTest();
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdMultitouch);
  }

  @override
  void dispose() {
    _testTimer?.cancel();
    super.dispose();
  }

  void _startTest() {
    setState(() {
      _currentState = MultiTouchTestState.testing;
      _touchPoints.clear();
      _touchColors.clear();
      _maxTouchesDetected = 0;
      _testComplete = false;
      _testResult = ScanStatus.passed; // Reset to passed
    });
    // Timer will start when first touch is detected
  }

  void _startTimer() {
    // Cancel any existing timer
    _testTimer?.cancel();
    
    // Test runs for maximum 3 seconds, but can end early when all touches are lifted
    _testTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _currentState == MultiTouchTestState.testing) {
        // Only transition if still in testing state and no touches
        if (_touchPoints.isEmpty) {
          setState(() {
            _currentState = MultiTouchTestState.resultReady;
            _testComplete = true;
          });
        }
      }
    });
  }

  void _checkAndEndTest() {
    // If all touches are lifted and we're in testing state, end the test
    if (_touchPoints.isEmpty && _currentState == MultiTouchTestState.testing) {
      _testTimer?.cancel();
      if (mounted) {
        setState(() {
          _currentState = MultiTouchTestState.resultReady;
          _testComplete = true;
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
        TestConfig.testIdMultitouch,
      );
    } else {
      debugPrint('❌ MultiTouchTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleTestPass() {
    setState(() {
      _testResult = ScanStatus.passed;
    });
    
    TestResultHelper.savePass(ref, TestConfig.testIdMultitouch);
    _navigateToNextTest();
  }

  void _handleTestFail() {
    setState(() {
      _testResult = ScanStatus.failed;
    });
    
    TestResultHelper.saveFail(ref, TestConfig.testIdMultitouch);
    _navigateToNextTest();
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdMultitouch);
    _navigateToNextTest();
  }

  void _handlePointerDown(PointerDownEvent event) {
    final pointerId = event.pointer;
    
    // Start timer on first touch
    if (_touchPoints.isEmpty) {
      _startTimer();
    }
    
    setState(() {
      _touchPoints[pointerId] = event.localPosition;
      // Assign color based on number of touches
      final touchIndex = _touchPoints.length - 1;
      if (touchIndex < _fingerColors.length) {
        _touchColors[pointerId] = _fingerColors[touchIndex];
      } else {
        // If more than 5 touches, cycle through colors
        _touchColors[pointerId] = _fingerColors[touchIndex % _fingerColors.length];
      }
      _maxTouchesDetected = _touchPoints.length > _maxTouchesDetected 
          ? _touchPoints.length 
          : _maxTouchesDetected;
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final pointerId = event.pointer;
    if (_touchPoints.containsKey(pointerId)) {
      setState(() {
        _touchPoints[pointerId] = event.localPosition;
      });
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    final pointerId = event.pointer;
    setState(() {
      _touchPoints.remove(pointerId);
      _touchColors.remove(pointerId);
    });
    // Check if all touches are lifted, then end test
    _checkAndEndTest();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    final pointerId = event.pointer;
    setState(() {
      _touchPoints.remove(pointerId);
      _touchColors.remove(pointerId);
    });
    // Check if all touches are lifted, then end test
    _checkAndEndTest();
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
                        if (_currentState == MultiTouchTestState.initial)
                          // Initial state - show instruction
                          CommonContentWidget(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdMultitouch,
                              isPassed: true,
                              localFallbackPath: AppStrings.image134Path,
                              fallbackIcon: Icons.touch_app,
                              width: 120,
                              height: 120,
                            ),
                            heading: AppStrings.multiTouchScreenTest,
                            subheading: AppStrings.multiTouchTestInstruction,
                          )
                        else if (_currentState == MultiTouchTestState.resultReady)
                          // Result ready - show ScanResultCard
                          ScanResultCard(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdMultitouch,
                              isPassed: _testResult == ScanStatus.passed,
                              localFallbackPath: AppStrings.image134Path,
                              fallbackIcon: Icons.touch_app,
                              width: 120,
                              height: 120,
                            ),
                            status: _testResult, // Use the test result status
                            title: AppStrings.multiTouchTestComplete,
                            subheadingLines: [
                              AppStrings.multiTouchTestCompleteMessage,
                            ],
                            showStatusIcon: true,
                          ),
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
                    if (_currentState == MultiTouchTestState.initial && _shouldShowStartTestButton())
                      CommonButton(
                        text: AppStrings.beginTestButton,
                        onPressed: _startTest,
                      )
                    else if (_currentState == MultiTouchTestState.resultReady)
                      // Show Pass/Fail buttons
                      CommonTwoButtons(
                        leftButtonText: AppStrings.failButton ,
                        rightButtonText: AppStrings.passButton,
                        onLeftButtonPressed: _handleTestFail ,
                        onRightButtonPressed: _handleTestPass,
                      ),
                  ],
                ),
              ),
            ],
          ),

          /// Full Screen White with Touch Points (shown during testing)
          if (_currentState == MultiTouchTestState.testing)
            Listener(
              onPointerDown: _handlePointerDown,
              onPointerMove: _handlePointerMove,
              onPointerUp: _handlePointerUp,
              onPointerCancel: _handlePointerCancel,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
                child: Stack(
                  children: [
                    // Touch points with different colors
                    ..._touchPoints.entries.map((entry) {
                      final pointerId = entry.key;
                      final position = entry.value;
                      final color = _touchColors[pointerId] ?? AppColors.primary;
                      
                      return Positioned(
                        left: position.dx - 30,
                        top: position.dy - 30,
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color,
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    
                    // Instruction overlay at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Touch with 2-5 fingers',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Current touches: ${_touchPoints.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        ),
      ),
    );
  }
}

