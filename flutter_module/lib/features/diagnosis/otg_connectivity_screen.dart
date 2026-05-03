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
import '../../core/widgets/common_toast.dart';
import '../../core/widgets/responsive_card.dart';
import '../../core/widgets/scan_result_card.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'providers/test_images_provider.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';
import '../../core/widgets/common_test_image.dart';

enum OtgTestState {
  readyToTest,
  testing,
  resultReady,
}

class OtgConnectivityScreen extends ConsumerStatefulWidget {
  const OtgConnectivityScreen({super.key});

  @override
  ConsumerState<OtgConnectivityScreen> createState() => _OtgConnectivityScreenState();
}

class _OtgConnectivityScreenState extends ConsumerState<OtgConnectivityScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('otg'); // Dynamic progress for screen 14
  final MethodChannel _otgChannel = MethodChannel(AppConfig.otgChannel);
  final EventChannel _otgEventChannel = EventChannel(AppConfig.otgEventChannel);
  
  OtgTestState _currentState = OtgTestState.readyToTest;
  bool _testComplete = false;
  bool? _otgSupported;
  bool? _otgDeviceDetected;
  bool _wasDeviceConnected = false; // Track if device was ever connected (for pass even after eject)
  String _vendorIdText = '';
  String _productIdText = '';
  String _statusMessage = 'Checking OTG support...';
  bool? _previousAttachedState; // Track previous state to prevent duplicate toasts

  // Logs for UI display (when Xcode is disconnected)
  final List<String> _logMessages = [];
  static const int _maxLogLines = 20; // Keep last 20 log lines
  
  StreamSubscription<dynamic>? _otgSubscription;
  bool _autoStartScheduled = false;

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdOtg)) return;
    if (_currentState != OtgTestState.readyToTest || _otgSupported != true) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == OtgTestState.readyToTest) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdOtg);
  }

  @override
  void initState() {
    super.initState();
    _checkOTGSupport();
  }

  @override
  void dispose() {
    _otgSubscription?.cancel();
    _otgSubscription = null;
    _stopOTGDetection();
    super.dispose();
  }

  Future<void> _checkOTGSupport() async {
    try {
      setState(() {
        _statusMessage = 'Checking OTG support...';
      });

      final isSupported = await _otgChannel.invokeMethod<bool>('checkOTGSupport') ?? false;
      
      if (mounted) {
        setState(() {
          _otgSupported = isSupported;
        });

        if (isSupported) {
          // Device supports OTG - show ready state with Begin Test button
          setState(() {
            _currentState = OtgTestState.readyToTest;
            _statusMessage = 'Device supports OTG';
            _otgDeviceDetected = null; // Reset detection state
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
        } else {
          // Device doesn't support OTG - show result immediately
          setState(() {
            _currentState = OtgTestState.resultReady;
            _testComplete = true;
            _otgDeviceDetected = false;
            _statusMessage = 'Device does not support OTG';
          });

        }
      }
    } catch (e) {
      debugPrint('Error checking OTG support: $e');
      if (mounted) {
        setState(() {
          _currentState = OtgTestState.resultReady;
          _testComplete = true;
          _otgSupported = false;
          _otgDeviceDetected = false;
          _statusMessage = 'Error checking OTG support. Please try again.';
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
          }
        });
      }
    }
  }

  Future<void> _startTest() async {
    setState(() {
      _currentState = OtgTestState.testing;
      _otgDeviceDetected = null;
      _wasDeviceConnected = false;
      _testComplete = false;
      _statusMessage = 'Waiting for OTG device connection...';
      _vendorIdText = '';
      _productIdText = '';
      _previousAttachedState = null;
      _logMessages.clear(); // Clear previous logs
    });
    
    _addLog('Test started - Ready to detect OTG devices');
    
    // Start OTG detection
    _startOTGDetection();
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        final timestamp = DateTime.now().toString().substring(11, 19); // HH:MM:SS
        _logMessages.add('[$timestamp] $message');
        if (_logMessages.length > _maxLogLines) {
          _logMessages.removeAt(0); // Remove oldest log
        }
      });
    }
    debugPrint('📱 OTG: $message');
  }

  void _startOTGDetection() {
    _addLog('Starting OTG detection...');
    _addLog('⚠️ IMPORTANT: Remove debug cable before connecting OTG device!');

    // Listen to OTG device events
    _otgSubscription = _otgEventChannel.receiveBroadcastStream().listen(
      (event) {
        _addLog('Received OTG event: $event');
        debugPrint('Received OTG event: $event');
        if (mounted) {
          final deviceInfo = event as Map<dynamic, dynamic>;
          final attached = deviceInfo['attached'] as bool? ?? false;
          final vendorIdText = deviceInfo['vendorIdText'] as String? ?? '';
          final productIdText = deviceInfo['productIdText'] as String? ?? '';
          final logMessage = deviceInfo['log'] as String? ?? '';
          
          // Only show toast if state has changed
          final stateChanged = _previousAttachedState != attached;
          
          // Update state first
          setState(() {
            _otgDeviceDetected = attached;
            _vendorIdText = vendorIdText;
            _productIdText = productIdText;
            
            if (attached) {
              // Device connected
              _wasDeviceConnected = true; // Mark as connected (even if ejected later, still pass)
              _statusMessage = 'OTG Device Detected!';
              _testComplete = true;
              _currentState = OtgTestState.resultReady;
              _addLog('✅✅✅ OTG DEVICE CONNECTED SUCCESSFULLY! ✅✅✅');
              if (logMessage.isNotEmpty) {
                _addLog(logMessage);
              } else {
                if (vendorIdText.isNotEmpty) _addLog('Vendor: $vendorIdText');
                if (productIdText.isNotEmpty) _addLog('Product: $productIdText');
              }
            } else {
              // Device detached
              // If device was connected before, keep it as pass (don't change state)
              if (_wasDeviceConnected) {
                // Already marked as pass, keep showing result
                _statusMessage = 'OTG Device Detected (Device disconnected)';
                _testComplete = true;
                _currentState = OtgTestState.resultReady;
              } else {
                // Never connected, keep waiting but buttons remain visible
                _statusMessage = 'Waiting for OTG device connection...';
                _testComplete = false;
                // Keep buttons visible - user can mark Pass/Fail anytime
              }
            }
          });
          
          // Auto-navigation for Android only (iOS: user manually decides)
          if (attached && stateChanged && mounted) {
            if (Platform.isAndroid) {
              // Android: Auto-save and navigate when device is detected
              TestResultHelper.savePass(ref, TestConfig.testIdOtg);
              _addLog('✅ Device detected! Auto-navigating (Android)...');
              
              // Auto-navigate after brief delay when test passes
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) {
                    _navigateToNextTest();
                  }
                });
              });
            } else {
              // iOS: Just update UI, user will manually decide Pass/Fail
              _addLog('✅ Device detected! You can mark Pass/Fail using buttons below.');
            }
          }
          
          // Show toast after setState to avoid blocking (defer to next frame)
          if (attached && stateChanged && mounted) {
            _previousAttachedState = attached;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  CommonToast.showSuccess(
                    context,
                    message: 'OTG Device Connected',
                    duration: const Duration(seconds: 2),
                  );
                } catch (e) {
                  debugPrint('Error showing toast: $e');
                }
              }
            });
          } else if (!attached && stateChanged && _previousAttachedState == true && mounted) {
            // Only show toast if it was previously attached
            _previousAttachedState = attached;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  CommonToast.showInfo(
                    context,
                    message: 'OTG Device Disconnected',
                    duration: const Duration(seconds: 2),
                  );
                } catch (e) {
                  debugPrint('Error showing toast: $e');
                }
              }
            });
          } else {
            _previousAttachedState = attached;
          }
        }
      },
      onError: (error) {
        _addLog('❌ Error listening to OTG events: $error');
        debugPrint('Error listening to OTG events: $error');
      },
    );

    // Start detection on native side
    _otgChannel.invokeMethod('startOTGDetection').then((_) {
      _addLog('✅ OTG detection started on native side');
    }).catchError((e) {
      _addLog('❌ Error starting OTG detection: $e');
      debugPrint('Error starting OTG detection: $e');
    });
  }

  Future<void> _stopOTGDetection() async {
    try {
      await _otgChannel.invokeMethod('stopOTGDetection');
    } catch (e) {
      debugPrint('Error stopping OTG detection: $e');
    }
  }

  Future<void> _navigateToNextTest() async {
    try {
      _otgSubscription?.cancel();
      _otgSubscription = null;
      // Stop detection in background (don't wait for it)
      _stopOTGDetection().catchError((e) {
        debugPrint('Error stopping OTG detection: $e');
      });
    } catch (error) {
      debugPrint('Error in navigation cleanup: $error');
    }

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
        TestConfig.testIdOtg,
      );
    } else {
      debugPrint('❌ OtgConnectivityScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handlePass() {
    TestResultHelper.savePass(ref, TestConfig.testIdOtg);
    _navigateToNextTest();
  }

  void _handleFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdOtg);
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
                    _otgSubscription?.cancel();
                    _otgSubscription = null;
                    _stopOTGDetection();
                    Navigator.of(context).pop();
                  },
                  onSkip: () {
                    // Cancel subscription immediately (don't wait)
                    _otgSubscription?.cancel();
                    _otgSubscription = null;
                    // Stop detection in background (don't wait for it)
                    _stopOTGDetection().catchError((e) {
                      debugPrint('Error stopping OTG detection: $e');
                    });
                    // Mark OTG test as skipped
                    TestResultHelper.saveSkip(ref, TestConfig.testIdOtg);
                    
                    // Navigate to Network Connectivity screen
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

                /// Begin Test Button (only when ready to test, hidden in auto mode)
                if (_currentState == OtgTestState.readyToTest && _otgSupported == true && _shouldShowStartTestButton())
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: CommonButton(
                      text: AppStrings.beginTestButton,
                      onPressed: _startTest,
                    ),
                  ),

                /// Pass/Fail Buttons (always visible during testing - user can mark Pass/Fail anytime)
                if (_currentState == OtgTestState.testing || _currentState == OtgTestState.resultReady)
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
  }

  Widget _buildContent() {
    switch (_currentState) {
      case OtgTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdOtg,
            isPassed: true,
            localFallbackPath: AppStrings.image118Path,
            fallbackIcon: Icons.usb,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.otgConnectivityTest,
          subtitleLines: [
            AppStrings.otgConnectivityInstruction,
            '',
            'Tap "Begin Test" to start detection.',
            'The device information will be displayed when detected.',
          ],
          showProgressBar: false,
        );
        
      case OtgTestState.testing:
        return Column(
          children: [
            ResponsiveCard(
              customImageWidget: CommonTestImage(
                screenName: TestConfig.testIdOtg,
                isPassed: true,
                localFallbackPath: AppStrings.image118Path,
                fallbackIcon: Icons.usb,
                width: 120,
                height: 120,
              ),
              heading: AppStrings.otgConnectivityTest,
              subtitleLines: [
                'Detection Status:',
                _statusMessage,
                if (_vendorIdText.isNotEmpty) _vendorIdText,
                if (_productIdText.isNotEmpty) _productIdText,
                if (_vendorIdText.isEmpty && _otgDeviceDetected == false) '⏳ Waiting for device connection...',
                if (_otgDeviceDetected == true) '✅ Device detected!',
                if (_vendorIdText.isEmpty) '⏳ Waiting for device connection...',
                '',
                'Please connect an OTG device now.',
                'The device will be detected automatically when connected.',
              ],

              showProgressBar: false,
            ),
          ],
        );
        
      case OtgTestState.resultReady:
        // Show detection status, but user has already marked Pass/Fail
        final deviceWasDetected = _wasDeviceConnected || _otgDeviceDetected == true;
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdOtg,
            isPassed: deviceWasDetected,
            localFallbackPath: AppStrings.image118Path,
            fallbackIcon: Icons.usb,
            width: 120,
            height: 120,
          ),
          status: deviceWasDetected 
              ? ScanStatus.passed 
              : ScanStatus.failed,
          title: deviceWasDetected 
              ? AppStrings.otgDeviceDetected 
              : (_otgSupported == false 
                  ? 'OTG Not Supported' 
                  : 'OTG Device Not Detected'),
          subheadingLines: [
            if (deviceWasDetected && _vendorIdText.isNotEmpty) _vendorIdText,
            if (deviceWasDetected && _productIdText.isNotEmpty) _productIdText,
            if (deviceWasDetected && _vendorIdText.isEmpty) _statusMessage,
            if (!deviceWasDetected) _statusMessage,
          ],
        );
    }
  }
}
