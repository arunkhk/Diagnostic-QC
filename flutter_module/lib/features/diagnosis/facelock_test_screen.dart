import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;
import 'package:camera/camera.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/scan_result_card.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import '../../core/widgets/common_test_image.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_images_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

enum FacelockTestState {
  initial,
  testing,
  detected,
  failed,
}

class FacelockTestScreen extends ConsumerStatefulWidget {
  const FacelockTestScreen({super.key});

  @override
  ConsumerState<FacelockTestScreen> createState() => _FacelockTestScreenState();
}

class _FacelockTestScreenState extends ConsumerState<FacelockTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('facelock'); // Dynamic progress for screen 23
  FacelockTestState _currentState = FacelockTestState.initial;
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = false;
  bool _faceDetected = false;
  String? _capturedImagePath;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isCheckingBiometrics = false;
  bool _hasBiometrics = false;
  bool _isAuthenticating = false;

  /// Prevent concurrent camera captures that can crash on some devices
  bool _isCapturingImage = false;

  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
    if (Platform.isIOS) {
      _checkBiometricAvailability();
    } else {
      _initializeCameras();
    }
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdFacelock)) return;
    if (_currentState != FacelockTestState.initial) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == FacelockTestState.initial) {
        _handleBeginTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdFacelock);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    setState(() {
      _isCheckingBiometrics = true;
    });

    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      
      if (!isDeviceSupported && !canCheckBiometrics) {
        setState(() {
          _isCheckingBiometrics = false;
          _hasBiometrics = false;
        });
        return;
      }

      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      final bool hasFaceID = availableBiometrics.contains(BiometricType.face) ||
          availableBiometrics.contains(BiometricType.strong);
      
      final bool canAuthenticate = await _localAuth.canCheckBiometrics;
      
      setState(() {
        _isCheckingBiometrics = false;
        _hasBiometrics = canAuthenticate && hasFaceID;
      });
    } catch (e) {
      print('❌ Error checking biometrics: $e');
      setState(() {
        _isCheckingBiometrics = false;
        _hasBiometrics = false;
      });
    }
  }

  Future<void> _authenticateWithFaceID() async {
    try {
      setState(() {
        _isAuthenticating = true;
        _currentState = FacelockTestState.testing;
      });

      final bool canAuthenticate = await _localAuth.canCheckBiometrics;
      if (!canAuthenticate) {
        setState(() {
          _isAuthenticating = false;
          _currentState = FacelockTestState.failed;
        });
        return;
      }

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate with Face ID or Touch ID to test biometric functionality',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        setState(() {
          _isAuthenticating = false;
          _faceDetected = true;
          _currentState = FacelockTestState.detected;
        });
        // Result saved when user taps Pass/Fail at bottom
      } else {
        setState(() {
          _isAuthenticating = false;
          _currentState = FacelockTestState.failed;
        });
      }
    } catch (e) {
      print('❌ Error authenticating with Face ID: $e');
      setState(() {
        _isAuthenticating = false;
        _currentState = FacelockTestState.failed;
      });
    }
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      print('❌ Error initializing cameras: $e');
    }
  }

  Future<void> _initializeFrontCamera() async {
    if (_cameras.isEmpty) {
      await _initializeCameras();
    }

    // Find front camera
    CameraDescription? frontCamera;
    for (var camera in _cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        frontCamera = camera;
        break;
      }
    }

    if (frontCamera == null) {
      setState(() {
        _currentState = FacelockTestState.failed;
      });
      return;
    }

    setState(() {
      _isInitializing = true;
    });

    try {
      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        await _cameraController!.setFlashMode(FlashMode.off);
      }

      setState(() {
        _isInitializing = false;
        _currentState = FacelockTestState.testing;
      });

      // Wait for 3 seconds, then check if camera is working
      await Future.delayed(const Duration(seconds: 3));

      if (!mounted) return;

      if (_cameraController != null && _cameraController!.value.isInitialized) {
        // Camera is working, capture image and mark as detected
        await _captureAndDetectFace();
      } else {
        // Camera not working
        if (mounted) {
          setState(() {
            _currentState = FacelockTestState.failed;
          });
        }
      }
    } catch (e) {
      print('❌ Error initializing front camera: $e');
      setState(() {
        _isInitializing = false;
        _currentState = FacelockTestState.failed;
      });
    }
  }

  Future<void> _captureAndDetectFace() async {
    if (!mounted) return;

    // Guard against double-invocation of takePicture on some devices
    if (_isCapturingImage) {
      debugPrint('⚠️ FacelockTestScreen: capture already in progress, ignoring.');
      return;
    }

    _isCapturingImage = true;
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        if (mounted) {
          setState(() {
            _currentState = FacelockTestState.failed;
          });
        }
        return;
      }

      // Capture image
      final XFile image = await _cameraController!.takePicture();
      
      if (!mounted) return;
      
      // Save image path and update state first
      if (mounted) {
        setState(() {
          _capturedImagePath = image.path;
          _faceDetected = true;
          _currentState = FacelockTestState.detected;
        });
        // Result saved when user taps Pass/Fail at bottom
      }

      // Wait a bit to ensure UI is updated before disposing camera
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Dispose camera after state is updated and UI has rendered
      if (mounted && _cameraController != null) {
        try {
          await _cameraController?.dispose();
          if (mounted) {
            setState(() {
              _cameraController = null;
            });
          }
        } catch (e) {
          print('❌ Error disposing camera: $e');
          // Continue even if disposal fails
        }
      }
    } catch (e) {
      print('❌ Error capturing image: $e');
      if (mounted) {
        setState(() {
          _currentState = FacelockTestState.failed;
        });
      }
    } finally {
      _isCapturingImage = false;
    }
  }

  void _handleBeginTest() {
    if (Platform.isIOS) {
      // iOS: Use Face ID/Touch ID authentication
      _authenticateWithFaceID();
    } else {
      // Android: Use camera approach
      _initializeFrontCamera();
    }
  }

  void _handleGoToSetting() {
    // Navigate to settings (can be implemented later)
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please go to Settings to configure facelock'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleNoFacelock() {
    // Mark as failed and show result
    setState(() {
      _currentState = FacelockTestState.failed;
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
        TestConfig.testIdFacelock,
      );
    } else {
      debugPrint('❌ FacelockTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleTestPass() {
    TestResultHelper.savePass(ref, TestConfig.testIdFacelock);
    _navigateToNextTest();
  }

  void _handleTestFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdFacelock);
    _navigateToNextTest();
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdFacelock);
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
                        if (_currentState == FacelockTestState.initial)
                          // Initial state - show instruction
                          CommonContentWidget(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdFacelock,
                              isPassed: true,
                              localFallbackPath: AppStrings.image136Path,
                              fallbackIcon: Icons.face,
                              width: 120,
                              height: 120,
                            ),
                            heading: AppStrings.testingFacelock,
                            subheading: Platform.isIOS
                                ? 'This test will verify Face ID or Touch ID functionality.\n\nTap "Begin Test" to start authentication.'
                                : AppStrings.facelockTestInstruction,
                          )
                        else if (_currentState == FacelockTestState.testing && Platform.isIOS)
                          // iOS: Show authentication in progress
                          CommonContentWidget(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdFacelock,
                              isPassed: true,
                              localFallbackPath: AppStrings.image136Path,
                              fallbackIcon: Icons.face,
                              width: 120,
                              height: 120,
                            ),
                            heading: 'Authenticating...',
                            subheading: _isAuthenticating
                                ? 'Please authenticate with Face ID or Touch ID'
                                : 'Checking biometric availability...',
                          )
                        else if (_currentState == FacelockTestState.detected)
                          // Face detected - show success with ScanResultCard
                          ScanResultCard(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdFacelock,
                              isPassed: true,
                              localFallbackPath: AppStrings.image136Path,
                              fallbackIcon: Icons.face,
                              width: 120,
                              height: 120,
                            ),
                            status: ScanStatus.passed,
                            title: AppStrings.faceLockDetected,
                            subheadingLines: null,
                            showStatusIcon: true,
                          )
                        else if (_currentState == FacelockTestState.failed)
                          // Face not detected - show failure
                          ScanResultCard(
                            customImageWidget: CommonTestImage(
                              screenName: TestConfig.testIdFacelock,
                              isPassed: false,
                              localFallbackPath: AppStrings.image136Path,
                              fallbackIcon: Icons.face,
                              width: 120,
                              height: 120,
                            ),
                            status: ScanStatus.failed,
                            title: AppStrings.faceLockNotDetected,
                            subheadingLines: [
                              AppStrings.faceLockNotDetectedMessage,
                            ],
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
                    if (_currentState == FacelockTestState.initial) ...[
                      // Two buttons: Go To Setting and No Facelock (only for iOS)
                      if (Platform.isIOS && !_hasBiometrics)
                        CommonTwoButtons(
                          leftButtonText: AppStrings.goToSettingButton,
                          rightButtonText: AppStrings.noFacelockButton,
                          onLeftButtonPressed: _handleGoToSetting,
                          onRightButtonPressed: _handleNoFacelock,
                        ),
                      if (Platform.isIOS && !_hasBiometrics) const SizedBox(height: 16),
                      // Begin Test button (hidden in auto mode)
                      if (_shouldShowStartTestButton())
                        CommonButton(
                          text: AppStrings.beginTestButton,
                          onPressed: _isCheckingBiometrics ? null : _handleBeginTest,
                        ),
                    ] else if (_currentState == FacelockTestState.detected ||
                        _currentState == FacelockTestState.failed)
                      // Pass/Fail buttons after result – tap to navigate next
                      CommonTwoButtons(
                        leftButtonText: AppStrings.failButton,
                        rightButtonText: AppStrings.passButton,
                        onLeftButtonPressed: _handleTestFail,
                        onRightButtonPressed: _handleTestPass,
                      ),
                  ],
                ),
              ),
            ],
          ),

          /// Camera Preview (shown during testing - Android only)
          if (_currentState == FacelockTestState.testing && !Platform.isIOS)
            Stack(
              children: [
                // Full screen camera preview
                _isInitializing
                    ? const Center(
                        child: CircularProgressIndicator(),
                      )
                    : _cameraController == null || !_cameraController!.value.isInitialized
                        ? const Center(
                            child: Text('Camera not initialized'),
                          )
                        : SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _cameraController!.value.previewSize?.height ?? 1,
                                height: _cameraController!.value.previewSize?.width ?? 1,
                                child: CameraPreview(_cameraController!),
                              ),
                            ),
                          ),
                // Overlay message when face is detected
                if (_faceDetected)
                  Positioned(
                    bottom: 100,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            AppStrings.faceLockDetected,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

          /// Common Footer (shown during test - Android only)
          if (_currentState == FacelockTestState.testing && !Platform.isIOS) const CommonFooter(),
        ],
        ),
      ),
    );
  }
}

