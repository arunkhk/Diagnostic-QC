/// Login request model
class LoginRequest {
  final String username;
  final String password;
  final int orgId;
  final int officeId;

  LoginRequest({
    required this.username,
    required this.password,
    required this.orgId,
    required this.officeId,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'orgId': orgId,
      'officeId': officeId,
    };
  }
}

