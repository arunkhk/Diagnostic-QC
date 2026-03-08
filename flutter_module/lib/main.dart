import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_module/features/diagnosis/battery_health_screen.dart';
import 'package:flutter_module/features/diagnosis/otg_connectivity_screen.dart';
import 'package:flutter_module/features/diagnosis/proximity_sensor_screen.dart';
import 'package:flutter_module/features/diagnosis/touch_screen_test_screen.dart';
import 'package:flutter_module/features/diagnosis/vibration_test_screen.dart';
import 'package:flutter_module/features/diagnosis/volume_button_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/api_loading_provider.dart';
import 'features/diagnosis/sd_card_detection_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/verification/imei_verification_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: DiagnosisApp()));
}

class DiagnosisApp extends ConsumerWidget {
  const DiagnosisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize global API loading notifier
    final apiLoadingNotifier = ref.read(apiLoadingProvider.notifier);
    setGlobalApiLoadingNotifier(apiLoadingNotifier);

    // Watch auth state to determine initial screen
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      // If user is authenticated, go directly to IMEI screen, otherwise show welcome screen
      home: authState.isAuthenticated 
          ? const ImeiVerificationScreen() 
          : const WelcomeScreen(),
    );
  }
}
