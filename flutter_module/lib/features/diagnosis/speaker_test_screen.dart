import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_text_input.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_toast.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

class SpeakerTestScreen extends ConsumerStatefulWidget {
  const SpeakerTestScreen({super.key});

  @override
  ConsumerState<SpeakerTestScreen> createState() => _SpeakerTestScreenState();
}

class _SpeakerTestScreenState extends ConsumerState<SpeakerTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('speaker'); // Dynamic progress for screen 16
  final TextEditingController _numberController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  bool _audioPlayed = false;
  bool _isNumberValid = false;
  String _randomNumber = '';
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeTts();
  }

  @override
  void dispose() {
    _numberController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.3); // Slow rate
      await _flutterTts.setPitch(0.3); // Lower pitch
      await _flutterTts.setVolume(1.0);
      
      // Set completion handler to track when speech finishes
      _flutterTts.setCompletionHandler(() {
        print('✅ Speech completed');
      });
      
      print('✅ TTS initialized successfully');
    } catch (e) {
      print('❌ Error initializing TTS: $e');
      // Continue anyway - will show error when trying to speak
    }
  }

  Future<void> _waitForSpeechComplete() async {
    // Wait for speech to complete (estimate based on rate)
    // With rate 0.3, each digit takes about 1-2 seconds
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  void _onNumberValidationChanged(bool isValid) {
    final enteredText = _numberController.text.trim();
    print('🔍 Number validation changed: isValid=$isValid, text=$enteredText');
    
    setState(() {
      _isNumberValid = isValid;
    });

    // Show toast when 3 digits are entered (valid format)
    if (isValid && enteredText.length == 3 && _randomNumber.isNotEmpty) {
      // Compare entered number with random number
      if (enteredText == _randomNumber) {
        // Success - show pass toast
        print('✅ Numbers match! Showing success toast');
        CommonToast.showSuccess(
          context,
          message: AppStrings.speakerPassToast,
        );
        
        // Auto-save result as pass (correct number entered)
        TestResultHelper.savePass(ref, TestConfig.testIdSpeaker);
        
        // Auto-navigate after brief delay when test passes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _navigateToNextTest();
            }
          });
        });
      } else {
        // Failure - show fail toast (no auto-navigation on fail)
        print('❌ Numbers do not match: entered="$enteredText", expected="$_randomNumber"');
        CommonToast.showError(
          context,
          message: AppStrings.speakerFailToast,
        );
      }
    }
  }

  String _generateRandomNumber() {
    // Generate 3-digit number with unique digits (0-9, no repeats)
    final List<int> availableDigits = List.generate(10, (index) => index); // 0-9
    availableDigits.shuffle(_random);
    
    // Take first 3 unique digits
    final digit1 = availableDigits[0];
    final digit2 = availableDigits[1];
    final digit3 = availableDigits[2];
    
    final number = '$digit1$digit2$digit3';
    print('Generated unique random number: $number (no repeats)');
    return number;
  }

  Future<void> _playAudio() async {
    // Generate new random number
    _randomNumber = _generateRandomNumber();
    print('Generated random number: $_randomNumber');

    // Clear previous input
    _numberController.clear();
    setState(() {
      _isNumberValid = false;
      _audioPlayed = true; // Show second screen first
    });

    // Wait for screen transition, then wait 1 second before speaking
    await Future.delayed(const Duration(milliseconds: 100)); // Allow UI to update
    await Future.delayed(const Duration(seconds: 1)); // Wait 1 second as requested

    // Speak the number slowly, digit by digit with pauses
    if (!mounted) return;
    
    try {
      // Stop any ongoing speech first
      try {
        await _flutterTts.stop();
      } catch (_) {
        // Ignore stop errors
      }
      
      // Small delay before starting new speech
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Speak each digit separately with pauses for clarity
      // Wait for each speak to complete before moving to next
      for (int i = 0; i < _randomNumber.length; i++) {
        if (!mounted) break;
        
        // Wait for previous speech to complete
        await _flutterTts.speak(_randomNumber[i]);
        
        // Wait for speech to finish before next digit
        // Use completion handler to ensure speech finishes
        await _waitForSpeechComplete();
        
        // Pause between digits
        if (i < _randomNumber.length - 1) {
          await Future.delayed(const Duration(milliseconds: 600));
        }
      }
    } on MissingPluginException catch (e) {
      print('❌ MissingPluginException: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Text-to-speech plugin not found. Please rebuild the app.'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❌ Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
        TestConfig.testIdSpeaker,
      );
    } else {
      debugPrint('❌ SpeakerTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleProceed() {
    final enteredNumber = _numberController.text.trim();
    
    print('🔍 Proceed clicked: entered="$enteredNumber", random="$_randomNumber", isValid=$_isNumberValid');
    
    if (enteredNumber.isEmpty || !_isNumberValid) {
      print('❌ Cannot proceed: empty or invalid');
      return;
    }

    // Determine if test passed or failed based on number match
    final testPassed = enteredNumber == _randomNumber;
    
    // Save Speaker test result (if not already saved by auto-navigation)
    if (testPassed) {
      TestResultHelper.savePass(ref, TestConfig.testIdSpeaker);
    } else {
      TestResultHelper.saveFail(ref, TestConfig.testIdSpeaker);
    }
    
    // Navigate to next test based on API order
    _navigateToNextTest();
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdSpeaker);
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
                        // Image, Heading, Subheading
                        CommonContentWidget(
                          customImageWidget: CommonTestImage(
                            screenName: TestConfig.testIdSpeaker,
                            isPassed: true,
                            localFallbackPath: AppStrings.image144Path,
                            fallbackIcon: Icons.volume_up,
                            width: 120,
                            height: 120,
                          ),
                          heading: AppStrings.testingSpeaker,
                          subheading: AppStrings.speakerTestInstruction,
                        ),

                        // Input field (shown only after audio is played)
                        if (_audioPlayed) ...[
                          const SizedBox(height: 32),
                          CommonTextInput(
                            editTextTitle: AppStrings.enterThreeDigitNumber,
                            editTextPlaceholder: AppStrings.valueRangeHint,
                            keyboardType: TextInputType.number,
                            regex: r'^[0-9]{3}$', // 3 digits, each 0-9
                            controller: _numberController,
                            onValidationChanged: _onNumberValidationChanged,
                            maxLength: 3,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                          ),
                          const SizedBox(height: 8),
                         
                        ],
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
                    // Play Audio Button (initial state)
                    if (!_audioPlayed)
                      CommonButton(
                        text: AppStrings.playAudioButton,
                        onPressed: _playAudio,
                      ),

                    // Play Audio Again and Proceed Buttons (after audio played)
                    if (_audioPlayed) ...[
                      // Play Audio Again Button (outlined style)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _playAudio,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.white,
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: EdgeInsets.zero,
                            elevation: 0,
                          ),
                          child: Center(
                            child: Text(
                              AppStrings.playAudioAgainButton,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Proceed Button (enabled only when 3 digits entered)
                      CommonButton(
                        text: AppStrings.proceedButton,
                        onPressed: _isNumberValid ? _handleProceed : null,
                        enabled: _isNumberValid,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          /// Common Footer (shown during test)
          if (_audioPlayed)
            const CommonFooter(),
        ],
        ),
      ),
    );
  }
}

