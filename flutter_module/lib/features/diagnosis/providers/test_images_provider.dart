import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/test_image_item.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

/// State class to hold test images data and loading state
class TestImagesState {
  final List<TestImageItem> images;
  final bool isLoading;
  final bool hasLoaded;
  final String? errorMessage;

  const TestImagesState({
    this.images = const [],
    this.isLoading = false,
    this.hasLoaded = false,
    this.errorMessage,
  });

  TestImagesState copyWith({
    List<TestImageItem>? images,
    bool? isLoading,
    bool? hasLoaded,
    String? errorMessage,
  }) {
    return TestImagesState(
      images: images ?? this.images,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage: errorMessage,
    );
  }
}

/// StateNotifier to manage test images fetching and storage
class TestImagesNotifier extends StateNotifier<TestImagesState> {
  final Ref ref;

  TestImagesNotifier(this.ref) : super(const TestImagesState());

  /// Fetch test images from API
  /// Called during IMEI verification screen (on Continue click)
  /// API endpoint: GET /PhoneDiagnostics/GetTestImages?subscriptionId={id}
  Future<bool> fetchTestImages() async {
    // Don't refetch if already loaded successfully
    if (state.hasLoaded && state.images.isNotEmpty) {
      debugPrint('📸 Test images already loaded (${state.images.length} items), skipping fetch');
      return true;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // Get subscriptionId from auth provider
      final authState = ref.read(authProvider);
      final subscriptionId = authState.user?.subscriptionId ?? 3;

      final apiService = ApiService();
      final url = '${ApiService.baseUrl}/PhoneDiagnostics/GetTestImages?subscriptionId=$subscriptionId';
      final uri = Uri.parse(url);
      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      if (apiService.authToken != null) {
        headers['Authorization'] = 'Bearer ${apiService.authToken}';
      }

      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📸 Fetching test images from API: $url');
      debugPrint('═══════════════════════════════════════════════════════════');

      final response = await http.get(uri, headers: headers);

      debugPrint('📡 Test Images API Response Status: ${response.statusCode}');
      // Full API result (pretty-printed for debugging)
      try {
        final pretty = const JsonEncoder.withIndent('  ').convert(
          response.body.isNotEmpty ? jsonDecode(response.body) : <dynamic>[],
        );
        debugPrint('📸 GetTestImages API full result:\n$pretty');
      } catch (_) {
        debugPrint('📸 GetTestImages API raw body: ${response.body}');
      }
      debugPrint('═══════════════════════════════════════════════════════════');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonData = jsonDecode(response.body);

        if (jsonData is List) {
          final images = jsonData
              .map((item) {
                try {
                  return TestImageItem.fromJson(item as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('❌ Failed to parse test image item: $e');
                  return null;
                }
              })
              .whereType<TestImageItem>()
              .toList();

          debugPrint('✅ Loaded ${images.length} test images from API');
          debugPrint('📸 Available screens: ${images.map((i) => i.screne).join(', ')}');

          state = state.copyWith(
            images: images,
            isLoading: false,
            hasLoaded: true,
          );
          return true;
        } else {
          debugPrint('❌ Unexpected API response format: ${jsonData.runtimeType}');
          state = state.copyWith(
            isLoading: false,
            hasLoaded: true,
            errorMessage: 'Unexpected API response format',
          );
          return false;
        }
      } else {
        debugPrint('❌ Test Images API returned error status: ${response.statusCode}');
        state = state.copyWith(
          isLoading: false,
          hasLoaded: true,
          errorMessage: 'API error: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error fetching test images: $e');
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        errorMessage: 'Error: $e',
      );
      return false;
    }
  }

  /// Get test image item by screen name (e.g., "wifi", "bluetooth")
  /// Returns null if not found
  TestImageItem? getImageForScreen(String screenName) {
    final normalizedScreenName = screenName.toLowerCase();
    try {
      return state.images.firstWhere(
        (image) => image.screne.toLowerCase() == normalizedScreenName,
      );
    } catch (e) {
      // Not found
      return null;
    }
  }

  /// Get pass icon URL for a screen
  /// Returns null if not found or API not loaded
  String? getPassIconUrl(String screenName) {
    final image = getImageForScreen(screenName);
    if (image != null && image.passIcon.isNotEmpty) {
      return image.passIcon;
    }
    return null;
  }

  /// Get fail icon URL for a screen
  /// Returns null if not found or API not loaded
  String? getFailIconUrl(String screenName) {
    final image = getImageForScreen(screenName);
    if (image != null && image.failIcon.isNotEmpty) {
      return image.failIcon;
    }
    return null;
  }

  /// Get other images list for a screen (e.g., scanning animations)
  /// Returns empty list if not found
  List<String> getOtherImages(String screenName) {
    final image = getImageForScreen(screenName);
    return image?.otherimages ?? [];
  }

  /// Whether auto mode is enabled for this screen (hide Start Test, auto-start after delay)
  /// Returns false if not found or API not loaded
  bool getIsAutoMode(String screenName) {
    final image = getImageForScreen(screenName);
    return image?.isAutoMode ?? false;
  }

  /// Get icon URL based on screen name and test status
  /// isPassed: true for pass, false for fail/skip/pending
  /// Returns null if not found
  String? getIconUrl(String screenName, {required bool isPassed}) {
    final image = getImageForScreen(screenName);
    if (image == null) {
      debugPrint('⚠️ getIconUrl: No image found for screen "$screenName"');
      return null;
    }
    
    final url = isPassed ? image.passIcon : image.failIcon;
    debugPrint('🔍 getIconUrl: screen="$screenName", isPassed=$isPassed');
    debugPrint('   passIcon: ${image.passIcon}');
    debugPrint('   failIcon: ${image.failIcon}');
    debugPrint('   returning: $url');
    
    return url;
  }

  /// Reset state (useful for logout or refresh)
  void reset() {
    state = const TestImagesState();
  }
}

/// Provider for test images
final testImagesProvider =
    StateNotifierProvider<TestImagesNotifier, TestImagesState>((ref) {
  return TestImagesNotifier(ref);
});

/// Convenience provider to check if test images are loaded
final testImagesLoadedProvider = Provider<bool>((ref) {
  final state = ref.watch(testImagesProvider);
  return state.hasLoaded && state.images.isNotEmpty;
});
