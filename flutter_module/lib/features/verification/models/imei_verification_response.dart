/// IMEI verification response model
class ImeiVerificationResponse {
  final String message;
  final String brandName;
  final String modelName;
  final int brandId;
  final int modelId;
  final int diagnosisSummarMasterId;
  final String? infoMessage;
  final String? type;

  ImeiVerificationResponse({
    required this.message,
    required this.brandName,
    required this.modelName,
    required this.brandId,
    required this.modelId,
    required this.diagnosisSummarMasterId,
    this.infoMessage,
    this.type,
  });

  factory ImeiVerificationResponse.fromJson(Map<String, dynamic> json) {
    return ImeiVerificationResponse(
      message: json['message'] as String? ?? '',
      brandName: json['brandName'] as String? ?? '',
      modelName: json['modelName'] as String? ?? '',
      brandId: json['brandId'] as int? ?? 0,
      modelId: json['modelId'] as int? ?? 0,
      diagnosisSummarMasterId: json['diagnosisSummarMasterId'] as int? ?? 0,
      infoMessage: json['infoMessage'] as String?,
      type: json['type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'brandName': brandName,
      'modelName': modelName,
      'brandId': brandId,
      'modelId': modelId,
      'diagnosisSummarMasterId': diagnosisSummarMasterId,
      'infoMessage': infoMessage,
      'type': type,
    };
  }
}

