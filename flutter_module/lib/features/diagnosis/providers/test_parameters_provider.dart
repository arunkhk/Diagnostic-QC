import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/test_parameter_item.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Flag to track if fallback to local JSON was used (for toast notification)
bool _shouldShowFallbackToast = false;

/// Get and reset the fallback toast flag
bool getAndResetFallbackToastFlag() {
  final shouldShow = _shouldShowFallbackToast;
  _shouldShowFallbackToast = false;
  return shouldShow;
}

/// Provider to fetch and store test parameters from REAL API
/// This provider automatically updates when subscriptionId changes (watches auth provider)
/// API endpoint: GET /Category/GettestParameters?OSType={android|ios}&subscriptionId={id}
/// Response format: List of test parameter objects (same structure as mock_test_parameters.json)
final testParametersProvider = FutureProvider<List<TestParameterItem>>((ref) async {
  // Real API implementation
  final apiService = ApiService();
  
  // Determine OS type
  final osType = Platform.isAndroid ? 'android' : 'ios';
  
  // Watch auth provider to automatically update when subscriptionId changes
  final authState = ref.watch(authProvider);
  final subscriptionId = authState.user?.subscriptionId ?? 3;
  
  debugPrint('═══════════════════════════════════════════════════════════');
  debugPrint('📌 Subscription ID Debug:');
  debugPrint('   Auth State - isAuthenticated: ${authState.isAuthenticated}');
  debugPrint('   User: ${authState.user != null ? "✅ Present" : "❌ Null"}');
  if (authState.user != null) {
    debugPrint('   User ID: ${authState.user!.userId}');
    debugPrint('   Subscription ID from user: ${authState.user!.subscriptionId}');
  }
  debugPrint('   Final subscriptionId being used: $subscriptionId');
  debugPrint('═══════════════════════════════════════════════════════════');
  try {
    // API returns a List directly, so we need to handle it with http directly
    final url = '${ApiService.baseUrl}/Category/GettestParameters?OSType=$osType&subscriptionId=$subscriptionId';
    final uri = Uri.parse(url);
    
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    
    if (apiService.authToken != null) {
      headers['Authorization'] = 'Bearer ${apiService.authToken}';
    }
    
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🌐 Calling REAL API: $url');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    final response = await http.get(uri, headers: headers);
    
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📡 API Response Status: ${response.statusCode}');
    debugPrint('📄 Full API Response Body:');
    
    // Print formatted JSON in chunks to avoid Flutter's debugPrint character limit (~1000 chars per line)
    try {
      final formattedJson = const JsonEncoder.withIndent('  ').convert(jsonDecode(response.body));
      // Split into chunks of 800 characters to ensure full output
      const chunkSize = 800;
      for (int i = 0; i < formattedJson.length; i += chunkSize) {
        final end = (i + chunkSize < formattedJson.length) ? i + chunkSize : formattedJson.length;
        debugPrint(formattedJson.substring(i, end));
      }
    } catch (e) {
      // If JSON parsing fails, print raw response in chunks
      const chunkSize = 800;
      final body = response.body;
      for (int i = 0; i < body.length; i += chunkSize) {
        final end = (i + chunkSize < body.length) ? i + chunkSize : body.length;
        debugPrint(body.substring(i, end));
      }
    }
    debugPrint('═══════════════════════════════════════════════════════════');
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Parse real API response
      final jsonData = jsonDecode(response.body);
      // API response can be either a List directly or a Map with 'data' key containing a List
      List<dynamic> items;
      if (jsonData is List) {
        // Response is a List directly
        items = jsonData;
      } else if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
        // Response is a Map with 'data' key
        items = jsonData['data'] as List<dynamic>;
      } else {
        debugPrint('❌ Unexpected API response format: ${jsonData.runtimeType}');
        // Fallback to local JSON file
        return _loadFromLocalJson();
      }
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🌐 REAL API Response received');
      debugPrint('📦 API response contains ${items.length} items');
      debugPrint('═══════════════════════════════════════════════════════════');
      // Parse items from API response
      // Each item should have: diagnoseParamID, paramValue, paramTypeID, displayOrder, catIcon, subscriptionID, uniqueTestKey
      final testParameters = items
          .map((item) {
            try {
              final parsed = TestParameterItem.fromJson(item as Map<String, dynamic>);
              debugPrint('✅ Parsed: ${parsed.paramValue} (order: ${parsed.displayOrder}, key: ${parsed.uniqueTestKey})');
              return parsed;
            } catch (e) {
              debugPrint('❌ Failed to parse item: $e');
              debugPrint('   Item data: $item');
              return null;
            }
          })
          .whereType<TestParameterItem>()
          .toList();
      
      // Sort by displayOrder to ensure correct sequence
      testParameters.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      
      debugPrint('═══════════════════════════════════════════════════════════');
      if (testParameters.isEmpty) {
        debugPrint('⚠️ WARNING: API returned ${items.length} items but parsed to 0 test parameters');
        debugPrint('   Falling back to local JSON file...');
        // Fallback to local JSON file
        return _loadFromLocalJson();
      } else {
        debugPrint('✅ Loaded ${testParameters.length} tests from REAL API');
        debugPrint('🔍 Test order: ${testParameters.map((p) => '${p.paramValue}(${p.displayOrder})').join(' → ')}');
      }
      debugPrint('═══════════════════════════════════════════════════════════');
      return testParameters;

    } else {
      debugPrint('❌ API returned error status: ${response.statusCode}');
      debugPrint('   Response: ${response.body}');
      debugPrint('   Falling back to local JSON file...');
      // Fallback to local JSON file
      return _loadFromLocalJson();
    }
  } catch (e) {
    debugPrint('❌ Error calling real API: $e');
    debugPrint('   Falling back to local JSON file...');
    // Fallback to local JSON file
    return _loadFromLocalJson();
  }
});

/// Helper function to load test parameters from local JSON file (fallback)
Future<List<TestParameterItem>> _loadFromLocalJson() async {
  try {
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📁 Loading test parameters from local JSON file (fallback)');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    final configJsonString = await rootBundle.loadString(
      'lib/features/diagnosis/data/mock_test_parameters.json',
    );
    final jsonData = jsonDecode(configJsonString);
    
    // Handle both List and Map formats
    List<dynamic> items;
    if (jsonData is List) {
      items = jsonData;
    } else if (jsonData is Map<String, dynamic> && jsonData.containsKey('data')) {
      items = jsonData['data'] as List<dynamic>;
    } else {
      debugPrint('❌ Unexpected local JSON format: ${jsonData.runtimeType}');
      return [];
    }
    
    final testParameters = items
        .map((item) {
          try {
            final parsed = TestParameterItem.fromJson(item as Map<String, dynamic>);
            debugPrint('✅ Parsed from local: ${parsed.paramValue} (order: ${parsed.displayOrder}, key: ${parsed.uniqueTestKey})');
            return parsed;
          } catch (e) {
            debugPrint('❌ Failed to parse local item: $e');
            return null;
          }
        })
        .whereType<TestParameterItem>()
        .toList();
    
    // Sort by displayOrder
    testParameters.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    
    debugPrint('✅ Loaded ${testParameters.length} tests from local JSON file');
    debugPrint('🔍 Test order: ${testParameters.map((p) => '${p.paramValue}(${p.displayOrder})').join(' → ')}');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    // Set flag to show toast (will be handled by diagnosis_screen)
    _shouldShowFallbackToast = true;
    
    return testParameters;
  } catch (e) {
    debugPrint('❌ Error loading local JSON file: $e');
    return [];
  }
}

/// Provider to get sorted test parameters (sorted by displayOrder)
final sortedTestParametersProvider = Provider<List<TestParameterItem>>((ref) {
  final asyncValue = ref.watch(testParametersProvider);
  return asyncValue.when(
    data: (parameters) => parameters,
    loading: () => [],
    error: (_, _) => [],
  );
});
