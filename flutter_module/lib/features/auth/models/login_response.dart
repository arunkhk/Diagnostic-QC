/// Login response model
class LoginResponse {
  final String token;
  final UserData user;
  final String expiresAt;

  LoginResponse({
    required this.token,
    required this.user,
    required this.expiresAt,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String,
      user: UserData.fromJson(json['user'] as Map<String, dynamic>),
      expiresAt: json['expiresAt'] as String,
    );
  }
}

/// User data model
class UserData {
  final String errorMessage;
  final int userId;
  final String userName;
  final String email;
  final int roleId;
  final String role;
  final int orgId;
  final String orgName;
  final String guid;
  final int officeId;
  final String officeName;
  final int? subscriptionId;
  final String? planName;
  final String? qrCode;
  final String? fullName;
  final String? mobileNo;
  final String? passwordHash;
  final bool? isActive;
  final String? createdOn;
  final bool? isSuccess;

  UserData({
    required this.errorMessage,
    required this.userId,
    required this.userName,
    required this.email,
    required this.roleId,
    required this.role,
    required this.orgId,
    required this.orgName,
    required this.guid,
    required this.officeId,
    required this.officeName,
    this.subscriptionId,
    this.planName,
    this.qrCode,
    this.fullName,
    this.mobileNo,
    this.passwordHash,
    this.isActive,
    this.createdOn,
    this.isSuccess,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      errorMessage: json['errorMessage'] as String? ?? '',
      userId: json['userId'] as int,
      userName: json['userName'] as String,
      email: json['email'] as String,
      roleId: json['roleId'] as int,
      role: json['role'] as String,
      orgId: json['orgId'] as int,
      orgName: json['orgName'] as String,
      guid: json['guid'] as String,
      officeId: json['officeId'] as int,
      officeName: json['officeName'] as String,
      subscriptionId: json['subscriptionId'] as int?,
      planName: json['planName'] as String?,
      qrCode: json['qrCode'] as String?,
      fullName: json['fullName'] as String?,
      mobileNo: json['mobileNo'] as String?,
      passwordHash: json['passwordHash'] as String?,
      isActive: json['isActive'] as bool?,
      createdOn: json['createdOn'] as String?,
      isSuccess: json['isSuccess'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'errorMessage': errorMessage,
      'userId': userId,
      'userName': userName,
      'email': email,
      'roleId': roleId,
      'role': role,
      'orgId': orgId,
      'orgName': orgName,
      'guid': guid,
      'officeId': officeId,
      'officeName': officeName,
      if (subscriptionId != null) 'subscriptionId': subscriptionId,
      if (planName != null) 'planName': planName,
      if (qrCode != null) 'qrCode': qrCode,
      if (fullName != null) 'fullName': fullName,
      if (mobileNo != null) 'mobileNo': mobileNo,
      if (passwordHash != null) 'passwordHash': passwordHash,
      if (isActive != null) 'isActive': isActive,
      if (createdOn != null) 'createdOn': createdOn,
      if (isSuccess != null) 'isSuccess': isSuccess,
    };
  }
}

