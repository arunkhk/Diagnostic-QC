import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:headphones_detection/headphones_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_config.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_two_buttons.dart';
import '../../core/widgets/common_dialog.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'providers/test_images_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

class HeadphonesTestScreen extends ConsumerStatefulWidget {
  const HeadphonesTestScreen({super.key});

  @override
  ConsumerState<HeadphonesTestScreen> createState() => _HeadphonesTestScreenState();
}

class _HeadphonesTestScreenState extends ConsumerState<HeadphonesTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('headphones'); // Dynamic progress for screen 21
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  final MethodChannel _headphonesChannel = const MethodChannel(AppConfig.headphonesChannel);
  
  bool _showTestScreen = false;
  bool _isPlayingMusic = false;
  bool _isRecording = false;
  bool _isPlayingRecording = false;
  bool _recordingComplete = false;
  bool _playbackComplete = false;
  int _recordingDuration = 0;
  String? _recordingPath;
  Timer? _recordingTimer;

  bool _autoStartScheduled = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleAutoStartIfNeeded());
  }

  void _scheduleAutoStartIfNeeded() {
    if (!mounted || _autoStartScheduled) return;
    if (!ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdHeadphones)) return;
    if (_showTestScreen) return;
    _autoStartScheduled = true;
    Future.delayed(testAutoModeStartDelay, () {
      if (mounted && !_showTestScreen) {
        _handleBeginTest();
      }
    });
  }

  bool _shouldShowStartTestButton() {
    return !ref.read(testImagesProvider.notifier).getIsAutoMode(TestConfig.testIdHeadphones);
  }

  Future<void> _initializeTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<bool> _checkHeadphonesConnected() async {
    try {
      final bool isConnected = await HeadphonesDetection.isHeadphonesConnected();
      return isConnected;
    } catch (e) {
      print('❌ Error checking headphones: $e');
      return false;
    }
  }

  Future<void> _playDefaultRingtone() async {
    try {
      setState(() {
        _isPlayingMusic = true;
      });
      
      // Try platform channel first
      try {
        await _headphonesChannel.invokeMethod('playDefaultRingtone');
        print('✅ Ringtone playing via platform channel');
      } catch (platformError) {
        // If platform channel fails, use flutter_tts as fallback
        print('⚠️ Platform channel failed, using TTS fallback: $platformError');
        
        // Use flutter_tts to play a simple tone/beep
        // Play a series of beeps to simulate ringtone
        for (int i = 0; i < 3; i++) {
          if (!mounted || !_isPlayingMusic) break;
          await _flutterTts.speak('beep');
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      // Stop after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isPlayingMusic = false;
          });
          _flutterTts.stop();
        }
      });
    } catch (e) {
      print('❌ Error playing ringtone: $e');
      setState(() {
        _isPlayingMusic = false;
      });
      _flutterTts.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing ringtone: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      // Check permission
      if (!await _audioRecorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission is required'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Get temporary directory for recording
      final directory = await getTemporaryDirectory();
      final fileName = 'headphones_mic_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _recordingPath = path.join(directory.path, fileName);

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _recordingPath!,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
        _recordingComplete = false;
        _playbackComplete = false;
      });

      // Start timer for 5 seconds
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration++;
        });

        if (_recordingDuration >= 5) {
          timer.cancel();
          _stopRecording();
        }
      });
    } catch (e) {
      print('❌ Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting recording: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stop();
      _recordingTimer?.cancel();

      setState(() {
        _isRecording = false;
        _recordingComplete = true;
      });

      // Automatically play the recording
      await _playRecording();
    } catch (e) {
      print('❌ Error stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error stopping recording: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _playRecording() async {
    if (_recordingPath == null || !File(_recordingPath!).existsSync()) {
      return;
    }

    try {
      setState(() {
        _isPlayingRecording = true;
        _playbackComplete = false;
      });

      await _audioPlayer.play(DeviceFileSource(_recordingPath!));

      // Listen for playback completion
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isPlayingRecording = false;
          _playbackComplete = true;
        });
      });
    } catch (e) {
      print('❌ Error playing recording: $e');
      setState(() {
        _isPlayingRecording = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing recording: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleBeginTest() async {
    final isConnected = await _checkHeadphonesConnected();
    
    if (isConnected) {
      // Headphones connected, show test screen
      setState(() {
        _showTestScreen = true;
      });
    } else {
      // Headphones not connected, show dialog
      _showHeadphonesNotConnectedDialog();
    }
  }

  void _showHeadphonesNotConnectedDialog() {
    showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => PopScope(
        canPop: false, // Prevent dismissing by back button
        child: CommonDialog(
          title: AppStrings.headphonesNotConnectedTitle,
          message: AppStrings.headphonesNotConnectedMessage,
          cancelText: AppStrings.yesButton,
          proceedText: AppStrings.noButton,
          onCancel: () {
            // User will connect headphones, just close the dialog
            Navigator.of(context).pop(false);
          },
          onProceed: () {
            // User chose not to connect headphones, test fails
            // Mark test as fail immediately (before navigation)
            TestResultHelper.saveFail(ref, TestConfig.testIdHeadphones);
            
            // Navigate to next test based on API order after dialog closes
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _navigateToNextTest();
              }
            });
          },
        ),
      ),
    ).then((value) {
      // Dialog was dismissed - check if button was clicked
      // value will be:
      // - true if "No" button was clicked (already handled in onProceed)
      // - false if "Yes" button was clicked (user will connect headphones)
      // - null if dialog was dismissed without clicking any button (shouldn't happen with barrierDismissible: false, but handle it)
      if (value == null && mounted) {
        // Dialog was dismissed without clicking any button - mark test as fail
        TestResultHelper.saveFail(ref, TestConfig.testIdHeadphones);
        
        // Navigate to next test based on API order
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _navigateToNextTest();
          }
        });
      }
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
        TestConfig.testIdHeadphones,
      );
    } else {
      debugPrint('❌ HeadphonesTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleTestPass() {
    TestResultHelper.savePass(ref, TestConfig.testIdHeadphones);
    _navigateToNextTest();
  }

  void _handleTestFail() {
    TestResultHelper.saveFail(ref, TestConfig.testIdHeadphones);
    _navigateToNextTest();
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdHeadphones);
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
                            screenName: TestConfig.testIdHeadphones,
                            isPassed: true,
                            localFallbackPath: AppStrings.image103Path,
                            fallbackIcon: Icons.headphones,
                            width: 120,
                            height: 120,
                          ),
                          heading: AppStrings.checkingHeadphones,
                          subheading: _showTestScreen
                              ? AppStrings.headphonesTestInstructionActive
                              : AppStrings.headphonesTestInstruction,
                        ),

                        const SizedBox(height: 32),

                        // Test buttons (shown on second screen)
                        if (_showTestScreen) ...[
                          CommonTwoButtons(
                            leftButtonText: AppStrings.playMusicButton,
                            rightButtonText: _isRecording
                                ? 'Recording... (${_recordingDuration}s)'
                                : AppStrings.recordMicButton,
                            onLeftButtonPressed: _isPlayingMusic ? null : _playDefaultRingtone,
                            onRightButtonPressed: (_isRecording || _isPlayingRecording) ? null : _startRecording,
                            leftButtonEnabled: !_isPlayingMusic,
                            rightButtonEnabled: !_isRecording && !_isPlayingRecording,
                          ),
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
                    // Begin Test Button (initial screen, hidden in auto mode)
                    if (_shouldShowStartTestButton() && !_showTestScreen)
                      CommonButton(
                        text: AppStrings.beginTestButton,
                        onPressed: _handleBeginTest,
                      )
                    // Pass/Fail Buttons (test screen)
                    else
                      CommonTwoButtons(
                        leftButtonText: AppStrings.passButton,
                        rightButtonText: AppStrings.failButton,
                        onLeftButtonPressed: _handleTestPass,
                        onRightButtonPressed: _handleTestFail,
                      ),
                  ],
                ),
              ),
            ],
          ),

          /// Common Footer (shown during test) - ignorePointer to allow button clicks
          if (_showTestScreen && (_isPlayingMusic || _isRecording || _isPlayingRecording))
            const CommonFooter(ignorePointer: true),
        ],
        ),
      ),
    );
  }
}

