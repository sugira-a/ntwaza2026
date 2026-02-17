import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Information We Collect',
              'We collect information you provide directly to us, including your name, email address, phone number, delivery addresses, and payment information when you create an account or place an order.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'How We Use Your Information',
              'We use the information we collect to:\n\n• Process and deliver your orders\n• Send you order updates and notifications\n• Improve our services and user experience\n• Communicate with you about promotions and updates\n• Ensure the security of our platform',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Information Sharing',
              'We share your information with:\n\n• Vendors to fulfill your orders\n• Delivery riders to complete deliveries\n• Payment processors to handle transactions\n• Service providers who assist our operations\n\nWe never sell your personal information to third parties.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Data Security',
              'We implement appropriate security measures to protect your personal information from unauthorized access, alteration, disclosure, or destruction. However, no method of transmission over the Internet is 100% secure.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Your Rights',
              'You have the right to:\n\n• Access your personal data\n• Correct inaccurate information\n• Request deletion of your account\n• Opt-out of marketing communications\n• Export your data',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Cookies and Tracking',
              'We use cookies and similar tracking technologies to enhance your experience, analyze usage patterns, and provide personalized content.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at:\n\nEmail: privacy@ntwaza.com\nPhone: +1 (555) 123-4567',
              isDark,
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: February 1, 2026',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
