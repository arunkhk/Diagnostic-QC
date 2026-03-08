import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/progress_calculator.dart';
import '../../core/widgets/common_header.dart';
import '../../core/widgets/common_footer.dart';
import '../../core/widgets/common_button.dart';
import '../../core/widgets/common_content_widget.dart';
import '../../core/widgets/common_test_image.dart';
import 'utils/test_result_helper.dart';
import 'utils/test_config.dart';
import 'utils/test_navigation_service.dart';
import 'providers/test_parameters_provider.dart';
import 'models/test_parameter_item.dart';
import 'diagnosis_summary_screen.dart';

class MicrophoneTestScreen extends ConsumerStatefulWidget {
  const MicrophoneTestScreen({super.key});

  @override
  ConsumerState<MicrophoneTestScreen> createState() => _MicrophoneTestScreenState();
}

class _MicrophoneTestScreenState extends ConsumerState<MicrophoneTestScreen> {
  final double _screenProgress = ProgressCalculator.getProgressForScreen('microphone'); // Dynamic progress for screen 20
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPlaying = false;
  bool _recordingComplete = false;
  bool _playbackComplete = false;
  int _recordingDuration = 0;
  double _amplitude = 0.0;
  String? _recordingPath;
  Timer? _recordingTimer;
  Timer? _amplitudeTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    // Check if microphone permission is granted
    final status = await _audioRecorder.hasPermission();
    if (!status) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required'),
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
      final fileName = 'microphone_test_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
        _amplitude = 0.0;
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

      // Start amplitude monitoring
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (_isRecording) {
          final amplitude = await _audioRecorder.getAmplitude();
          if (mounted) {
            setState(() {
              _amplitude = amplitude.current;
            });
          }
        } else {
          timer.cancel();
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
      _amplitudeTimer?.cancel();

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
        _isPlaying = true;
        _playbackComplete = false;
      });

      await _audioPlayer.play(DeviceFileSource(_recordingPath!));

      // Listen for playback completion
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isPlaying = false;
          _playbackComplete = true;
        });
      });
    } catch (e) {
      print('❌ Error playing recording: $e');
      setState(() {
        _isPlaying = false;
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
        TestConfig.testIdMicrophone,
      );
    } else {
      debugPrint('❌ MicrophoneTestScreen: Failed to get test parameters for navigation.');
      TestNavigationService.navigateToSummaryScreen(context);
    }
  }

  void _handleProceed() {
    TestResultHelper.savePass(ref, TestConfig.testIdMicrophone);
    _navigateToNextTest();
  }

  void _handleSkip() {
    TestResultHelper.saveSkip(ref, TestConfig.testIdMicrophone);
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
                            screenName: TestConfig.testIdMicrophone,
                            isPassed: true,
                            localFallbackPath: AppStrings.image144Path,
                            fallbackIcon: Icons.mic,
                            width: 120,
                            height: 120,
                          ),
                          heading: AppStrings.testingMicrophone,
                          subheading: AppStrings.microphoneTestInstruction,
                        ),

                        const SizedBox(height: 32),

                        // Time and Amplitude Display
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${AppStrings.timeLabel} ${_recordingComplete ? AppStrings.timeFinish : AppStrings.timeSeconds}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Text(
                              '${AppStrings.amplitudeLabel} ${_amplitude.toStringAsFixed(1)}',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
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
                    // Start Recording / Playing / Proceed Button
                    if (!_recordingComplete || !_playbackComplete)
                      CommonButton(
                        text: _isRecording
                            ? 'Recording... (${_recordingDuration}s)'
                            : _isPlaying
                                ? 'Playing Audio...'
                                : AppStrings.startRecordingButton,
                        onPressed: (_isRecording || _isPlaying) ? null : _startRecording,
                        enabled: !_isRecording && !_isPlaying,
                      )
                    else
                      CommonButton(
                        text: AppStrings.proceedButton,
                        onPressed: _playbackComplete ? _handleProceed : null,
                        enabled: _playbackComplete,
                      ),
                  ],
                ),
              ),
            ],
          ),

          /// Common Footer (shown during recording/playback)
          if (_isRecording || _isPlaying)
            const CommonFooter(),
        ],
        ),
      ),
    );
  }
}

