// lib/screens/admin/admin_dashboard_home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/admin_dashboard_service.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';
import '../../widgets/admin/notifications_panel.dart';

class AdminDashboardHome extends StatefulWidget {
  const AdminDashboardHome({super.key});

  @override
  State<AdminDashboardHome> createState() => _AdminDashboardHomeState();
}

class _AdminDashboardHomeState extends State<AdminDashboardHome> {
  // Palette — matches rider
  static const Color pureBlack = Color(0xFF0B0B0B);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color softBlack = Colors.black;
  static const Color borderGray = Color(0xFFE5E7EB);
  static const Color mutedGray = Color(0xFF6B7280);
  static const Color accentGreen = Color(0xFF4CAF50);

  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final service = AdminDashboardService(authProvider.apiService);
      final stats = await service.getStats();
      if (mounted) setState(() { _stats = stats; _isLoadingStats = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? pureBlack : const Color(0xFFDADDE2);
    final textColor = isDark ? pureWhite : pureBlack;
    final subtextColor = isDark ? Colors.white70 : mutedGray;
    final cardColor = isDark ? softBlack : const Color(0xFFDADDE2);
    final borderColor = isDark ? const Color(0xFF1F1F1F) : borderGray;
    final authProvider = context.watch<AuthProvider>();
    final greeting = _getGreeting();
    final name = authProvider.user?.fullName ?? 'Admin';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadStats();
            await context.read<AdminOrderProvider>().fetchOrders();
          },
          color: isDark ? pureWhite : pureBlack,
          child: ListView(
              padding: EdgeInsets.zero,
              children: [
              _buildHeader(isDark, textColor, subtextColor, name, greeting),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatCards(isDark, textColor, subtextColor, cardColor, borderColor),
                    const SizedBox(height: 20),
                    _buildRecentOrders(isDark, textColor, subtextColor, cardColor, borderColor),
                    const SizedBox(height: 20),
                    _buildQuickInsights(isDark, textColor, subtextColor, cardColor, borderColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = nowInRwanda().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildHeader(bool isDark, Color textColor, Color subtextColor, String name, String greeting) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final notifProvider = context.watch<NotificationProvider>();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.black),
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SizedBox(
          height: 80,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Admin avatar
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: accentGreen, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$greeting,',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Notification bell
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsPanel()),
                  ),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        const Center(child: Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22)),
                        if (notifProvider.unreadCount > 0)
                          Positioned(
                            top: 6, right: 6,
                            child: Container(
                              width: 16, height: 16,
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  notifProvider.unreadCount > 9 ? '9+' : '${notifProvider.unreadCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCards(bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final orders = context.watch<AdminOrderProvider>().orders;
    // Backend returns nested: { orders: { total }, revenue: { today }, users: { vendors, riders } }
    final statsOrders = _stats?['orders'] as Map<String, dynamic>?;
    final statsRevenue = _stats?['revenue'] as Map<String, dynamic>?;
    final statsUsers = _stats?['users'] as Map<String, dynamic>?;

    final totalOrders = statsOrders?['total'] ?? orders.length;
    final activeOrders = orders.where((o) =>
        o.status != OrderStatus.completed &&
        o.status != OrderStatus.cancelled).length;
    final revenueValue = statsRevenue?['today'] ?? orders.fold<double>(0, (s, o) => s + o.total);
    final totalRevenue = (revenueValue is num) ? revenueValue.toDouble() : 0.0;
    final totalRiders = statsUsers?['riders'] ?? 0;
    final totalVendors = statsUsers?['vendors'] ?? 0;
    
    // Count cancelled orders that need refunds (paid or completed payment status)
    final pendingRefunds = orders.where((o) => 
      o.status == OrderStatus.cancelled && 
      (o.paymentStatus == 'paid' || o.paymentStatus == 'completed')
    ).length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.receipt_long_rounded,
              label: 'Total Orders',
              value: '$totalOrders',
              color: accentGreen,
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(
              icon: Icons.local_shipping_rounded,
              label: 'Active',
              value: '$activeOrders',
              color: const Color(0xFFF59E0B),
              isDark: isDark,
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.payments_rounded,
              label: 'Revenue',
              value: '${_formatCurrency(totalRevenue)} RWF',
              color: accentGreen,
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(
              icon: Icons.store_rounded,
              label: 'Vendors',
              value: '$totalVendors',
              color: const Color(0xFF6366F1),
              isDark: isDark,
            )),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _StatCard(
              icon: Icons.two_wheeler_rounded,
              label: 'Riders',
              value: '$totalRiders',
              color: const Color(0xFF06B6D4),
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _StatCard(
              icon: Icons.currency_exchange_rounded,
              label: 'Pending Refunds',
              value: '$pendingRefunds',
              color: pendingRefunds > 0 ? const Color(0xFFEF4444) : const Color(0xFF6B7280),
              isDark: isDark,
              showBadge: pendingRefunds > 0,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentOrders(bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final orders = context.watch<AdminOrderProvider>().orders;
    final recentOrders = orders.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Orders',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3),
        ),
        const SizedBox(height: 12),
        if (recentOrders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Column(
              children: [
                Icon(Icons.inbox_rounded, size: 36, color: subtextColor.withOpacity(0.4)),
                const SizedBox(height: 8),
                Text('No orders yet', style: TextStyle(color: subtextColor, fontSize: 13)),
              ],
            ),
          )
        else
          ...recentOrders.map((order) => _buildOrderRow(order, isDark, textColor, subtextColor, cardColor, borderColor)),
      ],
    );
  }

  Widget _buildOrderRow(Order order, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final statusColor = _getStatusColor(order.status);
    final time = order.createdAt != null
        ? DateFormat('HH:mm').format(toRwandaTime(order.createdAt!))
        : '--:--';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_rounded, color: statusColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.orderNumber ?? order.id.substring(0, 8)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                ),
                const SizedBox(height: 2),
                Text(
                  '${order.vendorName} → ${order.customerName}',
                  style: TextStyle(fontSize: 11, color: subtextColor),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  order.status.displayName,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(time, style: TextStyle(fontSize: 10, color: subtextColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInsights(bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final orders = context.watch<AdminOrderProvider>().orders;
    final delivered = orders.where((o) => o.status == OrderStatus.completed).length;
    final cancelled = orders.where((o) => o.status == OrderStatus.cancelled).length;
    final pending = orders.where((o) => o.status == OrderStatus.pending).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Insights',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _InsightChip(
              label: 'Delivered', value: '$delivered',
              color: accentGreen, isDark: isDark,
            )),
            const SizedBox(width: 8),
            Expanded(child: _InsightChip(
              label: 'Cancelled', value: '$cancelled',
              color: const Color(0xFFEF4444), isDark: isDark,
            )),
            const SizedBox(width: 8),
            Expanded(child: _InsightChip(
              label: 'Pending', value: '$pending',
              color: const Color(0xFFF59E0B), isDark: isDark,
            )),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return accentGreen;
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.preparing:
        return const Color(0xFF6366F1);
      case OrderStatus.ready:
        return const Color(0xFF06B6D4);
      case OrderStatus.pickedUp:
        return const Color(0xFF8B5CF6);
      case OrderStatus.confirmed:
        return const Color(0xFF3B82F6);
      default:
        return mutedGray;
    }
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

// ─── Reusable stat card ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool fullWidth;
  final bool showBadge;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.fullWidth = false,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? Colors.black : const Color(0xFFDADDE2);
    final borderColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF0B0B0B);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: showBadge ? color.withOpacity(0.5) : borderColor, 
          width: showBadge ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (showBadge)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: cardColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: subtextColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Insight chip ───────────────────────────────────────────────────────
class _InsightChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _InsightChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? Colors.black : const Color(0xFFDADDE2);
    final borderColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF0B0B0B);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}
