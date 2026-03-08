/// Diagnosis detail model for DiagnosisDetails array
class DiagnosisDetail {
  final int diagnosisSummaryID;
  final String testParameter;
  final String testParameterID;
  final String diagnosedResult;
  final String diagnosedReason;
  final int createdBy;

  DiagnosisDetail({
    required this.diagnosisSummaryID,
    required this.testParameter,
    required this.testParameterID,
    required this.diagnosedResult,
    required this.diagnosedReason,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'DiagnosisSummaryID': diagnosisSummaryID,
      'TestParameter': testParameter,
      'TestParameterID': testParameterID,
      'DiagnosedResult': diagnosedResult,
      'DiagnosedReason': diagnosedReason,
      'CreatedBy': createdBy,
    };
  }
}

/// Final diagnosis request model
class FinalDiagnosisRequest {
  final int diagnosisSummaryID;
  final int brandID;
  final int modelID;
  final String brandName;
  final String modelName;
  final String overallRemarksStatus;
  final String failureRemarks;
  final String finalStatusRemarks;
  final String devicePhysicalCondition;
  final String displayfault;
  final String displayDetails;
  final int createdBy;
  final List<DiagnosisDetail> diagnosisDetails;
  final String diagnoseEngine;
  final String? feedback;

  FinalDiagnosisRequest({
    required this.diagnosisSummaryID,
    required this.brandID,
    required this.modelID,
    required this.brandName,
    required this.modelName,
    required this.overallRemarksStatus,
    required this.failureRemarks,
    required this.finalStatusRemarks,
    required this.devicePhysicalCondition,
    required this.displayfault,
    required this.displayDetails,
    required this.createdBy,
    required this.diagnosisDetails,
    required this.diagnoseEngine,
    this.feedback,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'DiagnosisSummaryID': diagnosisSummaryID,
      'BrandID': brandID,
      'ModelID': modelID,
      'BrandName': brandName,
      'ModelName': modelName,
      'OverallRemarksStatus': overallRemarksStatus,
      'FailureRemarks': failureRemarks,
      'FinalStatusRemarks': finalStatusRemarks,
      'DevicePhysicalCondition': devicePhysicalCondition,
      'Displayfault': displayfault,
      'DisplayDetails': displayDetails,
      'CreatedBy': createdBy,
      'DiagnosisDetails': diagnosisDetails.map((detail) => detail.toJson()).toList(),
      'DiagnoseEngine': diagnoseEngine,
    };
    
    // Add feedback - always include the key, use empty string if not provided
    json['Feedback'] = feedback != null && feedback!.trim().isNotEmpty 
        ? feedback!.trim() 
        : '';
    
    return json;
  }
}

