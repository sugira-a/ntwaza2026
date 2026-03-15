// lib/screens/admin/admin_finance_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_order_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_dashboard_service.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color mutedGray = Color(0xFF6B7280);

  String _selectedPeriod = 'today';
  Map<String, dynamic>? _revenueReport;
  bool _isLoading = true;
  String _viewMode = 'overview'; // overview, vendor, rider, pickup

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final service = AdminDashboardService(context.read<AuthProvider>().apiService);
      final report = await service.getRevenueReport(period: _selectedPeriod);
      if (mounted) setState(() { _revenueReport = report; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Order> _filterOrdersByPeriod(List<Order> orders) {
    final now = nowInRwanda();
    return orders.where((o) {
      if (o.createdAt == null) return false;
      final created = toRwandaTime(o.createdAt!);
      switch (_selectedPeriod) {
        case 'today':
          return created.year == now.year && created.month == now.month && created.day == now.day;
        case 'week':
          return now.difference(created).inDays < 7;
        case 'month':
          return now.difference(created).inDays < 30;
        case 'year':
          return created.year == now.year;
        default:
          return true;
      }
    }).toList();
  }

  Map<String, _VendorFinance> _groupByVendor(List<Order> orders) {
    final map = <String, _VendorFinance>{};
    for (final o in orders) {
      final key = o.vendorName.isEmpty ? 'Unknown' : o.vendorName;
      map.putIfAbsent(key, () => _VendorFinance(name: key));
      map[key]!.totalRevenue += o.total;
      map[key]!.orderCount += 1;
      map[key]!.deliveryFees += o.deliveryFee;
      if (o.status == OrderStatus.completed) map[key]!.completed += 1;
      if (o.status == OrderStatus.cancelled) map[key]!.cancelled += 1;
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.totalRevenue.compareTo(a.value.totalRevenue)));
  }

  Map<String, _RiderFinance> _groupByRider(List<Order> orders) {
    final map = <String, _RiderFinance>{};
    for (final o in orders) {
      final key = (o.riderName ?? '').isEmpty ? 'Unassigned' : o.riderName!;
      map.putIfAbsent(key, () => _RiderFinance(name: key));
      map[key]!.deliveryFees += o.deliveryFee;
      map[key]!.totalRevenue += o.total;
      map[key]!.totalOrders += 1;
      if (o.status == OrderStatus.completed) map[key]!.completed += 1;
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.totalRevenue.compareTo(a.value.totalRevenue)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF1F2F4);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : mutedGray;
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    final allOrders = context.watch<AdminOrderProvider>().orders;
    final filteredOrders = _filterOrdersByPeriod(allOrders);
    // Only count completed/delivered orders for revenue (not pending/cancelled)
    final completedOrders = filteredOrders.where((o) => o.status == OrderStatus.completed).toList();
    final totalRevenue = completedOrders.fold<double>(0, (s, o) => s + o.total);
    final totalDeliveryFees = completedOrders.fold<double>(0, (s, o) => s + o.deliveryFee);
    final riderRevenue = completedOrders.where((o) => o.riderName != null && o.riderName!.isNotEmpty).fold<double>(0, (s, o) => s + o.total);
    final deliveredCount = completedOrders.length;

    // Pickup revenue from backend report
    final pickupSummary = _revenueReport?['pickup_summary'] as Map<String, dynamic>?;
    final pickupRevenue = (pickupSummary?['total_revenue'] ?? 0).toDouble();
    final combinedData = _revenueReport?['combined'] as Map<String, dynamic>?;
    final combinedRevenue = (combinedData?['total_revenue'] ?? totalRevenue).toDouble();

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(color: Colors.black),
            padding: EdgeInsets.only(top: statusBarHeight),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Financial Overview',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4),
                  ),
                ),
                const SizedBox(height: 14),
                // Period selector
                _buildPeriodSelector(),
                const SizedBox(height: 14),
              ],
            ),
          ),

          // Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadReport,
              color: accentGreen,
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                  // Summary cards
                  _buildSummaryCards(combinedRevenue, totalDeliveryFees, pickupRevenue, deliveredCount, filteredOrders.length, isDark, textColor, subtextColor, cardColor, borderColor),
                  const SizedBox(height: 20),

                  // View mode toggle
                  _buildViewToggle(isDark, textColor),
                  const SizedBox(height: 14),

                  // Content based on view mode
                  if (_viewMode == 'overview')
                    _buildOverview(filteredOrders, isDark, textColor, subtextColor, cardColor, borderColor),
                  if (_viewMode == 'vendor')
                    _buildVendorBreakdown(filteredOrders, isDark, textColor, subtextColor, cardColor, borderColor),
                  if (_viewMode == 'rider')
                    _buildRiderBreakdown(filteredOrders, isDark, textColor, subtextColor, cardColor, borderColor),
                  if (_viewMode == 'pickup')
                    _buildPickupBreakdown(isDark, textColor, subtextColor, cardColor, borderColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _PeriodChip(label: 'Today', value: 'today', selected: _selectedPeriod == 'today', onTap: () { setState(() => _selectedPeriod = 'today'); _loadReport(); }),
          const SizedBox(width: 8),
          _PeriodChip(label: 'Week', value: 'week', selected: _selectedPeriod == 'week', onTap: () { setState(() => _selectedPeriod = 'week'); _loadReport(); }),
          const SizedBox(width: 8),
          _PeriodChip(label: 'Month', value: 'month', selected: _selectedPeriod == 'month', onTap: () { setState(() => _selectedPeriod = 'month'); _loadReport(); }),
          const SizedBox(width: 8),
          _PeriodChip(label: 'Year', value: 'year', selected: _selectedPeriod == 'year', onTap: () { setState(() => _selectedPeriod = 'year'); _loadReport(); }),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double revenue, double deliveryFees, double pickupRevenue, int delivered, int total, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    return Column(
      children: [
        // Main revenue card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentGreen.withOpacity(0.15), accentGreen.withOpacity(0.05)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentGreen.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Revenue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subtextColor)),
              const SizedBox(height: 4),
              Text(
                '${_formatCurrency(revenue)} RWF',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: accentGreen, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              Text(
                '$delivered delivered of $total orders',
                style: TextStyle(fontSize: 12, color: subtextColor),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryMiniCard(
                label: 'Pickup Revenue',
                value: '${_formatCurrency(pickupRevenue)} RWF',
                icon: Icons.local_shipping_rounded,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryMiniCard(
                label: 'Delivery Fees',
                value: '${_formatCurrency(deliveryFees)} RWF',
                icon: Icons.two_wheeler_rounded,
                color: const Color(0xFF3B82F6),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildViewToggle(bool isDark, Color textColor) {
    return Row(
      children: [
        _ViewToggle(label: 'Overview', selected: _viewMode == 'overview', onTap: () => setState(() => _viewMode = 'overview'), isDark: isDark),
        const SizedBox(width: 6),
        _ViewToggle(label: 'Vendor', selected: _viewMode == 'vendor', onTap: () => setState(() => _viewMode = 'vendor'), isDark: isDark),
        const SizedBox(width: 6),
        _ViewToggle(label: 'Rider', selected: _viewMode == 'rider', onTap: () => setState(() => _viewMode = 'rider'), isDark: isDark),
        const SizedBox(width: 6),
        _ViewToggle(label: 'Pickup', selected: _viewMode == 'pickup', onTap: () => setState(() => _viewMode = 'pickup'), isDark: isDark),
      ],
    );
  }

  Widget _buildOverview(List<Order> orders, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    // Revenue by status — only completed orders generate real revenue
    final delivered = orders.where((o) => o.status == OrderStatus.completed);
    final cancelled = orders.where((o) => o.status == OrderStatus.cancelled);
    final active = orders.where((o) =>
        o.status != OrderStatus.completed && o.status != OrderStatus.cancelled);

    final deliveredRevenue = delivered.fold<double>(0, (s, o) => s + o.total);
    // Show potential value of cancelled/active (informational, not counted as revenue)
    final cancelledValue = cancelled.fold<double>(0, (s, o) => s + o.total);
    final activeValue = active.fold<double>(0, (s, o) => s + o.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Revenue by Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        _StatusRevenueCard(label: 'Delivered', count: delivered.length, revenue: deliveredRevenue, color: accentGreen, isDark: isDark),
        const SizedBox(height: 8),
        _StatusRevenueCard(label: 'Active', count: active.length, revenue: activeValue, color: const Color(0xFF3B82F6), isDark: isDark),
        const SizedBox(height: 8),
        _StatusRevenueCard(label: 'Cancelled', count: cancelled.length, revenue: cancelledValue, color: const Color(0xFFEF4444), isDark: isDark),
        const SizedBox(height: 20),

        // Payment methods
        Text('Payment Methods', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        ..._buildPaymentMethodCards(orders, isDark, textColor, subtextColor, cardColor, borderColor),
      ],
    );
  }

  List<Widget> _buildPaymentMethodCards(List<Order> orders, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final methods = <String, double>{};
    final methodCounts = <String, int>{};
    for (final o in orders) {
      final method = o.paymentMethod ?? 'Unknown';
      methods[method] = (methods[method] ?? 0) + o.total;
      methodCounts[method] = (methodCounts[method] ?? 0) + 1;
    }

    final sorted = methods.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            e.key.toLowerCase().contains('momo') || e.key.toLowerCase().contains('mobile')
                ? Icons.phone_android_rounded
                : e.key.toLowerCase().contains('cash')
                    ? Icons.payments_rounded
                    : Icons.credit_card_rounded,
            color: accentGreen, size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                Text('${methodCounts[e.key]} orders', style: TextStyle(fontSize: 11, color: subtextColor)),
              ],
            ),
          ),
          Text('${_formatCurrency(e.value)} RWF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
        ],
      ),
    )).toList();
  }

  Widget _buildVendorBreakdown(List<Order> orders, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final groups = _groupByVendor(orders);
    if (groups.isEmpty) return _emptyState('No vendor data', isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vendor Revenue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        ...groups.entries.map((e) => _VendorFinanceCard(finance: e.value, isDark: isDark)),
      ],
    );
  }

  Widget _buildRiderBreakdown(List<Order> orders, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final groups = _groupByRider(orders);
    if (groups.isEmpty) return _emptyState('No rider data', isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rider Earnings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
        const SizedBox(height: 12),
        ...groups.entries.map((e) => _RiderFinanceCard(finance: e.value, isDark: isDark)),
      ],
    );
  }

  Widget _buildPickupBreakdown(bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    final pickupSummary = _revenueReport?['pickup_summary'] as Map<String, dynamic>?;
    final pickupRiders = _revenueReport?['pickup_rider_breakdown'] as List<dynamic>?;

    if (pickupSummary == null) {
      return _isLoading
          ? Center(child: Padding(padding: const EdgeInsets.all(40), child: CircularProgressIndicator(color: accentGreen)))
          : _emptyState('No pickup data available', isDark);
    }

    final totalRevenue = (pickupSummary['total_revenue'] ?? 0).toDouble();
    final deliveryFees = (pickupSummary['delivery_fees'] ?? 0).toDouble();
    final completedCount = pickupSummary['total_orders'] ?? 0;
    final allCount = pickupSummary['all_orders_count'] ?? 0;
    final riderPayouts = (pickupSummary['rider_payouts'] ?? 0).toDouble();
    final platformEarnings = (pickupSummary['platform_earnings'] ?? 0).toDouble();
    final paymentMethods = (pickupSummary['payment_methods'] as Map<String, dynamic>?) ?? {};
    final paymentMethodCounts = (pickupSummary['payment_method_counts'] as Map<String, dynamic>?) ?? {};
    final statusCounts = (pickupSummary['orders_by_status'] as Map<String, dynamic>?) ?? {};
    final revenueByStatus = (pickupSummary['revenue_by_status'] as Map<String, dynamic>?) ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pickup revenue header
        Text('Pickup Package Revenue', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textColor, letterSpacing: -0.3)),
        const SizedBox(height: 12),

        // Pickup summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFF8B5CF6).withOpacity(0.15), const Color(0xFF8B5CF6).withOpacity(0.05)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pickup Revenue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: subtextColor)),
              const SizedBox(height: 4),
              Text(
                '${_formatCurrency(totalRevenue)} RWF',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF8B5CF6), letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text('$completedCount delivered of $allCount total', style: TextStyle(fontSize: 11, color: subtextColor)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Financial split
        Row(
          children: [
            Expanded(
              child: _SummaryMiniCard(
                label: 'Rider Payouts',
                value: '${_formatCurrency(riderPayouts)} RWF',
                icon: Icons.two_wheeler_rounded,
                color: const Color(0xFF06B6D4),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryMiniCard(
                label: 'Platform Earnings',
                value: '${_formatCurrency(platformEarnings)} RWF',
                icon: Icons.account_balance_rounded,
                color: accentGreen,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Status breakdown
        if (statusCounts.isNotEmpty) ...[
          Text('Orders by Status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 10),
          ...statusCounts.entries.map((e) {
            final statusRevenue = (revenueByStatus[e.key] ?? 0).toDouble();
            final color = e.key == 'delivered' ? accentGreen
                : e.key == 'cancelled' ? const Color(0xFFEF4444)
                : const Color(0xFF3B82F6);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StatusRevenueCard(
                label: e.key[0].toUpperCase() + e.key.substring(1),
                count: (e.value as num).toInt(),
                revenue: statusRevenue,
                color: color,
                isDark: isDark,
              ),
            );
          }),
          const SizedBox(height: 14),
        ],

        // Payment methods
        if (paymentMethods.isNotEmpty) ...[
          Text('Payment Methods', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 10),
          ...paymentMethods.entries.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(
                  e.key.toLowerCase().contains('momo') || e.key.toLowerCase().contains('mobile')
                      ? Icons.phone_android_rounded
                      : e.key.toLowerCase().contains('cash')
                          ? Icons.payments_rounded
                          : Icons.credit_card_rounded,
                  color: const Color(0xFF8B5CF6), size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                      Text('${paymentMethodCounts[e.key] ?? 0} orders', style: TextStyle(fontSize: 11, color: subtextColor)),
                    ],
                  ),
                ),
                Text('${_formatCurrency((e.value as num).toDouble())} RWF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
              ],
            ),
          )),
          const SizedBox(height: 14),
        ],

        // Rider breakdown for pickups
        if (pickupRiders != null && pickupRiders.isNotEmpty) ...[
          Text('Pickup Rider Earnings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 10),
          ...pickupRiders.map((r) {
            final rider = r as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
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
                      color: const Color(0xFF8B5CF6).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF8B5CF6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rider['rider_name'] ?? 'Unknown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                        Text('${rider['delivery_count'] ?? 0} pickups', style: TextStyle(fontSize: 11, color: subtextColor)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_formatCurrency((rider['rider_payout'] ?? 0).toDouble())} RWF', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                      Text('Earned', style: TextStyle(fontSize: 9, color: subtextColor)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _emptyState(String msg, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 12),
            Text(msg, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45)),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

// ─── Data models ────────────────────────────────────────────────────
class _VendorFinance {
  final String name;
  double totalRevenue = 0;
  int orderCount = 0;
  double deliveryFees = 0;
  int completed = 0;
  int cancelled = 0;
  _VendorFinance({required this.name});
}

class _RiderFinance {
  final String name;
  double deliveryFees = 0;
  double totalRevenue = 0;
  int totalOrders = 0;
  int completed = 0;
  _RiderFinance({required this.name});
}

// ─── Period Chip ────────────────────────────────────────────────────
class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF22C55E).withOpacity(0.2) : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? const Color(0xFF22C55E).withOpacity(0.4) : Colors.transparent),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF22C55E) : Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── View Toggle ────────────────────────────────────────────────────
class _ViewToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _ViewToggle({required this.label, required this.selected, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accentGreen = const Color(0xFF22C55E);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accentGreen.withOpacity(0.15) : (isDark ? Colors.white.withOpacity(0.04) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? accentGreen.withOpacity(0.4) : (isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8)),
              width: 0.5,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? accentGreen : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Summary Mini Card ──────────────────────────────────────────────
class _SummaryMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _SummaryMiniCard({required this.label, required this.value, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: subtextColor)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─── Status Revenue Card ────────────────────────────────────────────
class _StatusRevenueCard extends StatelessWidget {
  final String label;
  final int count;
  final double revenue;
  final Color color;
  final bool isDark;

  const _StatusRevenueCard({required this.label, required this.count, required this.revenue, required this.color, required this.isDark});

  String _fmt(double a) => a.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
                Text('$count orders', style: TextStyle(fontSize: 11, color: subtextColor)),
              ],
            ),
          ),
          Text('${_fmt(revenue)} RWF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─── Vendor Finance Card ────────────────────────────────────────────
class _VendorFinanceCard extends StatelessWidget {
  final _VendorFinance finance;
  final bool isDark;

  const _VendorFinanceCard({required this.finance, required this.isDark});

  String _fmt(double a) => a.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final accentGreen = const Color(0xFF22C55E);
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.store_rounded, color: accentGreen, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(finance.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                    Text('${finance.orderCount} orders', style: TextStyle(fontSize: 11, color: subtextColor)),
                  ],
                ),
              ),
              Text('${_fmt(finance.totalRevenue)} RWF', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: accentGreen)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(label: 'Completed', value: '${finance.completed}', color: accentGreen, isDark: isDark),
              const SizedBox(width: 8),
              _MiniStat(label: 'Cancelled', value: '${finance.cancelled}', color: const Color(0xFFEF4444), isDark: isDark),
              const SizedBox(width: 8),
              _MiniStat(label: 'Del. Fees', value: '${_fmt(finance.deliveryFees)}', color: const Color(0xFF3B82F6), isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Rider Finance Card ─────────────────────────────────────────────
class _RiderFinanceCard extends StatelessWidget {
  final _RiderFinance finance;
  final bool isDark;

  const _RiderFinanceCard({required this.finance, required this.isDark});

  String _fmt(double a) => a.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    final accentGreen = const Color(0xFF22C55E);
    final cardColor = isDark ? const Color(0xFF252525) : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : const Color(0xFFE3E5E8);
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    // Show delivery fees if non-zero, otherwise show total revenue handled
    final hasDeliveryFees = finance.deliveryFees > 0;
    final displayAmount = hasDeliveryFees ? finance.deliveryFees : finance.totalRevenue;
    final displayLabel = hasDeliveryFees ? 'Earned' : 'Handled';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
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
              color: const Color(0xFF06B6D4).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.two_wheeler_rounded, color: Color(0xFF06B6D4), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(finance.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                Text('${finance.totalOrders} deliveries  •  ${finance.completed} completed', style: TextStyle(fontSize: 11, color: subtextColor)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_fmt(displayAmount)} RWF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF06B6D4))),
              Text(displayLabel, style: TextStyle(fontSize: 9, color: subtextColor)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Mini Stat ──────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _MiniStat({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, color: isDark ? Colors.white54 : const Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
