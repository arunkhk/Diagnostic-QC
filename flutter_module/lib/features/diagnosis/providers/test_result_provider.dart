import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/test_result.dart';

/// Provider for managing test results
/// Uses a Set to prevent duplicate test entries
final testResultProvider = StateNotifierProvider<TestResultNotifier, Set<TestResult>>((ref) {
  return TestResultNotifier();
});

class TestResultNotifier extends StateNotifier<Set<TestResult>> {
  TestResultNotifier() : super({});

  /// Add or update a test result (no duplicates - same testId will update existing)
  void addOrUpdateResult(TestResult result) {
    final updatedSet = Set<TestResult>.from(state);
    // Remove existing result with same testId if present
    updatedSet.removeWhere((r) => r.testId == result.testId);
    // Add new result
    updatedSet.add(result);
    state = updatedSet;
  }

  /// Update test status by testId
  void updateTestStatus(String testId, TestStatus status) {
    final updatedSet = state.map((result) {
      if (result.testId == testId) {
        return result.copyWith(status: status, timestamp: DateTime.now());
      }
      return result;
    }).toSet();
    state = updatedSet;
  }

  /// Get result for a specific test
  /// Returns null if test result not found (instead of creating a default one)
  /// This ensures testName and icon always come from API via TestResultHelper
  TestResult? getResult(String testId) {
    try {
      return state.firstWhere(
        (result) => result.testId == testId,
      );
    } catch (e) {
      // Test result not found - return null
      // Callers should use TestResultHelper to create results with API data
      return null;
    }
  }

  /// Get all test results
  Set<TestResult> getAllResults() {
    return state;
  }

  /// Calculate health score as "passedCount/totalTests" format (e.g., "4/32")
  /// totalTests should be provided from testParametersProvider (number of tests from API)
  String calculateHealthScore(int totalTests) {
    final passedCount = getPassedCount();
    return '$passedCount/$totalTests';
  }
  /// Get count of pending/skipped tests
  int getPendingCount() {
    return state.where((r) => r.status == TestStatus.pending || r.status == TestStatus.skip).length;
  }

  /// Get count of failed tests
  int getFailedCount() {
    return state.where((r) => r.status == TestStatus.fail).length;
  }

  /// Get count of passed tests
  int getPassedCount() {
    return state.where((r) => r.status == TestStatus.pass).length;
  }

  /// Get count of NA (not applicable) tests
  int getNaCount() {
    return state.where((r) => r.status == TestStatus.na).length;
  }

  /// Clear all results
  void clearAll() {
    state = {};
  }
}

