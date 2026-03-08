/// Diagnosis parameters response model
class DiagnosisParametersResponse {
  final List<String> finalDiagnosisFailRemarks;
  final List<String> devicePhysicalCondition;
  final List<String> displayCondition;

  DiagnosisParametersResponse({
    required this.finalDiagnosisFailRemarks,
    required this.devicePhysicalCondition,
    required this.displayCondition,
  });

  factory DiagnosisParametersResponse.fromJson(Map<String, dynamic> json) {
    return DiagnosisParametersResponse(
      finalDiagnosisFailRemarks: (json['finalDiagnosisFailRemarks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      devicePhysicalCondition: (json['devicePhysicalCondition'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      displayCondition: (json['displayCondition'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'finalDiagnosisFailRemarks': finalDiagnosisFailRemarks,
      'devicePhysicalCondition': devicePhysicalCondition,
      'displayCondition': displayCondition,
    };
  }
}

