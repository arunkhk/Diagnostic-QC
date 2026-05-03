import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'utils/test_navigation_service.dart';
import '../../core/widgets/common_test_image.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_images_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

enum RotationTestState {
  initial,
  readyToTest,
  testing,
  resultReady,
}

class ScreenRotationScreen extends ConsumerStatefulWidget {
  const ScreenRotationScreen({super.key});

  @override
  ConsumerState<ScreenRotationScreen> createState() => _ScreenRotationScreenState();
}

class _ScreenRotationScreenState extends ConsumerState<ScreenRotationScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('rotation'); // Dynamic progress for screen 12
  RotationTestState _currentState = RotationTestState.initial;
  Orientation? _initialOrientation;
  Orientation? _currentOrientation;
  bool _portraitToLandscape = false;
  bool _landscapeToPortrait = false;
  bool _testComplete = false;
  bool _showProceedButton = false;
  bool _rotationWorking = false;
  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    // Get initial orientation and transition to readyToTest
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final orientation = MediaQuery.of(context).orientation;
        setState(() {
          _initialOrientation = orientation;
          _currentOrientation = orientation;
          _currentState = RotationTestState.readyToTest;
        });
        _scheduleAutoStartIfNeeded();
      }
    });
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdRotation)) return;
    if (_currentState != RotationTestState.initial && _currentState != RotationTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && (_currentState == RotationTestState.initial || _currentState == RotationTestState.readyToTest)) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdRotation);
  }

  @override
  void dispose() {
    // Restore portrait lock when leaving screen
    _lockToPortrait();
    super.dispose();
  }

  Future<void> _lockToPortrait() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _unlockOrientation() async {
    // Allow all orientations for rotation test
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _startTest() async {
    // Unlock orientation for this screen
    await _unlockOrientation();
    
    // Get current orientation as starting point
    final orientation = MediaQuery.of(context).orientation;
    
    setState(() {
      _currentState = RotationTestState.testing;
      _initialOrientation = orientation;
      _currentOrientation = orientation;
      _portraitToLandscape = false;
      _landscapeToPortrait = false;
      _testComplete = false;
      _showProceedButton = false;
    });
  }

  void _handleOrientationChange(Orientation orientation) {
    if (!mounted || _currentState != RotationTestState.testing) return;
    
    setState(() {
      _currentOrientation = orientation;
      
      // Track rotation from portrait to landscape
      if (_initialOrientation == Orientation.portrait && 
          orientation == Orientation.landscape) {
        _portraitToLandscape = true;
      }
      
      // Track rotation from landscape to portrait
      if (_initialOrientation == Orientation.landscape && 
          orientation == Orientation.portrait) {
        _landscapeToPortrait = true;
      }
      
      // If started in portrait, check for portrait -> landscape -> portrait
      if (_initialOrientation == Orientation.portrait) {
        if (_portraitToLandscape && orientation == Orientation.portrait) {
          _evaluateTest();
        }
      }
      
      // If started in landscape, check for landscape -> portrait -> landscape
      if (_initialOrientation == Orientation.landscape) {
        if (_landscapeToPortrait && orientation == Orientation.landscape) {
          _evaluateTest();
        }
      }
    });
  }

  void _evaluateTest() {
    // Test passes if we detected rotation in both directions
    final rotationDetected = _portraitToLandscape || _landscapeToPortrait;
    
    // Lock back to portrait
    _lockToPortrait();
    
    if (mounted) {
      setState(() {
        _rotationWorking = rotationDetected;
        _testComplete = true;
        _currentState = RotationTestState.resultReady;
      });
      
      // Auto-save result based on test outcome
      if (rotationDetected) {
        TestResultHelper.savePass(ref, TestConfig.testIdRotation);
        
        // Auto-navigate after brief delay when test passes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _navigateToNextTest();
            }
          });
        });
      } else {
        // Show proceed button after a brief delay when test fails
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showProceedButton = true;
            });
          }
        });
      }
    }
  }

  Future<void> _navigateToNextTest() async {
    // Reset screen rotation to initial state before navigating
    _resetToInitialState();
    
    // Restore portrait lock before navigation
    _lockToPortrait();
    
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
        TestConfig.testIdRotation,
      );
    } else {
      debugPrint('❌ ScreenRotationScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _resetToInitialState() {
    // Restore portrait lock
    _lockToPortrait();
    
    // Reset all state variables to initial values
    setState(() {
      _currentState = RotationTestState.initial;
      _portraitToLandscape = false;
      _landscapeToPortrait = false;
      _testComplete = false;
      _showProceedButton = false;
      _rotationWorking = false;
    });
    
    // Get initial orientation and transition to readyToTest state after reset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final orientation = MediaQuery.of(context).orientation;
        setState(() {
          _initialOrientation = orientation;
          _currentOrientation = orientation;
          _currentState = RotationTestState.readyToTest;
        });
      }
    });
  }

  void _handlePass() {
    TestResultHelper.savePass(ref, TestConfig.testIdRotation);
    _navigateToNextTest();
  }

  void _handleFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdRotation);
    _navigateToNextTest();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to orientation changes using OrientationBuilder
    return OrientationBuilder(
      builder: (context, orientation) {
        // Handle orientation change during testing
        if (_currentState == RotationTestState.testing && 
            orientation != _currentOrientation) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleOrientationChange(orientation);
          });
        }
        
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
                      _lockToPortrait();
                      Navigator.of(context).pop();
                    },
                    onSkip: () {
                      _lockToPortrait();
                      // Mark Screen Rotation test as skipped
                      TestResultHelper.saveSkip(ref, TestConfig.testIdRotation);
                      
                      // Navigate to Screen Brightness screen
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
                        child: _buildContent(orientation),
                      ),
                    ),
                  ),

                  /// Begin Test Button (only when ready to test or initial, and not auto mode)
                  if (_shouldShowStartTestButton() &&
                      (_currentState == RotationTestState.readyToTest ||
                          _currentState == RotationTestState.initial))
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

              /// Common Footer with ellipse images (ignorePointer to allow button clicks)
              CommonFooter(
                leftEllipsePath: !_testComplete ? AppStrings.ellipse229Path : null,
                rightEllipsePath: !_testComplete ? AppStrings.ellipse230Path : null,
                ignorePointer: true,
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  Widget _buildContent(Orientation currentOrientation) {
    switch (_currentState) {
      case RotationTestState.initial:
      case RotationTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdRotation,
            isPassed: true,
            localFallbackPath: AppStrings.image86Path,
            fallbackIcon: Icons.screen_rotation,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingScreenRotation,
          subtitleLines: [
            AppStrings.screenRotationInstruction,
            '⚠️ IMPORTANT: Enable screen rotation in your device settings:',
            'Settings > Display > Auto-rotate screen (or similar)',
            'Note: We cannot change device settings automatically.',
            '',
            'Rotate your device to test screen rotation.',
            'Current orientation: ${currentOrientation == Orientation.portrait ? "Portrait" : "Landscape"}',
          ],
        );
        
      case RotationTestState.testing:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdRotation,
            isPassed: true,
            localFallbackPath: AppStrings.image86Path,
            fallbackIcon: Icons.screen_rotation,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingScreenRotation,
          subtitleLines: [
            'Rotate your device now.',
            'Current: ${currentOrientation == Orientation.portrait ? "Portrait" : "Landscape"}',
            if (_portraitToLandscape) '✓ Rotated to Landscape',
            if (_landscapeToPortrait) '✓ Rotated to Portrait',
            if (!_portraitToLandscape && !_landscapeToPortrait) ...[
              '⏳ Waiting for rotation...',
              '',
              '⚠️ If rotation not working:',
              'Enable auto-rotate in Settings > Display',
            ],
            if (_initialOrientation == Orientation.portrait)
              'Rotate to Landscape, then back to Portrait',
            if (_initialOrientation == Orientation.landscape)
              'Rotate to Portrait, then back to Landscape',
          ],
        );
        
      case RotationTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdRotation,
            isPassed: _rotationWorking,
            localFallbackPath: AppStrings.image86Path,
            fallbackIcon: Icons.screen_rotation,
            width: 120,
            height: 120,
          ),
          status: _rotationWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _rotationWorking 
              ? AppStrings.screenRotationWorking 
              : 'Screen Rotation Not Working',
          subheadingLines: _rotationWorking
              ? [AppStrings.screenRotationWorkingCorrectly]
              : ['Screen rotation was not detected. Please try again.'],
          showStatusIcon: true,
        );
    }
  }
}
