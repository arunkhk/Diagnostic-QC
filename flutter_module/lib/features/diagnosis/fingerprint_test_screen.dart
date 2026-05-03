import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_config.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/scan_result_card.dart';
import '../../core/widgets/common_dialog.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';
import '../../core/widgets/common_test_image.dart';

class FingerprintTestScreen extends ConsumerStatefulWidget {
  const FingerprintTestScreen({super.key});

  @override
  ConsumerState<FingerprintTestScreen> createState() => _FingerprintTestScreenState();
}

class _FingerprintTestScreenState extends ConsumerState<FingerprintTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('fingerprint'); // Dynamic progress for screen 22
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  bool _isChecking = true;
  bool _hasSensor = false;
  bool _hasFingerprintEnrolled = false;
  bool _isAuthenticating = false;
  bool _fingerprintDetected = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkFingerprintAvailability();
  }

  Future<void> _checkFingerprintAvailability() async {
    try {
      // Check if device supports biometric authentication
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!isDeviceSupported && !canCheckBiometrics) {
        setState(() {
          _isChecking = false;
          _hasSensor = false;
        });
        return;
      }

      // Check available biometric types
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        setState(() {
          _isChecking = false;
          _hasSensor = false;
        });
        return;
      }

      // Check if fingerprint is enrolled
      final bool hasFingerprint = availableBiometrics.contains(BiometricType.fingerprint) ||
          availableBiometrics.contains(BiometricType.strong) ||
          availableBiometrics.contains(BiometricType.weak);

      // Check if any biometrics are enrolled
      final bool canAuthenticate = await _localAuth.canCheckBiometrics;
      
      // Check if fingerprint is actually enrolled (not just available)
      final bool isFingerprintEnrolled = canAuthenticate && hasFingerprint;
      
      // If sensor exists but no fingerprint enrolled, treat as not detected
      if (!isFingerprintEnrolled) {
        setState(() {
          _isChecking = false;
          _hasSensor = false;
        });
        return;
      }

      setState(() {
        _isChecking = false;
        _hasSensor = true;
        _hasFingerprintEnrolled = true;
      });
    } catch (e) {
      print('❌ Error checking fingerprint: $e');
      setState(() {
        _isChecking = false;
        _hasSensor = false;
        _errorMessage = 'Error checking fingerprint sensor: $e';
      });
    }
  }

  Future<void> _authenticateFingerprint() async {
    try {
      setState(() {
        _isAuthenticating = true;
        _errorMessage = '';
      });

      // Check if we can authenticate first
      final bool canAuthenticate = await _localAuth.canCheckBiometrics;
      if (!canAuthenticate) {
        setState(() {
          _isAuthenticating = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot authenticate. Please check your device settings.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to test fingerprint sensor',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        setState(() {
          _fingerprintDetected = true;
          _isAuthenticating = false;
        });
        
        // Auto-save result as pass (fingerprint detected successfully)
        TestResultHelper.savePass(ref, TestConfig.testIdFingerprint);
        
        // Auto-navigate after brief delay when test passes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _navigateToNextTest();
            }
          });
        });
      } else {
        setState(() {
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      print('❌ Error authenticating fingerprint: $e');
      setState(() {
        _isAuthenticating = false;
        _errorMessage = 'Authentication failed: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openFingerprintSettings() async {
    // Show dialog with instructions
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => CommonDialog(
          title: AppStrings.goToSettingsTitle,
          message: AppStrings.goToSettingsMessage,
          proceedText: 'OK',
          onProceed: () {
            Navigator.of(context).pop();
            // Optionally open settings after user acknowledges
            _openSettingsDirectly();
          },
        ),
      );
    }
  }

  Future<void> _openSettingsDirectly() async {
    try {
      // Open Android security settings
      const platform = MethodChannel(AppConfig.settingsChannel);
      await platform.invokeMethod('openSecuritySettings');
    } catch (e) {
      print('❌ Error opening security settings: $e');
      // Fallback to general settings
      try {
        const platform = MethodChannel(AppConfig.settingsChannel);
        await platform.invokeMethod('openSecuritySettings');
      } catch (e2) {
        print('❌ Error opening settings: $e2');
      }
    }
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
        TestConfig.testIdFingerprint,
      );
    } else {
      debugPrint('❌ FingerprintTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleTestPass() {
    TestResultHelper.savePass(ref, TestConfig.testIdFingerprint);
    _navigateToNextTest();
  }

  void _handleTestFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdFingerprint);
    _navigateToNextTest();
  }

  void _handleProceed() {
    TestResultHelper.savePass(ref, TestConfig.testIdFingerprint);
    _navigateToNextTest();
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdFingerprint);
    _navigateToNextTest();
  }

  Widget _buildGoToSettingsButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: _openFingerprintSettings,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          side: const BorderSide(
            color: AppColors.primary,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        child: Text(
          AppStrings.goToSettingsButton,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                          // Loading state
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (!_hasSensor || !_hasFingerprintEnrolled)
                          // No sensor or fingerprint not enrolled - show generic message
                          ScanResultCard(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdFingerprint,
                              isPassed: false,
                              localFallbackPath: AppStrings.image128Path,
                              fallbackIcon: Icons.fingerprint,
                              width: 120,
                              height: 120,
                            ),
                            status: ScanStatus.failed,
                            title: AppStrings.fingerprintNotDetected,
                            subheadingLines: [
                              AppStrings.fingerprintNotDetectedMessage,
                            ],
                            optionalButton: _buildGoToSettingsButton(),
                          )
                        else if (_fingerprintDetected)
                          // Fingerprint detected successfully
                          ScanResultCard(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdFingerprint,
                              isPassed: true,
                              localFallbackPath: AppStrings.image128Path,
                              fallbackIcon: Icons.fingerprint,
                              width: 120,
                              height: 120,
                            ),
                            status: ScanStatus.passed,
                            title: AppStrings.fingerprintDetectedSuccessfully,
                            subheadingLines: null,
                          )
                        else
                          // Ready to test - show instruction with scan result card style (no status icon yet)
                          ScanResultCard(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdFingerprint,
                              isPassed: true,
                              localFallbackPath: AppStrings.image128Path,
                              fallbackIcon: Icons.fingerprint,
                              width: 120,
                              height: 120,
                            ),
                            status: ScanStatus.passed, // Status doesn't matter when showStatusIcon is false
                            title: AppStrings.testingFingerprintScan,
                            subheadingLines: [
                              AppStrings.fingerprintTestInstruction,
                            ],
                            showStatusIcon: false, // Don't show icon until fingerprint is detected
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
                    if (!_isChecking && !_hasSensor)
                      // No sensor - show Pass/Fail buttons
                      CommonTwoButtons(
                        leftButtonText: AppStrings.failButton ,
                        rightButtonText: AppStrings.passButton,
                        onLeftButtonPressed: _handleTestFail,
                        onRightButtonPressed: _handleTestPass,
                      )
                    else if (!_isChecking && !_hasFingerprintEnrolled)
                      // No fingerprint enrolled - show Pass/Fail buttons
                      CommonTwoButtons(
                        leftButtonText: AppStrings.failButton ,
                        rightButtonText: AppStrings.passButton,
                        onLeftButtonPressed: _handleTestFail,
                        onRightButtonPressed: _handleTestPass,
                      )
                    else if (!_isChecking && _hasFingerprintEnrolled && !_fingerprintDetected && !_isAuthenticating)
                      // Ready to authenticate - show button to start
                      CommonButton(
                        text: 'Touch Fingerprint Sensor',
                        onPressed: _authenticateFingerprint,
                      )
                    else if (!_isChecking && _hasFingerprintEnrolled && _fingerprintDetected)
                      // Fingerprint detected - show proceed button
                      CommonButton(
                        text: AppStrings.proceedButton,
                        onPressed: _handleProceed,
                      ),
                  ],
                ),
              ),
            ],
          ),

          /// Common Footer (shown during authentication)
          if (_isAuthenticating) const CommonFooter(),
        ],
        ),
      ),
    );
  }
}

