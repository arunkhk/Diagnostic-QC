import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:volume_controller/volume_controller.dart';
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

enum VolumeTestState {
  initial,
  readyToTest,
  testing,
  resultReady,
}

class VolumeButtonScreen extends ConsumerStatefulWidget {
  const VolumeButtonScreen({super.key});

  @override
  ConsumerState<VolumeButtonScreen> createState() => _VolumeButtonScreenState();
}

class _VolumeButtonScreenState extends ConsumerState<VolumeButtonScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('volume'); // Dynamic progress for screen 7
  VolumeTestState _currentState = VolumeTestState.initial;
  bool _volumeUpPressed = false;
  bool _volumeDownPressed = false;
  bool _testComplete = false;
  bool _showProceedButton = false;
  bool _buttonsWorking = false;
  
  VolumeController? _volumeController;
  double _lastVolume = 0.0;
  StreamSubscription<double>? _volumeSubscription;
  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    _initializeVolumeController().then((_) {
      if (mounted) {
        setState(() {
          _currentState = VolumeTestState.readyToTest;
        });
        _scheduleAutoStartIfNeeded();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdVolume)) return;
    if (_currentState != VolumeTestState.initial && _currentState != VolumeTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && (_currentState == VolumeTestState.initial || _currentState == VolumeTestState.readyToTest)) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdVolume);
  }

  @override
  void dispose() {
    _volumeSubscription?.cancel();
    _volumeController?.removeListener();
    super.dispose();
  }

  Future<void> _initializeVolumeController() async {
    try {
      _volumeController = VolumeController();
      final currentVolume = await _volumeController!.getVolume();
      _lastVolume = currentVolume;
    } catch (e) {
      print('❌ Error initializing volume controller: $e');
    }
  }

  void _handleVolumeChange(double newVolume) {
    if (!mounted || _currentState != VolumeTestState.testing) return;
    
    // Determine if volume increased or decreased
    if (newVolume > _lastVolume) {
      // Volume Up button pressed
      setState(() {
        _volumeUpPressed = true;
      });
    } else if (newVolume < _lastVolume) {
      // Volume Down button pressed
      setState(() {
        _volumeDownPressed = true;
      });
    }
    
    _lastVolume = newVolume;
    
    // Check if both buttons have been pressed
    if (_volumeUpPressed && _volumeDownPressed && !_testComplete) {
      _evaluateTest();
    }
  }

  Future<void> _startTest() async {
    try {
      // Get current volume as baseline
      final currentVolume = await _volumeController?.getVolume();
      if (currentVolume != null) {
        _lastVolume = currentVolume;
      }
      
      // Start listening to volume changes
      _volumeSubscription = _volumeController!.listener((volume) {
        _handleVolumeChange(volume);
      });
      
      setState(() {
        _currentState = VolumeTestState.testing;
        _volumeUpPressed = false;
        _volumeDownPressed = false;
        _testComplete = false;
        _showProceedButton = false;
      });
    } catch (e) {
      print('❌ Error starting volume test: $e');
    }
  }

  void _evaluateTest() {
    // Both buttons were pressed
    final bothButtonsPressed = _volumeUpPressed && _volumeDownPressed;
    
    // Stop listening
    _volumeSubscription?.cancel();
    _volumeController?.removeListener();
    
    if (mounted) {
      setState(() {
        _buttonsWorking = bothButtonsPressed;
        _testComplete = true;
        _currentState = VolumeTestState.resultReady;
      });
      
      // Auto-save result based on test outcome
      if (bothButtonsPressed) {
        TestResultHelper.savePass(ref, TestConfig.testIdVolume);
        
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
    // Reset volume button to initial state before navigating
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
        TestConfig.testIdVolume,
      );
    } else {
      debugPrint('❌ VolumeButtonScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _resetToInitialState() {
    // Cancel any active subscriptions
    _volumeSubscription?.cancel();
    _volumeSubscription = null;
    
    // Reset all state variables to initial values
    setState(() {
      _currentState = VolumeTestState.initial;
      _volumeUpPressed = false;
      _volumeDownPressed = false;
      _testComplete = false;
      _showProceedButton = false;
      _buttonsWorking = false;
      _lastVolume = 0.0;
    });
    
    // Re-initialize volume controller to transition to readyToTest state
    _initializeVolumeController().then((_) {
      if (mounted) {
        setState(() {
          _currentState = VolumeTestState.readyToTest;
        });
      }
    });
  }

  void _handlePass() {
    TestResultHelper.savePass(ref, TestConfig.testIdVolume);
    _navigateToNextTest();
  }

  void _handleFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdVolume);
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
                  // Mark Volume Button test as skipped
                  TestResultHelper.saveSkip(ref, TestConfig.testIdVolume);
                  
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

              /// Begin Test Button (only when ready to test or initial, and not auto mode)
              if (_shouldShowStartTestButton() &&
                  (_currentState == VolumeTestState.readyToTest ||
                      _currentState == VolumeTestState.initial))
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
      case VolumeTestState.initial:
      case VolumeTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdVolume,
            isPassed: true,
            localFallbackPath: AppStrings.image51Path,
            fallbackIcon: Icons.volume_up,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.checkingVolumeButton,
          subtitleLines: [
            AppStrings.volumeButtonInstruction,
            'Press the Volume Up (+) and Volume Down (-) buttons to test.',
          ],
        );
        
      case VolumeTestState.testing:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdVolume,
            isPassed: true,
            localFallbackPath: AppStrings.image51Path,
            fallbackIcon: Icons.volume_up,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.checkingVolumeButton,
          subtitleLines: [
            'Press Volume Up (+) and Volume Down (-) buttons.',
            if (_volumeUpPressed) '✓ Volume Up (+) detected',
            if (_volumeDownPressed) '✓ Volume Down (-) detected',
            if (!_volumeUpPressed) '⏳ Waiting for Volume Up (+)...',
            if (!_volumeDownPressed) '⏳ Waiting for Volume Down (-)...',
          ],
        );
        
      case VolumeTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdVolume,
            isPassed: _buttonsWorking,
            localFallbackPath: AppStrings.image51Path,
            fallbackIcon: Icons.volume_up,
            width: 120,
            height: 120,
          ),
          status: _buttonsWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _buttonsWorking 
              ? AppStrings.volumeButtonsWorking 
              : 'Volume Buttons Not Working',
          subheadingLines: _buttonsWorking
              ? [AppStrings.volumeButtonsWorkingCorrectly]
              : ['Volume buttons were not detected. Please try again.'],
          showStatusIcon: true,
        );
    }
  }
}
