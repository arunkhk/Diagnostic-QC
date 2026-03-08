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
import 'utils/test_navigation_service.dart';
import '../../core/widgets/common_test_image.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_images_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

enum BrightnessTestState {
  readyToTest,
  testing,
  resultReady,
}

class ScreenBrightnessScreen extends ConsumerStatefulWidget {
  const ScreenBrightnessScreen({super.key});

  @override
  ConsumerState<ScreenBrightnessScreen> createState() => _ScreenBrightnessScreenState();
}

class _ScreenBrightnessScreenState extends ConsumerState<ScreenBrightnessScreen> with WidgetsBindingObserver {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('brightness'); // Dynamic progress for screen 13
  BrightnessTestState _currentState = BrightnessTestState.readyToTest;
  double _currentBrightness = 1.0; // Current brightness level (0.0 to 1.0)
  double _originalBrightness = 1.0; // Store original brightness to restore later
  bool _testComplete = false;
  bool _showProceedButton = false;
  bool _brightnessWorking = false;
  Timer? _brightnessTimer;
  int _brightnessStep = 0; // 0 = 50%, 1 = 100%, 2 = back to normal
  bool _waitingForPermission = false; // Track if we're waiting for user to grant permission
  List<double> _brightnessReadings = []; // Store brightness readings to verify changes
  
  static const MethodChannel _brightnessChannel = MethodChannel(AppConfig.brightnessChannel);
  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getOriginalBrightness();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdBrightness)) return;
    if (_currentState != BrightnessTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == BrightnessTestState.readyToTest) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdBrightness);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _brightnessTimer?.cancel();
    _restoreBrightness();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes, check if permission was granted
    if (state == AppLifecycleState.resumed && _waitingForPermission) {
      _checkPermissionAndStartTest();
    }
  }

  Future<void> _checkPermissionAndStartTest() async {
    try {
      final canWrite = await _brightnessChannel.invokeMethod<bool>('canWriteSettings') ?? false;
      if (canWrite) {
        // Permission granted, start the test
        _waitingForPermission = false;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission granted! Starting brightness test...'),
              duration: Duration(seconds: 2),
            ),
          );
          // Clear previous readings
          _brightnessReadings.clear();
          
          // Get initial brightness reading
          final initialBrightness = await _getCurrentBrightness();
          _brightnessReadings.add(initialBrightness);
          
          setState(() {
            _currentState = BrightnessTestState.testing;
            _brightnessStep = 0;
            _testComplete = false;
            _showProceedButton = false;
          });
          
          // Start brightness cycle: 50% (0.5) → 100% (1.0) → Normal (original)
          _cycleBrightness();
        }
      }
    } catch (e) {
      print('❌ Error checking permission after resume: $e');
    }
  }

  Future<void> _getOriginalBrightness() async {
    // Get current brightness from system
    try {
      final brightness = await _brightnessChannel.invokeMethod<double>('getScreenBrightness');
      if (brightness != null) {
        _originalBrightness = brightness;
        _currentBrightness = brightness;
        print('📱 Original brightness: ${(_originalBrightness * 100).toStringAsFixed(0)}%');
      } else {
        _originalBrightness = 1.0;
        _currentBrightness = 1.0;
      }
    } catch (e) {
      print('❌ Error getting original brightness: $e');
      _originalBrightness = 1.0;
      _currentBrightness = 1.0;
    }
  }
  
  Future<double> _getCurrentBrightness() async {
    try {
      final brightness = await _brightnessChannel.invokeMethod<double>('getScreenBrightness');
      return brightness ?? _currentBrightness;
    } catch (e) {
      print('❌ Error getting current brightness: $e');
      return _currentBrightness;
    }
  }

  Future<void> _setBrightness(double brightness) async {
    try {
      print('🔆 Setting brightness to: $brightness');
      final result = await _brightnessChannel.invokeMethod('setScreenBrightness', {
        'brightness': brightness,
      });
      print('✅ Brightness set result: $result');
      if (mounted) {
        setState(() {
          _currentBrightness = brightness;
        });
      }
    } catch (e) {
      print('❌ Error setting brightness: $e');
      print('❌ Error details: ${e.toString()}');
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      await _setBrightness(_originalBrightness);
    } catch (e) {
      print('❌ Error restoring brightness: $e');
    }
  }

  Future<void> _startTest() async {
    // Check if WRITE_SETTINGS permission is granted
    try {
      final canWrite = await _brightnessChannel.invokeMethod<bool>('canWriteSettings') ?? false;
      if (!canWrite) {
        // Permission not granted, open settings screen
        print('⚠️ WRITE_SETTINGS permission not granted, opening settings...');
        _waitingForPermission = true;
        await _brightnessChannel.invokeMethod('openWriteSettings');
        
        // Show message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enable "Modify system settings" permission. If the toggle is grayed out, go to App Info → Advanced → Modify system settings.'),
              duration: Duration(seconds: 8),
            ),
          );
        }
        return;
      }
    } catch (e) {
      print('❌ Error checking WRITE_SETTINGS permission: $e');
    }
    
    // Permission granted, start the test
    _waitingForPermission = false;
    
    // Clear previous readings
    _brightnessReadings.clear();
    
    // Get initial brightness reading
    final initialBrightness = await _getCurrentBrightness();
    _brightnessReadings.add(initialBrightness);
    
    setState(() {
      _currentState = BrightnessTestState.testing;
      _brightnessStep = 0;
      _testComplete = false;
      _showProceedButton = false;
    });
    
    // Start brightness cycle: 50% (0.5) → 100% (1.0) → Normal (original)
    _cycleBrightness();
  }

  void _cycleBrightness() {
    _brightnessTimer?.cancel();
    
    print('🔄 Starting brightness cycle...');
    
    // Step 1: Set to 50% brightness
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (mounted && _currentState == BrightnessTestState.testing) {
        setState(() {
          _brightnessStep = 0;
        });
        print('🔄 Step 1: Setting to 50% brightness');
        await _setBrightness(0.5); // 50% brightness
        
        // Wait a bit then read actual brightness
        Future.delayed(const Duration(milliseconds: 500), () async {
          final actualBrightness = await _getCurrentBrightness();
          _brightnessReadings.add(actualBrightness);
          print('📊 Brightness after 50%: ${(actualBrightness * 100).toStringAsFixed(0)}%');
        });
      }
    });
    
    // Step 2: After 3 seconds, set to high brightness (1.0)
    _brightnessTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _currentState == BrightnessTestState.testing) {
        print('🔄 Step 2: Setting to high brightness (100%)');
        setState(() {
          _brightnessStep = 1;
        });
        _setBrightness(1.0).then((_) {
          // Wait a bit then read actual brightness
          Future.delayed(const Duration(milliseconds: 500), () async {
            final actualBrightness = await _getCurrentBrightness();
            if (mounted) {
              _brightnessReadings.add(actualBrightness);
              print('📊 Brightness after 100%: ${(actualBrightness * 100).toStringAsFixed(0)}%');
            }
          });
        });
        
        // Step 3: After 3 more seconds, restore to original
        _brightnessTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _currentState == BrightnessTestState.testing) {
            print('🔄 Step 3: Restoring to normal brightness');
            setState(() {
              _brightnessStep = 2;
            });
            _setBrightness(_originalBrightness).then((_) {
              // Wait a bit then read actual brightness
              Future.delayed(const Duration(milliseconds: 500), () async {
                final actualBrightness = await _getCurrentBrightness();
                if (mounted) {
                  _brightnessReadings.add(actualBrightness);
                  print('📊 Brightness after restore: ${(actualBrightness * 100).toStringAsFixed(0)}%');
                }
              });
            });
            
            // Complete test after showing normal brightness
            _brightnessTimer = Timer(const Duration(seconds: 1), () {
              if (mounted && _currentState == BrightnessTestState.testing) {
                print('✅ Brightness cycle complete');
                _evaluateTest();
              }
            });
          }
        });
      }
    });
  }

  Future<void> _evaluateTest() async {
    _brightnessTimer?.cancel();
    
    // Evaluate test based on actual brightness readings
    // We should have at least 3 readings: initial, after 50%, after 100%
    bool testPassed = false;
    
    if (_brightnessReadings.length >= 3) {
      final initial = _brightnessReadings[0];
      final after50 = _brightnessReadings[1];
      final after100 = _brightnessReadings[2];
      
      print('📊 Brightness Evaluation:');
      print('  Initial: ${(initial * 100).toStringAsFixed(0)}%');
      print('  After 50%: ${(after50 * 100).toStringAsFixed(0)}%');
      print('  After 100%: ${(after100 * 100).toStringAsFixed(0)}%');
      
      // Test passes if:
      // 1. Brightness changed from initial to 50% (should be around 0.5, allow 0.3-0.7 range)
      // 2. Brightness changed from 50% to 100% (should be around 1.0, allow 0.8-1.0 range)
      final changedTo50 = (after50 >= 0.3 && after50 <= 0.7) || (after50 < initial - 0.1);
      final changedTo100 = (after100 >= 0.8 && after100 <= 1.0) || (after100 > after50 + 0.2);
      
      testPassed = changedTo50 && changedTo100;
      
      print('  Changed to 50%: $changedTo50');
      print('  Changed to 100%: $changedTo100');
      print('  Test Result: ${testPassed ? "PASS" : "FAIL"}');
    } else {
      // If we don't have enough readings, assume it worked if cycle completed
      testPassed = _brightnessStep >= 2;
      print('⚠️ Not enough brightness readings, using step count: $testPassed');
    }
    
    if (mounted) {
      setState(() {
        _brightnessWorking = testPassed;
        _testComplete = true;
        _currentState = BrightnessTestState.resultReady;
      });
      
      // Show proceed button after a brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showProceedButton = true;
          });
        }
      });
    }
  }

  Future<void> _navigateToNextTest() async {
    _restoreBrightness();
    
    final testParametersAsyncValue = ref.read(testParametersProvider);
    List<TestParameterItem>? testParameters;

    if (testParametersAsyncValue.hasValue) {
      testParameters = testParametersAsyncValue.value;
    } else {
      // If still loading, wait a bit and try again
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
        TestConfig.testIdBrightness,
      );
    } else {
      debugPrint('❌ ScreenBrightnessScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handlePass() {
    _restoreBrightness();
    // Save Screen Brightness test result as pass (uses API paramValue and catIcon)
    TestResultHelper.savePass(ref, TestConfig.testIdBrightness);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleFail() {
    _restoreBrightness();
    // Save Screen Brightness test result as fail (uses API paramValue and catIcon)
    TestResultHelper.saveFail(ref, TestConfig.testIdBrightness);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  String _getBrightnessLevelText() {
    if (_brightnessStep == 0) return '50%';
    if (_brightnessStep == 1) return '100%';
    return 'Normal';
  }

  double _getProgressValue() {
    // Progress: 0.0 → 0.5 → 1.0
    if (_brightnessStep == 0) return 0.33; // Low brightness
    if (_brightnessStep == 1) return 0.66; // High brightness
    if (_brightnessStep == 2) return 1.0; // Back to normal
    return 0.0;
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
                  _restoreBrightness();
                  Navigator.of(context).pop();
                },
                onSkip: () {
                  _restoreBrightness();
                  // Mark Screen Brightness test as skipped (uses API paramValue and catIcon)
                  TestResultHelper.saveSkip(ref, TestConfig.testIdBrightness);
                  
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
              if (_shouldShowStartTestButton() && _currentState == BrightnessTestState.readyToTest)
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
      case BrightnessTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdBrightness,
            isPassed: true,
            localFallbackPath: AppStrings.image94Path,
            fallbackIcon: Icons.brightness_6,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingScreenBrightness,
          subtitleLines: [
            AppStrings.screenBrightnessInstruction,
            'The screen brightness will change automatically:',
            '50% → 100% → Normal',
            'Watch the screen brightness change.',
            '',
            '⚠️ Note: You may need to grant "Modify system settings" permission.',
            'If the toggle is disabled, go to:',
            'Settings → Apps → [This App] → Advanced → Modify system settings',
          ],
        );
        
      case BrightnessTestState.testing:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdBrightness,
            isPassed: true,
            localFallbackPath: AppStrings.image94Path,
            fallbackIcon: Icons.brightness_6,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingScreenBrightness,
          subtitleLines: [
            'Brightness Level: ${_getBrightnessLevelText()}',
            'Current: ${(_currentBrightness * 100).toStringAsFixed(0)}%',
            '',
            'Watch the screen brightness change:',
            if (_brightnessStep == 0) '⬇️ Decreasing to 50%...',
            if (_brightnessStep == 1) '⬆️ Increasing to 100%...',
            if (_brightnessStep == 2) '✓ Restoring to Normal...',
          ],
          showProgressBar: true,
          progressValue: _getProgressValue(),
        );
        
      case BrightnessTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdBrightness,
            isPassed: _brightnessWorking,
            localFallbackPath: AppStrings.image94Path,
            fallbackIcon: Icons.brightness_6,
            width: 120,
            height: 120,
          ),
          status: _brightnessWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _brightnessWorking 
              ? AppStrings.screenBrightnessWorking 
              : 'Screen Brightness Not Working',
          subheadingLines: _brightnessWorking
              ? [AppStrings.screenBrightnessWorkingCorrectly]
              : ['Screen brightness change was not detected. Please try again.'],
          showStatusIcon: true,
        );
    }
  }
}
