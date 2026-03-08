import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

enum CameraTestState {
  initial,
  frontCamera,
  backCamera,
  preview,
}

class CameraTestScreen extends ConsumerStatefulWidget {
  const CameraTestScreen({super.key});

  @override
  ConsumerState<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends ConsumerState<CameraTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('cameras'); // Dynamic progress for screen 19
  CameraTestState _currentState = CameraTestState.initial;
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = false;
  /// Prevent concurrent captures (double-tap shutter) which can crash on some devices
  bool _isCapturing = false;
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  String? _frontCameraImagePath;
  String? _backCameraImagePath;
  bool _isFrontCameraTested = false;
  bool _isBackCameraTested = false;

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No cameras available on this device'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error initializing cameras: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing cameras: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    setState(() {
      _isInitializing = true;
    });

    try {
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      // Set aspect ratio to fit screen
      if (mounted) {
        await _cameraController!.setFlashMode(FlashMode.off);
      }

      // Get zoom capabilities
      _minZoom = await _cameraController!.getMinZoomLevel();
      _maxZoom = await _cameraController!.getMaxZoomLevel();
      _currentZoom = _minZoom;

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      print('❌ Error initializing camera: $e');
      setState(() {
        _isInitializing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing camera: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openFrontCamera() async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Front camera not available'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    await _initializeCamera(frontCamera);
    setState(() {
      _currentState = CameraTestState.frontCamera;
    });
  }

  Future<void> _openBackCamera() async {
    if (_cameras.isEmpty) {
      await _initializeCameras();
    }

    // Find back camera
    CameraDescription? backCamera;
    for (var camera in _cameras) {
      if (camera.lensDirection == CameraLensDirection.back) {
        backCamera = camera;
        break;
      }
    }

    if (backCamera == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Back camera not available'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    await _initializeCamera(backCamera);
    setState(() {
      _currentState = CameraTestState.backCamera;
    });
  }

  Future<void> _captureImage() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Guard against rapid repeated taps on the capture button
    if (_isCapturing) {
      debugPrint('⚠️ CameraTestScreen: capture already in progress, ignoring tap.');
      return;
    }

    _isCapturing = true;
    try {
      final XFile image = await _cameraController!.takePicture();
      
      // Get application documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String fileName = 'camera_${_currentState == CameraTestState.frontCamera ? 'front' : 'back'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(appDocDir.path, fileName);
      
      // Copy image to app documents directory
      await image.saveTo(filePath);

      if (_currentState == CameraTestState.frontCamera) {
        setState(() {
          _frontCameraImagePath = filePath;
        });
        // After capturing front camera, automatically open back camera
        await _openBackCamera();
      } else if (_currentState == CameraTestState.backCamera) {
        setState(() {
          _backCameraImagePath = filePath;
          // After capturing back camera, show preview screen
          _cameraController?.dispose();
          _cameraController = null;
          _currentState = CameraTestState.preview;
        });
      }

      print('📸 Image saved to: $filePath');
    } catch (e) {
      print('❌ Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error capturing image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      _isCapturing = false;
    }
  }

  double _baseScale = 1.0;

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentZoom;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    final newScale = (_baseScale * details.scale).clamp(_minZoom, _maxZoom);
    setState(() {
      _currentZoom = newScale;
    });

    _cameraController!.setZoomLevel(_currentZoom);
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
        TestConfig.testIdCameras,
      );
    } else {
      debugPrint('❌ CameraTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleCameraPass() {
    TestResultHelper.savePass(ref, TestConfig.testIdCameras);
    _navigateToNextTest();
  }

  void _handleCameraFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdCameras);
    _navigateToNextTest();
  }

  void _handleBack() async {
    if (_currentState == CameraTestState.preview) {
      // From preview, go back to initial screen
      if (mounted) {
        setState(() {
          _currentState = CameraTestState.initial;
          _frontCameraImagePath = null;
          _backCameraImagePath = null;
        });
      }
    } else if (_currentState == CameraTestState.backCamera) {
      // Go back to front camera
      _openFrontCamera();
    } else if (_currentState == CameraTestState.frontCamera) {
      // Go back to initial screen
      if (_cameraController != null) {
        try {
          await _cameraController!.dispose();
        } catch (e) {
          print('❌ Error disposing camera on back: $e');
        }
      }
      if (mounted) {
        setState(() {
          _cameraController = null;
          _currentState = CameraTestState.initial;
          _currentZoom = 1.0;
          _frontCameraImagePath = null;
          _backCameraImagePath = null;
        });
      }
    } else {
      // Go back to previous screen
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _handleSkip() async {
    // Dispose camera controller before navigating
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
        if (mounted) {
          setState(() {
            _cameraController = null;
          });
        }
      } catch (e) {
        print('❌ Error disposing camera on skip: $e');
        // Continue even if disposal fails
      }
    }
    
    // Mark Camera test as skipped (uses API paramValue and catIcon)
    TestResultHelper.saveSkip(ref, TestConfig.testIdCameras);
    
    // Navigate to next test based on API order
    if (mounted) {
      _navigateToNextTest();
    }
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
                onBack: _handleBack,
                onSkip: _handleSkip,
                skipText: AppStrings.skipButton,
              ),

              /// Progress Bar (only show on initial and preview screens)
              if (_currentState == CameraTestState.initial || _currentState == CameraTestState.preview)
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

              if (_currentState == CameraTestState.initial || _currentState == CameraTestState.preview)
                const SizedBox(height: 16),

              /// Main Content
              Expanded(
                child: _buildContent(),
              ),

              /// Bottom Buttons
              if (_currentState == CameraTestState.initial)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: CommonButton(
                    text: AppStrings.openCameraButton,
                    onPressed: _openFrontCamera,
                  ),
                )
              else if (_currentState == CameraTestState.preview)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: CommonTwoButtons(
                    leftButtonText: AppStrings.failButton,
                    rightButtonText: AppStrings.passButton,
                    onLeftButtonPressed: _handleCameraFail,
                    onRightButtonPressed: _handleCameraPass ,
                  ),
                ),
            ],
          ),

          /// Common Footer (shown during camera test, not on preview)
          if (_currentState != CameraTestState.initial && _currentState != CameraTestState.preview)
            const CommonFooter(),
        ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_currentState == CameraTestState.initial) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommonContentWidget(
                customImageWidget: CommonTestImage(
                  screenName: TestConfig.testIdCameras,
                  isPassed: true,
                  localFallbackPath: AppStrings.image97Path,
                  fallbackIcon: Icons.camera_alt,
                  width: 120,
                  height: 120,
                ),
                heading: AppStrings.testingCamera,
                subheading: AppStrings.cameraTestInstruction,
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      );
    }

    // Preview screen with both images
    if (_currentState == CameraTestState.preview) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Front Camera Image
              if (_frontCameraImagePath != null) ...[
                Text(
                  'Front Camera',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_frontCameraImagePath!),
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 200,
                        color: AppColors.surface,
                        child: const Center(
                          child: Icon(Icons.error, color: AppColors.error),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Back Camera Image
              if (_backCameraImagePath != null) ...[
                Text(
                  'Back Camera',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_backCameraImagePath!),
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 200,
                        color: AppColors.surface,
                        child: const Center(
                          child: Icon(Icons.error, color: AppColors.error),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Camera preview - Full screen
    return Stack(
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
                : GestureDetector(
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    child: SizedBox(
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
                  ),
        // iOS-style Capture Button (centered at bottom)
        if (_cameraController != null && _cameraController!.value.isInitialized)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _captureImage,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: AppColors.primary,
                    size: 35,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

}

