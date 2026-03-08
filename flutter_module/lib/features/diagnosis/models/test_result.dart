/// Test result model for tracking individual test statuses
enum TestStatus {
  pending, // Test not yet run
  pass,    // Test passed
  fail,    // Test failed
  skip,    // Test skipped
  na,      // Not applicable (e.g. device has no NFC)
}

/// Test result data model
class TestResult {
  final String testId;
  final String testName;
  final String? icon; // Icon from API (catIcon)
  final TestStatus status;
  final DateTime? timestamp;

  TestResult({
    required this.testId,
    required this.testName,
    this.icon,
    required this.status,
    this.timestamp,
  });

  TestResult copyWith({
    String? testId,
    String? testName,
    String? icon,
    TestStatus? status,
    DateTime? timestamp,
  }) {
    return TestResult(
      testId: testId ?? this.testId,
      testName: testName ?? this.testName,
      icon: icon ?? this.icon,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TestResult && other.testId == testId;
  }

  @override
  int get hashCode => testId.hashCode;
}

