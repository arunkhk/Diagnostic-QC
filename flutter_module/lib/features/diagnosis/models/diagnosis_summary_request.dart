/// Diagnosis summary test parameter model
class DiagnosisSummaryTestParam {
  final int testParameterID;
  final String testParameter;
  final int diagnosisSummaryID;
  final String diagnosedResult; // "Pass", "Fail", or "Skipped"
  final String diagnosedReason;
  final int createdBy;

  DiagnosisSummaryTestParam({
    required this.testParameterID,
    required this.testParameter,
    required this.diagnosisSummaryID,
    required this.diagnosedResult,
    required this.diagnosedReason,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'TestParameterID': testParameterID,
      'TestParameter': testParameter,
      'DiagnosisSummaryID': diagnosisSummaryID,
      'DiagnosedResult': diagnosedResult,
      'DiagnosedReason': diagnosedReason,
      'CreatedBy': createdBy,
    };
  }
}

