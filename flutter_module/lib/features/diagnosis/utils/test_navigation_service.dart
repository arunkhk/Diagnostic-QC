import 'package:flutter/material.dart';
import '../models/test_parameter_item.dart';
import '../utils/test_config.dart';
import '../diagnosis_screen.dart';
import '../sd_card_detection_screen.dart';
import '../charger_test_screen.dart';
import '../battery_health_screen.dart';
import '../touch_screen_test_screen.dart';
import '../light_sensor_screen.dart';
import '../proximity_sensor_screen.dart';
import '../volume_button_screen.dart';
import '../power_button_screen.dart';
import '../back_button_screen.dart';
import '../home_button_screen.dart';
import '../menu_button_screen.dart';
import '../screen_rotation_screen.dart';
import '../network_connectivity_screen.dart';
import '../flashlight_test_screen.dart';
import '../screen_brightness_screen.dart';
import '../camera_test_screen.dart';
import '../fingerprint_test_screen.dart';
import '../facelock_test_screen.dart';
import '../magnet_sensor_test_screen.dart';
import '../accelerometer_test_screen.dart';
import '../gyroscope_test_screen.dart';
import '../otg_connectivity_screen.dart';
import '../display_test_screen.dart';
import '../multi_touch_test_screen.dart';
import '../sar_level_test_screen.dart';
import '../nfc_test_screen.dart';
import '../vibration_test_screen.dart';
import '../microphone_test_screen.dart';
import '../headphones_test_screen.dart';
import '../speaker_test_screen.dart';
import '../diagnosis_summary_screen.dart';

/// Service to handle dynamic navigation based on API test parameter order
class TestNavigationService {
  TestNavigationService._();

  /// Get the next test parameter after the current one
  /// If currentTestId is from combined screen (WiFi/Bluetooth/GPS), skip other combined screen tests
  static TestParameterItem? getNextTestParameter(
    List<TestParameterItem> allParameters,
    String currentTestId,
  ) {
    debugPrint('🔍 getNextTestParameter: Looking for next test after: $currentTestId');
    debugPrint('🔍 Total parameters: ${allParameters.length}');
    debugPrint('🔍 Parameter order: ${allParameters.map((p) => '${p.paramValue}(${p.displayOrder})').join(' → ')}');
    
    // Check if current test is from combined screen
    final isCombinedScreenTest = currentTestId == TestConfig.testIdWifi ||
        currentTestId == TestConfig.testIdBluetooth ||
        currentTestId == TestConfig.testIdLocation;
    
    debugPrint('🔍 Is combined screen test: $isCombinedScreenTest');
    
    // Find current parameter by uniqueTestKey
    int? currentIndex;
    for (int i = 0; i < allParameters.length; i++) {
      if (allParameters[i].uniqueTestKey == currentTestId) {
        currentIndex = i;
        debugPrint('✅ Found current test at index $i: ${allParameters[i].paramValue}');
        break;
      }
    }

    if (currentIndex == null) {
      debugPrint('❌ Current test $currentTestId not found in parameters!');
      return null;
    }

    // If current test is from combined screen, skip other combined screen tests
    if (isCombinedScreenTest) {
      debugPrint('🔍 Skipping combined screen tests, looking for next non-combined test...');
      // Find next test that is NOT WiFi, Bluetooth, or GPS
      for (int i = currentIndex + 1; i < allParameters.length; i++) {
        final testId = allParameters[i].uniqueTestKey;
        debugPrint('🔍 Checking index $i: ${allParameters[i].paramValue} (testId: $testId)');
        if (testId != TestConfig.testIdWifi &&
            testId != TestConfig.testIdBluetooth &&
            testId != TestConfig.testIdLocation) {
          debugPrint('✅ Found next test: ${allParameters[i].paramValue} at index $i');
          return allParameters[i];
        } else {
          debugPrint('⏭️ Skipping combined screen test: ${allParameters[i].paramValue}');
        }
      }
      debugPrint('❌ No next test found after skipping combined screen tests');
      return null;
    }

    // For other tests, return next parameter normally
    if (currentIndex < allParameters.length - 1) {
      final nextParam = allParameters[currentIndex + 1];
      debugPrint('✅ Found next test: ${nextParam.paramValue} at index ${currentIndex + 1}');
      return nextParam;
    }

    debugPrint('❌ No next test found (current is last)');
    return null;
  }

  /// Navigate to summary screen (centralized fallback)
  static void navigateToSummaryScreen(BuildContext context) {
    debugPrint('✅ Navigating to DiagnosisSummaryScreen (fallback)');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DiagnosisSummaryScreen(),
      ),
    );
  }

  /// Navigate to the next test screen based on API order
  /// If no more tests or screen not found, navigates to DiagnosisSummaryScreen
  static void navigateToNextTest(
    BuildContext context,
    List<TestParameterItem> allParameters,
    String currentTestId,
  ) {
    debugPrint('🚀 navigateToNextTest: Current test: $currentTestId');
    final nextParam = getNextTestParameter(allParameters, currentTestId);
    if (nextParam == null) {
      debugPrint('✅ No more tests - navigating to DiagnosisSummaryScreen');
      // No more tests - navigate to DiagnosisSummaryScreen
      navigateToSummaryScreen(context);
      return;
    }

    // Use uniqueTestKey directly from the model
    final nextTestId = nextParam.uniqueTestKey;
    debugPrint('🚀 Next test: ${nextParam.paramValue} (testId: $nextTestId)');

    // Navigate to the appropriate screen
    final nextScreen = _getScreenForTestId(nextTestId);
    if (nextScreen != null) {
      debugPrint('✅ Navigating to screen for: ${nextParam.paramValue}');
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => nextScreen,
        ),
      );
    } else {
      debugPrint('❌ No screen found for testId: $nextTestId');
      debugPrint('✅ Navigating to DiagnosisSummaryScreen (no screen available for next test)');
      // If no screen found, navigate to summary screen
      navigateToSummaryScreen(context);
    }
  }

  /// Get the screen widget for a testId
  static Widget? _getScreenForTestId(String testId) {
    // Combined screen handles WiFi, Bluetooth, and Location
    if (testId == TestConfig.testIdWifi ||
        testId == TestConfig.testIdBluetooth ||
        testId == TestConfig.testIdLocation) {
      return const DiagnosisScreen();
    }
    
    if (testId == TestConfig.testIdSdcard) {
      return const SdCardDetectionScreen();
    }
    if (testId == TestConfig.testIdCharging) {
      return const ChargerTestScreen();
    }
    if (testId == TestConfig.testIdBattery) {
      return const BatteryHealthScreen();
    }
    if (testId == TestConfig.testIdTouch) {
      return const TouchScreenTestScreen();
    }
    if (testId == TestConfig.testIdLight) {
      return const LightSensorScreen();
    }
    if (testId == TestConfig.testIdProximity) {
      return const ProximitySensorScreen();
    }
    if (testId == TestConfig.testIdVolume) {
      return const VolumeButtonScreen();
    }
    if (testId == TestConfig.testIdPower) {
      return const PowerButtonScreen();
    }
    if (testId == TestConfig.testIdBack) {
      return const BackButtonScreen();
    }
    if (testId == TestConfig.testIdHome) {
      return const HomeButtonScreen();
    }
    if (testId == TestConfig.testIdMenu) {
      return const MenuButtonScreen();
    }
    if (testId == TestConfig.testIdRotation) {
      return const ScreenRotationScreen();
    }
    if (testId == TestConfig.testIdNetworks) {
      return const NetworkConnectivityScreen();
    }
    if (testId == TestConfig.testIdFlashlight) {
      return const FlashlightTestScreen();
    }
    if (testId == TestConfig.testIdBrightness) {
      return const ScreenBrightnessScreen();
    }
    if (testId == TestConfig.testIdCameras) {
      return const CameraTestScreen();
    }
    if (testId == TestConfig.testIdFingerprint) {
      return const FingerprintTestScreen();
    }
    if (testId == TestConfig.testIdFacelock) {
      return const FacelockTestScreen();
    }
    if (testId == TestConfig.testIdMagnet) {
      return const MagnetSensorTestScreen();
    }
    if (testId == TestConfig.testIdAccelerometer) {
      return const AccelerometerTestScreen();
    }
    if (testId == TestConfig.testIdGyrosensor) {
      return const GyroscopeTestScreen();
    }
    if (testId == TestConfig.testIdOtg) {
      return const OtgConnectivityScreen();
    }
    if (testId == TestConfig.testIdColor) {
      return const DisplayTestScreen(); // Using display test for color
    }
    if (testId == TestConfig.testIdMultitouch) {
      return const MultiTouchTestScreen();
    }
    if (testId == TestConfig.testIdSar) {
      return const SarLevelTestScreen();
    }
    if (testId == TestConfig.testIdNfc) {
      return const NfcTestScreen();
    }
    if (testId == TestConfig.testIdVibration) {
      return const VibrationTestScreen();
    }
    if (testId == TestConfig.testIdMicrophone) {
      return const MicrophoneTestScreen();
    }
    if (testId == TestConfig.testIdHeadphones) {
      return const HeadphonesTestScreen();
    }
    if (testId == TestConfig.testIdSpeaker) {
      return const SpeakerTestScreen();
    }
    
    return null;
  }

  /// Get test execution order for combined screen (WiFi, Bluetooth, GPS)
  /// Returns list of testIds in API order
  static List<String> getCombinedScreenTestOrder(List<TestParameterItem> allParameters) {
    final order = <String>[];
    
    // Find WiFi, Bluetooth, and GPS in API order using uniqueTestKey
    for (final param in allParameters) {
      final testId = param.uniqueTestKey;
      if (testId == TestConfig.testIdWifi ||
          testId == TestConfig.testIdBluetooth ||
          testId == TestConfig.testIdLocation) {
        if (!order.contains(testId)) {
          order.add(testId);
        }
      }
    }
    
    return order;
  }
}

