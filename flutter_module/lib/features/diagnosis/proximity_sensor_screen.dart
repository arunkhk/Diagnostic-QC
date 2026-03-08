import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
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

enum ProximityTestState {
  initial,
  checking,
  sensorNotAvailable,
  readyToTest,
  testing,
  resultReady,
}

class ProximitySensorScreen extends ConsumerStatefulWidget {
  const ProximitySensorScreen({super.key});

  @override
  ConsumerState<ProximitySensorScreen> createState() => _ProximitySensorScreenState();
}

class _ProximitySensorScreenState extends ConsumerState<ProximitySensorScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('proximity'); // Dynamic progress for screen 5
  ProximityTestState _currentState = ProximityTestState.initial;
  bool _isNear = false;
  int _cycleCount = 0;
  bool _sensorWorking = false;
  bool _testComplete = false;
  bool _showProceedButton = false;
  
  // Track screen state changes
  List<bool> _screenStateChanges = []; // true = screen off, false = screen on
  bool _lastProximityState = false; // false = far, true = near
  
  StreamSubscription<int>? _proximitySubscription;
  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    _checkProximitySensorAvailability();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    final isAutoMode = ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdProximity);
    if (!isAutoMode) return;
    if (_currentState != ProximityTestState.initial && _currentState != ProximityTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && (_currentState == ProximityTestState.initial || _currentState == ProximityTestState.readyToTest)) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdProximity);
  }

  @override
  void dispose() {
    _proximitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkProximitySensorAvailability() async {
    setState(() {
      _currentState = ProximityTestState.checking;
    });

    try {
      // Platform-specific check
      if (Platform.isIOS) {
        // iOS: Try to listen to events to check availability
        final completer = Completer<bool>();
        bool sensorAvailable = false;
        StreamSubscription<int>? testSubscription;
        
        try {
          testSubscription = ProximitySensor.events.listen(
            (int event) {
              print('📱 iOS Proximity event received: $event');
              sensorAvailable = true;
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            },
            onError: (error) {
              print('❌ iOS Proximity sensor error: $error');
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
          );
          
          // Wait longer on iOS to detect sensor
          await Future.delayed(const Duration(milliseconds: 1000));
          
          if (!completer.isCompleted) {
            // If no events received, assume sensor exists but needs activation
            // iOS proximity sensor may need actual proximity to trigger
            completer.complete(true); // Assume available, let test determine
          }
          
          await testSubscription.cancel();
        } catch (e) {
          print('❌ iOS Proximity sensor check exception: $e');
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }
        
        final isAvailable = await completer.future;
        
        if (mounted) {
          setState(() {
            if (isAvailable) {
              _currentState = ProximityTestState.readyToTest;
            } else {
              _currentState = ProximityTestState.sensorNotAvailable;
            }
          });
          _scheduleAutoStartIfNeeded();
        }
      } else {
        // Android: Original implementation
        final completer = Completer<bool>();
        bool sensorAvailable = false;
        
        try {
          final subscription = ProximitySensor.events.listen(
            (int event) {
              sensorAvailable = true;
              if (!completer.isCompleted) {
                completer.complete(true);
              }
            },
            onError: (error) {
              if (!completer.isCompleted) {
                completer.complete(false);
              }
            },
          );
          
          // Wait a short time to see if we get any events
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (!completer.isCompleted) {
            completer.complete(sensorAvailable);
          }
          
          await subscription.cancel();
        } catch (e) {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        }
        
        final isAvailable = await completer.future;
        
        if (mounted) {
          setState(() {
            if (isAvailable) {
              _currentState = ProximityTestState.readyToTest;
            } else {
              _currentState = ProximityTestState.sensorNotAvailable;
            }
          });
          _scheduleAutoStartIfNeeded();
        }
      }
    } catch (e) {
      print('❌ Error checking proximity sensor: $e');
      if (mounted) {
        setState(() {
          _currentState = ProximityTestState.sensorNotAvailable;
        });
      }
    }
  }

  Future<void> _startTest() async {
    setState(() {
      _currentState = ProximityTestState.testing;
      _cycleCount = 0;
      _screenStateChanges = [];
      _lastProximityState = false;
    });

    try {
      // Start listening to proximity sensor using proximity_sensor package
      print('📱 Starting proximity sensor test (Platform: ${Platform.isIOS ? "iOS" : "Android"})');
      
      _proximitySubscription = ProximitySensor.events.listen(
        (int event) {
          // Platform-specific threshold for "near" detection
          bool isNear;
          if (Platform.isIOS) {
            // iOS: More sensitive - detect at ~1cm away (lower threshold)
            // iOS proximity sensor values: 0 = far, >0 = near
            // For 1cm detection, we accept any positive value
            isNear = event > 0;
            print('📱 iOS Proximity event: $event, isNear: $isNear (threshold: >0 for ~1cm)');
          } else {
            // Android: Original threshold
            isNear = event > 0;
            print('📱 Android Proximity event: $event, isNear: $isNear');
          }
          _handleProximityChange(isNear);
        },
        onError: (error) {
          print('❌ Proximity sensor error: $error');
          if (mounted) {
            setState(() {
              _currentState = ProximityTestState.readyToTest;
            });
            _scheduleAutoStartIfNeeded();
          }
        },
        cancelOnError: false, // Keep listening even on errors
      );
      
      // iOS: Add timeout to handle cases where sensor doesn't trigger immediately
      if (Platform.isIOS) {
        Future.delayed(const Duration(seconds: 15), () {
          if (mounted && _currentState == ProximityTestState.testing && _cycleCount < 2) {
            print('⚠️ iOS Proximity test timeout - sensor may need activation');
            // Don't fail, just log - user might still be testing
          }
        });
      }
    } catch (e) {
      print('❌ Error starting proximity test: $e');
      if (mounted) {
        setState(() {
          _currentState = ProximityTestState.readyToTest;
        });
        _scheduleAutoStartIfNeeded();
      }
    }
  }

  void _handleProximityChange(bool isNear) {
    if (!mounted || _currentState != ProximityTestState.testing) return;

    setState(() {
      _isNear = isNear;
    });

    // If proximity state changed (near -> far or far -> near)
    if (_lastProximityState != isNear) {
      _lastProximityState = isNear;
      
      if (isNear) {
        // Hand is near earpiece - show black overlay (screen off)
        _screenStateChanges.add(true); // Screen off
      } else {
        // Hand is away - remove overlay (screen on)
        _screenStateChanges.add(false); // Screen on
        
        // Count a cycle when hand moves away (complete cycle: near -> away)
        _cycleCount++;
        
        // Check if we've completed 2 cycles
        if (_cycleCount >= 2) {
          _evaluateTest();
        }
      }
    }
  }

  // Removed brightness control - using black overlay instead

  Future<void> _evaluateTest() async {
    // Stop listening
    await _proximitySubscription?.cancel();
    
    // Check if screen turned on and off correctly
    // We should have at least 4 state changes: off, on, off, on (for 2 cycles)
    // Pattern: near (off) -> away (on) -> near (off) -> away (on)
    bool working = false;
    
    if (_screenStateChanges.length >= 4) {
      // Check if we have alternating on/off pattern
      // First should be off (true), then on (false), then off (true), then on (false)
      working = _screenStateChanges[0] == true && // First: off
                _screenStateChanges[1] == false && // Second: on
                _screenStateChanges[2] == true && // Third: off
                _screenStateChanges[3] == false;  // Fourth: on
    }
    
    if (mounted) {
      setState(() {
        _sensorWorking = working;
        _testComplete = true;
        _currentState = ProximityTestState.resultReady;
      });
      
      // Restore brightness

      
      // Auto-save result based on test outcome
      if (working) {
        TestResultHelper.savePass(ref, TestConfig.testIdProximity);
        
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
    // Reset proximity sensor to initial state before navigating
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
        TestConfig.testIdProximity,
      );
    } else {
      debugPrint('❌ ProximitySensorScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _resetToInitialState() {
    // Cancel any active subscriptions
    _proximitySubscription?.cancel();
    _proximitySubscription = null;
    
    // Reset all state variables to initial values
    setState(() {
      _currentState = ProximityTestState.initial;
      _isNear = false;
      _cycleCount = 0;
      _sensorWorking = false;
      _testComplete = false;
      _showProceedButton = false;
      _screenStateChanges = [];
      _lastProximityState = false;
    });
    
    // Re-check sensor availability to transition to readyToTest state
    // This ensures the screen shows the initial content with "Start Test" button
    _checkProximitySensorAvailability();
  }

  void _handlePass() {
    TestResultHelper.savePass(ref, TestConfig.testIdProximity);
    _navigateToNextTest();
  }

  void _handleFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdProximity);
    _navigateToNextTest();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Black overlay when proximity sensor detects near object
            if (_currentState == ProximityTestState.testing && _isNear)
              Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
              ),
            
            Column(
              children: [
              /// Common Header with Skip button
              CommonHeader(
                title: AppStrings.welcomeTitle,
                version: AppStrings.appVersion,
                onBack: () {
                  Navigator.of(context).pop();
                },
                onSkip: () {
                  // Mark Proximity test as skipped
                  TestResultHelper.saveSkip(ref, TestConfig.testIdProximity);
                  // Navigate to Light Sensor screen
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
                  (_currentState == ProximityTestState.readyToTest ||
                      _currentState == ProximityTestState.initial))
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

  Widget _buildContent() {
    switch (_currentState) {
      case ProximityTestState.initial:
      case ProximityTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdProximity,
            isPassed: true,
            localFallbackPath: AppStrings.image44Path,
            fallbackIcon: Icons.sensor_door,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingProximitySensor,
          subtitleLines: [
            if (Platform.isIOS) ...[
              'Hold your hand about 1 cm away from the top front sensor.',
              'Move hand closer (1 cm) and away twice.',
              'Screen will turn black when hand is near (~1 cm).',
              'Screen will be visible when hand is away.',
              'Note: You don\'t need to touch, just hold hand near (~1 cm).',
            ] else ...[
              'Place your hand on the earpiece and move it away twice.',
              'When hand is near, screen will show black overlay.',
              'When hand is away, screen will be visible again.',
            ],
          ],
        );
        
      case ProximityTestState.checking:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdProximity,
            isPassed: true,
            localFallbackPath: AppStrings.image44Path,
            fallbackIcon: Icons.sensor_door,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingProximitySensor,
          subtitleLines: ['Checking proximity sensor availability...'],
        );
        
      case ProximityTestState.sensorNotAvailable:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdProximity,
            isPassed: false,
            localFallbackPath: AppStrings.image44Path,
            fallbackIcon: Icons.sensor_door,
            width: 120,
            height: 120,
          ),
          heading: 'Proximity Sensor Not Available',
          subtitleLines: [
            'This device does not have a proximity sensor.',
            'The test cannot be performed.',
            if (Platform.isIOS) 'Note: If sensor exists, try restarting the app or device.',
          ],
        );
        
      case ProximityTestState.testing:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdProximity,
            isPassed: true,
            localFallbackPath: AppStrings.image44Path,
            fallbackIcon: Icons.sensor_door,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingProximitySensor,
          subtitleLines: [
            if (Platform.isIOS) ...[
              _isNear 
                  ? 'Hand detected near sensor (~1 cm) - Black overlay shown'
                  : 'Hold hand about 1 cm away from top front sensor',
              'Cycles completed: $_cycleCount / 2',
              'Move hand closer (~1 cm) and away - no need to touch!',
            ] else ...[
              _isNear 
                  ? 'Hand detected near earpiece - Black overlay shown'
                  : 'Hand away from earpiece - Screen visible',
              'Cycles completed: $_cycleCount / 2',
              'Do not move until you place your hand on the earpiece.',
            ],
          ],
        );
        
      case ProximityTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdProximity,
            isPassed: _sensorWorking == true,
            localFallbackPath: AppStrings.image44Path,
            fallbackIcon: Icons.sensor_door,
            width: 120,
            height: 120,
          ),
          status: _sensorWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _sensorWorking 
              ? AppStrings.sensorDetected 
              : AppStrings.sensorNotDetected,
          subheadingLines: _sensorWorking
              ? [AppStrings.proximitySensorWorkingCorrectly]
              : [AppStrings.proximitySensorIssueDetected],
          showStatusIcon: true,
        );
        
      default:
        return const SizedBox();
    }
  }
}
