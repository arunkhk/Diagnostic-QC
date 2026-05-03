import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/scan_result_card.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_images_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

enum AccelerometerTestState {
  initial,
  testing,
  sensorNotAvailable,
  resultReady,
}

class AccelerometerTestScreen extends ConsumerStatefulWidget {
  const AccelerometerTestScreen({super.key});

  @override
  ConsumerState<AccelerometerTestScreen> createState() => _AccelerometerTestScreenState();
}

class _AccelerometerTestScreenState extends ConsumerState<AccelerometerTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('accelerometer'); // Dynamic progress for screen 25
  AccelerometerTestState _currentState = AccelerometerTestState.initial;
  
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _x = 0.0;
  double _y = 0.0;
  double _z = 0.0;
  
  bool _hasSensor = false;
  bool _isChecking = true;
  bool _sensorWorking = false;
  bool _testComplete = false;
  Timer? _testTimer;
  List<double> _xValues = [];
  List<double> _yValues = [];
  List<double> _zValues = [];

  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    _checkAccelerometerAvailability();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdAccelerometer)) return;
    if (_currentState != AccelerometerTestState.initial || !_hasSensor) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == AccelerometerTestState.initial && _hasSensor) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdAccelerometer);
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _testTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAccelerometerAvailability() async {
    try {
      // Try to listen to accelerometer for a short time to check if sensor exists
      final completer = Completer<bool>();
      bool sensorAvailable = false;
      
      final subscription = accelerometerEventStream().listen(
        (event) {
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

      // Wait for 500ms to see if we get any sensor data
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!completer.isCompleted) {
        completer.complete(sensorAvailable);
      }
      
      await subscription.cancel();
      
      final isAvailable = await completer.future;
      
      setState(() {
        _isChecking = false;
        _hasSensor = isAvailable;
        if (!isAvailable) {
          _currentState = AccelerometerTestState.sensorNotAvailable;
        }
      });
      _scheduleAutoStartIfNeeded();
    } catch (e) {
      print('❌ Error checking accelerometer sensor: $e');
      setState(() {
        _isChecking = false;
        _hasSensor = false;
        _currentState = AccelerometerTestState.sensorNotAvailable;
      });
    }
  }

  void _startTest() {
    if (!_hasSensor) {
      return;
    }

    setState(() {
      _currentState = AccelerometerTestState.testing;
      _xValues.clear();
      _yValues.clear();
      _zValues.clear();
      _sensorWorking = false;
      _testComplete = false;
    });

    // Listen to accelerometer events
    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        setState(() {
          _x = event.x;
          _y = event.y;
          _z = event.z;
          _xValues.add(event.x);
          _yValues.add(event.y);
          _zValues.add(event.z);
        });

        // Check if values are fluctuating (sensor is working)
        if (_xValues.length > 10) {
          // Get last 10 readings
          final lastXValues = _xValues.sublist(_xValues.length - 10);
          final lastYValues = _yValues.sublist(_yValues.length - 10);
          final lastZValues = _zValues.sublist(_zValues.length - 10);

          // Calculate min and max for each axis
          final xMin = lastXValues.reduce((a, b) => a < b ? a : b);
          final xMax = lastXValues.reduce((a, b) => a > b ? a : b);
          final yMin = lastYValues.reduce((a, b) => a < b ? a : b);
          final yMax = lastYValues.reduce((a, b) => a > b ? a : b);
          final zMin = lastZValues.reduce((a, b) => a < b ? a : b);
          final zMax = lastZValues.reduce((a, b) => a > b ? a : b);

          // Calculate variation (range) for each axis
          final xVariation = (xMax - xMin).abs();
          final yVariation = (yMax - yMin).abs();
          final zVariation = (zMax - zMin).abs();

          // If there's significant variation, sensor is working
          if (xVariation > 0.1 || yVariation > 0.1 || zVariation > 0.1) {
            if (!_sensorWorking) {
              setState(() {
                _sensorWorking = true;
              });
            }
          }
        }
      },
      onError: (error) {
        print('❌ Accelerometer error: $error');
        setState(() {
          _currentState = AccelerometerTestState.sensorNotAvailable;
        });
      },
    );

    // Test runs for 5 seconds
    _testTimer = Timer(const Duration(seconds: 5), () {
      _accelerometerSubscription?.cancel();
      setState(() {
        _currentState = AccelerometerTestState.resultReady;
        _testComplete = true;
      });
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
        TestConfig.testIdAccelerometer,
      );
    } else {
      debugPrint('❌ AccelerometerTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleTestPass() {
    TestResultHelper.savePass(ref, TestConfig.testIdAccelerometer);
    _navigateToNextTest();
  }

  void _handleTestFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdAccelerometer);
    _navigateToNextTest();
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdAccelerometer);
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
                        if (_isChecking)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_currentState == AccelerometerTestState.initial)
                          // Initial state - show instruction
                          CommonContentWidget(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdAccelerometer,
                              isPassed: true,
                              localFallbackPath: AppStrings.image113Path,
                              fallbackIcon: Icons.device_hub,
                              width: 120,
                              height: 120,
                            ),
                            heading: AppStrings.testingAccelerometer,
                            subheading: AppStrings.accelerometerTestInstruction,
                          )
                        else if (_currentState == AccelerometerTestState.sensorNotAvailable)
                          // Sensor not available - show error
                          ScanResultCard(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdAccelerometer,
                              isPassed: false,
                              localFallbackPath: AppStrings.image113Path,
                              fallbackIcon: Icons.device_hub,
                              width: 120,
                              height: 120,
                            ),
                            status: ScanStatus.failed,
                            title: AppStrings.accelerometerNotDetected,
                            subheadingLines: [
                              AppStrings.accelerometerNotDetectedMessage,
                            ],
                            showStatusIcon: false,
                          )
                        else if (_currentState == AccelerometerTestState.testing)
                          // Testing - show sensor values
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CommonContentWidget(
                                customImageWidget: CommonTestImage(
                                  screenName: TestConfig.testIdAccelerometer,
                                  isPassed: true,
                                  localFallbackPath: AppStrings.image113Path,
                                  fallbackIcon: Icons.device_hub,
                                  width: 120,
                                  height: 120,
                                ),
                                heading: AppStrings.testingAccelerometer,
                                subheading: null,
                              ),
                              const SizedBox(height: 24),
                              // Sensor values display - full width with proper background
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• X: ${_x.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '• Y: ${_y.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '• Z: ${_z.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        else if (_currentState == AccelerometerTestState.resultReady)
                          // Result ready - show ScanResultCard with pass/fail status
                          ScanResultCard(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdAccelerometer,
                              isPassed: _sensorWorking == true,
                              localFallbackPath: AppStrings.image113Path,
                              fallbackIcon: Icons.device_hub,
                              width: 120,
                              height: 120,
                            ),
                            status: _sensorWorking ? ScanStatus.passed : ScanStatus.failed,
                            title: _sensorWorking 
                                ? AppStrings.accelerometerWorking 
                                : AppStrings.accelerometerNotWorking,
                            subheadingLines: _sensorWorking 
                                ? [AppStrings.accelerometerWorkingMessage]
                                : [AppStrings.accelerometerNotWorkingMessage],
                            showStatusIcon: true,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              /// Bottom Buttons - Always at bottom
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    if (_currentState == AccelerometerTestState.initial && _shouldShowStartTestButton())
                      CommonButton(
                        text: AppStrings.beginTestButton,
                        onPressed: _hasSensor ? _startTest : null,
                        enabled: _hasSensor,
                      )
                    else if (_currentState == AccelerometerTestState.sensorNotAvailable)
                      // Pass/Fail buttons when sensor not available
                      CommonTwoButtons(
                        leftButtonText: AppStrings.failButton,
                        rightButtonText: AppStrings.passButton,
                        onLeftButtonPressed: _handleTestFail,
                        onRightButtonPressed: _handleTestPass,
                      )
                    else if (_currentState == AccelerometerTestState.resultReady)
                      // Show Pass/Fail buttons
                      CommonTwoButtons(
                        leftButtonText: AppStrings.failButton,
                        rightButtonText: AppStrings.passButton,
                        onLeftButtonPressed: _handleTestFail,
                        onRightButtonPressed: _handleTestPass,
                      )
                    else if (_currentState == AccelerometerTestState.testing)
                      // Show testing state - keep button at bottom but disabled
                      CommonButton(
                        text: 'Testing...',
                        onPressed: null,
                        enabled: false,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }
}

