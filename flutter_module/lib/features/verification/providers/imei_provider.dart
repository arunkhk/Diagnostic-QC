import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/imei_verification_response.dart';

/// IMEI verification state model
class ImeiVerificationState {
  final ImeiVerificationResponse? response;
  final String? imei;
  final bool isLoading;
  final String? errorMessage;

  ImeiVerificationState({
    this.response,
    this.imei,
    this.isLoading = false,
    this.errorMessage,
  });

  ImeiVerificationState copyWith({
    ImeiVerificationResponse? response,
    String? imei,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ImeiVerificationState(
      response: response ?? this.response,
      imei: imei ?? this.imei,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Clear IMEI verification state
  ImeiVerificationState clear() {
    return ImeiVerificationState(
      isLoading: false,
    );
  }
}

/// IMEI verification state notifier
class ImeiVerificationNotifier extends StateNotifier<ImeiVerificationState> {
  ImeiVerificationNotifier() : super(ImeiVerificationState());

  /// Save IMEI verification response
  void saveResponse(ImeiVerificationResponse response, String imei) {
    state = state.copyWith(
      response: response,
      imei: imei,
      errorMessage: null,
    );
  }

  /// Clear IMEI verification state
  void clear() {
    state = state.clear();
  }

  /// Get current response
  ImeiVerificationResponse? get currentResponse => state.response;

  /// Get current IMEI
  String? get currentImei => state.imei;

  /// Get diagnosis summary master ID
  int? get diagnosisSummaryMasterId => state.response?.diagnosisSummarMasterId;
}

/// IMEI verification provider
final imeiVerificationProvider =
    StateNotifierProvider<ImeiVerificationNotifier, ImeiVerificationState>((ref) {
  return ImeiVerificationNotifier();
});

