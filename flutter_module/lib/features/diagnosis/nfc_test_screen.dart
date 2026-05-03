import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:vibration/vibration.dart';
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
import 'providers/test_images_provider.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import '../../core/widgets/common_test_image.dart';

enum NfcTestState {
  initial,
  checking,
  nfcNotAvailable,
  readyToTest,
  testing,
  resultReady,
}

class NfcTestScreen extends ConsumerStatefulWidget {
  const NfcTestScreen({super.key});

  @override
  ConsumerState<NfcTestScreen> createState() => _NfcTestScreenState();
}

class _NfcTestScreenState extends ConsumerState<NfcTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('nfc');
  NfcTestState _currentState = NfcTestState.initial;
  bool _testComplete = false;
  bool _showProceedButton = false;
  bool _nfcWorking = false;
  bool _nfcDetected = false;
  
  Timer? _nfcPollTimer;
  bool _autoStartScheduled = false;

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdNfc)) return;
    if (_currentState != NfcTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == NfcTestState.readyToTest) {
        _startTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdNfc);
  }

  @override
  void initState() {
    super.initState();
    _checkNfcAvailability();
  }

  @override
  void dispose() {
    _nfcPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkNfcAvailability() async {
    setState(() {
      _currentState = NfcTestState.checking;
    });

    try {
      // Check if NFC is available using nfc_manager package
      final isAvailable = await NfcManager.instance.isAvailable();
      
      if (mounted) {
        setState(() {
          if (isAvailable) {
            _currentState = NfcTestState.readyToTest;
          } else {
            _currentState = NfcTestState.nfcNotAvailable;
          }
        });
        if (isAvailable) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
        }
      }
    } catch (e) {
      print('❌ Error checking NFC availability: $e');
      if (mounted) {
        setState(() {
          _currentState = NfcTestState.nfcNotAvailable;
        });
      }
    }
  }

  Future<void> _startTest() async {
    setState(() {
      _currentState = NfcTestState.testing;
      _nfcDetected = false;
      _testComplete = false;
      _showProceedButton = false;
    });

    // Start NFC tag detection using nfc_manager
    _startNfcTagDetection();
  }

  Future<void> _startNfcTagDetection() async {
    try {
      // Start NFC session to detect tags
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          print('✅ NFC tag detected');
          
          // Vibrate phone once when NFC tag is detected
          try {
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(duration: 200);
            }
          } catch (e) {
            print('⚠️ Error vibrating: $e');
          }
          
          if (mounted && _currentState == NfcTestState.testing && !_nfcDetected) {
            // Stop the NFC session
            await NfcManager.instance.stopSession();
            
            // Handle detected NFC tag
            _handleNfcDetected();
          }
        },
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
      );
      
      // Auto-timeout after 10 seconds if no NFC tag detected
      Future.delayed(const Duration(seconds: 10), () async {
        if (mounted && _currentState == NfcTestState.testing && !_nfcDetected) {
          try {
            await NfcManager.instance.stopSession();
          } catch (e) {
            print('⚠️ Error stopping NFC session: $e');
          }
          _evaluateTest();
        }
      });
    } catch (e) {
      print('❌ Error starting NFC session: $e');
      if (mounted) {
        setState(() {
          _currentState = NfcTestState.nfcNotAvailable;
        });
      }
    }
  }

  void _handleNfcDetected() {
    if (!mounted || _currentState != NfcTestState.testing) return;
    
    setState(() {
      _nfcDetected = true;
      _nfcWorking = true;
      _testComplete = true;
      _currentState = NfcTestState.resultReady;
      _showProceedButton = true;
    });
    // Result saved when user taps Pass / NA / Fail at bottom
  }

  void _evaluateTest() {
    final working = _nfcDetected;
    if (mounted) {
      setState(() {
        _nfcWorking = working;
        _testComplete = true;
        _currentState = NfcTestState.resultReady;
        _showProceedButton = true;
      });
    }
  }

  Future<void> _navigateToNextTest() async {
    // Reset NFC test to initial state before navigating
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
        TestConfig.testIdNfc,
      );
    } else {
      debugPrint('❌ NfcTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _resetToInitialState() {
    // Cancel any active timers
    _nfcPollTimer?.cancel();
    _nfcPollTimer = null;
    
    // Stop any active NFC session
    try {
      NfcManager.instance.stopSession();
    } catch (e) {
      print('⚠️ Error stopping NFC session during reset: $e');
    }
    
    // Reset all state variables to initial values
    setState(() {
      _currentState = NfcTestState.initial;
      _testComplete = false;
      _showProceedButton = false;
      _nfcWorking = false;
      _nfcDetected = false;
    });
    
    // Re-check NFC availability to transition to readyToTest state
    _checkNfcAvailability();
  }

  void _handlePass() {
    TestResultHelper.savePass(ref, TestConfig.testIdNfc);
    _navigateToNextTest();
  }

  void _handleFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdNfc);
    _navigateToNextTest();
  }

  void _handleNA() {
    TestResultHelper.saveNA(ref, TestConfig.testIdNfc);
    _navigateToNextTest();
  }

  Widget _buildNfcResultButton({required String text, required VoidCallback onPressed}) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          elevation: 0,
        ),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
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
                  TestResultHelper.saveSkip(ref, TestConfig.testIdNfc);
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

              /// Begin Test Button (only when ready to test or initial, hidden in auto mode)
              if (_shouldShowStartTestButton() &&
                  (_currentState == NfcTestState.readyToTest || 
                  _currentState == NfcTestState.initial))
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: CommonButton(
                    text: AppStrings.beginTestButton,
                    onPressed: _startTest,
                  ),
                ),

              /// When hardware not available: only NA button visible, Fail and Pass disappear
              if (_currentState == NfcTestState.nfcNotAvailable)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: CommonButton(
                    text: AppStrings.naButton,
                    onPressed: _handleNA,
                  ),
                ),

              /// Fail / Pass / NA buttons only when test completed (result ready); when hardware unavailable only NA shows above
              if (_showProceedButton && _currentState == NfcTestState.resultReady)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: CommonTwoButtons(
                          leftButtonText: AppStrings.failButton,
                          rightButtonText: AppStrings.passButton,
                          onLeftButtonPressed: _handleFail,
                          onRightButtonPressed: _handlePass,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildNfcResultButton(
                          text: AppStrings.naButton,
                          onPressed: _handleNA,
                        ),
                      ),
                    ],
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
      case NfcTestState.initial:
      case NfcTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdNfc,
            isPassed: true,
            localFallbackPath: AppStrings.nfcIconPath,
            fallbackIcon: Icons.nfc,
            width: 120,
            height: 120,
          ),
          heading: 'Testing NFC',
          subtitleLines: [
            'What to detect:',
            '• NFC-enabled debit card',
            '• NFC-enabled credit card',
            '• NFC tag or card',
            '',
            'Instructions:',
            'Tap the NFC card or tag on the back of the device.',
            'Hold the card near the NFC sensor area.',
            'The device will detect the NFC tag automatically.',
            '',
            'Note: WiFi debit cards and credit cards work with NFC.',
            'Make sure NFC is enabled in your device settings.',
          ],
        );
        
      case NfcTestState.checking:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdNfc,
            isPassed: true,
            localFallbackPath: AppStrings.nfcIconPath,
            fallbackIcon: Icons.nfc,
            width: 120,
            height: 120,
          ),
          heading: 'Testing NFC',
          subtitleLines: ['Checking NFC availability...'],
        );
        
      case NfcTestState.nfcNotAvailable:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdNfc,
            isPassed: false,
            localFallbackPath: AppStrings.nfcIconPath,
            fallbackIcon: Icons.nfc,
            width: 120,
            height: 120,
          ),
          heading: 'NFC Not Available',
          subtitleLines: [
            'This device does not have NFC capability.',
            'The test cannot be performed.',
            '',
            'You can skip this test and continue.',
          ],
        );
        
      case NfcTestState.testing:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdNfc,
            isPassed: true,
            localFallbackPath: AppStrings.nfcIconPath,
            fallbackIcon: Icons.nfc,
            width: 120,
            height: 120,
          ),
          heading: 'Testing NFC',
          subtitleLines: [
            '⏳ Waiting for NFC tag... (10 seconds timeout)',
            '',
            'Tap an NFC card or tag on the back of the device:',
            '• NFC-enabled debit card',
            '• NFC-enabled credit card',
            '• NFC tag or card',
            '',
            'Hold the card near the NFC sensor area.',
            'Note: WiFi debit cards and credit cards work with NFC.',
            '',
            'Make sure the NFC tag is close to the device.',
          ],
        );
        
      case NfcTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdNfc,
            isPassed: _nfcWorking,
            localFallbackPath: AppStrings.nfcIconPath,
            fallbackIcon: Icons.nfc,
            width: 120,
            height: 120,
          ),
          status: _nfcWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _nfcWorking 
              ? 'NFC Working' 
              : 'NFC Not Detected',
          subheadingLines: _nfcWorking
              ? [
                  'NFC tag was detected successfully.',
                  'NFC functionality is working correctly.',
                ]
              : ['NFC tag was not detected. Please try again.'],
          showStatusIcon: true,
        );
      default:
        return const SizedBox();
    }
  }
}
