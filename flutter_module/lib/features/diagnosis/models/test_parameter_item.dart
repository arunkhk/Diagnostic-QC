/// Model for a single test parameter from the API
class TestParameterItem {
  final int diagnoseParamID;
  final String paramValue;
  final int paramTypeID;
  final int displayOrder;
  final String catIcon;
  final int subscriptionID;
  final String uniqueTestKey; 

  TestParameterItem({
    required this.diagnoseParamID,
    required this.paramValue,
    required this.paramTypeID,
    required this.displayOrder,
    required this.catIcon,
    required this.subscriptionID,
    required this.uniqueTestKey,
  });

  factory TestParameterItem.fromJson(Map<String, dynamic> json) {
    final paramValue = json['paramValue'] as String;
    final uniqueTestKey = json['uniqueTestKey'] as String;
    
    if (uniqueTestKey.isEmpty) {
      throw ArgumentError('uniqueTestKey is required and cannot be empty for paramValue: $paramValue');
    }
    
    return TestParameterItem(
      diagnoseParamID: json['diagnoseParamID'] as int,
      paramValue: paramValue,
      paramTypeID: json['paramTypeID'] as int,
      displayOrder: json['displayOrder'] as int,
      catIcon: json['catIcon'] as String,
      subscriptionID: json['subscriptionID'] as int,
      uniqueTestKey: uniqueTestKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'diagnoseParamID': diagnoseParamID,
      'paramValue': paramValue,
      'paramTypeID': paramTypeID,
      'displayOrder': displayOrder,
      'catIcon': catIcon,
      'subscriptionID': subscriptionID,
      'uniqueTestKey': uniqueTestKey,
    };
  }

  /// Get display name for this test parameter
  /// Uses paramValue from API directly (e.g., "Wifi", "Bluetooth")
  String get displayName => paramValue;
}

