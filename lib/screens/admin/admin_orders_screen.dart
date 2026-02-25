// lib/screens/admin/admin_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_order_provider.dart';
import '../../services/admin_dashboard_service.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> with SingleTickerProviderStateMixin {
  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color mutedGray = Color(0xFF6B7280);

  late TabController _tabController;
  String _selectedFilter = 'all';
  String? _selectedVendor;
  String? _selectedRider;
  final _searchController = TextEditingController();

  // Vendor / Rider lists
  List<Map<String, dynamic>> _vendors = [];
  List<Map<String, dynamic>> _riders = [];
  bool _loadingFilters = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFilterData());
  }

  Future<void> _loadFilterData() async {
    try {
      final service = AdminDashboardService(context.read<AuthProvider>().apiService);
      final vendorsResult = await service.getVendors();
      final ridersResult = await service.getRiders();
      if (mounted) {
        setState(() {
          _vendors = List<Map<String, dynamic>>.from(vendorsResult['vendors'] ?? []);
          _riders = List<Map<String, dynamic>>.from(ridersResult['riders'] ?? []);
          _loadingFilters = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingFilters = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Order> _applyFilters(List<Order> orders) {
    var filtered = List<Order>.from(orders);

    // Status filter
    if (_selectedFilter == 'stale') {
      filtered = filtered.where((o) => _isOrderStale(o)).toList();
    } else if (_selectedFilter == 'pending_refunds') {
      // Filter for cancelled orders that need refunds (paid/completed payment status)
      filtered = filtered.where((o) => 
        o.status == OrderStatus.cancelled && 
        (o.paymentStatus == 'paid' || o.paymentStatus == 'completed')
      ).toList();
    } else if (_selectedFilter != 'all') {
      final statusMap = {
        'pending': OrderStatus.pending,
        'preparing': OrderStatus.preparing,
        'ready': OrderStatus.ready,
        'picked_up': OrderStatus.pickedUp,
        'on_the_way': OrderStatus.pickedUp,
        'delivered': OrderStatus.completed,
        'cancelled': OrderStatus.cancelled,
      };
      final target = statusMap[_selectedFilter];
      if (target != null) filtered = filtered.where((o) => o.status == target).toList();
    }

    // Vendor filter
    if (_selectedVendor != null) {
      filtered = filtered.where((o) => o.vendorId == _selectedVendor).toList();
    }

    // Rider filter
    if (_selectedRider != null) {
      filtered = filtered.where((o) => o.riderId == _selectedRider).toList();
    }

    // Search
    final q = _searchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered.where((o) {
        return o.customerName.toLowerCase().contains(q) ||
            o.vendorName.toLowerCase().contains(q) ||
            (o.riderName ?? '').toLowerCase().contains(q) ||
            (o.orderNumber ?? '').toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  Map<String, List<Order>> _groupByVendor(List<Order> orders) {
    final map = <String, List<Order>>{};
    for (final o in orders) {
      final key = o.vendorName.isEmpty ? 'Unknown Vendor' : o.vendorName;
      map.putIfAbsent(key, () => []).add(o);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length)));
  }

  Map<String, List<Order>> _groupByRider(List<Order> orders) {
    final map = <String, List<Order>>{};
    for (final o in orders) {
      final key = (o.riderName ?? '').isEmpty ? 'Unassigned' : o.riderName!;
      map.putIfAbsent(key, () => []).add(o);
    }
    return Map.fromEntries(map.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0B) : const Color(0xFFDADDE2);
    final textColor = isDark ? Colors.white : const Color(0xFF0B0B0B);
    final subtextColor = isDark ? Colors.white70 : mutedGray;
    final cardColor = isDark ? Colors.black : const Color(0xFFDADDE2);
    final borderColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final statusBarHeight = MediaQuery.of(context).padding.top;

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
                    'Order Management',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4),
                  ),
                ),
                const SizedBox(height: 14),
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search orders, vendors, riders...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4), size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  indicatorColor: accentGreen,
                  indicatorWeight: 2.5,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.4),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'All Orders'),
                    Tab(text: 'By Vendor'),
                    Tab(text: 'By Rider'),
                  ],
                ),
              ],
            ),
          ),
          // Filters
          _buildFilterRow(isDark, textColor, subtextColor),
          // Content
          Expanded(
            child: Consumer<AdminOrderProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.orders.isEmpty) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
                }

                final filtered = _applyFilters(provider.orders);

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllOrdersList(filtered, isDark, textColor, subtextColor, cardColor, borderColor),
                    _buildGroupedList(_groupByVendor(filtered), Icons.store_rounded, isDark, textColor, subtextColor, cardColor, borderColor),
                    _buildGroupedList(_groupByRider(filtered), Icons.two_wheeler_rounded, isDark, textColor, subtextColor, cardColor, borderColor),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(bool isDark, Color textColor, Color subtextColor) {
    final chipBg = isDark ? Colors.white.withOpacity(0.06) : Colors.white;
    final chipBorder = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          _FilterChip(label: 'All', selected: _selectedFilter == 'all', onTap: () => setState(() => _selectedFilter = 'all'), chipBg: chipBg, chipBorder: chipBorder),
          _FilterChip(label: '⚠ Stale', selected: _selectedFilter == 'stale', onTap: () => setState(() => _selectedFilter = 'stale'), chipBg: chipBg, chipBorder: chipBorder, isWarning: true),
          _FilterChip(label: 'Pending', selected: _selectedFilter == 'pending', onTap: () => setState(() => _selectedFilter = 'pending'), chipBg: chipBg, chipBorder: chipBorder),
          _FilterChip(label: 'Preparing', selected: _selectedFilter == 'preparing', onTap: () => setState(() => _selectedFilter = 'preparing'), chipBg: chipBg, chipBorder: chipBorder),
          _FilterChip(label: 'Ready', selected: _selectedFilter == 'ready', onTap: () => setState(() => _selectedFilter = 'ready'), chipBg: chipBg, chipBorder: chipBorder),
          _FilterChip(label: 'On the Way', selected: _selectedFilter == 'on_the_way', onTap: () => setState(() => _selectedFilter = 'on_the_way'), chipBg: chipBg, chipBorder: chipBorder),
          _FilterChip(label: 'Delivered', selected: _selectedFilter == 'delivered', onTap: () => setState(() => _selectedFilter = 'delivered'), chipBg: chipBg, chipBorder: chipBorder),
          _FilterChip(label: 'Cancelled', selected: _selectedFilter == 'cancelled', onTap: () => setState(() => _selectedFilter = 'cancelled'), chipBg: chipBg, chipBorder: chipBorder),
          _FilterChip(label: '💳 Refunds', selected: _selectedFilter == 'pending_refunds', onTap: () => setState(() => _selectedFilter = 'pending_refunds'), chipBg: chipBg, chipBorder: chipBorder, isWarning: true),
          const SizedBox(width: 8),
          // Vendor dropdown
          _buildDropdownChip(
            label: _selectedVendor == null ? 'Vendor' : _vendors.firstWhere((v) => v['id']?.toString() == _selectedVendor, orElse: () => {'business_name': 'Vendor'})['business_name'] ?? 'Vendor',
            items: _vendors.map((v) => DropdownMenuItem(value: v['id']?.toString(), child: Text(v['business_name']?.toString() ?? 'Unknown', style: TextStyle(fontSize: 12)))).toList(),
            value: _selectedVendor,
            onChanged: (val) => setState(() => _selectedVendor = val),
            isDark: isDark,
            chipBg: chipBg,
            chipBorder: chipBorder,
          ),
          const SizedBox(width: 6),
          // Rider dropdown
          _buildDropdownChip(
            label: _selectedRider == null ? 'Rider' : _riders.firstWhere((r) => r['id']?.toString() == _selectedRider, orElse: () => {'name': 'Rider'})['name'] ?? 'Rider',
            items: _riders.map((r) => DropdownMenuItem(value: r['id']?.toString(), child: Text(r['name']?.toString() ?? 'Unknown', style: TextStyle(fontSize: 12)))).toList(),
            value: _selectedRider,
            onChanged: (val) => setState(() => _selectedRider = val),
            isDark: isDark,
            chipBg: chipBg,
            chipBorder: chipBorder,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required List<DropdownMenuItem<String>> items,
    required String? value,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    required Color chipBg,
    required Color chipBorder,
  }) {
    final isActive = value != null;
    return GestureDetector(
      onTap: () {
        if (isActive) {
          onChanged(null);
          return;
        }
        showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? const Color(0xFF111111) : Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => _buildPickerSheet(label, items, onChanged, isDark, ctx),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? accentGreen.withOpacity(0.15) : chipBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? accentGreen.withOpacity(0.4) : chipBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? accentGreen : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive ? Icons.close_rounded : Icons.arrow_drop_down_rounded,
              size: 16,
              color: isActive ? accentGreen : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerSheet(String title, List<DropdownMenuItem<String>> items, ValueChanged<String?> onChanged, bool isDark, BuildContext ctx) {
    final textColor = isDark ? Colors.white : Colors.black;
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('Select $title', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textColor)),
                const Spacer(),
                IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return ListTile(
                  title: item.child,
                  onTap: () {
                    onChanged(item.value);
                    Navigator.pop(ctx);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── All Orders List ──────────────────────────────────────────────
  Widget _buildAllOrdersList(List<Order> orders, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    if (orders.isEmpty) return _buildEmptyState('No orders found', isDark);

    return RefreshIndicator(
      onRefresh: () => context.read<AdminOrderProvider>().fetchOrders(),
      color: accentGreen,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: orders.length,
        itemBuilder: (context, i) => _OrderCard(order: orders[i], isDark: isDark, isStale: _isOrderStale(orders[i]), onTap: () => _showOrderDetail(orders[i])),
      ),
    );
  }

  // ─── Grouped List (by Vendor or Rider) ────────────────────────────
  Widget _buildGroupedList(Map<String, List<Order>> groups, IconData icon, bool isDark, Color textColor, Color subtextColor, Color cardColor, Color borderColor) {
    if (groups.isEmpty) return _buildEmptyState('No orders found', isDark);

    return RefreshIndicator(
      onRefresh: () => context.read<AdminOrderProvider>().fetchOrders(),
      color: accentGreen,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: groups.length,
        itemBuilder: (context, i) {
          final name = groups.keys.elementAt(i);
          final groupOrders = groups[name]!;
          final revenue = groupOrders.fold<double>(0.0, (s, o) => s + o.total);

          return _ExpandableGroup(
            name: name,
            icon: icon,
            orderCount: groupOrders.length,
            revenue: revenue,
            isDark: isDark,
            orders: groupOrders,
            onOrderTap: _showOrderDetail,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String msg, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: isDark ? Colors.white24 : Colors.black26),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 14)),
        ],
      ),
    );
  }

  bool _isOrderStale(Order order) {
    if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) return false;
    final now = nowInRwanda();
    final created = toRwandaTime(order.createdAt);
    final minutes = now.difference(created).inMinutes;
    if (order.status == OrderStatus.pending) return minutes > 5;
    if (order.status == OrderStatus.confirmed) return minutes > 15;
    if (order.status == OrderStatus.preparing) return minutes > 30;
    if (order.status == OrderStatus.ready) return minutes > 10;
    if (order.status == OrderStatus.pickedUp) return minutes > 45;
    return false;
  }

  void _showOrderDetail(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Filter Chip
// ═══════════════════════════════════════════════════════════════════════
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color chipBg;
  final Color chipBorder;
  final bool isWarning;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.chipBg,
    required this.chipBorder,
    this.isWarning = false,
  });

  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color warningRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final activeColor = isWarning ? warningRed : accentGreen;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? activeColor.withOpacity(0.15) : chipBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? activeColor.withOpacity(0.4) : chipBorder, width: 0.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? activeColor : (isWarning ? warningRed.withOpacity(0.7) : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : const Color(0xFF6B7280))),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Expandable Group
// ═══════════════════════════════════════════════════════════════════════
class _ExpandableGroup extends StatefulWidget {
  final String name;
  final IconData icon;
  final int orderCount;
  final double revenue;
  final bool isDark;
  final List<Order> orders;
  final ValueChanged<Order> onOrderTap;

  const _ExpandableGroup({
    required this.name,
    required this.icon,
    required this.orderCount,
    required this.revenue,
    required this.isDark,
    required this.orders,
    required this.onOrderTap,
  });

  @override
  State<_ExpandableGroup> createState() => _ExpandableGroupState();
}

class _ExpandableGroupState extends State<_ExpandableGroup> {
  bool _expanded = false;

  static const Color accentGreen = Color(0xFF4CAF50);

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? Colors.black : const Color(0xFFDADDE2);
    final borderColor = widget.isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final textColor = widget.isDark ? Colors.white : const Color(0xFF0B0B0B);
    final subtextColor = widget.isDark ? Colors.white70 : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: Column(
        children: [
          // Group header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: accentGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, color: accentGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.orderCount} orders  •  ${_formatCurrency(widget.revenue)} RWF',
                          style: TextStyle(fontSize: 11, color: subtextColor),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, color: subtextColor),
                  ),
                ],
              ),
            ),
          ),
          // Expanded orders
          if (_expanded)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: borderColor, width: 0.5)),
              ),
              child: Column(
                children: widget.orders.map((o) => _OrderCard(
                  order: o,
                  isDark: widget.isDark,
                  compact: true,
                  isStale: _isOrderStaleStatic(o),
                  onTap: () => widget.onOrderTap(o),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Order Card
// ═══════════════════════════════════════════════════════════════════════
// Top-level stale check for use in widgets outside _AdminOrdersScreenState
bool _isOrderStaleStatic(Order order) {
  if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) return false;
  final now = nowInRwanda();
  final created = toRwandaTime(order.createdAt);
  final minutes = now.difference(created).inMinutes;
  if (order.status == OrderStatus.pending) return minutes > 5;
  if (order.status == OrderStatus.confirmed) return minutes > 15;
  if (order.status == OrderStatus.preparing) return minutes > 30;
  if (order.status == OrderStatus.ready) return minutes > 10;
  if (order.status == OrderStatus.pickedUp) return minutes > 45;
  return false;
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool isDark;
  final bool compact;
  final bool isStale;
  final VoidCallback? onTap;

  const _OrderCard({
    required this.order,
    required this.isDark,
    this.compact = false,
    this.isStale = false,
    this.onTap,
  });

  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color warningRed = Color(0xFFEF4444);

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed: return accentGreen;
      case OrderStatus.cancelled: return const Color(0xFFEF4444);
      case OrderStatus.pending: return const Color(0xFFF59E0B);
      case OrderStatus.preparing: return const Color(0xFF6366F1);
      case OrderStatus.ready: return const Color(0xFF06B6D4);
      case OrderStatus.pickedUp: return const Color(0xFF8B5CF6);
      case OrderStatus.confirmed: return const Color(0xFF3B82F6);
      default: return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : const Color(0xFF0B0B0B);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
    final statusColor = _getStatusColor(order.status);
    final time = order.createdAt != null
        ? DateFormat('MMM d, HH:mm').format(toRwandaTime(order.createdAt!))
        : '--';

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(compact ? 12 : 14),
        margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
        decoration: compact
            ? BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor, width: 0.3)),
                color: isStale ? warningRed.withOpacity(0.05) : null,
              )
            : BoxDecoration(
                color: isStale
                    ? (isDark ? warningRed.withOpacity(0.08) : warningRed.withOpacity(0.04))
                    : (isDark ? Colors.black : const Color(0xFFDADDE2)),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isStale ? warningRed.withOpacity(0.5) : borderColor,
                  width: isStale ? 1.2 : 0.5,
                ),
              ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4, height: 36,
              decoration: BoxDecoration(
                color: isStale ? warningRed : statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${order.orderNumber ?? order.id.substring(0, 8)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
                      ),
                      if (isStale) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: warningRed.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 10, color: warningRed),
                              const SizedBox(width: 3),
                              Text('STALE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: warningRed, letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
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
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.vendorName}  →  ${order.customerName}',
                    style: TextStyle(fontSize: 11, color: subtextColor),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.two_wheeler_rounded, size: 12, color: subtextColor.withOpacity(0.6)),
                      const SizedBox(width: 4),
                      Text(
                        order.riderName ?? 'Unassigned',
                        style: TextStyle(fontSize: 10, color: isStale ? warningRed.withOpacity(0.8) : subtextColor.withOpacity(0.7)),
                      ),
                      const Spacer(),
                      Text(
                        '${order.total.toStringAsFixed(0)} RWF',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                      ),
                      const SizedBox(width: 8),
                      Text(time, style: TextStyle(fontSize: 10, color: subtextColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
