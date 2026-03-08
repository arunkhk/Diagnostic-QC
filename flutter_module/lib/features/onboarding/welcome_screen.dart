import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../auth/login_screen.dart';
import '../auth/providers/auth_provider.dart';
import '../verification/imei_verification_screen.dart';

final welcomeStartedProvider = StateProvider<bool>((ref) => false);

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final started = ref.watch(welcomeStartedProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: Image.asset(
                        'assets/images/image26.png',
                        fit: BoxFit.contain,

                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        AppStrings.smartDiagnosisTitle,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.black,
                          shadows: [
                            Shadow(
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                              color: AppColors.primary.withOpacity(0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    // Check if user is logged in
                    final authState = ref.read(authProvider);
                    
                    if (authState.isAuthenticated) {
                      // User is logged in, navigate to IMEI screen
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const ImeiVerificationScreen(),
                        ),
                      );
                    } else {
                      // User is not logged in, navigate to login screen
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    }
                  },
                  child: Text(
                    started ? AppStrings.runningButton : AppStrings.getStarted,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

