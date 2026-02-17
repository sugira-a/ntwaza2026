// lib/screens/rider/rider_delivery_history.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/rider_order_provider.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';

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
  static const Color accentGreen = Color(0xFF4CAF50);

  String _selectedFilter = 'all'; // all, today, week, month

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RiderOrderProvider>().fetchDeliveryHistory();
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

    return Container(
      color: isDark ? Colors.black : const Color(0xFFDADDE2),
      child: Consumer<RiderOrderProvider>(
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
              const SizedBox(height: 16),
              _buildFilterChips(isDark),
              const SizedBox(height: 16),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => prov.fetchDeliveryHistory(),
                  color: primaryColor,
                  child: filteredOrders.isEmpty
                      ? _buildEmptyFilterState(isDark)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
                color: accentGreen.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delivery_dining_outlined,
                size: 56,
                color: accentGreen,
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
                color: accentGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: accentGreen.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                '💡 Go online to start accepting orders',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accentGreen,
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
                  color: accentGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.filter_list_off_outlined,
                  size: 48,
                  color: accentGreen,
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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [successColor, const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: successColor.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Earnings',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RWF ${totalEarnings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.delivery_dining_outlined,
                  label: 'Deliveries',
                  value: '${filteredOrders.length}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.trending_up_rounded,
                  label: 'Avg Order',
                  value: filteredOrders.isNotEmpty
                      ? 'RWF ${(totalEarnings / filteredOrders.length).toStringAsFixed(0)}'
                      : 'RWF 0',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
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
            const SizedBox(width: 10),
            _buildFilterChip('Today', 'today', isDark),
            const SizedBox(width: 10),
            _buildFilterChip('This Week', 'week', isDark),
            const SizedBox(width: 10),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? accentGreen
              : isDark
                  ? const Color(0xFF1F1F1F)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? accentGreen
                : isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.15 : 0.03),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : isDark
                    ? Colors.white.withOpacity(0.75)
                    : Color(0xFF1F2937),
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Order order, bool isDark) {
    final deliveryTime = order.completedAt != null && order.acceptedAt != null
        ? order.completedAt!.difference(order.acceptedAt!).inMinutes
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.08) 
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? successColor.withOpacity(0.15) 
                        : successLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: successColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shortenOrderNumber(order.orderNumber),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : darkGray,
                        ),
                      ),
                      if (order.completedAt != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 12,
                              color: neutralGray,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatRwandaTime(order.completedAt!, 'MMM dd, yyyy'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white.withOpacity(0.6) : neutralGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.access_time_outlined,
                              size: 12,
                              color: neutralGray,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatRwandaTime(order.completedAt!, 'HH:mm'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white.withOpacity(0.6) : neutralGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? successColor.withOpacity(0.15) 
                        : successLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'RWF ${order.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: successColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info Cards
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.store_outlined,
                    label: 'Vendor',
                    value: order.vendorName,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.person_outline,
                    label: 'Customer',
                    value: order.customerName ?? 'N/A',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Stats Row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withOpacity(0.03) 
                    : lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.shopping_bag_outlined,
                    value: '${order.itemCount}',
                    label: 'Items',
                    color: primaryColor,
                    isDark: isDark,
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark 
                        ? Colors.white.withOpacity(0.08) 
                        : const Color(0xFFE2E8F0),
                  ),
                  if (deliveryTime != null)
                    _buildStatItem(
                      icon: Icons.schedule_outlined,
                      value: '$deliveryTime',
                      label: 'Minutes',
                      color: infoColor,
                      isDark: isDark,
                    )
                  else
                    _buildStatItem(
                      icon: Icons.schedule_outlined,
                      value: '-',
                      label: 'Time',
                      color: neutralGray,
                      isDark: isDark,
                    ),
                  Container(
                    width: 1,
                    height: 32,
                    color: isDark 
                        ? Colors.white.withOpacity(0.08) 
                        : const Color(0xFFE2E8F0),
                  ),
                  _buildStatItem(
                    icon: Icons.check_circle_outline,
                    value: '✓',
                    label: 'Done',
                    color: successColor,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark 
            ? Colors.white.withOpacity(0.03) 
            : lightGray,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon, 
                size: 14, 
                color: isDark ? Colors.white.withOpacity(0.5) : neutralGray,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white.withOpacity(0.5) : neutralGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : darkGray,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : darkGray,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white.withOpacity(0.5) : neutralGray,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Delivery History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
