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
import '../../core/widgets/common_test_image.dart';
import '../../core/widgets/responsive_card.dart';
import '../../core/widgets/scan_result_card.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_result_provider.dart';
import 'utils/test_navigation_service.dart';
import 'models/test_parameter_item.dart';

class SdCardDetectionScreen extends ConsumerStatefulWidget {
  const SdCardDetectionScreen({super.key});

  @override
  ConsumerState<SdCardDetectionScreen> createState() => _SdCardDetectionScreenState();
}

class _SdCardDetectionScreenState extends ConsumerState<SdCardDetectionScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('sd_card'); // Dynamic progress for screen 1
  final MethodChannel _sdCardChannel = MethodChannel(AppConfig.sdCardChannel);
  
  bool _scanningComplete = false;
  bool _showResultButtons = false;
  /// First run auto-navigates; when user comes back, we keep them here with Pass/Fail buttons.
  bool _shouldAutoNavigate = true;
  bool? _sdCardDetected;
  String _statusMessage = AppStrings.checkingCardHealth;

  @override
  void initState() {
    super.initState();
    // If we already have a stored result for SD card, treat this as a manual review visit.
    final existingResult =
        ref.read(testResultProvider.notifier).getResult(TestConfig.testIdSdcard);
    if (existingResult != null) {
      _shouldAutoNavigate = false;
    }
    _checkSDCard();
  }

  Future<void> _checkSDCard() async {
    try {
      setState(() {
        _statusMessage = AppStrings.checkingCardHealth;
      });

      // Wait 2 seconds before checking (similar to original Android code)
      await Future.delayed(const Duration(seconds: 2));

      final result = await _sdCardChannel.invokeMethod<Map<dynamic, dynamic>>('checkSDCard');
      
      if (result != null) {
        final isSupported = result['isSupported'] as bool? ?? false;
        final isPresent = result['isPresent'] as bool? ?? false;
        final isAvailable = result['isAvailable'] as bool? ?? false;

        final hasSlot = isSupported;
        final detected = isPresent && isAvailable;

        if (mounted) {
          setState(() {
            _scanningComplete = true;
            _sdCardDetected = detected;
            _statusMessage = hasSlot
                ? (detected ? AppStrings.sdCardFound : AppStrings.noSdCardFound)
                : AppStrings.noSdCardFound;
            _showResultButtons = true;
          });

          // Auto-mark result based on detection
          if (!hasSlot) {
            // Device has no SD slot → NA
            TestResultHelper.saveNA(ref, TestConfig.testIdSdcard);
          } else if (detected) {
            // SD card available → Pass
            TestResultHelper.savePass(ref, TestConfig.testIdSdcard);
          } else {
            // Slot exists but no card detected → Fail
            TestResultHelper.saveFail(ref, TestConfig.testIdSdcard);
          }

          // On first auto-run, navigate after a short delay so user can see the result.
          // When user revisits this screen (existing result), we do NOT auto-navigate and
          // instead keep them on this screen with enabled Pass/Fail buttons.
          if (_shouldAutoNavigate) {
            Future.delayed(const Duration(milliseconds: 700), () {
              if (mounted) {
                _navigateToNextTest();
              }
            });
          }
        }
      } else {
        throw Exception('SD card check returned null');
      }
    } catch (e) {
      debugPrint('Error checking SD card: $e');
      if (mounted) {
        setState(() {
          _scanningComplete = true;
          _sdCardDetected = false;
          _statusMessage = 'Error checking SD card. Please try again.';
          _showResultButtons = true;
        });
        // On error, conservatively mark as Fail and move on
        TestResultHelper.saveFail(ref, TestConfig.testIdSdcard);
        if (_shouldAutoNavigate) {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) {
              _navigateToNextTest();
            }
          });
        }
      }
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
      TestConfig.testIdSdcard,
    );
  }
  void _handlePass() {
    // Save SD Card test result as pass
    TestResultHelper.savePass(ref, TestConfig.testIdSdcard);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleFail() {
    // Save SD Card test result as fail
    TestResultHelper.saveFail(ref, TestConfig.testIdSdcard);
    
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
                  // Mark SD Card test as skipped
                  TestResultHelper.saveSkip(ref, TestConfig.testIdSdcard);
                  
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

          /// Main Content Card - ResponsiveCard when scanning, ScanResultCard when complete
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: 180, // Add bottom padding to avoid touching ellipses
              ),
              child: _scanningComplete
                  ? ScanResultCard(
                      // Use network image with local fallback
                      customImageWidget: CommonTestImage(
                        screenName: TestConfig.testIdSdcard,
                        isPassed: _sdCardDetected == true,
                        localFallbackPath: _sdCardDetected == true
                            ? AppStrings.image20Path
                            : AppStrings.image21Path,
                        fallbackIcon: Icons.sd_card,
                        width: 120,
                        height: 120,
                      ),
                      status: _sdCardDetected == true
                          ? ScanStatus.passed
                          : ScanStatus.failed,
                      title: _sdCardDetected == true
                          ? AppStrings.sdCardDetected
                          : AppStrings.sdCardNotDetected,
                      subheadingLines: [
                        _statusMessage,
                      ],
                    )
                  : ResponsiveCard(
                      // Use network image with local fallback
                      customImageWidget: CommonTestImage(
                        screenName: TestConfig.testIdSdcard,
                        isPassed: true,
                        localFallbackPath: AppStrings.image20Path,
                        fallbackIcon: Icons.sd_card,
                        width: 120,
                        height: 120,
                      ),
                      heading: AppStrings.scanningSdCard,
                      subtitleLines: [
                        _statusMessage,
                      ],
                      showProgressBar: true,
                      progressDuration: const Duration(seconds: 2),
                      onProgressComplete: () {},
                    ),
            ),
          ),

          /// Pass/Fail Buttons (only after scanning completes)
          if (_showResultButtons)
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
          /// Common Footer with ellipse images (only show after scanning completes) - ignorePointer to allow button clicks
          CommonFooter(
            leftEllipsePath: !_scanningComplete ? AppStrings.ellipse229Path : null,
            rightEllipsePath: !_scanningComplete ? AppStrings.ellipse230Path : null,
            ignorePointer: true,
          ),

        ],
        ),
      ),
    );
  }
}

