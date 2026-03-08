import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_strings.dart';

/// Immutable state describing the current diagnostic run.
class DiagnosticsState {
  const DiagnosticsState({
    this.isRunning = false,
    this.lastRun,
    this.statusMessage = AppStrings.readyStatus,
  });

  final bool isRunning;
  final DateTime? lastRun;
  final String statusMessage;

  DiagnosticsState copyWith({
    bool? isRunning,
    DateTime? lastRun,
    String? statusMessage,
  }) {
    return DiagnosticsState(
      isRunning: isRunning ?? this.isRunning,
      lastRun: lastRun ?? this.lastRun,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

/// Simple controller that mimics a quick diagnostic sweep.
class DiagnosticsController extends StateNotifier<DiagnosticsState> {
  DiagnosticsController() : super(const DiagnosticsState());

  Future<void> runQuickCheck() async {
    if (state.isRunning) return;
    state = state.copyWith(
      isRunning: true,
      statusMessage: AppStrings.runningStatus,
    );

    await Future<void>.delayed(const Duration(seconds: 2));

    state = DiagnosticsState(
      isRunning: false,
      lastRun: DateTime.now(),
      statusMessage: AppStrings.successStatus,
    );
  }
}

final diagnosticsControllerProvider =
    StateNotifierProvider<DiagnosticsController, DiagnosticsState>(
  (ref) => DiagnosticsController(),
);

