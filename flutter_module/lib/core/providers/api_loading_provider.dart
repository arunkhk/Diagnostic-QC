import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global API loading state provider
/// Automatically tracks when any API call is in progress
class ApiLoadingState {
  final bool isLoading;
  final int activeRequests;

  ApiLoadingState({
    this.isLoading = false,
    this.activeRequests = 0,
  });

  ApiLoadingState copyWith({
    bool? isLoading,
    int? activeRequests,
  }) {
    return ApiLoadingState(
      isLoading: isLoading ?? (activeRequests != null && activeRequests > 0),
      activeRequests: activeRequests ?? this.activeRequests,
    );
  }
}

/// API loading state notifier
class ApiLoadingNotifier extends StateNotifier<ApiLoadingState> {
  ApiLoadingNotifier() : super(ApiLoadingState());

  /// Increment active requests (call when API request starts)
  void startRequest() {
    state = state.copyWith(activeRequests: state.activeRequests + 1);
  }

  /// Decrement active requests (call when API request completes)
  void endRequest() {
    final newCount = (state.activeRequests - 1).clamp(0, double.infinity).toInt();
    state = state.copyWith(activeRequests: newCount);
  }

  /// Reset loading state
  void reset() {
    state = ApiLoadingState();
  }
}

/// Global API loading provider
final apiLoadingProvider = StateNotifierProvider<ApiLoadingNotifier, ApiLoadingState>((ref) {
  return ApiLoadingNotifier();
});

/// Global reference to the API loading notifier (for use in ApiService)
ApiLoadingNotifier? _globalApiLoadingNotifier;

/// Set the global API loading notifier (called from main app)
void setGlobalApiLoadingNotifier(ApiLoadingNotifier notifier) {
  _globalApiLoadingNotifier = notifier;
}

/// Get the global API loading notifier
ApiLoadingNotifier? getGlobalApiLoadingNotifier() {
  return _globalApiLoadingNotifier;
}

