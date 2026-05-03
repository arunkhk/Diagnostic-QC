import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/login_response.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/api_response.dart';

/// Authentication state model
class AuthState {
  final String? token;
  final UserData? user;
  final String? expiresAt;
  final bool isAuthenticated;
  final bool isLoading;
  final String? errorMessage;

  AuthState({
    this.token,
    this.user,
    this.expiresAt,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    String? token,
    UserData? user,
    String? expiresAt,
    bool? isAuthenticated,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      token: token ?? this.token,
      user: user ?? this.user,
      expiresAt: expiresAt ?? this.expiresAt,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Clear authentication state
  AuthState clear() {
    return AuthState(
      isAuthenticated: false,
      isLoading: false,
    );
  }
}

/// Auth state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    // Load saved auth asynchronously
    _loadSavedAuth();
  }

  /// Load saved authentication from SharedPreferences
  Future<void> _loadSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final userJson = prefs.getString('auth_user');
      final expiresAt = prefs.getString('auth_expires_at');

      if (token != null && userJson != null) {
        final userMap = jsonDecode(userJson) as Map<String, dynamic>;
        final user = UserData.fromJson(userMap);
        
        // Restore token in API service
        ApiService().setAuthToken(token);

        // Update state
        state = state.copyWith(
          token: token,
          user: user,
          expiresAt: expiresAt,
          isAuthenticated: true,
        );
      }
    } catch (e) {
      // If loading fails, clear saved data
      await _clearSavedAuth();
    }
  }

  /// Save authentication to SharedPreferences
  Future<void> _saveAuth({
    required String token,
    required UserData user,
    required String expiresAt,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('auth_user', jsonEncode(user.toJson()));
      await prefs.setString('auth_expires_at', expiresAt);
      await prefs.setBool('is_authenticated', true);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Clear saved authentication from SharedPreferences
  Future<void> _clearSavedAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_user');
      await prefs.remove('auth_expires_at');
      await prefs.remove('is_authenticated');
    } catch (e) {
      // Handle error silently
    }
  }

  /// Login user
  Future<ApiResponse<LoginResponse>> login({
    required String username,
    required String password,
    required int orgId,
    required int officeId,
  }) async {
    state = state.copyWith(errorMessage: null);

    try {
      final apiService = ApiService();
      final response = await apiService.post<LoginResponse>(
        '/UserAuth/login',
        body: {
          'username': username,
          'password': password,
          'orgId': orgId,
          'officeId': officeId,
        },
        fromJson: (json) => LoginResponse.fromJson(json),
      );

      if (response.success && response.data != null) {
        // Store token in API service for future requests
        apiService.setAuthToken(response.data!.token);

        // Save to persistent storage
        await _saveAuth(
          token: response.data!.token,
          user: response.data!.user,
          expiresAt: response.data!.expiresAt,
        );

        // Update state
        state = state.copyWith(
          token: response.data!.token,
          user: response.data!.user,
          expiresAt: response.data!.expiresAt,
          isAuthenticated: true,
          errorMessage: null,
        );

        return response;
      } else {
        state = state.copyWith(
          errorMessage: response.errorMessage ?? 'Login failed',
        );
        return response;
      }
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Login error: $e',
      );
      return ApiResponse.error('Login error: $e');
    }
  }

  /// Logout user
  Future<void> logout() async {
    ApiService().setAuthToken(null);
    await _clearSavedAuth();
    state = state.clear();
  }

  /// Get current user
  UserData? get currentUser => state.user;

  /// Get auth token
  String? get token => state.token;
}

/// Auth provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

