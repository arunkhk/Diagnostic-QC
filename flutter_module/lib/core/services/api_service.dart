import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/api_response.dart';
import '../utils/api_logger.dart';
import '../providers/api_loading_provider.dart';

/// Centralized API service for making HTTP requests
class ApiService {
  static const String baseUrl = 'https://casaabuelagoa.com/api';
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  String? _authToken;



  /// Set authentication token for subsequent API calls
  void setAuthToken(String? token) {
    _authToken = token;
  }

  /// Get current authentication token
  String? get authToken => _authToken;

  /// Notify loading state start
  void _notifyLoadingStart() {
    final notifier = getGlobalApiLoadingNotifier();
    if (notifier != null) {
      notifier.startRequest();
    }
  }

  /// Notify loading state end
  void _notifyLoadingEnd() {
    final notifier = getGlobalApiLoadingNotifier();
    if (notifier != null) {
      notifier.endRequest();
    }
  }

  /// Make a GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final url = '$baseUrl$endpoint';
    _notifyLoadingStart();
    try {
      final uri = Uri.parse(url);
      final requestHeaders = _buildHeaders(headers);

      // Log request
      ApiLogger.logRequest(
        method: 'GET',
        url: url,
        headers: requestHeaders,
      );

      final response = await http.get(uri, headers: requestHeaders);

      // Log response
      _logResponse('GET', url, response);

      final result = _handleResponse<T>(response, fromJson: fromJson);
      _notifyLoadingEnd();
      return result;
    } catch (e) {
      _notifyLoadingEnd();
      ApiLogger.logError(
        method: 'GET',
        url: url,
        error: 'Network error',
        exception: e,
      );
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Make a POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    dynamic body, // Changed to dynamic to support both Map and List
    Map<String, String>? headers,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final url = '$baseUrl$endpoint';
    _notifyLoadingStart();
    try {
      final uri = Uri.parse(url);
      final requestHeaders = _buildHeaders(headers);

      // Log request
      ApiLogger.logRequest(
        method: 'POST',
        url: url,
        body: body,
        headers: requestHeaders,
      );

      final response = await http.post(
        uri,
        headers: requestHeaders,
        body: body != null ? jsonEncode(body) : null,
      );

      // Log response
      _logResponse('POST', url, response);

      final result = _handleResponse<T>(response, fromJson: fromJson);
      _notifyLoadingEnd();
      return result;
    } catch (e) {
      _notifyLoadingEnd();
      ApiLogger.logError(
        method: 'POST',
        url: url,
        error: 'Network error',
        exception: e,
      );
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Make a PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final url = '$baseUrl$endpoint';
    _notifyLoadingStart();
    try {
      final uri = Uri.parse(url);
      final requestHeaders = _buildHeaders(headers);

      // Log request
      ApiLogger.logRequest(
        method: 'PUT',
        url: url,
        body: body,
        headers: requestHeaders,
      );

      final response = await http.put(
        uri,
        headers: requestHeaders,
        body: body != null ? jsonEncode(body) : null,
      );

      // Log response
      _logResponse('PUT', url, response);

      final result = _handleResponse<T>(response, fromJson: fromJson);
      _notifyLoadingEnd();
      return result;
    } catch (e) {
      _notifyLoadingEnd();
      ApiLogger.logError(
        method: 'PUT',
        url: url,
        error: 'Network error',
        exception: e,
      );
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Make a DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, String>? headers,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    final url = '$baseUrl$endpoint';
    _notifyLoadingStart();
    try {
      final uri = Uri.parse(url);
      final requestHeaders = _buildHeaders(headers);

      // Log request
      ApiLogger.logRequest(
        method: 'DELETE',
        url: url,
        headers: requestHeaders,
      );

      final response = await http.delete(uri, headers: requestHeaders);

      // Log response
      _logResponse('DELETE', url, response);

      final result = _handleResponse<T>(response, fromJson: fromJson);
      _notifyLoadingEnd();
      return result;
    } catch (e) {
      _notifyLoadingEnd();
      ApiLogger.logError(
        method: 'DELETE',
        url: url,
        error: 'Network error',
        exception: e,
      );
      return ApiResponse.error('Network error: $e');
    }
  }

  /// Build headers with authentication token
  Map<String, String> _buildHeaders(Map<String, String>? customHeaders) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add auth token if available
    if (_authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    // Merge custom headers
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  /// Log HTTP response
  void _logResponse(String method, String url, http.Response response) {
    debugPrint('🔍 _logResponse called for $method $url');
    try {
      Map<String, dynamic>? bodyJson;
      String? rawBody;

      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          // Handle both Map and other JSON types
          if (decoded is Map<String, dynamic>) {
            bodyJson = decoded;
            debugPrint('🔍 Response parsed as Map with ${bodyJson.length} keys');
          } else {
            // If it's a List or other type, convert to string for logging
            rawBody = const JsonEncoder.withIndent('  ').convert(decoded);
            debugPrint('🔍 Response parsed as non-Map type, using rawBody');
          }
        } catch (e) {
          // If JSON parsing fails, use raw body
          rawBody = response.body;
          debugPrint('🔍 JSON parsing failed, using raw body: $e');
        }
      } else {
        rawBody = '[Empty Response Body]';
        debugPrint('🔍 Response body is empty');
      }

      debugPrint('🔍 Calling ApiLogger.logResponse...');
      ApiLogger.logResponse(
        method: method,
        url: url,
        statusCode: response.statusCode,
        body: bodyJson,
        rawBody: rawBody,
      );
      debugPrint('🔍 ApiLogger.logResponse completed');
    } catch (e, stackTrace) {
      // If logging fails, still try to log basic info
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📥 API RESPONSE (Logging Error)');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Method: $method');
      debugPrint('URL: $url');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Error logging response: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Response Body Length: ${response.body.length}');
      if (response.body.isNotEmpty && response.body.length < 500) {
        debugPrint('Response Body: ${response.body}');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }

  /// Handle HTTP response
  ApiResponse<T> _handleResponse<T>(
    http.Response response, {
    T Function(Map<String, dynamic>)? fromJson,
  }) {
    final statusCode = response.statusCode;

    try {
      if (statusCode >= 200 && statusCode < 300) {
        // Success
        if (response.body.isEmpty) {
          return ApiResponse.success(null as T, statusCode: statusCode);
        }

        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;

        if (fromJson != null) {
          final data = fromJson(jsonData);
          return ApiResponse.success(data, statusCode: statusCode);
        } else {
          return ApiResponse.success(jsonData as T, statusCode: statusCode);
        }
      } else if (statusCode == 401) {
        // Unauthorized - try to extract actual error message from response
        String errorMessage = 'Invalid username or password';
        try {
          // Try to parse JSON response
          if (response.body.isNotEmpty) {
            try {
              final jsonData = jsonDecode(response.body);
              if (jsonData is Map<String, dynamic>) {
                errorMessage = jsonData['message'] as String? ?? 
                              jsonData['errorMessage'] as String? ?? 
                              errorMessage;
              } else if (jsonData is String) {
                // If response is a plain string (like "Your account has been deactivated...")
                errorMessage = jsonData;
              }
            } catch (e) {
              // If JSON parsing fails, use response body as-is (might be plain string)
              errorMessage = response.body.trim();
            }
          }
        } catch (e) {
          // Fallback to default message
          errorMessage = 'Invalid username or password';
        }
        
        return ApiResponse.error(
          errorMessage,
          statusCode: statusCode,
        );
      } else {

        // Other errors
        String errorMessage = 'Request failed';
        try {
          final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = jsonData['message'] as String? ?? 
                        jsonData['errorMessage'] as String? ?? 
                        errorMessage;
        } catch (e) {
          errorMessage = response.body.isNotEmpty 
              ? response.body 
              : 'Request failed with status $statusCode';
        }

        return ApiResponse.error(errorMessage, statusCode: statusCode);
      }
    } catch (e) {
      return ApiResponse.error('Failed to parse response: $e', statusCode: statusCode);
    }
  }
}

