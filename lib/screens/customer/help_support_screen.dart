import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expandedIndex;

  final List<FAQItem> faqs = [
    FAQItem(
      question: 'How do I place an order?',
      answer:
          'Browse vendors or restaurants, select items, add them to cart, choose delivery address, and proceed to checkout. You can track your order in real-time.',
      icon: Icons.shopping_cart,
    ),
    FAQItem(
      question: 'What payment methods are accepted?',
      answer:
          'We accept mobile money (MTN, Airtel), credit/debit cards, and cash on delivery for orders within Kigali.',
      icon: Icons.payment,
    ),
    FAQItem(
      question: 'How long does delivery take?',
      answer:
          'Most deliveries in Kigali take 30-60 minutes depending on traffic and distance. Real-time tracking is available.',
      icon: Icons.timer,
    ),
    FAQItem(
      question: 'Can I cancel my order?',
      answer:
          'You can cancel within 5 minutes of placing the order before the vendor starts preparing. Contact support for urgent cancellations.',
      icon: Icons.cancel,
    ),
    FAQItem(
      question: 'What is your refund policy?',
      answer:
          'We offer full refunds for cancelled orders or if items are not delivered as promised. Refunds are processed within 2-3 business days.',
      icon: Icons.money_off,
    ),
    FAQItem(
      question: 'How do I report a missing item?',
      answer:
          'Report missing items within 1 hour of delivery through the order details page. Include photos for faster resolution.',
      icon: Icons.report_problem,
    ),
    FAQItem(
      question: 'Is my location data safe?',
      answer:
          'Your location data is encrypted and only shared with delivery personnel for the current order. We never sell your data.',
      icon: Icons.security,
    ),
    FAQItem(
      question: 'How do I update my profile?',
      answer:
          'Go to Profile > Edit Profile to update your name, phone, address, and payment methods. Changes are saved instantly.',
      icon: Icons.edit,
    ),
  ];

  final List<SupportChannelItem> supportChannels = [
    SupportChannelItem(
      title: 'Live Chat',
      description: 'Chat with support team',
      icon: Icons.chat_bubble,
      color: Colors.blue,
      action: 'Available 8AM - 10PM',
    ),
    SupportChannelItem(
      title: 'Email Support',
      description: 'support@ntwaza.com',
      icon: Icons.email,
      color: Colors.orange,
      action: 'Response within 24 hours',
    ),
    SupportChannelItem(
      title: 'Phone Support',
      description: '+250 788 123 456',
      icon: Icons.phone,
      color: Colors.green,
      action: 'Call us anytime',
    ),
    SupportChannelItem(
      title: 'WhatsApp',
      description: 'Get instant help',
      icon: Icons.chat,
      color: Colors.lightGreen,
      action: 'Click to chat',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;
    final bgColor = isDarkMode ? const Color(0xFF121212) : Colors.white;
    final cardColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[50];
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF2E7D32),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Help & Support',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF2E7D32),
                      Colors.green[600]!,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.help_outline, size: 60, color: Colors.white.withOpacity(0.8)),
                    const SizedBox(height: 12),
                    Text(
                      'How can we help you today?',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Support Channels
                  _buildSectionTitle('Contact Us', textColor),
                  const SizedBox(height: 12),
                  _buildSupportChannels(isDarkMode, cardColor),
                  const SizedBox(height: 32),

                  // FAQ Section
                  _buildSectionTitle('Frequently Asked Questions', textColor),
                  const SizedBox(height: 12),
                  _buildFAQSection(isDarkMode, cardColor, textColor, subtextColor),
                  const SizedBox(height: 32),

                  // Additional Help
                  _buildAdditionalHelp(isDarkMode, cardColor, textColor, subtextColor),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildSupportChannels(bool isDarkMode, Color? cardColor) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: supportChannels.length,
      itemBuilder: (context, index) {
        final channel = supportChannels[index];
        return GestureDetector(
          onTap: () {
            _showChannelAction(context, channel);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: channel.color.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: channel.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    channel.icon,
                    size: 32,
                    color: channel.color,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  channel.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  channel.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFAQSection(bool isDarkMode, Color? cardColor, Color textColor, Color? subtextColor) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        final faq = faqs[index];
        final isExpanded = _expandedIndex == index;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isExpanded
                  ? const Color(0xFF2E7D32).withOpacity(0.5)
                  : (isDarkMode ? Colors.grey[800]! : Colors.grey[200]!),
              width: 1.5,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              onExpansionChanged: (expanded) {
                setState(() {
                  _expandedIndex = expanded ? index : null;
                });
              },
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      faq.icon,
                      size: 20,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      faq.question,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
              children: [
                Text(
                  faq.answer,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtextColor,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdditionalHelp(bool isDarkMode, Color? cardColor, Color textColor, Color? subtextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2E7D32).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF2E7D32),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Need more help?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'If you couldn\'t find the answer to your question, our support team is ready to help. Reach out through any of the channels above.',
            style: TextStyle(
              fontSize: 13,
              color: subtextColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening chat with support team...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text(
                'Start Live Chat',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChannelAction(BuildContext context, SupportChannelItem channel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${channel.title}: ${channel.action}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;
  final IconData icon;

  FAQItem({
    required this.question,
    required this.answer,
    required this.icon,
  });
}

class SupportChannelItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String action;

  SupportChannelItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.action,
  });
}
