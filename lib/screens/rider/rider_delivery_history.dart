// lib/screens/rider/rider_delivery_history.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/rider_order_provider.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';
import './rider_order_detail.dart' show RiderOrderDetailScreen;

class RiderDeliveryHistory extends StatefulWidget {
  const RiderDeliveryHistory({super.key});

  @override
  State<RiderDeliveryHistory> createState() => _RiderDeliveryHistoryState();
}

class _RiderDeliveryHistoryState extends State<RiderDeliveryHistory> {
  // Neutral palette + green accent
  static const Color primaryColor = Color(0xFF111111);
  static const Color successColor = Color(0xFF1F1F1F);
  static const Color successLight = Color(0xFFDADDE2);
  static const Color infoColor = Color(0xFF111111);
  static const Color infoLight = Color(0xFFDADDE2);
  static const Color neutralGray = Color(0xFF6B7280);
  static const Color lightGray = Color(0xFFE5E7EB);
  static const Color darkGray = Color(0xFF0B0B0B);
  static const Color bgLight = Color(0xFFFFFFFF);
  static const Color accentBlack = Color(0xFF1A1A1A);

  String _selectedFilter = 'all'; // all, today, week, month

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RiderOrderProvider>().fetchDeliveryHistory();
      }
    });
  }

  List<Order> _filterOrders(List<Order> orders) {
    final now = nowInRwanda();
    
    switch (_selectedFilter) {
      case 'today':
        return orders.where((order) {
          final completedAt = order.completedAt;
          if (completedAt == null) return false;
          final rwandaCompletedAt = toRwandaTime(completedAt);
          return rwandaCompletedAt.year == now.year &&
                 rwandaCompletedAt.month == now.month &&
                 rwandaCompletedAt.day == now.day;
        }).toList();
      case 'week':
        final weekAgo = now.subtract(const Duration(days: 7));
        return orders.where((order) {
          final completedAt = order.completedAt;
          if (completedAt == null) return false;
          final rwandaCompletedAt = toRwandaTime(completedAt);
          return rwandaCompletedAt.isAfter(weekAgo);
        }).toList();
      case 'month':
        final monthAgo = now.subtract(const Duration(days: 30));
        return orders.where((order) {
          final completedAt = order.completedAt;
          if (completedAt == null) return false;
          final rwandaCompletedAt = toRwandaTime(completedAt);
          return rwandaCompletedAt.isAfter(monthAgo);
        }).toList();
      default:
        return orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/rider');
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFDADDE2),
        body: Consumer<RiderOrderProvider>(
        builder: (context, prov, _) {
          if (prov.isLoadingHistory) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: primaryColor,
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading history...',
                    style: TextStyle(
                      color: isDark ? Colors.white.withOpacity(0.6) : neutralGray,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (prov.deliveryHistory.isEmpty) {
            return Column(
              children: [
                _buildHeader(isDark),
                Expanded(child: _buildEmptyState(isDark)),
              ],
            );
          }

          final filteredOrders = _filterOrders(prov.deliveryHistory);
          final totalEarnings = filteredOrders.fold<double>(
            0,
            (sum, order) => sum + order.total,
          );

          return Column(
            children: [
              _buildHeader(isDark),
              _buildStatsHeader(filteredOrders, totalEarnings, isDark),
              const SizedBox(height: 12),
              _buildFilterChips(isDark),
              const SizedBox(height: 12),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => prov.fetchDeliveryHistory(),
                  color: primaryColor,
                  child: filteredOrders.isEmpty
                      ? _buildEmptyFilterState(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            return _buildHistoryCard(context, order, isDark);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delivery_dining_outlined,
                size: 56,
                color: Colors.black.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Delivery History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Color(0xFF0B0B0B),
                letterSpacing: -0.5,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your completed deliveries will appear here',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white.withOpacity(0.65) : Color(0xFF6B7280),
                height: 1.6,
                letterSpacing: -0.2,
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.black.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                '💡 Go online to start accepting orders',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withOpacity(0.6),
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFilterState(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.filter_list_off_outlined,
                  size: 48,
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Deliveries Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Color(0xFF0B0B0B),
                  letterSpacing: -0.3,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filter',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white.withOpacity(0.65) : Color(0xFF6B7280),
                  letterSpacing: -0.2,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(List<Order> filteredOrders, double totalEarnings, bool isDark) {
    final avgOrderValue = filteredOrders.isNotEmpty
        ? totalEarnings / filteredOrders.length
        : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.04) 
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          // Main earnings row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Earnings',
                    style: TextStyle(
                      color: isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RWF ${totalEarnings.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0B0B0B),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  color: Color(0xFF4CAF50),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Compact stats row
          Row(
            children: [
              Expanded(
                child: _buildCompactStatCard(
                  icon: Icons.local_shipping_outlined,
                  label: 'Deliveries',
                  value: '${filteredOrders.length}',
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactStatCard(
                  icon: Icons.trending_up_rounded,
                  label: 'Avg',
                  value: 'RWF ${avgOrderValue.toStringAsFixed(0)}',
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF6B7280),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0B0B0B),
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF6B7280),
              fontSize: 10,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All Time', 'all', isDark),
            const SizedBox(width: 8),
            _buildFilterChip('Today', 'today', isDark),
            const SizedBox(width: 8),
            _buildFilterChip('This Week', 'week', isDark),
            const SizedBox(width: 8),
            _buildFilterChip('This Month', 'month', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _selectedFilter == value;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.4),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : isDark
                  ? const Color(0xFF1A1A1A)
                  : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : isDark
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : isDark
                        ? Colors.white.withOpacity(0.7)
                        : const Color(0xFF1F2937),
                letterSpacing: -0.2,
                decoration: TextDecoration.none,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.check_rounded,
                size: 12,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Order order, bool isDark) {
    // Calculate actual delivery time from acceptedAt to completedAt
    int? deliveryTime;
    if (order.acceptedAt != null && order.completedAt != null) {
      final difference = order.completedAt!.difference(order.acceptedAt!).inMinutes;
      deliveryTime = difference > 0 ? difference : null;
    } else if (order.createdAt != null && order.completedAt != null) {
      final difference = order.completedAt!.difference(order.createdAt!).inMinutes;
      deliveryTime = difference > 0 ? difference : null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.04) 
              : const Color(0xFFE5E7EB),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RiderOrderDetailScreen(order: order),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${shortenOrderNumber(order.orderNumber)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0B0B0B),
                              letterSpacing: -0.2,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (order.completedAt != null)
                            Text(
                              formatRwandaTime(order.completedAt!, 'MMM dd, HH:mm'),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark 
                                    ? Colors.white.withOpacity(0.5) 
                                    : const Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.none,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'RWF ${order.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4CAF50),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Info Cards Row
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactInfoCard(
                        icon: Icons.store_outlined,
                        label: 'Vendor',
                        value: order.vendorName,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildCompactInfoCard(
                        icon: Icons.person_outline,
                        label: 'Customer',
                        value: order.customerName ?? 'N/A',
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Stats Row with Dividers
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withOpacity(0.02) 
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.04)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCompactStatItem(
                        icon: Icons.shopping_bag_outlined,
                        value: '${order.items.length}',
                        label: 'Items',
                        isDark: isDark,
                      ),
                      _buildCompactVerticalDivider(isDark),
                      if (deliveryTime != null)
                        _buildCompactStatItem(
                          icon: Icons.schedule_outlined,
                          value: '${deliveryTime}m',
                          label: 'Time',
                          isDark: isDark,
                        )
                      else
                        _buildCompactStatItem(
                          icon: Icons.schedule_outlined,
                          value: '-',
                          label: 'Time',
                          isDark: isDark,
                        ),
                      _buildCompactVerticalDivider(isDark),
                      _buildCompactStatItem(
                        icon: Icons.check_circle_rounded,
                        value: '✓',
                        label: 'Done',
                        isDark: isDark,
                        accentColor: const Color(0xFF4CAF50),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.03) 
            : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon, 
                size: 12, 
                color: isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF6B7280),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0B0B0B),
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactVerticalDivider(bool isDark) {
    return Container(
      width: 0.5,
      height: 24,
      color: isDark 
          ? Colors.white.withOpacity(0.06) 
          : const Color(0xFFE5E7EB),
    );
  }

  Widget _buildCompactStatItem({
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
    Color? accentColor,
  }) {
    final iconColor = accentColor ?? (isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF6B7280));
    final valueColor = accentColor ?? (isDark ? Colors.white : const Color(0xFF0B0B0B));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white.withOpacity(0.4) : const Color(0xFF6B7280),
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(bool isDark) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SizedBox(
          height: 72,
          child: Center(
            child: Text(
              'Delivery History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.4,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
