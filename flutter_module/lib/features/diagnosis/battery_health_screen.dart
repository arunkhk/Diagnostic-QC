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
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/responsive_card.dart';
import '../../core/widgets/scan_result_card.dart';
import 'providers/battery_provider.dart';
import 'providers/test_parameters_provider.dart';
import 'utils/test_navigation_service.dart';
import 'utils/test_config.dart';
import 'utils/test_result_helper.dart';
import 'models/test_parameter_item.dart';
import '../../core/widgets/common_test_image.dart';

class BatteryHealthScreen extends ConsumerStatefulWidget {
  const BatteryHealthScreen({super.key});

  @override
  ConsumerState<BatteryHealthScreen> createState() => _BatteryHealthScreenState();
}

class _BatteryHealthScreenState extends ConsumerState<BatteryHealthScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('battery'); // Dynamic progress for screen 3
  final MethodChannel _batteryChannel = MethodChannel(AppConfig.batteryChannel);

  final EventChannel _batteryEventChannel = EventChannel(AppConfig.batteryEventChannel);
  
  bool _testComplete = false;
  bool? _batteryHealthGood;
  bool _showResultButtons = false;
  StreamSubscription<dynamic>? _batterySubscription;
  
  // Battery information
  String _health = 'Unknown';
  int _level = 0;
  int _scale = 100;
  String _status = 'Unknown';
  String _technology = 'Unknown';
  double _temperature = 0.0;
  int _voltage = 0;

  @override
  void initState() {
    super.initState();
    _checkBatteryInfo();
    _listenToBatteryEvents();
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkBatteryInfo() async {
    try {
      final result = await _batteryChannel.invokeMethod<Map<dynamic, dynamic>>('getBatteryInfo');
      if (result != null && mounted) {
        _updateBatteryInfo(result);
      }
    } catch (e) {
      debugPrint('Error checking battery info: $e');
      if (mounted) {
        setState(() {
          _testComplete = true;
          _batteryHealthGood = false;
        });
      }
    }
  }

  void _listenToBatteryEvents() {
    _batterySubscription = _batteryEventChannel.receiveBroadcastStream().listen(
      (event) {
        if (mounted) {
          final batteryInfo = event as Map<dynamic, dynamic>;
          _updateBatteryInfo(batteryInfo);
        }
      },
      onError: (error) {
        debugPrint('Error listening to battery events: $error');
      },
    );
  }

  void _updateBatteryInfo(Map<dynamic, dynamic> batteryInfo) {
    if (mounted) {
      setState(() {
        _health = batteryInfo['health'] as String? ?? 'Unknown';
        _level = batteryInfo['level'] as int? ?? 0;
        _scale = batteryInfo['scale'] as int? ?? 100;
        _status = batteryInfo['status'] as String? ?? 'Unknown';
        _technology = batteryInfo['technology'] as String? ?? 'Unknown';
        _temperature = (batteryInfo['temperature'] as num?)?.toDouble() ?? 0.0;
        _voltage = batteryInfo['voltage'] as int? ?? 0;
        
        _batteryHealthGood = _health == 'Good';
        _testComplete = true;
      });
      
      // Save battery info to provider for later use in diagnosis summary
      ref.read(batteryProvider.notifier).saveBatteryInfo(
        BatteryInfo(
          health: _health,
          level: _level,
          scale: _scale,
          status: _status,
          technology: _technology,
          temperature: _temperature,
          voltage: _voltage,
        ),
      );
      
      // Show result buttons after a brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showResultButtons = true;
          });
        }
      });
    }
  }

  Future<void> _navigateToNextTest() async {
    if (!mounted) return;
    
    // Wait for test parameters to load if needed
    final testParametersAsync = ref.read(testParametersProvider);
    List<TestParameterItem> testParameters;
    
    if (testParametersAsync.hasValue) {
      testParameters = testParametersAsync.value!;
    } else {
      // Wait a bit for parameters to load
      await Future.delayed(const Duration(milliseconds: 200));
      final updatedValue = ref.read(testParametersProvider);
      if (updatedValue.hasValue) {
        testParameters = updatedValue.value!;
      } else {
        // Still loading, use sorted provider (might be empty)
        testParameters = ref.read(sortedTestParametersProvider);
      }
    }
    
    if (!mounted) return;
    
    // Navigate to next test based on API order
    TestNavigationService.navigateToNextTest(
      context,
      testParameters,
      TestConfig.testIdBattery,
    );
  }

  void _handlePass() {
    // Save Battery Health test result as pass (uses API paramValue and catIcon)
    TestResultHelper.savePass(ref, TestConfig.testIdBattery);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleFail() {
    // Save Battery Health test result as fail (uses API paramValue and catIcon)
    TestResultHelper.saveFail(ref, TestConfig.testIdBattery);
    
    // Navigate to next test based on API order
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
                  // Mark Battery Health test as skipped (uses API paramValue and catIcon)
                  TestResultHelper.saveSkip(ref, TestConfig.testIdBattery);
                  
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
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: _testComplete ? 24 : 180, // Less padding when complete (content is scrollable)
                  ),
                  child: _testComplete && _batteryHealthGood != null
                      ? ScanResultCard(
                          customImageWidget: CommonTestImage(
                            screenName: TestConfig.testIdBattery,
                            isPassed: _batteryHealthGood == true,
                            localFallbackPath: AppStrings.image41Path,
                            fallbackIcon: Icons.battery_full,
                            width: 120,
                            height: 120,
                          ),
                          status: _batteryHealthGood == true
                              ? ScanStatus.passed
                              : ScanStatus.failed,
                          title: 'Battery Info',
                          subheadingLines: [
                            'Health: ${Platform.isIOS && _health == 'Good' ? 'Good (iOS limitation)' : _health}',
                            'Level: $_level%',
                            'Status: $_status',
                            'Temperature: ${Platform.isIOS && _temperature == 0.0 ? 'N/A (iOS limitation)' : '${_temperature.toStringAsFixed(1)}°C'}',
                            'Voltage: ${Platform.isIOS && _voltage == 0 ? 'N/A (iOS limitation)' : '${(_voltage / 1000.0).toStringAsFixed(2)}V'}',
                            'Technology: ${Platform.isIOS && _technology == 'Unknown' ? 'N/A (iOS limitation)' : _technology}',
                            'Scale: $_scale',
                            if (Platform.isIOS) 'Note: iOS doesn\'t provide temperature, voltage, or technology via public API',
                          ],
                        )
                      : ResponsiveCard(
                          customImageWidget: CommonTestImage(
                            screenName: TestConfig.testIdBattery,
                            isPassed: true,
                            localFallbackPath: AppStrings.image41Path,
                            fallbackIcon: Icons.battery_full,
                            width: 120,
                            height: 120,
                          ),
                          heading: AppStrings.checkingBatteryHealth,
                          subtitleLines: [
                            AppStrings.analyzingBatteryPerformance,
                          ],
                          showProgressBar: false,
                          progressDuration: const Duration(seconds: 0),
                          onProgressComplete: () {},
                        ),
                ),
              ),

              /// Pass/Fail Buttons (only after test completes)
              if (_showResultButtons && _batteryHealthGood != null)
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
          /// Common Footer with ellipse images (only show after test completes) - ignorePointer to allow button clicks
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
}

