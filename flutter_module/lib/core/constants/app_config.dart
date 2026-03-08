/// Centralized application configuration constants
/// 
/// This file contains all package names, method channel names, and other
/// app-level configuration that should not be hardcoded throughout the codebase.
class AppConfig {
  AppConfig._();

  /// Application package name / namespace
  /// This should match the package name in AndroidManifest.xml and build.gradle.kts
  static const String packageName = 'com.example.qc';

  /// Method channel names
  /// These are used for platform channel communication between Flutter and native code
  static const String bluetoothChannel = '$packageName/bluetooth';
  static const String wifiChannel = '$packageName/wifi';
  static const String phoneChannel = '$packageName/phone';
  static const String headphonesChannel = '$packageName/headphones';
  static const String settingsChannel = '$packageName/settings';
  static const String buttonChannel = '$packageName/buttons';
  static const String buttonEventChannel = '$packageName/buttons/events';
  static const String brightnessChannel = '$packageName/brightness';
  static const String sdCardChannel = '$packageName/sdcard';
  static const String chargerChannel = '$packageName/charger';
  static const String chargerEventChannel = '$packageName/charger/events';
  static const String batteryChannel = '$packageName/battery';
  static const String batteryEventChannel = '$packageName/battery/events';
  static const String touchChannel = '$packageName/touch';
  static const String touchEventChannel = '$packageName/touch/events';
  static const String otgChannel = '$packageName/otg';
  static const String otgEventChannel = '$packageName/otg/events';
  static const String nfcChannel = '$packageName/nfc';

  /// Helper method to create method channel names
  /// Usage: AppConfig.getMethodChannel('custom') => 'com.example.qc/custom'
  static String getMethodChannel(String channelName) {
    return '$packageName/$channelName';
  }
}

