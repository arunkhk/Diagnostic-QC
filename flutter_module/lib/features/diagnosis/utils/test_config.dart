import 'package:flutter/material.dart';

/// Delay before auto-starting a test when isAutoMode is true (from GetTestImages API)
const Duration testAutoModeStartDelay = Duration(milliseconds: 500);

/// Centralized configuration for test IDs
/// NOTE: Test names (testName) come from API paramValue, not from this class
/// This class only provides test ID constants for type safety
class TestConfig {
  TestConfig._();
  /// Test ID constants
  static String get testIdCharging => 'charging';
  static String get testIdBattery => 'battery';
  static String get testIdTouch => 'touch';
  static String get testIdVolume => 'volume';
  static String get testIdVibration => 'vibration';
  static String get testIdSpeaker => 'speaker';
  static String get testIdFlashlight => 'flashlight';
  static String get testIdMicrophone => 'microphone';
  static String get testIdHeadphones => 'headphones';
  static String get testIdCameras => 'cameras';
  static String get testIdSdcard => 'sdcard';
  static String get testIdRotation => 'rotation';
  static String get testIdBrightness => 'brightness';
  static String get testIdFingerprint => 'fingerprint';
  static String get testIdFacelock => 'facelock';
  static String get testIdProximity => 'proximity';
  static String get testIdLight => 'light';
  static String get testIdMagnet => 'magnet';
  static String get testIdAccelerometer => 'accelerometer';
  static String get testIdGyrosensor => 'gyrosensor';
  static String get testIdOtg => 'otg';
  static String get testIdColor => 'color';
  static String get testIdMultitouch => 'multitouch';
  static String get testIdSar => 'sar';
  static String get testIdWifi => 'wifi';
  static String get testIdBluetooth => 'bluetooth';
  static String get testIdLocation => 'location';
  static String get testIdNetworks => 'networks';
  static String get testIdMenu => 'menu';
  static String get testIdBack => 'back';
  static String get testIdPower => 'power';
  static String get testIdHome => 'home';
  static String get testIdNfc => 'nfc';

  /// Map uniqueTestKey to IconData for displaying icons
  /// Uses getter values directly to ensure consistency with test ID constants
  static IconData getIconForTestKey(String uniqueTestKey) {
    // Build icon map using getter values to ensure consistency
    final iconMap = <String, IconData>{
      testIdCharging: Icons.battery_charging_full,
      testIdBattery: Icons.battery_full,
      testIdTouch: Icons.touch_app,
      testIdVolume: Icons.volume_up,
      testIdVibration: Icons.vibration,
      testIdSpeaker: Icons.volume_up,
      testIdFlashlight: Icons.flashlight_on,
      testIdMicrophone: Icons.mic,
      testIdHeadphones: Icons.headphones,
      testIdCameras: Icons.camera_alt,
      testIdSdcard: Icons.sd_card,
      testIdRotation: Icons.screen_rotation,
      testIdBrightness: Icons.brightness_6,
      testIdFingerprint: Icons.fingerprint,
      testIdFacelock: Icons.face,
      testIdProximity: Icons.sensor_door,
      testIdLight: Icons.lightbulb,
      testIdMagnet: Icons.explore,
      testIdAccelerometer: Icons.device_hub,
      testIdGyrosensor: Icons.my_location,
      testIdOtg: Icons.usb,
      testIdColor: Icons.palette,
      testIdMultitouch: Icons.touch_app,
      testIdSar: Icons.science,
      testIdWifi: Icons.wifi,
      testIdBluetooth: Icons.bluetooth,
      testIdLocation: Icons.location_on,
      testIdNetworks: Icons.signal_cellular_alt,
      testIdMenu: Icons.menu,
      testIdBack: Icons.arrow_back,
      testIdPower: Icons.power_settings_new,
      testIdHome: Icons.home,
      testIdNfc: Icons.nfc,
    };
    return iconMap[uniqueTestKey.toLowerCase()] ?? Icons.help_outline;
  }
}

