/// Model for a single test image item from the GetTestImages API
/// API endpoint: GET /PhoneDiagnostics/GetTestImages?subscriptionId={id}
class TestImageItem {
  /// URL for the fail icon (shown when test fails)
  final String failIcon;
  
  /// URL for the pass icon (shown when test passes)
  final String passIcon;
  
  /// Screen identifier (matches uniqueTestKey from TestConfig, e.g., "wifi", "bluetooth")
  final String screne;
  
  /// List of additional images for this screen (e.g., scanning animations)
  final List<String> otherimages;

  /// When true, hide "Start Test" and auto-start the test after a short delay
  final bool isAutoMode;

  TestImageItem({
    required this.failIcon,
    required this.passIcon,
    required this.screne,
    required this.otherimages,
    this.isAutoMode = false,
  });

  factory TestImageItem.fromJson(Map<String, dynamic> json) {
    return TestImageItem(
      failIcon: json['failIcon'] as String? ?? '',
      passIcon: json['passIcon'] as String? ?? '',
      screne: json['screne'] as String? ?? '',
      otherimages: (json['otherimages'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isAutoMode: json['isAutoMode'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'failIcon': failIcon,
      'passIcon': passIcon,
      'screne': screne,
      'otherimages': otherimages,
      'isAutoMode': isAutoMode,
    };
  }

  /// Get the appropriate icon URL based on test status
  /// Returns passIcon for pass, failIcon for fail/skip/pending
  String getIconForStatus(bool isPassed) {
    return isPassed ? passIcon : failIcon;
  }
}
