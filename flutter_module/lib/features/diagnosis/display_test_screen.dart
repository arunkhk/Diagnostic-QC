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

enum DisplayTestState {
  initial,
  testing,
  resultReady,
}

class DisplayTestScreen extends ConsumerStatefulWidget {
  const DisplayTestScreen({super.key});

  @override
  ConsumerState<DisplayTestScreen> createState() => _DisplayTestScreenState();
}

class _DisplayTestScreenState extends ConsumerState<DisplayTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('color'); // Dynamic progress for screen 27
  DisplayTestState _currentState = DisplayTestState.initial;
  
  int _currentColorIndex = 0;
  Timer? _colorTimer;
  bool _autoStartScheduled = false;
  
  // Colors for display test - commonly used for screen testing
  final List<Color> _testColors = [
    Colors.white,           // Test for white uniformity
    Colors.black,           // Test for black levels and dead pixels
    Colors.red,             // Test red channel
    Colors.green,           // Test green channel
    Colors.blue,            // Test blue channel
    Colors.yellow,          // Test yellow (red + green)
    AppColors.magenta,      // Test magenta (red + blue)
    Colors.cyan,            // Test cyan (green + blue)
    Colors.grey,            // Test grey scale
  ];
  
  final List<String> _colorNames = [
    'White',
    'Black',
    'Red',
    'Green',
    'Blue',
    'Yellow',
    'Magenta',
    'Cyan',
    'Grey',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdColor)) return;
    if (_currentState != DisplayTestState.initial) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == DisplayTestState.initial) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdColor);
  }

  @override
  void dispose() {
    _colorTimer?.cancel();
    super.dispose();
  }

  void _startTest() {
    setState(() {
      _currentState = DisplayTestState.testing;
      _currentColorIndex = 0;
    });

    // Cycle through colors - 4 seconds per color
    _colorTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) {
        setState(() {
          _currentColorIndex++;
          if (_currentColorIndex >= _testColors.length) {
            _currentColorIndex = 0;
            timer.cancel();
            _currentState = DisplayTestState.resultReady;
          }
        });
      } else {
        timer.cancel();
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
        TestConfig.testIdColor,
      );
    } else {
      debugPrint('❌ DisplayTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleTestPass() {
    TestResultHelper.savePass(ref, TestConfig.testIdColor);
    _navigateToNextTest();
  }

  void _handleTestFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdColor);
    _navigateToNextTest();
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdColor);
    _navigateToNextTest();
  }

  void _handleNextColor() {
    if (_currentColorIndex < _testColors.length - 1) {
      setState(() {
        _currentColorIndex++;
      });
    } else {
      // Test complete
      _colorTimer?.cancel();
      setState(() {
        _currentState = DisplayTestState.resultReady;
      });
    }
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
                        if (_currentState == DisplayTestState.initial)
                          // Initial state - show instruction
                          CommonContentWidget(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdColor,
                              isPassed: true,
                              localFallbackPath: AppStrings.imageDisplayTestPath,
                              fallbackIcon: Icons.palette,
                              width: 120,
                              height: 120,
                            ),
                            heading: AppStrings.testingDisplay,
                            subheading: AppStrings.displayTestInstruction,
                          )
                        else if (_currentState == DisplayTestState.resultReady)
                          // Result ready - show ScanResultCard
                          ScanResultCard(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdColor,
                              isPassed: true,
                              localFallbackPath: AppStrings.imageDisplayTestPath,
                              fallbackIcon: Icons.palette,
                              width: 120,
                              height: 120,
                            ),
                            status: ScanStatus.passed, // Default to passed, user can mark fail
                            title: AppStrings.displayTestComplete,
                            subheadingLines: [
                              AppStrings.displayTestCompleteMessage,
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
                    if (_currentState == DisplayTestState.initial && _shouldShowStartTestButton())
                      CommonButton(
                        text: AppStrings.beginTestButton,
                        onPressed: _startTest,
                      )
                    else if (_currentState == DisplayTestState.resultReady)
                      // Show Pass/Fail buttons
                      CommonTwoButtons(
                        leftButtonText: AppStrings.failButton,
                        rightButtonText: AppStrings.passButton,
                        onLeftButtonPressed: _handleTestFail,
                        onRightButtonPressed: _handleTestPass ,
                      )
                    else if (_currentState == DisplayTestState.testing)
                      // Show Next button during test
                      CommonButton(
                        text: _currentColorIndex < _testColors.length - 1
                            ? 'Next Color'
                            : 'Complete Test',
                        onPressed: _handleNextColor,
                      ),
                  ],
                ),
              ),
            ],
          ),

          /// Full Screen Color Display (shown during testing)
          if (_currentState == DisplayTestState.testing)
            GestureDetector(
              onTap: _handleNextColor,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: _testColors[_currentColorIndex],
                child: SafeArea(
                  child: Stack(
                    children: [
                      // Center color dot/indicator
                      Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: _testColors[_currentColorIndex],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _testColors[_currentColorIndex] == Colors.white ||
                                      _testColors[_currentColorIndex] == Colors.yellow ||
                                      _testColors[_currentColorIndex] == Colors.cyan
                                  ? Colors.black
                                  : Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bottom info section
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Column(
                          children: [
                            // Color name indicator
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _colorNames[_currentColorIndex],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Progress indicator
                            Text(
                              '${_currentColorIndex + 1} / ${_testColors.length}',
                              style: TextStyle(
                                color: _testColors[_currentColorIndex] == Colors.white ||
                                        _testColors[_currentColorIndex] == Colors.yellow ||
                                        _testColors[_currentColorIndex] == Colors.cyan
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Instruction
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 24),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Tap anywhere to continue\nCheck for discoloration, dead pixels, or color issues',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
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
    );
  }
}

