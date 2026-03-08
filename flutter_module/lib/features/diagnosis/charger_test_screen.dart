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
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/widgets/responsive_card.dart';
import '../../core/widgets/scan_result_card.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'providers/test_parameters_provider.dart';
import 'utils/test_navigation_service.dart';
import 'models/test_parameter_item.dart';
import '../../core/widgets/common_test_image.dart';

class ChargerTestScreen extends ConsumerStatefulWidget {
  const ChargerTestScreen({super.key});

  @override
  ConsumerState<ChargerTestScreen> createState() => _ChargerTestScreenState();
}

class _ChargerTestScreenState extends ConsumerState<ChargerTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('charger'); // Dynamic progress for screen 2
  final MethodChannel _chargerChannel = MethodChannel(AppConfig.chargerChannel);
  final EventChannel _chargerEventChannel = EventChannel(AppConfig.chargerEventChannel);
  
  bool _testComplete = false;
  bool? _chargerConnected;
  bool? _previousChargerState; // Track previous state to prevent duplicate toasts
  bool _showResultButtons = false;
  StreamSubscription<dynamic>? _chargerSubscription;

  @override
  void initState() {
    super.initState();
    _checkChargerStatus();
    _listenToChargerEvents();
  }

  @override
  void dispose() {
    // Cancel subscription to stop listening to events
    _chargerSubscription?.cancel();
    _chargerSubscription = null;
    super.dispose();
  }

  Future<void> _checkChargerStatus() async {
    try {
      final isConnected = await _chargerChannel.invokeMethod<bool>('isChargerConnected');
      if (mounted) {
        setState(() {
          _chargerConnected = isConnected ?? false;
          _previousChargerState = isConnected ?? false; // Initialize previous state
          _testComplete = true; // Mark test as complete regardless of connection status
        });
        
        // If charger is already connected when screen loads, auto-pass and navigate
        if (isConnected == true) {
          CommonToast.showSuccess(
            context,
            message: AppStrings.chargerConnected,
            duration: const Duration(seconds: 2),
          );
          
              // Auto-pass and navigate to next test
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              // Save Charger test result as pass
              TestResultHelper.savePass(ref, TestConfig.testIdCharging);
              
              // Navigate to next test based on API order
              _navigateToNextTest();
            }
          });
        } else {
          // Charger not connected - show buttons after delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() {
                _showResultButtons = true;
              });
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking charger status: $e');
      if (mounted) {
        setState(() {
          _chargerConnected = false;
          _previousChargerState = false;
          _testComplete = true; // Mark test as complete even on error
        });
        
        // Show buttons after delay even on error
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showResultButtons = true;
            });
          }
        });
      }
    }
  }

  void _listenToChargerEvents() {
    _chargerSubscription = _chargerEventChannel.receiveBroadcastStream().listen(
      (event) {
        if (mounted) {
          // Handle both string (Android) and boolean (iOS) values
          bool isConnected;
          if (event is bool) {
            // iOS sends boolean
            isConnected = event;
          } else if (event is String) {
            // Android sends string
            isConnected = event == 'connected';
          } else {
            // Fallback: try to parse as string
            final status = event.toString();
            isConnected = status == 'connected' || status == 'true';
          }
          
          // Only show toast if state has changed
          final stateChanged = _previousChargerState != isConnected;
          
          setState(() {
            _chargerConnected = isConnected;
            if (!_testComplete) {
              _testComplete = true;
            }
          });
          
          // Show toast message only when state changes
          if (stateChanged) {
            _previousChargerState = isConnected;
            if (isConnected) {
              CommonToast.showSuccess(
                context,
                message: AppStrings.chargerConnected,
                duration: const Duration(seconds: 2),
              );
              
              // Auto-pass and navigate to next test when charger is connected
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  // Save Charger test result as pass
                  TestResultHelper.savePass(ref, TestConfig.testIdCharging);
                  
                  // Navigate to next test based on API order
                  _navigateToNextTest();
                }
              });
            } else {
              CommonToast.showError(
                context,
                message: AppStrings.chargerNotConnected,
                duration: const Duration(seconds: 2),
              );
              // Show result buttons only when charger is not connected
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() {
                    _showResultButtons = true;
                  });
                }
              });
            }
          }
        }
      },
      onError: (error) {
        debugPrint('Error listening to charger events: $error');
      },
    );
  }

  Future<void> _navigateToNextTest() async {
    // Cancel subscription before navigation to prevent toasts on other screens
    _chargerSubscription?.cancel();
    _chargerSubscription = null;
    
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
      TestConfig.testIdCharging,
    );
  }

  void _handlePass() {
    // Save Charger test result as pass
    TestResultHelper.savePass(ref, TestConfig.testIdCharging);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleFail() {
    // Save Charger test result as fail
    TestResultHelper.saveFail(ref, TestConfig.testIdCharging);
    
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
                onBack: () {
                  // Cancel subscription before navigation
                  _chargerSubscription?.cancel();
                  _chargerSubscription = null;
                  Navigator.of(context).pop();
                },
                onSkip: () {
                  // Mark Charger test as skipped
                  TestResultHelper.saveSkip(ref, TestConfig.testIdCharging);
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
                  padding: const EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: 180, // Add bottom padding to avoid touching ellipses
                  ),
                  child: _testComplete && _chargerConnected != null
                      ? ScanResultCard(
                          customImageWidget: CommonTestImage(
                            screenName: TestConfig.testIdCharging,
                            isPassed: _chargerConnected == true,
                            localFallbackPath: AppStrings.image25Path,
                            fallbackIcon: Icons.battery_charging_full,
                            width: 120,
                            height: 120,
                          ),
                          status: _chargerConnected == true
                              ? ScanStatus.passed
                              : ScanStatus.failed,
                          title: _chargerConnected == true
                              ? AppStrings.chargerConnected
                              : AppStrings.chargerNotConnected,
                          subheadingLines: _chargerConnected == true
                              ? [
                                  AppStrings.chargerWorkingCorrectly,
                                ]
                              : [
                                  AppStrings.chargerIssueDetected,
                                ],
                        )
                      : ResponsiveCard(
                          customImageWidget: CommonTestImage(
                            screenName: TestConfig.testIdCharging,
                            isPassed: true,
                            localFallbackPath: AppStrings.image25Path,
                            fallbackIcon: Icons.battery_charging_full,
                            width: 120,
                            height: 120,
                          ),
                          heading: AppStrings.connectCharger,
                          subtitleLines: [
                            AppStrings.plugInChargerInstruction,
                          ],
                          showProgressBar: false,
                          progressDuration: const Duration(seconds: 0),
                          onProgressComplete: () {},
                        ),
                ),
              ),

              /// Pass/Fail Buttons (only after test completes)
              if (_showResultButtons && _chargerConnected != null)
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

