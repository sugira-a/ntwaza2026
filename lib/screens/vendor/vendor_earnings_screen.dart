// lib/screens/vendor/vendor_earnings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vendor_order_provider.dart';
import '../../utils/helpers.dart';

class VendorEarningsScreen extends StatefulWidget {
  const VendorEarningsScreen({super.key});

  @override
  State<VendorEarningsScreen> createState() => _VendorEarningsScreenState();
}

class _VendorEarningsScreenState extends State<VendorEarningsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final orderProvider = context.watch<VendorOrderProvider>();
    
    final isDarkMode = themeProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF202124) : Colors.white;
    final cardColor = isDarkMode ? const Color(0xFF1B1B1F) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    // Calculate earnings from real data
    final todayEarnings = _calculateTodayEarnings(orderProvider);
    final weekEarnings = _calculateWeekEarnings(orderProvider);
    final monthEarnings = _calculateMonthEarnings(orderProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Earnings',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await orderProvider.fetchOrders();
        },
        backgroundColor: cardColor,
        color: isDarkMode ? Colors.white : Colors.black,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Total Balance Card
              // Available Balance Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.75),
                      Colors.black.withOpacity(0.45),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.circle, color: Colors.cyan, size: 6),
                              SizedBox(width: 4),
                              Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Rwf ${NumberFormat('#,###').format(todayEarnings)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ready for payout',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _showPayoutDialog(context, todayEarnings, isDarkMode, cardColor, isDarkMode ? Colors.white : Colors.black),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_wallet, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Request Payout',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Period Selector
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: UnderlineTabIndicator(
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.white : Colors.black,
                      width: 3,
                    ),
                    insets: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  labelColor: isDarkMode ? Colors.white : Colors.black,
                  unselectedLabelColor: isDarkMode ? Colors.grey[500] : Colors.grey[500],
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  dividerColor: Colors.transparent,
                  isScrollable: false,
                  tabs: const [
                    Tab(text: 'Today', height: 52),
                    Tab(text: 'Week', height: 52),
                    Tab(text: 'Month', height: 52),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats Cards
              SizedBox(
                height: 480,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStatsView(
                      context,
                      'Today',
                      todayEarnings,
                      orderProvider.todayOrderCount,
                      cardColor,
                      isDarkMode ? Colors.white : Colors.black,
                      isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                    ),
                    _buildStatsView(
                      context,
                      'This Week',
                      weekEarnings,
                      orderProvider.orders.where((o) => _isThisWeek(o.createdAt)).length,
                      cardColor,
                      isDarkMode ? Colors.white : Colors.black,
                      isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                    ),
                    _buildStatsView(
                      context,
                      'This Month',
                      monthEarnings,
                      orderProvider.orders.where((o) => _isThisMonth(o.createdAt)).length,
                      cardColor,
                      isDarkMode ? Colors.white : Colors.black,
                      isDarkMode ? Colors.grey[500]! : Colors.grey[600]!,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsView(
    BuildContext context,
    String period,
    double earnings,
    int orderCount,
    Color cardColor,
    Color textColor,
    Color subtextColor,
  ) {
    final avgOrderValue = orderCount > 0 ? earnings / orderCount : 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Revenue Card
          _buildStatCard(
            icon: Icons.trending_up,
            iconColor: const Color(0xFF3B82F6),
            title: 'Total Revenue',
            value: 'Rwf ${NumberFormat('#,###').format(earnings)}',
            subtitle: '$orderCount orders completed',
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
          const SizedBox(height: 12),

          // Average Order Value Card
          _buildStatCard(
            icon: Icons.receipt_long,
            iconColor: const Color(0xFF8B5CF6),
            title: 'Average Order',
            value: 'Rwf ${NumberFormat('#,###').format(avgOrderValue)}',
            subtitle: 'Per order',
            cardColor: cardColor,
            textColor: textColor,
            subtextColor: subtextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // Light blue background
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFBBDEFB),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  iconColor.withOpacity(0.35),
                  iconColor.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTodayEarnings(VendorOrderProvider provider) {
    return provider.orders
        .where((o) => _isToday(o.createdAt) && o.status.index >= 4)
        .fold(0.0, (sum, order) => sum + order.total);
  }

  double _calculateWeekEarnings(VendorOrderProvider provider) {
    return provider.orders
        .where((o) => _isThisWeek(o.createdAt) && o.status.index >= 4)
        .fold(0.0, (sum, order) => sum + order.total);
  }

  double _calculateMonthEarnings(VendorOrderProvider provider) {
    return provider.orders
        .where((o) => _isThisMonth(o.createdAt) && o.status.index >= 4)
        .fold(0.0, (sum, order) => sum + order.total);
  }

  bool _isToday(DateTime date) {
    final now = nowInRwanda();
    final rwandaDate = toRwandaTime(date);
    return rwandaDate.year == now.year &&
        rwandaDate.month == now.month &&
        rwandaDate.day == now.day;
  }

  bool _isThisWeek(DateTime date) {
    final now = nowInRwanda();
    final rwandaDate = toRwandaTime(date);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return rwandaDate.isAfter(startOfWeek.subtract(const Duration(days: 1)));
  }

  bool _isThisMonth(DateTime date) {
    final now = nowInRwanda();
    final rwandaDate = toRwandaTime(date);
    return rwandaDate.year == now.year && rwandaDate.month == now.month;
  }

  void _showPayoutDialog(
    BuildContext context,
    double suggestedAmount,
    bool isDarkMode,
    Color cardColor,
    Color textColor,
  ) {
    final TextEditingController amountController = TextEditingController(
      text: suggestedAmount > 0 ? suggestedAmount.toStringAsFixed(0) : '',
    );
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Request Payout',
            style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.account_balance, size: 64, color: Color(0xFF3B82F6)),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter amount in RWF',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
                  ),
                  prefix: Text(
                    'Rwf ',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF3B82F6),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Funds will be transferred to your registered bank account within 2-3 business days.',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                amountController.dispose();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid amount'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                amountController.dispose();
                _submitPayoutRequest(context, amount);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPayoutRequest(BuildContext context, double amount) async {
    try {
      final authProvider = context.read<AuthProvider>();

      final response = await authProvider.apiService.post(
        '/api/vendor/payout-request',
        {'amount': amount},
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Payout request submitted successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error'] ?? 'Failed to submit payout request'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInfoDialog(
    BuildContext context,
    bool isDarkMode,
    Color cardColor,
    Color textColor,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Earnings Info',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.info_outline, 'Your real earnings from completed orders', isDarkMode),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.schedule, 'Payout time: 2-3 business days', isDarkMode),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.account_balance, 'Paid to registered bank account', isDarkMode),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.receipt, 'Detailed statement available on web', isDarkMode),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, bool isDarkMode) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}