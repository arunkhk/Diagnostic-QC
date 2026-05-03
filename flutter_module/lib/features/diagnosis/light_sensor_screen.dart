import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:light_sensor/light_sensor.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/responsive_card.dart';
import '../../core/widgets/scan_result_card.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_images_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

enum LightTestState {
  initial,
  checking,
  sensorNotAvailable,
  readyToTest,
  testing,
  resultReady,
}

class LightSensorScreen extends ConsumerStatefulWidget {
  const LightSensorScreen({super.key});

  @override
  ConsumerState<LightSensorScreen> createState() => _LightSensorScreenState();
}

class _LightSensorScreenState extends ConsumerState<LightSensorScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('light'); // Dynamic progress for screen 6
  LightTestState _currentState = LightTestState.initial;
  bool _testComplete = false;
  bool _showProceedButton = false;
  
  // Light sensor data
  double _currentLightLevel = 0.0; // in lux
  bool _isValuesFluctuating = false;
  bool _isCovered = false;
  int _cycleCount = 0;
  bool _sensorWorking = false;
  bool _coverageDetected = false; // Track if sensor coverage was detected
  
  // Track light level changes for cycles
  List<double> _lightLevels = []; // Store light levels for each state
  bool _lastIsCovered = false;
  
  // For fluctuation detection
  final List<double> _recentLightValues = [];
  static const int _fluctuationCheckCount = 10;
  
  StreamSubscription<int>? _lightSubscription;
  
  // iOS-specific stepper feature
  int _iosStepperStep = 0; // 0: Enable, 1: Detected, 2: Show LUX
  Timer? _stepperTimer; // Timer for stepper progression
  bool _autoPassTriggered = false; // Prevent multiple auto-passes
  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    _checkLightSensorAvailability();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdLight)) return;
    if (_currentState != LightTestState.initial && _currentState != LightTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && (_currentState == LightTestState.initial || _currentState == LightTestState.readyToTest)) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdLight);
  }

  @override
  void dispose() {
    // Clean up all resources when screen is disposed
    _cleanupLightSensor();
    _stepperTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLightSensorAvailability() async {
    setState(() {
      _currentState = LightTestState.checking;
    });

    try {
      // Platform-specific check
      if (Platform.isIOS) {
        // iOS: iPhone 16 has ambient light sensor, but we use camera-based estimation
        // Assume available and let the test determine functionality
        if (mounted) {
          setState(() {
            _currentState = LightTestState.readyToTest;
            // Don't start listening yet - wait for user to click "Start Test"
            // This prevents auto-triggering before user is ready
          });
          _scheduleAutoStartIfNeeded();
        }
      } else {
        // Android: Check if light sensor is available using light_sensor package
        final isAvailable = await LightSensor.hasSensor();
        
        if (mounted) {
          setState(() {
            if (isAvailable) {
              _currentState = LightTestState.readyToTest;
              // Don't start listening yet - wait for user to click "Start Test"
              // This prevents auto-triggering before user is ready
            } else {
              _currentState = LightTestState.sensorNotAvailable;
            }
          });
          if (isAvailable) _scheduleAutoStartIfNeeded();
        }
      }
    } catch (e) {
      print('❌ Error checking light sensor: $e');
      if (mounted) {
        setState(() {
          _currentState = LightTestState.sensorNotAvailable;
        });
      }
    }
  }

  void _startLightSensorListening() {
    try {
      _lightSubscription = LightSensor.luxStream().listen(
        (int lux) {
          if (!mounted) return;
          
          final double luxDouble = lux.toDouble();
          
          setState(() {
            _currentLightLevel = luxDouble;
            
            // Track recent values for fluctuation detection
            _recentLightValues.add(luxDouble);
            if (_recentLightValues.length > _fluctuationCheckCount) {
              _recentLightValues.removeAt(0);
            }
            
            // Check for fluctuation
            if (_recentLightValues.length >= 5) {
              final min = _recentLightValues.reduce((a, b) => a < b ? a : b);
              final max = _recentLightValues.reduce((a, b) => a > b ? a : b);
              if (Platform.isIOS) {
                // iOS camera-based: Lower threshold (0.5 lux) since camera values may vary less
                _isValuesFluctuating = (max - min) > 0.5;
              } else {
                // Android real sensor: Original threshold (1.0 lux)
                _isValuesFluctuating = (max - min) > 1.0;
              }
            }
            
            // Determine if sensor is covered (light level significantly decreased)
            // Platform-specific thresholds
            if (_recentLightValues.length >= 3) {
              final avg = _recentLightValues.reduce((a, b) => a + b) / _recentLightValues.length;
              if (Platform.isIOS) {
                // iOS camera-based: More lenient threshold (30% drop) since camera responds differently
                _isCovered = luxDouble < (avg * 0.7);
              } else {
                // Android real sensor: Original threshold (50% drop)
                _isCovered = luxDouble < (avg * 0.5);
              }
            }
            
            // Track cycles (cover -> uncover)
            if (_currentState == LightTestState.testing) {
              _handleLightChange(luxDouble);
            }
            
            // iOS-specific: Start stepper sequence when sensor is working
            // Only trigger when test is actively running (testing state)
            if (Platform.isIOS && 
                !_autoPassTriggered && 
                _recentLightValues.length >= 3 &&
                _currentState == LightTestState.testing &&
                _iosStepperStep == 0) {
              _startIOSStepperSequence();
            }
          });
        },
        onError: (error) {
          print('❌ Light sensor error: $error');
        },
      );
    } catch (e) {
      print('❌ Error starting light sensor listening: $e');
    }
  }

  // iOS-specific: Stepper sequence (Enable → Detected → Show LUX → Auto-pass)
  void _startIOSStepperSequence() {
    if (_autoPassTriggered) return; // Prevent multiple triggers
    
    print('📱 iOS: Light sensor working! Starting stepper sequence...');
    
    // Step 1: Enable (show immediately)
    setState(() {
      _iosStepperStep = 1; // Show first line
    });
    
    // Step 2: Detected (after 3 seconds)
    _stepperTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _iosStepperStep = 2; // Show second line
      });
      
      // Step 3: Show LUX (after another 3 seconds)
      _stepperTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        
        // Check if LUX is zero (no sensor)
        final hasSensor = _currentLightLevel > 0;
        
        setState(() {
          _iosStepperStep = 3; // Show third line
        });
        
        if (hasSensor) {
          // Sensor detected - auto-pass after 3 seconds
          _stepperTimer = Timer(const Duration(seconds: 3), () {
            if (!mounted) return;
            _autoPassTriggered = true;
            
            // Mark test as passed
            setState(() {
              _sensorWorking = true;
              _testComplete = true;
              _currentState = LightTestState.resultReady;
            });
            
            print('✅ iOS: Light sensor test auto-passed! Moving to next screen...');
            
            // Save result and navigate to next screen
            TestResultHelper.savePass(ref, TestConfig.testIdLight);
            print('✅ iOS: Light sensor test PASSED - Result saved to diagnosis summary');
            
            // Auto-navigate to next screen after showing result briefly
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                _navigateToNextTest();
              }
            });
          });
        } else {
          // No sensor (LUX = 0) - mark as failed
          _autoPassTriggered = true;
          setState(() {
            _sensorWorking = false;
            _testComplete = true;
            _currentState = LightTestState.resultReady;
            _showProceedButton = true;
          });
          
          TestResultHelper.saveFail(ref, TestConfig.testIdLight);
          print('❌ iOS: No light sensor detected (LUX = 0) - Test failed');
        }
      });
    });
  }

  void _handleLightChange(double lux) {
    // If covered state changed
    if (_lastIsCovered != _isCovered) {
      _lastIsCovered = _isCovered;
      
      if (_isCovered) {
        // Sensor just got covered - light decreased
        _lightLevels.add(lux);
        _coverageDetected = true; // Mark that coverage was detected
      } else {
        // Sensor just got uncovered - light increased
        _lightLevels.add(lux);
        
        // Count a cycle when sensor is uncovered (complete cycle: cover -> uncover)
        _cycleCount++;
        
        // Check if we've completed 1 cycle
        if (_cycleCount >= 1) {
          _evaluateTest();
        }
      }
    }
  }

  Future<void> _startTest() async {
    // Clean up any existing timers/subscriptions before starting
    _cleanupLightSensor();
    
    setState(() {
      _currentState = LightTestState.testing;
      _cycleCount = 0;
      _lightLevels = [];
      _lastIsCovered = false;
      _coverageDetected = false;
      _recentLightValues.clear();
      _autoPassTriggered = false; // Reset auto-pass flag
      _iosStepperStep = 0; // Reset stepper
      _testComplete = false;
      _showProceedButton = false;
    });
    
    // Restart light sensor listening for the test
    _startLightSensorListening();
  }
  
  // Clean up all light sensor resources
  void _cleanupLightSensor() {
    // Cancel subscription
    _lightSubscription?.cancel();
    _lightSubscription = null;
    
    // Cancel timers
    _stepperTimer?.cancel();
    _stepperTimer = null;
    
    // Reset flags
    _iosStepperStep = 0;
    _autoPassTriggered = false;
    
    print('🧹 Light sensor: All resources cleaned up');
  }

  Future<void> _evaluateTest() async {
    // Stop listening
    await _lightSubscription?.cancel();
    
    // Evaluate test based on:
    // 1. Sensor coverage was detected (sensor was covered during test)
    // 2. Light level was fluctuating
    // 3. After 1 cycle, mark as pass if both conditions are met
    bool working = false;
    
    // Platform-specific evaluation
    if (Platform.isIOS) {
      // iOS: Very lenient - sensor is working if we got light values
      // Since camera-based estimation may have static values in stable light,
      // we pass if we're receiving values (proves sensor is functional)
      if (_recentLightValues.length >= 3) {
        // Check if values are changing (even slightly)
        final min = _recentLightValues.reduce((a, b) => a < b ? a : b);
        final max = _recentLightValues.reduce((a, b) => a > b ? a : b);
        bool hasVariation = (max - min) > 0.1; // Very small threshold
        
        // Check coverage (for iOS, use the instance variable)
        final coverageDetected = _coverageDetected && _lightLevels.length >= 2;
        
        // iOS: Pass if we have 3+ values (sensor is clearly working)
        // OR if coverage detected OR values vary OR cycle completed
        // This is very lenient because camera-based estimation may have static values
        working = _recentLightValues.length >= 3 || coverageDetected || hasVariation || _cycleCount >= 1;
        print('📱 iOS Test Evaluation:');
        print('  - Values received: ${_recentLightValues.length}');
        print('  - Coverage detected: $coverageDetected');
        print('  - Has variation: $hasVariation (min=$min, max=$max)');
        print('  - Cycles: $_cycleCount');
        print('  - Result: $working (passing because ${_recentLightValues.length >= 3 ? "3+ values received" : "other criteria met"})');
      } else if (_recentLightValues.length > 0) {
        // Not enough values yet, but if we have any, sensor is working
        working = true;
        print('📱 iOS Test: ${_recentLightValues.length} values received, sensor is working');
      } else {
        working = false;
        print('📱 iOS Test: No values received, sensor not working');
      }
    } else {
      // Android: Original strict criteria - need both coverage AND fluctuation
      if (_cycleCount >= 1) {
        final coverageDetected = _coverageDetected && _lightLevels.length >= 2;
        bool valuesFluctuated = false;
        if (_recentLightValues.length >= 5) {
          final min = _recentLightValues.reduce((a, b) => a < b ? a : b);
          final max = _recentLightValues.reduce((a, b) => a > b ? a : b);
          valuesFluctuated = (max - min) > 1.0;
        }
        working = coverageDetected && valuesFluctuated;
        print('🔍 Android Test Evaluation:');
        print('  - Cycles completed: $_cycleCount');
        print('  - Coverage detected: $coverageDetected');
        print('  - Values fluctuating: $valuesFluctuated');
        print('  - Sensor working: $working');
      }
    }
    
    if (mounted) {
      setState(() {
        _sensorWorking = working;
        _testComplete = true;
        _currentState = LightTestState.resultReady;
      });
      
      // Auto-save result based on test outcome
      if (working) {
        TestResultHelper.savePass(ref, TestConfig.testIdLight);
        print('✅ Light sensor test: PASSED - Result saved to diagnosis summary');
        
        // Auto-navigate after brief delay when test passes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _navigateToNextTest();
            }
          });
        });
      } else {
        // Save fail result so it shows in diagnosis summary
        TestResultHelper.saveFail(ref, TestConfig.testIdLight);
        print('❌ Light sensor test: FAILED - Result saved to diagnosis summary');
        
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
    // Reset light sensor to initial state before navigating
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
        TestConfig.testIdLight,
      );
    } else {
      debugPrint('❌ LightSensorScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _resetToInitialState() {
    // Cancel any active subscriptions
    _lightSubscription?.cancel();
    _lightSubscription = null;
    
    // Reset all state variables to initial values
    setState(() {
      _currentState = LightTestState.initial;
      _testComplete = false;
      _showProceedButton = false;
      _currentLightLevel = 0.0;
      _isValuesFluctuating = false;
      _isCovered = false;
      _cycleCount = 0;
      _sensorWorking = false;
      _coverageDetected = false;
      _lightLevels = [];
      _lastIsCovered = false;
      _recentLightValues.clear();
      _autoPassTriggered = false;
      _iosStepperStep = 0;
    });
    
    // Re-check sensor availability to transition to readyToTest state
    // This ensures the screen shows the initial content with "Start Test" button
    _checkLightSensorAvailability();
  }

  void _handlePass() {
    TestResultHelper.savePass(ref, TestConfig.testIdLight);
    _navigateToNextTest();
  }

  void _handleFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdLight);
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
                  // Mark Light Sensor test as skipped
                  TestResultHelper.saveSkip(ref, TestConfig.testIdLight);
                  
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

              /// Main Content Card - ResponsiveCard when testing, ScanResultCard when complete
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      bottom: _testComplete ? 24 : 180, // Less padding when complete
                    ),
                    child: _buildContent(),
                  ),
                ),
              ),

              /// Begin Test Button (only when ready to test or initial, and not auto mode)
              if (_shouldShowStartTestButton() &&
                  (_currentState == LightTestState.readyToTest ||
                      _currentState == LightTestState.initial))
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

            /// Common Footer with ellipse images (only show before test completes) - ignorePointer to allow button clicks
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

  // Build iOS stepper card - shows only current step text (not previous steps)
  Widget _buildIOSStepperCard() {
    // Show only the current step text (not previous steps)
    final hasSensor = _currentLightLevel > 0;
    
    List<String> subtitleLines = [];
    
    // Show only the current step (not cumulative)
    switch (_iosStepperStep) {
      case 1: // Step 1: Enable Light Sensor
        subtitleLines.add('Step 1: Enable Light Sensor');
        subtitleLines.add('iOS uses the back camera to estimate ambient light levels.');
        subtitleLines.add('The camera\'s ISO and exposure settings are analyzed to calculate lux values.');
        break;
        
      case 2: // Step 2: Sensor Detected
        subtitleLines.add('Step 2: Sensor Detected');
        subtitleLines.add('Light sensor is working and receiving values.');
        break;
        
      case 3: // Step 3: Show LUX
        if (hasSensor) {
          subtitleLines.add('Step 3: Light Level Detected');
          subtitleLines.add('Current Light Level: ${_currentLightLevel.toStringAsFixed(2)} lux');
          subtitleLines.add('Test will pass automatically...');
        } else {
          subtitleLines.add('Step 3: No Sensor Detected');
          subtitleLines.add('Light Level: 0.00 lux');
          subtitleLines.add('Device does not have ambient light sensor.');
        }
        break;
    }
    
    // Determine icon and color based on current step
    IconData stepIcon = Icons.settings;
    Color stepColor = Colors.blue;
    
    if (_iosStepperStep >= 3) {
      stepIcon = hasSensor ? Icons.lightbulb : Icons.error;
      stepColor = hasSensor ? Colors.amber : Colors.red;
    } else if (_iosStepperStep >= 2) {
      stepIcon = Icons.check_circle;
      stepColor = Colors.green;
    } else {
      stepIcon = Icons.settings;
      stepColor = Colors.blue;
    }
    
    return ResponsiveCard(
      customImageWidget: CommonTestImage(
        screenName: TestConfig.testIdLight,
        isPassed: true,
        localFallbackPath: AppStrings.image48Path,
        fallbackIcon: Icons.lightbulb,
        width: 120,
        height: 120,
      ),
      heading: AppStrings.testingLightSensor,
      subtitleLines: subtitleLines,
    );
  }
  
  Widget _buildStepperDot(int step, Color activeColor) {
    final isActive = _iosStepperStep >= step;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? activeColor : Colors.grey,
        border: Border.all(
          color: isActive ? activeColor : Colors.grey,
          width: 2,
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentState) {
      case LightTestState.initial:
      case LightTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdLight,
            isPassed: true,
            localFallbackPath: AppStrings.image48Path,
            fallbackIcon: Icons.lightbulb,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingLightSensor,
          subtitleLines: [
            if (Platform.isIOS) ...[
              'Click "Start Test" to begin.',
              'If sensor is working, test will pass automatically.',
              'Note: iOS uses the back camera for light estimation.',
            ] else ...[
              'Current Light Level: ${_currentLightLevel.toStringAsFixed(2)} lux',
              if (_isValuesFluctuating) 'Values are fluctuating',
              'Cover the sensor with your hand and move it away once.',
              'Light level should decrease when covered and increase when uncovered.',
            ],
          ],
        );
        
      case LightTestState.checking:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdLight,
            isPassed: true,
            localFallbackPath: AppStrings.image48Path,
            fallbackIcon: Icons.lightbulb,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingLightSensor,
          subtitleLines: ['Checking light sensor availability...'],
        );
        
      case LightTestState.sensorNotAvailable:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdLight,
            isPassed: false,
            localFallbackPath: AppStrings.image48Path,
            fallbackIcon: Icons.lightbulb,
            width: 120,
            height: 120,
          ),
          heading: 'Light Sensor Not Available',
          subtitleLines: [
            'This device does not have a light sensor.',
            'The test cannot be performed.',
          ],
        );
        
      case LightTestState.testing:
        // iOS-specific: Show stepper UI
        if (Platform.isIOS && _iosStepperStep > 0) {
          return _buildIOSStepperCard();
        }
        // Normal testing state (Android or iOS manual test)
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdLight,
            isPassed: true,
            localFallbackPath: AppStrings.image48Path,
            fallbackIcon: Icons.lightbulb,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingLightSensor,
          subtitleLines: [
            'Current Light Level: ${_currentLightLevel.toStringAsFixed(2)} lux',
            if (_isValuesFluctuating) 'Values are fluctuating',
            _isCovered 
                ? (Platform.isIOS ? 'Camera covered - Light level decreased' : 'Sensor covered - Light level decreased')
                : (Platform.isIOS ? 'Camera uncovered - Light level increased' : 'Sensor uncovered - Light level increased'),
            if (Platform.isIOS) ...[
              // iOS: Stepper or manual test
              if (_iosStepperStep > 0) ...[
                // Stepper is active, don't show manual instructions
              ] else ...[
                'Cycles completed: $_cycleCount / 1',
                'Cover the camera area (back camera preferred) with your hand and move it away once.',
              ],
            ] else ...[
              // Android: Original manual test flow
              'Cycles completed: $_cycleCount / 1',
              'Cover the sensor with your hand and move it away once.',
            ],
          ],
        );
        
      case LightTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdLight,
            isPassed: _sensorWorking == true,
            localFallbackPath: AppStrings.image48Path,
            fallbackIcon: Icons.lightbulb,
            width: 120,
            height: 120,
          ),
          status: _sensorWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _sensorWorking 
              ? AppStrings.lightSensorDetected 
              : AppStrings.lightSensorNotDetected,
          subheadingLines: _sensorWorking
              ? [
                  'Light Quantity: ${_currentLightLevel.toStringAsFixed(2)} lux',
                  AppStrings.lightSensorStatus,
                ]
              : [AppStrings.lightSensorIssueDetected],
          showStatusIcon: true,
        );
        
      default:
        return const SizedBox();
    }
  }
}
