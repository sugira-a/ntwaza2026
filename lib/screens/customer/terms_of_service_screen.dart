import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  static const String _email = 'support@ntwaza.com';
  static const String _legalEmail = 'legal@ntwaza.com';
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
        title: Text('Terms of Service',
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
                        Icon(Icons.calendar_today_outlined, size: 14, color: accent),
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
                      'Please read these Terms of Service ("Terms", "Agreement") carefully before using the Ntwaza platform ("Service") operated by NTWAZA Ltd. ("Company", "we", "us", "our").',
                      style: TextStyle(fontSize: 13.5, color: sub, height: 1.7),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'By accessing or using our Service, you agree to be bound by these Terms. If you do not agree to any part of these Terms, you must discontinue use of the Service immediately.',
                      style: TextStyle(fontSize: 13.5, color: sub, height: 1.7),
                    ),
                  ]),

                  const SizedBox(height: 20),

                  _numberedSection('1', 'Definitions', card, text, sub, divider, [
                    '"Platform" refers to the Ntwaza mobile application and website.',
                    '"User" refers to any individual who accesses or uses the Platform, including customers, vendors, and delivery riders.',
                    '"Vendor" refers to any business or individual that lists products or services on the Platform.',
                    '"Rider" refers to an independent delivery partner who fulfils delivery orders.',
                    '"Order" refers to a request placed by a User to purchase and have goods delivered.',
                  ]),
                  _numberedSection('2', 'Service Description', card, text, sub, divider, [
                    'Ntwaza is a technology-enabled delivery platform that connects customers with local vendors, shops, and service providers. We facilitate the ordering, payment, and last-mile delivery of goods — including but not limited to food, groceries, retail products, and packages.',
                    'Ntwaza acts as an intermediary between Users and Vendors. We do not manufacture, store, or directly sell any products listed on the Platform. Vendors are solely responsible for the quality, accuracy, and safety of their offerings.',
                  ]),
                  _numberedSection('3', 'Eligibility & Account Registration', card, text, sub, divider, [
                    'You must be at least 18 years of age, or have verifiable parental or guardian consent, to create an account.',
                    'You agree to provide accurate, current, and complete information during registration and to update such information as necessary.',
                    'You are responsible for safeguarding your account credentials. Any activity conducted under your account is your sole responsibility.',
                    'We reserve the right to suspend or terminate accounts that provide false information or violate these Terms.',
                  ]),
                  _numberedSection('4', 'Orders, Pricing & Payment', card, text, sub, divider, [
                    'All orders placed through the Platform are subject to acceptance by the relevant Vendor.',
                    'Prices are displayed in Rwandan Francs (RWF) and include applicable taxes unless otherwise stated.',
                    'We accept Mobile Money (MTN MoMo, Airtel Money), debit/credit cards (Visa, Mastercard), and Cash on Delivery where available.',
                    'Delivery fees are calculated based on distance and may vary by location, time of day, and demand.',
                    'Promotional offers and discount codes are subject to specific terms and may be revoked at any time.',
                    'Payment is processed through secure, PCI-compliant third-party payment processors. Ntwaza does not store your full payment credentials.',
                  ]),
                  _numberedSection('5', 'Cancellations & Refunds', card, text, sub, divider, [
                    'You may cancel an order within 5 minutes of placement and before the Vendor begins preparation, at no charge.',
                    'Cancellations made after preparation has begun may incur partial or full charges at our discretion.',
                    'Refunds for missing, incorrect, or damaged items are evaluated on a case-by-case basis. Supporting evidence (e.g. photographs) may be required.',
                    'Approved refunds are processed within 2–5 business days to the original payment method.',
                    'Repeated abuse of the cancellation or refund policy may result in account restrictions.',
                  ]),
                  _numberedSection('6', 'Delivery Terms', card, text, sub, divider, [
                    'Estimated delivery times are provided for informational purposes and are not guaranteed. Actual times depend on traffic, weather, vendor preparation, and rider availability.',
                    'You must provide an accurate and accessible delivery address. Failed deliveries due to incorrect addresses may result in additional charges.',
                    'Our riders are independent contractors. They are responsible for safe handling of goods during transit.',
                    'Ntwaza is not liable for delays caused by force majeure events including, but not limited to, natural disasters, civil unrest, or government-imposed restrictions.',
                  ]),
                  _numberedSection('7', 'Vendor & Rider Responsibilities', card, text, sub, divider, [
                    'Vendors are responsible for: accurate product listings and descriptions, food safety and hygiene compliance, timely order preparation, and maintaining adequate stock levels.',
                    'Riders are responsible for: timely pickup and delivery, safe handling of packages, professional and courteous conduct, and compliance with traffic laws.',
                    'Ntwaza does not employ Vendors or Riders. They operate as independent partners under their own terms.',
                  ]),
                  _numberedSection('8', 'Prohibited Conduct', card, text, sub, divider, [
                    'You shall not use the Platform for any unlawful purpose or to facilitate illegal activity.',
                    'Harassment, abuse, or threats directed at Vendors, Riders, or other Users will result in immediate account termination.',
                    'Manipulation of ratings, reviews, or promotional systems is strictly prohibited.',
                    'Sharing, transferring, or selling your account credentials to third parties is forbidden.',
                    'Any attempt to reverse-engineer, decompile, or interfere with the Platform\'s infrastructure is prohibited and may result in legal action.',
                  ]),
                  _numberedSection('9', 'Intellectual Property', card, text, sub, divider, [
                    'All content on the Platform — including logos, trademarks, text, graphics, software, and design elements — is the property of NTWAZA Ltd. or its licensors and is protected under applicable intellectual property laws.',
                    'You are granted a limited, non-exclusive, non-transferable licence to use the Platform for personal, non-commercial purposes. Any unauthorised reproduction or distribution of Platform content is strictly prohibited.',
                  ]),
                  _numberedSection('10', 'Limitation of Liability', card, text, sub, divider, [
                    'TO THE FULLEST EXTENT PERMITTED BY APPLICABLE LAW, NTWAZA SHALL NOT BE LIABLE FOR: product quality or safety issues attributable to Vendors; delivery delays beyond our reasonable control; allergic reactions or dietary concerns arising from Vendor-prepared items; loss, theft, or damage of goods during transit; or any indirect, incidental, special, consequential, or punitive damages.',
                    'Our total aggregate liability for any claims arising from or related to the Service shall not exceed the total fees paid by you in the 12 months preceding the claim.',
                  ]),
                  _numberedSection('11', 'Indemnification', card, text, sub, divider, [
                    'You agree to indemnify, defend, and hold harmless NTWAZA Ltd., its officers, directors, employees, and agents from and against any and all claims, damages, losses, liabilities, and expenses (including reasonable legal fees) arising out of your use of the Service or violation of these Terms.',
                  ]),
                  _numberedSection('12', 'Governing Law & Dispute Resolution', card, text, sub, divider, [
                    'These Terms are governed by and construed in accordance with the laws of the Republic of Rwanda.',
                    'Any dispute arising from these Terms shall first be resolved through good-faith negotiations between the parties.',
                    'If negotiation fails, disputes shall be submitted to binding arbitration in Kigali, Rwanda, in accordance with the rules of the Kigali International Arbitration Centre (KIAC).',
                    'Nothing in this clause prevents either party from seeking injunctive or equitable relief in a court of competent jurisdiction.',
                  ]),
                  _numberedSection('13', 'Amendments', card, text, sub, divider, [
                    'We reserve the right to modify these Terms at any time. Material changes will be communicated via push notification, email, or in-app notice at least 14 days prior to taking effect.',
                    'Continued use of the Service after such notice constitutes your acceptance of the revised Terms. If you do not agree, you must discontinue use of the Service.',
                  ]),
                  _numberedSection('14', 'Severability', card, text, sub, divider, [
                    'If any provision of these Terms is found to be invalid, illegal, or unenforceable by a court of competent jurisdiction, the remaining provisions shall remain in full force and effect.',
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
                            Icon(Icons.contact_mail_outlined, size: 18, color: accent),
                            const SizedBox(width: 8),
                            Text('Contact & Inquiries',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'For questions, concerns, or legal inquiries regarding these Terms of Service, please contact us:',
                          style: TextStyle(fontSize: 13, color: sub, height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        _contactRow(Icons.email_outlined, 'General: $_email', sub),
                        const SizedBox(height: 6),
                        _contactRow(Icons.gavel_outlined, 'Legal: $_legalEmail', sub),
                        const SizedBox(height: 6),
                        _contactRow(Icons.phone_outlined, 'Phone: $_phone', sub),
                        const SizedBox(height: 6),
                        _contactRow(Icons.location_on_outlined, 'NTWAZA Ltd., Kigali, Rwanda', sub),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse('mailto:$_legalEmail?subject=Terms%20of%20Service%20Inquiry');
                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                },
                                icon: const Icon(Icons.email_outlined, size: 16),
                                label: const Text('Email Legal Team', style: TextStyle(fontSize: 12.5)),
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
                                icon: const Icon(Icons.phone_outlined, size: 16),
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
                        '\u00a9 ${DateTime.now().year} NTWAZA Ltd. All rights reserved.',
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
