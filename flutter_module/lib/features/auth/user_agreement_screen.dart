import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class UserAgreementScreen extends StatelessWidget {
  const UserAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.userAgreement,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Agreement',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Last Updated: January 1, 2024',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
              ),
              
              const SizedBox(height: 24),
              
              _buildSection(
                context,
                '1. Acceptance of Terms',
                'By accessing and using the Smart Diagnosis application, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
              ),
              
              _buildSection(
                context,
                '2. Use License',
                'Permission is granted to temporarily use Smart Diagnosis for personal, non-commercial diagnostic purposes only. This is the grant of a license, not a transfer of title, and under this license you may not:\n\n'
                '• Modify or copy the materials\n'
                '• Use the materials for any commercial purpose\n'
                '• Attempt to reverse engineer any software contained in the application\n'
                '• Remove any copyright or other proprietary notations from the materials',
              ),
              
              _buildSection(
                context,
                '3. User Responsibilities',
                'You agree to:\n\n'
                '• Provide accurate and complete information during registration\n'
                '• Maintain the security of your account credentials\n'
                '• Use the application only for lawful purposes\n'
                '• Not interfere with or disrupt the application\'s functionality\n'
                '• Report any security vulnerabilities or breaches immediately',
              ),
              
              _buildSection(
                context,
                '4. Diagnostic Services',
                'Smart Diagnosis provides device diagnostic services. The results are provided "as is" and we make no warranties, expressed or implied, regarding the accuracy, reliability, or completeness of diagnostic information. You acknowledge that:\n\n'
                '• Diagnostic results may vary based on device conditions\n'
                '• We are not responsible for any decisions made based on diagnostic results\n'
                '• You should consult with qualified technicians for critical issues',
              ),
              
              _buildSection(
                context,
                '5. Limitation of Liability',
                'In no event shall Smart Diagnosis or its suppliers be liable for any damages (including, without limitation, damages for loss of data or profit, or due to business interruption) arising out of the use or inability to use the application, even if we have been notified orally or in writing of the possibility of such damage.',
              ),
              
              _buildSection(
                context,
                '6. Account Termination',
                'We reserve the right to terminate or suspend your account and access to the application immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.',
              ),
              
              _buildSection(
                context,
                '7. Changes to Terms',
                'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material, we will try to provide at least 30 days notice prior to any new terms taking effect.',
              ),
              
              _buildSection(
                context,
                '8. Governing Law',
                'These terms and conditions are governed by and construed in accordance with the laws of the jurisdiction in which we operate, and you irrevocably submit to the exclusive jurisdiction of the courts in that location.',
              ),
              
              _buildSection(
                context,
                '9. Contact Information',
                'If you have any questions about this User Agreement, please contact us at:\n\n'
                'Email: support@smartdiagnosis.com\n'
                'Phone: +1 (555) 123-4567\n'
                'Address: 123 Tech Street, Digital City, DC 12345',
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryDark,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 16,
                  color: AppColors.text,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

