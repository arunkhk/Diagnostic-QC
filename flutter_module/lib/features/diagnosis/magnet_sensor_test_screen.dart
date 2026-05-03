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

enum MagnetSensorTestState {
  initial,
  testing,
  sensorNotAvailable,
  resultReady,
}

class MagnetSensorTestScreen extends ConsumerStatefulWidget {
  const MagnetSensorTestScreen({super.key});

  @override
  ConsumerState<MagnetSensorTestScreen> createState() => _MagnetSensorTestScreenState();
}
class _MagnetSensorTestScreenState extends ConsumerState<MagnetSensorTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('magnet'); // Dynamic progress for screen 24
  MagnetSensorTestState _currentState = MagnetSensorTestState.initial;
  
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;
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
    _checkMagnetSensorAvailability();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdMagnet)) return;
    if (_currentState != MagnetSensorTestState.initial || !_hasSensor) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == MagnetSensorTestState.initial && _hasSensor) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdMagnet);
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    _testTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkMagnetSensorAvailability() async {
    try {
      // Try to listen to magnetometer for a short time to check if sensor exists
      final completer = Completer<bool>();
      bool sensorAvailable = false;
      
      final subscription = magnetometerEventStream().listen(
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
          _currentState = MagnetSensorTestState.sensorNotAvailable;
        }
      });
      _scheduleAutoStartIfNeeded();
    } catch (e) {
      print('❌ Error checking magnet sensor: $e');
      setState(() {
        _isChecking = false;
        _hasSensor = false;
        _currentState = MagnetSensorTestState.sensorNotAvailable;
      });
    }
  }

  void _startTest() {
    if (!_hasSensor) {
      return;
    }

    setState(() {
      _currentState = MagnetSensorTestState.testing;
      _xValues.clear();
      _yValues.clear();
      _zValues.clear();
      _sensorWorking = false;
      _testComplete = false;
    });

    // Listen to magnetometer events
    _magnetometerSubscription = magnetometerEventStream().listen(
      (MagnetometerEvent event) {
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
        print('❌ Magnetometer error: $error');
        setState(() {
          _currentState = MagnetSensorTestState.sensorNotAvailable;
        });
      },
    );

    // Test runs for 5 seconds
    _testTimer = Timer(const Duration(seconds: 5), () {
      _magnetometerSubscription?.cancel();
      setState(() {
        _currentState = MagnetSensorTestState.resultReady;
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
        TestConfig.testIdMagnet,
      );
    } else {
      debugPrint('❌ MagnetSensorTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleTestPass() {
    TestResultHelper.savePass(ref, TestConfig.testIdMagnet);
    _navigateToNextTest();
  }

  void _handleTestFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdMagnet);
    _navigateToNextTest();
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdMagnet);
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
                    else if (_currentState == MagnetSensorTestState.initial)
                      // Initial state - show instruction
                      CommonContentWidget(
                        customImageWidget: CommonTestImage(
                          screenName: TestConfig.testIdMagnet,
                          isPassed: true,
                          localFallbackPath: AppStrings.image129Path,
                          fallbackIcon: Icons.explore,
                          width: 120,
                          height: 120,
                        ),
                        heading: AppStrings.testingMagnetSensor,
                        subheading: AppStrings.magnetSensorTestInstruction,
                      )
                    else if (_currentState == MagnetSensorTestState.sensorNotAvailable)
                      // Sensor not available - show error (similar to fingerprint test)
                      ScanResultCard(
                        customImageWidget: CommonTestImage(
                          screenName: TestConfig.testIdMagnet,
                          isPassed: false,
                          localFallbackPath: AppStrings.image129Path,
                          fallbackIcon: Icons.explore,
                          width: 120,
                          height: 120,
                        ),
                        status: ScanStatus.failed,
                        title: AppStrings.magnetSensorNotDetected,
                        subheadingLines: [
                          AppStrings.magnetSensorNotDetectedMessage,
                        ],
                        showStatusIcon: false,
                      )
                    else if (_currentState == MagnetSensorTestState.testing)
                      // Testing - show sensor values
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CommonContentWidget(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdMagnet,
                              isPassed: true,
                              localFallbackPath: AppStrings.image129Path,
                              fallbackIcon: Icons.explore,
                              width: 120,
                              height: 120,
                            ),
                            heading: AppStrings.testingMagnetSensor,
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
                    else if (_currentState == MagnetSensorTestState.resultReady)
                      // Result ready - show ScanResultCard with pass/fail status
                      ScanResultCard(
                        customImageWidget: CommonTestImage(
                          screenName: TestConfig.testIdMagnet,
                          isPassed: _sensorWorking == true,
                          localFallbackPath: AppStrings.image129Path,
                          fallbackIcon: Icons.explore,
                          width: 120,
                          height: 120,
                        ),
                        status: _sensorWorking ? ScanStatus.passed : ScanStatus.failed,
                        title: _sensorWorking 
                            ? AppStrings.magnetSensorWorking 
                            : AppStrings.magnetSensorNotWorking,
                        subheadingLines: _sensorWorking 
                            ? [AppStrings.magnetSensorWorkingMessage]
                            : [AppStrings.magnetSensorNotWorkingMessage],
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
                if (_currentState == MagnetSensorTestState.initial && _shouldShowStartTestButton())
                  CommonButton(
                    text: AppStrings.beginTestButton,
                    onPressed: _hasSensor ? _startTest : null,
                    enabled: _hasSensor,
                  )
                else if (_currentState == MagnetSensorTestState.sensorNotAvailable)
                  // Pass/Fail buttons when sensor not available
                  CommonTwoButtons(
                    leftButtonText: AppStrings.failButton,
                    rightButtonText: AppStrings.passButton,
                    onLeftButtonPressed: _handleTestFail,
                    onRightButtonPressed: _handleTestPass,
                  )
                else if (_currentState == MagnetSensorTestState.resultReady)
                  // Show Pass/Fail buttons
                  CommonTwoButtons(
                    leftButtonText: AppStrings.failButton,
                    rightButtonText: AppStrings.passButton,
                    onLeftButtonPressed: _handleTestFail,
                    onRightButtonPressed: _handleTestPass,
                  )
                else if (_currentState == MagnetSensorTestState.testing)
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

