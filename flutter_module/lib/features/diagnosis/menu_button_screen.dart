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
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/responsive_card.dart';
import '../../core/widgets/scan_result_card.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_images_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

enum MenuTestState {
  readyToTest,
  testing,
  resultReady,
  notAvailable,
}

class MenuButtonScreen extends ConsumerStatefulWidget {
  const MenuButtonScreen({super.key});

  @override
  ConsumerState<MenuButtonScreen> createState() => _MenuButtonScreenState();
}

class _MenuButtonScreenState extends ConsumerState<MenuButtonScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('menu'); // Dynamic progress for screen 11
  MenuTestState _currentState = MenuTestState.readyToTest;
  bool _menuButtonPressed = false;
  bool _testComplete = false;
  bool _showProceedButton = false;
  bool _buttonWorking = false;
  
  StreamSubscription<dynamic>? _buttonSubscription;
  static const EventChannel _buttonChannel = EventChannel(AppConfig.buttonEventChannel);
  static const MethodChannel _buttonMethodChannel = MethodChannel(AppConfig.buttonChannel);
  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    _checkMenuButtonAvailability();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdMenu)) return;
    if (_currentState != MenuTestState.readyToTest) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && _currentState == MenuTestState.readyToTest) _startTest();
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdMenu);
  }
  
  Future<void> _checkMenuButtonAvailability() async {
    try {
      final hasMenuButton = await _buttonMethodChannel.invokeMethod<bool>('hasMenuButton') ?? false;
      if (!hasMenuButton && mounted) {
        // Only show not available if device truly doesn't have menu button
        // Don't auto-complete, let user see the message and proceed manually
        setState(() {
          _currentState = MenuTestState.notAvailable;
          _testComplete = true;
        });
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _showProceedButton = true;
            });
          }
        });
      }
    } catch (e) {
      print('❌ Error checking menu button availability: $e');
    }
  }

  @override
  void dispose() {
    _buttonSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startTest() async {
    setState(() {
      _currentState = MenuTestState.testing;
      _menuButtonPressed = false;
      _testComplete = false;
      _showProceedButton = false;
    });
    
    // Start listening for button events
    try {
      _buttonSubscription = _buttonChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          if (event == 'menu' && _currentState == MenuTestState.testing) {
            _handleMenuButtonPress();
          }
        },
        onError: (error) {
          print('❌ Button channel error: $error');
        },
      );
    } catch (e) {
      print('❌ Error listening to button channel: $e');
    }
  }

  void _handleMenuButtonPress() {
    if (mounted && _currentState == MenuTestState.testing && !_menuButtonPressed) {
      setState(() {
        _menuButtonPressed = true;
        _buttonWorking = true;
        _testComplete = true;
        _currentState = MenuTestState.resultReady;
      });
      
      // Stop listening
      _buttonSubscription?.cancel();
      
      // Show proceed button after a brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _showProceedButton = true;
          });
        }
      });
    }
  }

  Future<void> _navigateToNextTest() async {
    final testParametersAsyncValue = ref.read(testParametersProvider);
    List<TestParameterItem>? testParameters;

    if (testParametersAsyncValue.hasValue) {
      testParameters = testParametersAsyncValue.value;
    } else {
      // If still loading, wait a bit and try again
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
        TestConfig.testIdMenu,
      );
    } else {
      debugPrint('❌ MenuButtonScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handlePass() {
    // Save Menu Button test result as pass (uses API paramValue and catIcon)
    TestResultHelper.savePass(ref, TestConfig.testIdMenu);
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleFail() {
    // Save Menu Button test result as fail (uses API paramValue and catIcon)
    TestResultHelper.saveFail(ref, TestConfig.testIdMenu);
    
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
                  // Mark Menu Button test as skipped (uses API paramValue and catIcon)
                  TestResultHelper.saveSkip(ref, TestConfig.testIdMenu);
                  
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

              /// Begin Test Button (only when ready to test, and not auto mode)
              if (_shouldShowStartTestButton() && _currentState == MenuTestState.readyToTest)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: CommonButton(
                    text: AppStrings.beginTestButton,
                    onPressed: _startTest,
                  ),
                ),

              /// Pass/Fail Buttons (only after test completes)
              if (_showProceedButton)
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

          /// Common Footer with ellipse images - ignorePointer to allow button clicks
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
      case MenuTestState.readyToTest:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdMenu,
            isPassed: true,
            localFallbackPath: AppStrings.image84Path,
            fallbackIcon: Icons.menu,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingMenuButton,
          subtitleLines: [
            AppStrings.menuButtonInstruction,
            'Press the Menu button to test.',
            'Note: Menu button is not available on modern Android devices.',
          ],
        );
        
      case MenuTestState.testing:
        return ResponsiveCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdMenu,
            isPassed: true,
            localFallbackPath: AppStrings.image84Path,
            fallbackIcon: Icons.menu,
            width: 120,
            height: 120,
          ),
          heading: AppStrings.testingMenuButton,
          subtitleLines: [
            'Press the Menu button now.',
            '⏳ Waiting for Menu button press...',
          ],
        );
        
      case MenuTestState.notAvailable:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdMenu,
            isPassed: false,
            localFallbackPath: AppStrings.image84Path,
            fallbackIcon: Icons.menu,
            width: 120,
            height: 120,
          ),
          status: ScanStatus.failed,
          title: 'Menu Button Not Available',
          subheadingLines: [
            'This device does not have a physical Menu button.',
            'Justification:',
            '• Menu button was deprecated in Android 3.0 (2011)',
            '• Modern devices use on-screen navigation buttons',
            '• Android 3.0+ devices use software menu (3-dot icon)',
            '• This is expected behavior for devices running Android 3.0+',
            'You can proceed to the next test.',
          ],
          showStatusIcon: true,
        );
        
      case MenuTestState.resultReady:
        return ScanResultCard(
          customImageWidget: CommonTestImage(
            screenName: TestConfig.testIdMenu,
            isPassed: _buttonWorking,
            localFallbackPath: AppStrings.image84Path,
            fallbackIcon: Icons.menu,
            width: 120,
            height: 120,
          ),
          status: _buttonWorking ? ScanStatus.passed : ScanStatus.failed,
          title: _buttonWorking 
              ? AppStrings.menuButtonWorking 
              : 'Menu Button Not Working',
          subheadingLines: _buttonWorking
              ? [AppStrings.menuButtonWorkingCorrectly]
              : ['Menu button was not detected. Please try again.'],
          showStatusIcon: true,
        );
    }
  }
}
