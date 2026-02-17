import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
              '1. Acceptance of Terms',
              'By accessing and using NTWAZA ("the Service"), you accept and agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our service.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '2. Service Description',
              'NTWAZA is a food delivery platform that connects customers with local vendors and delivery riders. We facilitate the ordering and delivery of food but are not responsible for the food preparation or quality.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '3. User Accounts',
              'You must:\n\n• Provide accurate and complete information\n• Maintain the security of your account\n• Notify us immediately of any unauthorized access\n• Be at least 18 years old or have parental consent\n• Use the service only for lawful purposes',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '4. Orders and Payment',
              '• All orders are subject to vendor acceptance\n• Prices are displayed in your local currency\n• You agree to pay all charges at the prices in effect\n• Payment is processed through secure third-party providers\n• Delivery fees may apply based on distance and vendor\n• Tips to riders are optional but appreciated',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '5. Cancellation and Refunds',
              '• Orders can be cancelled before vendor confirmation\n• Refunds are processed at our discretion\n• Contact customer support for refund requests\n• Delivery delays may occur due to factors beyond our control\n• We are not responsible for incorrect orders prepared by vendors',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '6. Vendor and Rider Responsibilities',
              'Vendors are responsible for:\n• Food quality and safety\n• Accurate menu information\n• Order preparation time\n\nRiders are responsible for:\n• Timely delivery\n• Order handling\n• Professional conduct',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '7. Prohibited Activities',
              'You may not:\n\n• Use the service for illegal purposes\n• Harass vendors, riders, or other users\n• Attempt to manipulate ratings or reviews\n• Share your account credentials\n• Interfere with the proper operation of the service\n• Attempt to gain unauthorized access to our systems',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '8. Limitation of Liability',
              'NTWAZA is not liable for:\n\n• Food quality or safety issues\n• Delays caused by vendors or riders\n• Errors in vendor menu information\n• Allergic reactions or dietary concerns\n• Loss or damage during delivery\n\nYou use the service at your own risk.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '9. Intellectual Property',
              'All content, trademarks, and logos on the platform are owned by NTWAZA or our licensors. You may not use our intellectual property without written permission.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '10. Modifications to Terms',
              'We reserve the right to modify these terms at any time. Continued use of the service after changes constitutes acceptance of the new terms.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '11. Governing Law',
              'These terms are governed by and construed in accordance with applicable laws. Any disputes shall be resolved through binding arbitration.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              '12. Contact Information',
              'For questions about these Terms of Service:\n\nEmail: legal@ntwaza.com\nPhone: +1 (555) 123-4567\nAddress: 123 Main Street, City, Country',
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
