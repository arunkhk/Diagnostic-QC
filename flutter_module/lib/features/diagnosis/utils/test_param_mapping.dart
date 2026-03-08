/// Utility to map testId to testParamID and paramValue
class TestParamMapping {
  TestParamMapping._();

  /// Map of testId to (testParamID, paramValue)
  static const Map<String, Map<String, dynamic>> _testParamMap = {
    'wifi': {'testParamID': 2, 'paramValue': 'Wifi'},
    'bluetooth': {'testParamID': 3, 'paramValue': 'Bluetooth'},
    'location': {'testParamID': 4, 'paramValue': 'GPS'},
    'nfc': {'testParamID': 37, 'paramValue': 'NFC'},
    'flashlight': {'testParamID': 7, 'paramValue': 'Flashlight'},
    'vibration': {'testParamID': 10, 'paramValue': 'Vibration'},
    'microphone': {'testParamID': 11, 'paramValue': 'Microphone'},
    'headphones': {'testParamID': 12, 'paramValue': 'Headphone'},
    'charging': {'testParamID': 13, 'paramValue': 'Charging'},
    'battery': {'testParamID': 14, 'paramValue': 'BatteryHealth'},
    'touch': {'testParamID': 15, 'paramValue': 'Touch'},
    'volume': {'testParamID': 16, 'paramValue': 'VolumeUp'},
    'fingerprint': {'testParamID': 17, 'paramValue': 'FingerPrint'},
    'rotation': {'testParamID': 18, 'paramValue': 'Rotation'},
    'menu': {'testParamID': 19, 'paramValue': 'MenuButton'},
    'back': {'testParamID': 20, 'paramValue': 'BackButton'},
    'brightness': {'testParamID': 21, 'paramValue': 'Brightness'},
    'power': {'testParamID': 22, 'paramValue': 'PowerButton'},
    'home': {'testParamID': 23, 'paramValue': 'HomeButton'},
    'light': {'testParamID': 25, 'paramValue': 'LightSensor'},
    'facelock': {'testParamID': 27, 'paramValue': 'FaceLock'},
    'sdcard': {'testParamID': 28, 'paramValue': 'SDCard'},
    'proximity': {'testParamID': 29, 'paramValue': 'Proxy'},
    'magnet': {'testParamID': 30, 'paramValue': 'MagnetSensor'},
    'accelerometer': {'testParamID': 31, 'paramValue': 'Accelerometer'},
    'gyrosensor': {'testParamID': 32, 'paramValue': 'GyroSensor'},
    'otg': {'testParamID': 33, 'paramValue': 'Otg'},
    'color': {'testParamID': 34, 'paramValue': 'Color'},
    'multitouch': {'testParamID': 35, 'paramValue': 'MultiTouch'},
    'sar': {'testParamID': 36, 'paramValue': 'SarValue'},
  };

  /// Get test parameters for a given testId
  /// Returns a list because some tests (cameras, networks) map to multiple entries
  static List<Map<String, dynamic>> getTestParams(String testId) {
    // Special handling for cameras - returns both front and back
    if (testId == 'cameras') {
      return [
        {'testParamID': 5, 'paramValue': 'FrontCamera'},
        {'testParamID': 6, 'paramValue': 'BackCamera'},
      ];
    }

    // Special handling for networks - returns both network and network2
    if (testId == 'networks') {
      return [
        {'testParamID': 8, 'paramValue': 'Network'},
        {'testParamID': 9, 'paramValue': 'Network2'},
      ];
    }

    // For other tests (including volume), return single entry
    // Note: Volume only has VolumeUp (testParamID: 16) in the mapping list
    final mapping = _testParamMap[testId];
    if (mapping != null) {
      return [mapping];
    }

    return [];
  }

  /// Get testParamID for a given testId (returns first one for cameras/networks)
  static int? getTestParamID(String testId) {
    final params = getTestParams(testId);
    return params.isNotEmpty ? params[0]['testParamID'] as int? : null;
  }

  /// Get paramValue for a given testId (returns first one for cameras/networks)
  static String? getParamValue(String testId) {
    final params = getTestParams(testId);
    return params.isNotEmpty ? params[0]['paramValue'] as String? : null;
  }

  /// Check if testId has a mapping
  static bool hasMapping(String testId) {
    return testId == 'cameras' || 
           testId == 'networks' || 
           _testParamMap.containsKey(testId);
  }

  /// Get all mapped testIds
  static List<String> getMappedTestIds() {
    final ids = _testParamMap.keys.toList();
    ids.addAll(['cameras', 'networks']);
    return ids;
  }
}

