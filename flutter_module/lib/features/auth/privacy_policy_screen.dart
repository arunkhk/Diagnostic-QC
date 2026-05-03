import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          AppStrings.privacyPolicy,
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
                'Privacy Policy',
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
                '1. Introduction',
                'Welcome to Smart Diagnosis. We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
              ),
              
              _buildSection(
                context,
                '2. Information We Collect',
                'We may collect information that you provide directly to us, including:\n\n'
                '• Employee ID and authentication credentials\n'
                '• Device information and diagnostic data\n'
                '• Usage data and app interactions\n'
                '• Location data (with your permission)\n'
                '• Device hardware and software information',
              ),
              
              _buildSection(
                context,
                '3. How We Use Your Information',
                'We use the collected information for the following purposes:\n\n'
                '• To provide and maintain our diagnostic services\n'
                '• To authenticate your identity\n'
                '• To improve our app functionality and user experience\n'
                '• To generate diagnostic reports\n'
                '• To comply with legal obligations',
              ),
              
              _buildSection(
                context,
                '4. Data Security',
                'We implement appropriate technical and organizational security measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the internet or electronic storage is 100% secure.',
              ),
              
              _buildSection(
                context,
                '5. Data Sharing',
                'We do not sell, trade, or rent your personal information to third parties. We may share your information only in the following circumstances:\n\n'
                '• With your explicit consent\n'
                '• To comply with legal obligations\n'
                '• To protect our rights and safety\n'
                '• With service providers who assist in our operations',
              ),
              
              _buildSection(
                context,
                '6. Your Rights',
                'You have the right to:\n\n'
                '• Access your personal information\n'
                '• Request correction of inaccurate data\n'
                '• Request deletion of your data\n'
                '• Object to processing of your data\n'
                '• Withdraw consent at any time',
              ),
              
              _buildSection(
                context,
                '7. Contact Us',
                'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                'Email: privacy@smartdiagnosis.com\n'
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

