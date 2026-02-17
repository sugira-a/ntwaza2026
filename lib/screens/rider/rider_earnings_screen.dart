import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_order_provider.dart';

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  bool _dataLoaded = false;

  @override
  void initState() {
    super.initState();
    // Load earnings data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dataLoaded && mounted) {
        _dataLoaded = true;
        final provider = context.read<RiderOrderProvider>();
        provider.fetchEarnings();
      }
    });
  }

  // Neutral palette
  static const Color primaryColor = Color(0xFF111111);
  static const Color primaryLight = Color(0xFFDADDE2);
  static const Color successColor = Color(0xFF1F1F1F);
  static const Color warningColor = Color(0xFF2A2A2A);
  static const Color darkGray = Color(0xFF0B0B0B);
  static const Color lightGray = Color(0xFFDADDE2);
  static const Color accentGreen = Color(0xFF4CAF50);
  static const LinearGradient headerGradient = LinearGradient(
    colors: [
      Color(0xFF000000),
      Color(0xFF000000),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final riderProvider = context.watch<RiderOrderProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isDark ? Colors.black : const Color(0xFFDADDE2);
    final cardColor = isDark ? Colors.black : const Color(0xFFDADDE2);
    final textColor = isDark ? Colors.white : darkGray;
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    // Get earnings data from provider, fallback to loading state
    final earnings = riderProvider.earnings;
    final isLoading = riderProvider.isLoadingEarnings;

    final totalEarnings = earnings['totalEarnings'] ?? 0.0;
    final completedDeliveries = earnings['totalDeliveries'] ?? 0;
    final averagePerDelivery = earnings['averagePerDelivery'] ?? 0.0;
    final thisMonthEarnings = earnings['thisMonthEarnings'] ?? 0.0;
    final thisWeekEarnings = earnings['thisWeekEarnings'] ?? 0.0;
    final pendingPayouts = earnings['pendingPayouts'] ?? 0.0;
    final recentDeliveries = earnings['recentDeliveries'] as List? ?? [];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          'Earnings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => riderProvider.fetchEarnings(),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: headerGradient,
          ),
        ),
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                    color: primaryColor,
                  ),
            )
          : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Earnings Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: darkGray,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                  'Total Earnings',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentGreen.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                color: accentGreen,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                              'RWF ${totalEarnings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                              'All Time',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Pending: RWF ${pendingPayouts.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Quick Stats
            Text(
              'This Period',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 28,
              height: 3,
              decoration: BoxDecoration(
                color: accentGreen,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'This Month',
                    value: 'Rwf ${thisMonthEarnings.toStringAsFixed(0)}',
                    icon: Icons.calendar_month_rounded,
                    color: successColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'This Week',
                    value: 'Rwf ${thisWeekEarnings.toStringAsFixed(0)}',
                    icon: Icons.today_rounded,
                    color: warningColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Deliveries',
                    value: '$completedDeliveries',
                    icon: Icons.local_shipping_rounded,
                    color: primaryColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'Avg. per Delivery',
                    value: 'Rwf ${averagePerDelivery.toStringAsFixed(0)}',
                    icon: Icons.show_chart_rounded,
                    color: Colors.orange,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Earnings Breakdown / Recent Deliveries
            Text(
              'Recent Deliveries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            if (recentDeliveries.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : const Color(0xFFDADDE2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'No deliveries yet',
                    style: TextStyle(color: subtextColor),
                  ),
                ),
              )
            else
              ...recentDeliveries.map<Widget>((delivery) {
                final amount = delivery['amount'] ?? 0.0;
                final orderNumber = delivery['orderNumber'] ?? 'N/A';
                final customerName = delivery['customerName'] ?? 'Unknown';
                final deliveredAt = delivery['deliveredAt'] != null
                    ? DateTime.parse(delivery['deliveredAt']).toString().split('.')[0]
                    : 'Unknown date';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRecentDeliveryItem(
                    orderNumber,
                    customerName,
                    'Rwf ${amount.toStringAsFixed(2)}',
                    deliveredAt,
                    cardColor,
                    textColor,
                    subtextColor,
                    successColor,
                  ),
                );
              }).toList(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              color: subtextColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDeliveryItem(
    String orderNumber,
    String customerName,
    String amount,
    String date,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    Color amountColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: amountColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderNumber,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customerName,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: amountColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.check_circle_rounded,
                color: amountColor,
                size: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(
    String title,
    String amount,
    String percentage,
    Color color,
    Color cardColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                percentage,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
