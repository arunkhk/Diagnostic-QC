/// Utility class to calculate dynamic progress for diagnosis screens
/// Based on 31 total screens, each screen represents ~3.23% of total progress
class ProgressCalculator {
  static const int totalScreens = 31;
  static const double progressPerScreen = 1.0 / totalScreens; // ~0.0333 (3.33% per screen)
  
  /// Screen order in the diagnosis flow
  /// Note: diagnosis screen is screen 31 (100%) as it's the completion screen
  static const Map<String, int> screenOrder = {
    'sd_card': 1,
    'charger': 2,
    'battery': 3,
    'touch': 4,
    'proximity': 5,
    'light': 6,
    'volume': 7,
    'back': 8,
    'power': 9,
    'home': 10,
    'menu': 11,
    'rotation': 12,
    'brightness': 13,
    'otg': 14,
    'networks': 15,
    'speaker': 16,
    'flashlight': 17,
    'vibration': 18,
    'cameras': 19,
    'microphone': 20,
    'headphones': 21,
    'fingerprint': 22,
    'facelock': 23,
    'magnet': 24,
    'accelerometer': 25,
    'gyrosensor': 26,
    'color': 27,
    'multitouch': 28,
    'sar': 29,
    'nfc': 30,
    'diagnosis': 31, // Diagnosis screen shows 100% when displayed
  };
  
  /// Calculate progress for a given screen identifier
  /// Returns progress value between 0.0 and 1.0
  static double getProgressForScreen(String screenId) {
    final order = screenOrder[screenId] ?? 1;
    // Progress = (screen number / total screens)
    // This gives us: screen 1 = 3.33%, screen 2 = 6.67%, ..., screen 30 (diagnosis) = 100%
    return (order / totalScreens);
  }
  
  /// Get progress for screen by order number (1-30)
  static double getProgressForOrder(int order) {
    if (order < 1) return 0.0;
    if (order > totalScreens) return 1.0;
    return (order / totalScreens);
  }
}

