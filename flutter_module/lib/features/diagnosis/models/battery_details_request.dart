/// Battery details request model for API
class BatteryDetailsRequest {
  final int diagnosisSummaryID;
  final String batteryType;
  final String testResult;
  final String batteryHealth;
  final String voltage;
  final String chargingLevel;
  final String temperature;
  final String scale;
  final String remarks;
  final String createdBy;

  BatteryDetailsRequest({
    required this.diagnosisSummaryID,
    required this.batteryType,
    required this.testResult,
    required this.batteryHealth,
    required this.voltage,
    required this.chargingLevel,
    required this.temperature,
    required this.scale,
    required this.remarks,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'diagnosisSummaryID': diagnosisSummaryID,
      'batteryType': batteryType,
      'testResult': testResult,
      'batteryHealth': batteryHealth,
      'voltage': voltage,
      'chargingLevel': chargingLevel,
      'temperature': temperature,
      'scale': scale,
      'remarks': remarks,
      'createdBy': createdBy,
    };
  }
}

