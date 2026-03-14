import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _email = 'support@ntwaza.com';
  static const String _privacyEmail = 'privacy@ntwaza.com';
  static const String _phone = '+250 782 195 474';
  static const String _lastUpdated = 'March 1, 2026';
  static const String _effectiveDate = 'March 1, 2026';

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final card = bg;
    final text = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final sub = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final divider = Colors.transparent;
    const accent = Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Privacy Policy',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: text)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  const SizedBox(height: 20),

                  // Effective date badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: accent),
                        const SizedBox(width: 8),
                        Text('Effective Date: $_effectiveDate',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent)),
                        const Spacer(),
                        Text('Last Updated: $_lastUpdated',
                            style: TextStyle(fontSize: 11, color: sub)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Preamble
                  _buildCard(card, divider, [
                    Text(
                      'NTWAZA Delivery Ltd. ("Company", "we", "us", "our") is committed to protecting your privacy. This Privacy Policy describes how we collect, use, disclose, and safeguard your personal information when you use the NTWAZA Delivery platform ("Service").',
                      style: TextStyle(fontSize: 13.5, color: sub, height: 1.7),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'By using our Service, you consent to the data practices described in this policy. If you do not agree with any part of this policy, please discontinue use of the Service.',
                      style: TextStyle(fontSize: 13.5, color: sub, height: 1.7),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  _numberedSection('1', 'Information We Collect', card, text, sub, divider, [
                    'Account Information: Full name, email address, phone number, profile photo, and delivery addresses provided during registration.',
                    'Order Data: Items ordered, order history, delivery preferences, vendor interactions, and transaction records.',
                    'Payment Information: Payment method details (processed and stored securely by our PCI-compliant payment partners — we do not store your full mobile money PIN).',
                    'Location Data: Real-time GPS location (with your permission) to facilitate delivery tracking, estimate distances, and connect you with nearby vendors.',
                    'Device & Technical Data: Device type, operating system, app version, IP address, browser type, crash logs, and performance diagnostics.',
                    'Usage Analytics: Pages viewed, features used, search queries, session duration, and interaction patterns to improve our Service.',
                    'Communications: Messages exchanged with our support team, feedback, and survey responses.',
                  ]),
                  _numberedSection('2', 'How We Use Your Information', card, text, sub, divider, [
                    'To process, fulfil, and deliver your orders accurately and efficiently.',
                    'To send real-time order status notifications, delivery updates, and confirmations.',
                    'To verify your identity and prevent fraud, unauthorised access, and abuse.',
                    'To personalise your experience — including product recommendations, promotions, and content relevant to your location and preferences.',
                    'To process payments and issue refunds through our secure payment partners.',
                    'To communicate with you regarding account activity, policy changes, and service announcements.',
                    'To improve, maintain, and optimise the Platform\'s functionality, performance, and reliability.',
                    'To comply with applicable legal obligations, regulatory requirements, and law enforcement requests.',
                  ]),
                  _numberedSection('3', 'Information Sharing & Disclosure', card, text, sub, divider, [
                    'Vendors: We share your name, delivery address, and order details with Vendors solely for the purpose of fulfilling your order.',
                    'Riders: We share your delivery address, contact name, and order pickup/drop-off details with assigned delivery riders.',
                    'Payment Processors: Transaction data is shared with our secure, PCI-compliant payment partners (e.g., MTN MoMo, Airtel Money) to process payments.',
                    'Service Providers: We may engage third-party providers (cloud hosting, analytics, email delivery) who process data on our behalf under strict confidentiality agreements.',
                    'Legal Compliance: We may disclose information when required by law, court order, or governmental authority, or to protect the rights, safety, or property of NTWAZA Delivery, our users, or the public.',
                    'We never sell, rent, or trade your personal information to third parties for marketing purposes.',
                  ]),
                  _numberedSection('4', 'Data Retention', card, text, sub, divider, [
                    'Account data is retained for as long as your account is active, plus an additional 12 months after deletion for legal and audit purposes.',
                    'Order and transaction records are retained for a minimum of 5 years to comply with Rwandan tax and commercial regulations.',
                    'Location data collected during deliveries is retained for 30 days and then anonymised for analytical purposes.',
                    'Support ticket correspondence is retained for 2 years from resolution.',
                    'You may request earlier deletion of certain data — see "Your Rights" below.',
                  ]),
                  _numberedSection('5', 'Data Security', card, text, sub, divider, [
                    'All data transmitted between your device and our servers is encrypted using TLS 1.2 or higher.',
                    'Sensitive data at rest is encrypted using AES-256 encryption standards.',
                    'We implement role-based access controls, ensuring only authorised personnel can access personal data on a need-to-know basis.',
                    'We conduct periodic security audits and vulnerability assessments.',
                    'Despite our best efforts, no method of electronic transmission or storage is 100% secure. We cannot guarantee absolute security, but we are committed to promptly notifying affected users in the event of a data breach, in accordance with applicable laws.',
                  ]),
                  _numberedSection('6', 'Your Rights', card, text, sub, divider, [
                    'Access: You have the right to request a copy of the personal data we hold about you.',
                    'Correction: You may request correction of any inaccurate or incomplete personal information.',
                    'Deletion: You may request deletion of your account and associated personal data, subject to our legal retention obligations.',
                    'Portability: You may request your data in a structured, commonly-used, machine-readable format.',
                    'Opt-Out: You may opt out of promotional emails and push notifications at any time via your account settings or by contacting us.',
                    'Withdraw Consent: Where processing is based on your consent, you may withdraw it at any time. Withdrawal does not affect the lawfulness of prior processing.',
                    'To exercise any of these rights, contact us at $_privacyEmail or $_phone.',
                  ]),
                  _numberedSection('7', 'Location Data', card, text, sub, divider, [
                    'We collect precise location data only when you grant explicit permission through your device settings.',
                    'Location data is used to: show nearby vendors, calculate delivery distances and fees, provide real-time delivery tracking, and improve route optimisation.',
                    'Location data is shared only with your assigned delivery rider during an active order. It is never shared with advertisers or data brokers.',
                    'You may revoke location permissions at any time through your device settings. Note that some features (e.g., delivery tracking, nearby vendors) may not function without location access.',
                  ]),
                  _numberedSection('8', 'Cookies & Tracking Technologies', card, text, sub, divider, [
                    'Our web platform uses essential cookies (required for basic functionality), analytical cookies (to understand usage patterns), and preference cookies (to remember your settings).',
                    'Our mobile application uses anonymous analytics SDKs (e.g., Firebase Analytics) to monitor app performance and crash reporting.',
                    'We do not use invasive tracking technologies or participate in cross-app advertising networks.',
                    'You can manage cookie preferences via your browser settings. Disabling essential cookies may impair Platform functionality.',
                  ]),
                  _numberedSection('9', 'Children\'s Privacy', card, text, sub, divider, [
                    'The NTWAZA Delivery Service is not directed at individuals under the age of 13. We do not knowingly collect personal information from children under 13.',
                    'If we learn that we have inadvertently collected information from a child under 13, we will take steps to delete it promptly. If you believe a child has provided us with personal data, please contact us at $_privacyEmail.',
                  ]),
                  _numberedSection('10', 'International Data Transfers', card, text, sub, divider, [
                    'Your data is primarily stored and processed in Rwanda. In cases where data is transferred to servers outside Rwanda (e.g., cloud hosting providers), we ensure appropriate safeguards are in place, including contractual clauses and compliance with applicable data protection frameworks.',
                  ]),
                  _numberedSection('11', 'Changes to This Policy', card, text, sub, divider, [
                    'We may update this Privacy Policy from time to time. Material changes will be communicated through in-app notifications, push alerts, or email at least 14 days before taking effect.',
                    'Your continued use of the Service after the effective date of any changes constitutes your acceptance of the updated policy.',
                    'We encourage you to review this policy periodically.',
                  ]),

                  const SizedBox(height: 24),

                  // Contact section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.contact_mail, size: 18, color: accent),
                            const SizedBox(width: 8),
                            Text('Data Protection Contact',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'For questions, concerns, or requests related to your personal data or this Privacy Policy, please contact our Data Protection Officer:',
                          style: TextStyle(fontSize: 13, color: sub, height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        _contactRow(Icons.email, 'Privacy: $_privacyEmail', sub),
                        const SizedBox(height: 6),
                        _contactRow(Icons.email, 'General: $_email', sub),
                        const SizedBox(height: 6),
                        _contactRow(Icons.phone, 'Phone: $_phone', sub),
                        const SizedBox(height: 6),
                        _contactRow(Icons.location_on_rounded, 'NTWAZA Delivery Ltd., Kigali, Rwanda', sub),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse('mailto:$_privacyEmail?subject=Privacy%20Inquiry');
                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                },
                                icon: const Icon(Icons.email, size: 16),
                                label: const Text('Email Privacy Team', style: TextStyle(fontSize: 12.5)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accent,
                                  side: BorderSide(color: accent.withOpacity(0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse('tel:+250782195474');
                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                },
                                icon: const Icon(Icons.phone, size: 16),
                                label: const Text('Call Support', style: TextStyle(fontSize: 12.5)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: accent,
                                  side: BorderSide(color: accent.withOpacity(0.4)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Footer
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 32),
                      child: Text(
                        '\u00a9 ${DateTime.now().year} NTWAZA Delivery Ltd. All rights reserved.',
                        style: TextStyle(fontSize: 11.5, color: sub),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Helpers ──

  Widget _buildCard(Color card, Color border, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _numberedSection(String num, String title, Color card, Color text, Color sub, Color divider, List<String> paragraphs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(num,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...paragraphs.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: sub.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p, style: TextStyle(fontSize: 13, color: sub, height: 1.65)),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, Color sub) {
    return Row(
      children: [
        Icon(icon, size: 15, color: sub),
        const SizedBox(width: 10),
        Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: sub, height: 1.3))),
      ],
    );
  }
}
