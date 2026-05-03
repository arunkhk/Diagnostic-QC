import 'dart:convert';
import 'package:flutter/foundation.dart';

/// API Logger utility for logging requests and responses
/// Can be enabled/disabled via flag
class ApiLogger {
  ApiLogger._();

  /// Flag to enable/disable API logging
  /// Set to true to see API logs, false to disable
  static const bool enabled = true; // Change to false to disable logging

  /// Log API request
  static void logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) {
    if (!enabled) return;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📤 API REQUEST');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Method: $method');
    debugPrint('URL: $url');
    
    if (headers != null && headers.isNotEmpty) {
      debugPrint('Headers:');
      headers.forEach((key, value) {
        // Mask authorization token for security
        if (key.toLowerCase() == 'authorization') {
          final masked = value.length > 20 
              ? '${value.substring(0, 20)}...' 
              : '***';
          debugPrint('  $key: $masked');
        } else {
          debugPrint('  $key: $value');
        }
      });
    }
    
    if (body != null && body.isNotEmpty) {
      debugPrint('Body:');
      try {
        final jsonString = const JsonEncoder.withIndent('  ').convert(body);
        debugPrint(jsonString);
      } catch (e) {
        debugPrint('  $body');
      }
    }
    
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  /// Log API response
  static void logResponse({
    required String method,
    required String url,
    required int statusCode,
    Map<String, dynamic>? body,
    String? rawBody,
    String? error,
  }) {
    if (!enabled) return;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📥 API RESPONSE');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Method: $method');
    debugPrint('URL: $url');
    debugPrint('Status Code: $statusCode');
    
    if (error != null) {
      debugPrint('Error: $error');
    } else if (body != null && body.isNotEmpty) {
      debugPrint('Response Body:');
      try {
        final jsonString = const JsonEncoder.withIndent('  ').convert(body);
        debugPrint(jsonString);
      } catch (e) {
        debugPrint('  $body');
      }
    } else if (rawBody != null && rawBody.isNotEmpty) {
      debugPrint('Response Body (Raw):');
      debugPrint(rawBody);
    } else {
      debugPrint('Response Body: [Empty]');
    }
    
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint(''); // Empty line for readability
  }

  /// Log API error
  static void logError({
    required String method,
    required String url,
    required String error,
    dynamic exception,
  }) {
    if (!enabled) return;

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('❌ API ERROR');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('Method: $method');
    debugPrint('URL: $url');
    debugPrint('Error: $error');
    if (exception != null) {
      debugPrint('Exception: $exception');
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}

