import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Battery information model
class BatteryInfo {
  final String health;
  final int level;
  final int scale;
  final String status;
  final String technology;
  final double temperature;
  final int voltage;

  BatteryInfo({
    required this.health,
    required this.level,
    required this.scale,
    required this.status,
    required this.technology,
    required this.temperature,
    required this.voltage,
  });

  BatteryInfo copyWith({
    String? health,
    int? level,
    int? scale,
    String? status,
    String? technology,
    double? temperature,
    int? voltage,
  }) {
    return BatteryInfo(
      health: health ?? this.health,
      level: level ?? this.level,
      scale: scale ?? this.scale,
      status: status ?? this.status,
      technology: technology ?? this.technology,
      temperature: temperature ?? this.temperature,
      voltage: voltage ?? this.voltage,
    );
  }
}

/// Battery state
class BatteryState {
  final BatteryInfo? batteryInfo;

  BatteryState({
    this.batteryInfo,
  });

  BatteryState copyWith({
    BatteryInfo? batteryInfo,
  }) {
    return BatteryState(
      batteryInfo: batteryInfo ?? this.batteryInfo,
    );
  }
}

/// Battery state notifier
class BatteryNotifier extends StateNotifier<BatteryState> {
  BatteryNotifier() : super(BatteryState());

  /// Save battery information
  void saveBatteryInfo(BatteryInfo info) {
    state = state.copyWith(batteryInfo: info);
  }

  /// Clear battery information
  void clear() {
    state = BatteryState();
  }
}

/// Battery provider
final batteryProvider =
    StateNotifierProvider<BatteryNotifier, BatteryState>((ref) {
  return BatteryNotifier();
});

