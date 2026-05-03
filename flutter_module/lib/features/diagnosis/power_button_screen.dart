import 'dart:async';
import 'dart:io';
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

enum PowerTestState {
  initial,
  readyToTest,
  testing,
  resultReady,
}

class PowerButtonScreen extends ConsumerStatefulWidget {
  const PowerButtonScreen({super.key});

  @override
  ConsumerState<PowerButtonScreen> createState() => _PowerButtonScreenState();
}

class _PowerButtonScreenState extends ConsumerState<PowerButtonScreen> with WidgetsBindingObserver {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('power'); // Dynamic progress for screen 9
  PowerTestState _currentState = PowerTestState.initial;
  bool _powerButtonPressed = false;
  bool _testComplete = false;
  bool _showProceedButton = false;
  bool _buttonWorking = false;
  
  // iOS-specific: Track power button state
  bool _iosScreenOff = false; // Track if screen was turned off
  bool _iosScreenOn = false; // Track if screen was turned on
  
  StreamSubscription<dynamic>? _buttonSubscription;
  static const EventChannel _buttonChannel = EventChannel(AppConfig.buttonEventChannel);

  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Transition to readyToTest state after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentState = PowerTestState.readyToTest;
        });
        _scheduleAutoStartIfNeeded();
      }
    });
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdPower)) return;
    if (_currentState != PowerTestState.initial && _currentState != PowerTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && (_currentState == PowerTestState.initial || _currentState == PowerTestState.readyToTest)) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdPower);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _buttonSubscription?.cancel();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // iOS-specific: Detect power button press via app lifecycle
    if (Platform.isIOS && _currentState == PowerTestState.testing && !_powerButtonPressed) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        // Power button pressed - screen turned off
        if (!_iosScreenOff) {
          _iosScreenOff = true;
          print('📱 iOS: Power button detected - Screen OFF');
        }
      } else if (state == AppLifecycleState.resumed && _iosScreenOff) {
        // Power button pressed again - screen turned on
        if (!_iosScreenOn) {
          _iosScreenOn = true;
          print('📱 iOS: Power button detected - Screen ON');
          // Both OFF and ON detected - power button is working
          _handlePowerButtonPress();
        }
      }
    }
  }

  Future<void> _startTest() async {
    setState(() {
      _currentState = PowerTestState.testing;
      _powerButtonPressed = false;
      _testComplete = false;
      _showProceedButton = false;
      // Reset iOS-specific tracking
      _iosScreenOff = false;
      _iosScreenOn = false;
    });
    
    // Android: Start listening for button events via channel
    if (!Platform.isIOS) {
      try {
        _buttonSubscription = _buttonChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            // Detect power button press (screen on/off events)
            if ((event == 'power_on' || event == 'power_off') && 
                _currentState == PowerTestState.testing && 
                !_powerButtonPressed) {
              _handlePowerButtonPress();
            }
          },
          onError: (error) {
            print('❌ Button channel error: $error');
          },
        );
      } catch (e) {
        print('❌ Error listening to button channel: $e');
      }
    }
    // iOS: Detection is handled via didChangeAppLifecycleState
  }

  void _handlePowerButtonPress() {
    if (mounted && _currentState == PowerTestState.testing && !_powerButtonPressed) {
      setState(() {
        _powerButtonPressed = true;
        _buttonWorking = true;
        _testComplete = true;
        _currentState = PowerTestState.resultReady;
      });
      
      // Stop listening (Android only)
      _buttonSubscription?.cancel();
      
      // Auto-save result as pass (power button was detected)
      TestResultHelper.savePass(ref, TestConfig.testIdPower);
      print('✅ Power button test: PASSED - Result saved to diagnosis summary');
      
      // Auto-navigate after brief delay when test passes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _navigateToNextTest();
          }
        });
      });
    }
  }

  Future<void> _navigateToNextTest() async {
    // Reset power button to initial state before navigating
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
        TestConfig.testIdPower,
      );
    } else {
      debugPrint('❌ PowerButtonScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _resetToInitialState() {
    _buttonSubscription?.cancel();
    _buttonSubscription = null;
    
    // Reset all state variables to initial values
    setState(() {
      _currentState = PowerTestState.initial;
      _powerButtonPressed = false;
      _testComplete = false;
      _showProceedButton = false;
      _buttonWorking = false;
      // Reset iOS-specific tracking
      _iosScreenOff = false;
      _iosScreenOn = false;
    });
    
    // Transition to readyToTest state after reset
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _currentState = PowerTestState.readyToTest;
        });
      }
    });
  }

  void _handlePass() {
    TestResultHelper.savePass(ref, TestConfig.testIdPower);
    _navigateToNextTest();
  }
  void _handleFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdPower);
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
                  TestResultHelper.saveSkip(ref, TestConfig.testIdPower);
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
                  (_currentState == PowerTestState.readyToTest ||
                      _currentState == PowerTestState.initial))
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
      case PowerTestState.initial:
      case PowerTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdPower,
            isPassed: true,
            localFallbackPath: AppStrings.image78Path,
            fallbackIcon: Icons.power_settings_new,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingPowerButton,
          subtitleLines: [
            AppStrings.powerButtonInstruction,
            'Instructions:',
            '1. Press the Power button to turn OFF the screen',
            '2. Wait 2 seconds',
            '3. Press the Power button again to turn ON the screen',
            'Note: The screen will lock when you turn it off.',
          ],
        );
        
      case PowerTestState.testing:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdPower,
            isPassed: true,
            localFallbackPath: AppStrings.image78Path,
            fallbackIcon: Icons.power_settings_new,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingPowerButton,
          subtitleLines: [
            'Press Power button to turn screen OFF, then ON again.',
            '⏳ Waiting for Power button press...',
            'Step 1: Press Power to turn screen OFF',
            'Step 2: Press Power again to turn screen ON',
          ],
        );
        
      case PowerTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdPower,
            isPassed: _buttonWorking,
            localFallbackPath: AppStrings.image78Path,
            fallbackIcon: Icons.power_settings_new,
            width: 120,
            height: 120,
          ),
          status: _buttonWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _buttonWorking 
              ? AppStrings.powerButtonWorking 
              : 'Power Button Not Working',
          subheadingLines: _buttonWorking
              ? [AppStrings.powerButtonWorkingCorrectly]
              : ['Power button was not detected. Please try again.'],
          showStatusIcon: true,
        );
    }
  }
}
