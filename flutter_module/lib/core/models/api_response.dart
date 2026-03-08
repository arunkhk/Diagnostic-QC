/// Generic API response wrapper
class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? errorMessage;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.errorMessage,
    this.statusCode,
  });

  factory ApiResponse.success(T data, {int? statusCode}) {
    return ApiResponse<T>(
      success: true,
      data: data,
      statusCode: statusCode ?? 200,
    );
  }

  factory ApiResponse.error(String errorMessage, {int? statusCode}) {
    return ApiResponse<T>(
      success: false,
      errorMessage: errorMessage,
      statusCode: statusCode,
    );
  }
}

