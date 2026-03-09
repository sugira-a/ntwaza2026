import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api/api_service.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expandedIndex;
  bool _isSubmitting = false;

  // ── Contact Info ──
  static const String _phone = '+250782195474';
  static const String _phoneDisplay = '+250 782 195 474';
  static const String _email = 'support@ntwaza.com';
  static const String _whatsApp = '250782195474';
  static const String _workingHours = 'Mon – Sat, 7:00 AM – 9:00 PM (CAT)';

  // ── FAQ ──
  final List<_FAQ> _faqs = [
    _FAQ(
      q: 'How do I place an order?',
      a: 'Browse vendors near you, add items to your cart, confirm your delivery address, and proceed to checkout. You will receive real-time updates once the order is accepted.',
      icon: Icons.shopping_bag_rounded,
    ),
    _FAQ(
      q: 'What payment methods are accepted?',
      a: 'We accept Mobile Money (MTN MoMo, Airtel Money) and Visa / Mastercard.',
      icon: Icons.account_balance_wallet,
    ),
    _FAQ(
      q: 'How long does delivery take?',
      a: 'Most deliveries within Kigali are completed in 20–60 minutes depending on distance, traffic, and vendor preparation time. You can track your rider in real time.',
      icon: Icons.schedule,
    ),
    _FAQ(
      q: 'Can I cancel or modify my order?',
      a: 'You may cancel within 5 minutes of placing your order, provided the vendor has not yet started preparing it. Modifications can be made by contacting our support team before preparation begins.',
      icon: Icons.edit_note,
    ),
    _FAQ(
      q: 'What is your refund policy?',
      a: 'Full refunds are issued for cancelled orders and undelivered items. Partial refunds may apply for missing or incorrect items. Refunds are processed within 2–3 business days to the original payment method.',
      icon: Icons.currency_exchange,
    ),
    _FAQ(
      q: 'How do I report a problem with my order?',
      a: 'Navigate to your order history, select the order, and tap "Report an Issue". Alternatively, submit a support ticket below or email us at $_email. Please include photos where applicable.',
      icon: Icons.flag,
    ),
    _FAQ(
      q: 'Is my personal data secure?',
      a: 'Absolutely. All data is encrypted in transit and at rest. Location data is shared only with your assigned rider during active deliveries and is never sold to third parties. See our Privacy Policy for details.',
      icon: Icons.shield,
    ),
    _FAQ(
      q: 'Do you deliver outside Kigali?',
      a: 'We currently operate within Kigali and its surrounding areas. We are actively expanding to other cities in Rwanda and will notify you when new areas become available.',
      icon: Icons.location_on_rounded,
    ),
  ];

  // ── Support ticket form ──
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _ticketCategory = 'general';

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──
  Future<void> _launchPhone() async {
    final uri = Uri.parse('tel:$_phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchEmail() async {
    final uri = Uri.parse('mailto:$_email?subject=Support%20Request');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse('https://wa.me/$_whatsApp?text=Hello%20Ntwaza%20Support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final auth = context.read<AuthProvider>();
      final token = auth.token;
      if (token == null) {
        _showSnack('Please log in to submit a support ticket.', isError: true);
        setState(() => _isSubmitting = false);
        return;
      }

      final api = ApiService();
      final response = await api.post(
        '/api/admin/dashboard/complaints',
        {
          'subject': _subjectCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'category': _ticketCategory,
          'priority': 'medium',
        },
      );

      // response is already decoded by ApiService._handleResponse
      if (response is Map && response['success'] == true) {
        final ticketNum = response['data']?['ticket_number'] ?? '';
        _subjectCtrl.clear();
        _descCtrl.clear();
        _showSnack('Ticket $ticketNum submitted successfully. We\'ll respond within 24 hours.');
      } else {
        final errMsg = (response is Map) ? (response['error'] ?? 'Failed to submit ticket') : 'Failed to submit ticket';
        _showSnack(errMsg.toString(), isError: true);
      }
    } catch (e) {
      _showSnack('Unable to reach support servers. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : const Color(0xFF2E7D32),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final card = bg; // cards match background — seamless
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
        title: Text('Help & Support',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: text)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('We\'re here to help', style: TextStyle(fontSize: 14, color: sub)),
            const SizedBox(height: 24),

            // ── Contact Channels ──
            _sectionHeader('Contact Us', Icons.headset_mic, text),
            const SizedBox(height: 4),
            Text('Reach our support team through any of the channels below.',
                style: TextStyle(fontSize: 13, color: sub, height: 1.4)),
            const SizedBox(height: 12),
            _contactCard(
              icon: Icons.phone,
              title: 'Phone',
              subtitle: _phoneDisplay,
              trailing: 'Mon-Sat 7AM-9PM',
              onTap: _launchPhone,
              card: card,
              text: text,
              sub: sub,
              accent: accent,
            ),
            const SizedBox(height: 8),
            _contactCard(
              icon: Icons.email,
              title: 'Email',
              subtitle: _email,
              trailing: 'Within 24hrs',
              onTap: _launchEmail,
              card: card,
              text: text,
              sub: sub,
              accent: accent,
            ),
            const SizedBox(height: 8),
            _contactCard(
              icon: Icons.chat,
              title: 'WhatsApp',
              subtitle: 'Chat with us instantly',
              trailing: 'Open WhatsApp',
              onTap: _launchWhatsApp,
              card: card,
              text: text,
              sub: sub,
              accent: accent,
            ),

            const SizedBox(height: 28),

                  // ── FAQ ──
                  _sectionHeader('Frequently Asked Questions', Icons.quiz, text),
                  const SizedBox(height: 4),
                  Text('Quick answers to common questions.',
                      style: TextStyle(fontSize: 13, color: sub, height: 1.4)),
                  const SizedBox(height: 16),
                  ..._faqs.asMap().entries.map((e) =>
                      _faqTile(e.key, e.value, isDark, card, text, sub, divider, accent)),

                  const SizedBox(height: 32),

                  // ── Submit Ticket ──
                  _sectionHeader('Submit a Support Ticket', Icons.confirmation_number, text),
                  const SizedBox(height: 4),
                  Text('Can\'t find your answer? Describe your issue and our team will respond promptly.',
                      style: TextStyle(fontSize: 13, color: sub, height: 1.4)),
                  const SizedBox(height: 16),
                  _ticketForm(isDark, card, text, sub, divider, accent),

                  const SizedBox(height: 32),

                  // ── Office Info ──
                  _sectionHeader('Company Information', Icons.business, text),
                  const SizedBox(height: 16),
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
                        Text('NTWAZA Ltd.',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
                        const SizedBox(height: 12),
                        _infoRow(Icons.location_on_rounded, 'Kigali, Rwanda', sub),
                        const SizedBox(height: 8),
                        _infoRow(Icons.phone, _phoneDisplay, sub),
                        const SizedBox(height: 8),
                        _infoRow(Icons.email, _email, sub),
                        const SizedBox(height: 8),
                        _infoRow(Icons.access_time, _workingHours, sub),
                        const SizedBox(height: 16),
                        Divider(color: divider, height: 1),
                        const SizedBox(height: 16),
                        Text(
                          'Ntwaza is a technology-driven delivery platform connecting customers with local vendors and service providers across Rwanda.',
                          style: TextStyle(fontSize: 12.5, color: sub, height: 1.5),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
  }

  // ── Widgets ──

  Widget _sectionHeader(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
      ],
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback onTap,
    required Color card,
    required Color text,
    required Color sub,
    required Color accent,
  }) {
    return Material(
      color: card,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: text)),
                    Text(subtitle,
                        style: TextStyle(fontSize: 11.5, color: sub),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: 0,
                child: Text(trailing,
                    style: TextStyle(fontSize: 9.5, color: sub.withOpacity(0.6)),
                    textAlign: TextAlign.end,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: sub.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _faqTile(int index, _FAQ faq, bool isDark, Color card, Color text, Color sub, Color divider, Color accent) {
    final isOpen = _expandedIndex == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          initiallyExpanded: isOpen,
          onExpansionChanged: (open) => setState(() => _expandedIndex = open ? index : null),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(faq.icon, size: 18, color: accent),
          ),
          title: Text(faq.q,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: text)),
          trailing: AnimatedRotation(
            turns: isOpen ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.expand_more, color: sub, size: 22),
          ),
          children: [
            Text(faq.a, style: TextStyle(fontSize: 13, color: sub, height: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _ticketForm(bool isDark, Color card, Color text, Color sub, Color divider, Color accent) {
    final categories = {
      'general': 'General Inquiry',
      'order_issue': 'Order Issue',
      'payment': 'Payment Problem',
      'account': 'Account & Profile',
      'technical': 'Technical / App Bug',
      'feedback': 'Feedback & Suggestions',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: text)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _ticketCategory,
              decoration: _inputDecor(isDark, sub),
              dropdownColor: card,
              style: TextStyle(fontSize: 13.5, color: text),
              items: categories.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _ticketCategory = v ?? 'general'),
            ),
            const SizedBox(height: 16),
            Text('Subject', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: text)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _subjectCtrl,
              style: TextStyle(fontSize: 13.5, color: text),
              decoration: _inputDecor(isDark, sub).copyWith(hintText: 'Brief summary of your issue'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
            ),
            const SizedBox(height: 16),
            Text('Description', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: text)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              style: TextStyle(fontSize: 13.5, color: text),
              decoration: _inputDecor(isDark, sub).copyWith(
                hintText: 'Please describe the issue in detail...',
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Ticket',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecor(bool isDark, Color sub) {
    return InputDecoration(
      filled: true,
      fillColor: isDark ? const Color(0xFF262626) : const Color(0xFFF5F5F5),
      hintStyle: TextStyle(fontSize: 13, color: sub.withOpacity(0.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red[400]!, width: 1),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, Color sub) {
    return Row(
      children: [
        Icon(icon, size: 16, color: sub),
        const SizedBox(width: 10),
        Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: sub, height: 1.3))),
      ],
    );
  }
}

class _FAQ {
  final String q, a;
  final IconData icon;
  _FAQ({required this.q, required this.a, required this.icon});
}
