import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/test_result.dart';
import '../providers/test_result_provider.dart';
import '../models/test_parameter_item.dart';
import '../providers/test_parameters_provider.dart';

/// Centralized utility for managing test results
class TestResultHelper {
  /// Get TestParameterItem for a given testId from the provider
  /// Returns null if not found or provider is still loading
  /// Uses case-insensitive comparison to handle API variations
  static TestParameterItem? _getParameterFromProvider(
    WidgetRef ref,
    String testId,
  ) {
    final testParametersAsync = ref.read(testParametersProvider);
    if (testParametersAsync.hasValue) {
      final parameters = testParametersAsync.value!;
      try {
        // Try exact match first
        try {
          return parameters.firstWhere(
            (param) => param.uniqueTestKey == testId,
          );
        } catch (e) {
          // Fallback to case-insensitive match
          return parameters.firstWhere(
            (param) => param.uniqueTestKey.toLowerCase() == testId.toLowerCase(),
          );
        }
      } catch (e) {
        // Log available keys for debugging
        final availableKeys = parameters.map((p) => p.uniqueTestKey).toList();
        debugPrint('❌ TestParameterItem not found for testId: $testId');
        debugPrint('   Available uniqueTestKeys: ${availableKeys.join(", ")}');
        return null;
      }
    }
    return null;
  }

  /// Save a test result (pass, fail, or skip)
  /// Automatically gets testName (paramValue) and icon (catIcon) from API parameter
  static void saveTestResult(
    WidgetRef ref,
    String testId,
    TestStatus status,
  ) {
    // Get parameter from provider - API always provides paramValue and catIcon
    final parameter = _getParameterFromProvider(ref, testId);
    
    if (parameter == null) {
      // If parameter not found, throw error since API should always provide it
      throw StateError('TestParameterItem not found for testId: $testId. API should always provide paramValue and catIcon.');
    }
    
    ref.read(testResultProvider.notifier).addOrUpdateResult(
          TestResult(
            testId: testId,
            testName: parameter.paramValue, // From API
            icon: parameter.catIcon, // From API
            status: status,
            timestamp: DateTime.now(),
          ),
        );
  }

  /// Save test result from TestParameterItem (uses API data: testName and icon)
  /// This method directly uses the parameter's data instead of looking it up again
  static void saveTestResultFromParameter(
    WidgetRef ref,
    TestParameterItem parameter,
    TestStatus status,
  ) {
    // Use parameter data directly (paramValue and catIcon from API)
    ref.read(testResultProvider.notifier).addOrUpdateResult(
          TestResult(
            testId: parameter.uniqueTestKey,
            testName: parameter.paramValue, // From API
            icon: parameter.catIcon, // From API
            status: status,
            timestamp: DateTime.now(),
          ),
        );
  }

  /// Save test result as pass
  /// Automatically gets testName (paramValue) and icon (catIcon) from API parameter
  static void savePass(
    WidgetRef ref,
    String testId,
  ) {
    saveTestResult(ref, testId, TestStatus.pass);
  }
  /// Save test result as fail
  /// Automatically gets testName (paramValue) and icon (catIcon) from API parameter
  static void saveFail(
    WidgetRef ref,
    String testId,
  ) {
    saveTestResult(ref, testId, TestStatus.fail);
  }

  /// Save test result as skip
  /// Automatically gets testName (paramValue) and icon (catIcon) from API parameter
  static void saveSkip(
    WidgetRef ref,
    String testId,
  ) {
    saveTestResult(ref, testId, TestStatus.skip);
  }

  /// Save test result as NA (not applicable)
  /// e.g. device has no NFC - sent to BE as "NA" on final submit
  static void saveNA(
    WidgetRef ref,
    String testId,
  ) {
    saveTestResult(ref, testId, TestStatus.na);
  }

  /// Save test result as pending
  /// Automatically gets testName (paramValue) and icon (catIcon) from API parameter
  static void savePending(
    WidgetRef ref,
    String testId,
  ) {
    saveTestResult(ref, testId, TestStatus.pending);
  }
}

