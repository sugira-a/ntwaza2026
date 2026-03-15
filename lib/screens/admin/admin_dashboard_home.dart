// lib/screens/admin/admin_dashboard_home.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/pickup_order_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/admin_dashboard_service.dart';
import '../../models/order.dart';
import '../../models/pickup_order.dart';
import '../../utils/helpers.dart';
import '../../widgets/admin/notifications_panel.dart';
import 'admin_order_detail_screen.dart';

class AdminDashboardHome extends StatefulWidget {
  const AdminDashboardHome({super.key});

  @override
  State<AdminDashboardHome> createState() => _AdminDashboardHomeState();
}

class _AdminDashboardHomeState extends State<AdminDashboardHome> {
  static const Color _accent = Color(0xFF22C55E);

  Map<String, dynamic>? _stats;
  bool _isLoadingStats = true;
  List<Map<String, dynamic>> _riders = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
      _loadRiders();
      _loadPickupOrders();
    });
  }

  Future<void> _loadStats() async {
    try {
      final auth = context.read<AuthProvider>();
      final service = AdminDashboardService(auth.apiService);
      final stats = await service.getStats();
      if (mounted) setState(() { _stats = stats; _isLoadingStats = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadRiders() async {
    try {
      final auth = context.read<AuthProvider>();
      final service = AdminDashboardService(auth.apiService);
      final result = await service.getRiders();
      if (mounted) {
        setState(() => _riders = List<Map<String, dynamic>>.from(result['riders'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadPickupOrders() async {
    try {
      await context.read<PickupOrderProvider>().fetchAllPickupOrders();
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadStats(),
      _loadRiders(),
      _loadPickupOrders(),
      context.read<AdminOrderProvider>().fetchOrders(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FA);
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final card = isDark ? const Color(0xFF252525) : Colors.white;
    final border = isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB);
    final auth = context.watch<AuthProvider>();
    final name = auth.user?.firstName?.trim().isNotEmpty == true
        ? auth.user!.firstName!.trim()
        : 'Admin';

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: _accent,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(name, isDark)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusGrid(isDark, text, sub, card, border),
                    const SizedBox(height: 24),
                    _buildQuickActions(isDark, text, sub, card, border),
                    const SizedBox(height: 24),
                    _buildUnassignedOrders(isDark, text, sub, card, border),
                    const SizedBox(height: 24),
                    _buildPickupOrders(isDark, text, sub, card, border),
                    const SizedBox(height: 24),
                    _buildRecentOrders(isDark, text, sub, card, border),
                    const SizedBox(height: 24),
                    _buildInsights(isDark, text, sub, card, border),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════ HEADER ══════════

  Widget _buildHeader(String name, bool isDark) {
    final statusBarH = MediaQuery.of(context).padding.top;
    final notifProvider = context.watch<NotificationProvider>();

    return Container(
      color: isDark ? const Color(0xFF111111) : Colors.black,
      padding: EdgeInsets.fromLTRB(20, statusBarH + 10, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Admin Dashboard', style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ],
            ),
          ),
          _headerIconBtn(
            icon: Icons.notifications_none_rounded,
            badge: notifProvider.unreadCount,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPanel())),
          ),
        ],
      ),
    );
  }

  Widget _headerIconBtn({required IconData icon, int? badge, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Center(child: Icon(icon, color: Colors.white, size: 20)),
          if (badge != null && badge > 0)
            Positioned(right: -3, top: -3,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(badge > 9 ? '9+' : '$badge',
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ),
            ),
        ]),
      ),
    );
  }

  // ══════════ STATUS GRID ══════════

  Widget _buildStatusGrid(bool isDark, Color text, Color sub, Color card, Color border) {
    final orders = context.watch<AdminOrderProvider>().orders;
    final statsOrders = _stats?['orders'] as Map<String, dynamic>?;
    final statsRevenue = _stats?['revenue'] as Map<String, dynamic>?;
    final statsUsers = _stats?['users'] as Map<String, dynamic>?;

    final total = statsOrders?['total'] ?? orders.length;
    final active = orders.where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled).length;
    final pending = orders.where((o) => o.status == OrderStatus.pending).length;
    final rev = (statsRevenue?['today'] ?? orders.fold<double>(0, (s, o) => s + o.total));
    final revenue = (rev is num) ? rev.toDouble() : 0.0;
    final riders = statsUsers?['riders'] ?? 0;

    return Column(children: [
      Container(
        width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: border),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TODAY\'S ORDERS', style: TextStyle(color: sub, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('$total', style: TextStyle(color: text, fontSize: 38, fontWeight: FontWeight.w900, height: 1, letterSpacing: -2)),
          ])),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _accent.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.receipt_long_rounded, color: _accent, size: 24),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _gridCard('Active', '$active', Colors.orange, isDark, card, border, sub, text)),
        const SizedBox(width: 12),
        Expanded(child: _gridCard('Pending', '$pending', const Color(0xFFF59E0B), isDark, card, border, sub, text)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _gridCard('Riders', '$riders', const Color(0xFF06B6D4), isDark, card, border, sub, text)),
        const SizedBox(width: 12),
        Expanded(child: _earningsCard(revenue, isDark)),
      ]),
    ]);
  }

  Widget _gridCard(String label, String value, Color color, bool isDark, Color card, Color border, Color sub, Color text) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label.toUpperCase(), style: TextStyle(color: sub, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1, letterSpacing: -1, color: text)),
      ]),
    );
  }

  Widget _earningsCard(double revenue, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF000000), Color(0xFF1A1A1A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          const Text('REVENUE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        Text(_fmtCurrency(revenue), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, height: 1, letterSpacing: -0.5, color: Colors.white)),
        const SizedBox(height: 2),
        const Text('RWF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white54)),
      ]),
    );
  }

  // ══════════ QUICK ACTIONS ══════════

  Widget _buildQuickActions(bool isDark, Color text, Color sub, Color card, Color border) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.5)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _actionTile(Icons.local_shipping_rounded, 'Manage\nPickups', const Color(0xFF3B82F6), isDark, card, border, text, () {})),
        const SizedBox(width: 10),
        Expanded(child: _actionTile(Icons.person_add_rounded, 'Assign\nRiders', const Color(0xFF8B5CF6), isDark, card, border, text, () {})),
        const SizedBox(width: 10),
        Expanded(child: _actionTile(Icons.analytics_rounded, 'View\nReports', const Color(0xFFF59E0B), isDark, card, border, text, () {})),
      ]),
    ]);
  }

  Widget _actionTile(IconData icon, String label, Color color, bool isDark, Color card, Color border, Color text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border),
          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: text, height: 1.3), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  // ══════════ UNASSIGNED ORDERS (Customer orders needing rider) ══════════

  Widget _buildUnassignedOrders(bool isDark, Color text, Color sub, Color card, Color border) {
    final orders = context.watch<AdminOrderProvider>().orders;
    final unassigned = orders.where((o) =>
        (o.status == OrderStatus.pending || o.status == OrderStatus.confirmed || o.status == OrderStatus.ready) &&
        (o.riderId == null || o.riderId!.isEmpty)).toList();

    if (unassigned.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Needs Rider Assignment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.5)),
        const SizedBox(width: 8),
        _badge('${unassigned.length}', const Color(0xFFF59E0B)),
      ]),
      const SizedBox(height: 4),
      Text('Customer orders awaiting rider', style: TextStyle(fontSize: 12, color: sub)),
      const SizedBox(height: 12),
      ...unassigned.take(5).map((order) => _buildUnassignedCard(order, isDark, text, sub, card, border)),
    ]);
  }

  Widget _buildUnassignedCard(Order order, bool isDark, Color text, Color sub, Color card, Color border) {
    final statusColor = _statusColor(order.status);
    final time = order.createdAt != null ? DateFormat('HH:mm').format(toRwandaTime(order.createdAt!)) : '--:--';
    final elapsed = order.createdAt != null ? nowInRwanda().difference(toRwandaTime(order.createdAt!)).inMinutes : 0;
    final isUrgent = elapsed > 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUrgent ? const Color(0xFFF59E0B).withOpacity(0.5) : border, width: isUrgent ? 1.5 : 1),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.receipt_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${order.orderNumber ?? order.id.substring(0, 8)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
            const SizedBox(height: 2),
            Text('${order.vendorName} \u2192 ${order.customerName}',
                style: TextStyle(fontSize: 11, color: sub), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(order.status.displayName.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 4),
            Text(isUrgent ? '${elapsed}m ago' : time,
                style: TextStyle(fontSize: 10, color: isUrgent ? const Color(0xFFF59E0B) : sub, fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order))),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text))),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _showAssignRiderSheet(order),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Text('Assign Rider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  // ══════════ PICKUP ORDERS ══════════

  Widget _buildPickupOrders(bool isDark, Color text, Color sub, Color card, Color border) {
    final pickupProvider = context.watch<PickupOrderProvider>();
    final pickups = pickupProvider.pickupOrders.where((o) =>
        o.status == PickupOrderStatus.pending ||
        o.status == PickupOrderStatus.confirmed ||
        o.status == PickupOrderStatus.assignedToRider).toList();

    if (pickups.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Pickup Packages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.5)),
        const SizedBox(width: 8),
        _badge('${pickups.length}', const Color(0xFF3B82F6)),
      ]),
      const SizedBox(height: 4),
      Text('Customer package pickups & deliveries', style: TextStyle(fontSize: 12, color: sub)),
      const SizedBox(height: 12),
      ...pickups.take(5).map((order) => _buildPickupCard(order, isDark, text, sub, card, border)),
    ]);
  }

  Widget _buildPickupCard(PickupOrder order, bool isDark, Color text, Color sub, Color card, Color border) {
    final hasRider = order.riderId != null && order.riderId!.isNotEmpty;
    final statusColor = _pickupStatusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF3B82F6), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pickup #${order.orderNumber}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
            const SizedBox(height: 2),
            Text('${order.customerName} \u00b7 ${order.items.length} item${order.items.length != 1 ? "s" : ""}',
                style: TextStyle(fontSize: 11, color: sub), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Text(order.statusDisplay.toUpperCase(),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.5)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.circle, size: 8, color: _accent),
          const SizedBox(width: 8),
          Expanded(child: Text(order.pickupLocation.address, style: TextStyle(fontSize: 11, color: sub), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Container(width: 2, height: 12, color: border),
        ),
        Row(children: [
          const Icon(Icons.location_on, size: 8, color: Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(child: Text(order.dropoffLocation.address, style: TextStyle(fontSize: 11, color: sub), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text('RWF ${order.totalAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: text)),
          const Spacer(),
          if (!hasRider)
            GestureDetector(
              onTap: () => _showAssignRiderForPickup(order),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: _accent, borderRadius: BorderRadius.circular(8)),
                child: const Text('Assign Rider', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.two_wheeler, size: 14, color: _accent),
                const SizedBox(width: 6),
                Text(order.riderName ?? 'Assigned', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _accent)),
              ]),
            ),
        ]),
      ]),
    );
  }

  // ══════════ RECENT ORDERS ══════════

  Widget _buildRecentOrders(bool isDark, Color text, Color sub, Color card, Color border) {
    final orders = context.watch<AdminOrderProvider>().orders;
    final recent = orders.take(5).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Recent Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.5)),
      const SizedBox(height: 12),
      if (recent.isEmpty)
        _buildEmpty(Icons.inbox_rounded, 'No orders yet', 'Orders will appear as they come in', isDark, text, sub, card, border)
      else
        ...recent.map((order) => _buildOrderCard(order, isDark, text, sub, card, border)),
    ]);
  }

  Widget _buildOrderCard(Order order, bool isDark, Color text, Color sub, Color card, Color border) {
    final statusColor = _statusColor(order.status);
    final time = order.createdAt != null ? DateFormat('HH:mm').format(toRwandaTime(order.createdAt!)) : '--:--';
    final hasRider = order.riderId != null && order.riderId!.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(Icons.receipt_rounded, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('#${order.orderNumber ?? order.id.substring(0, 8)}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text)),
              if (hasRider) ...[
                const SizedBox(width: 6),
                Icon(Icons.two_wheeler, size: 12, color: _accent),
              ],
            ]),
            const SizedBox(height: 2),
            Text('${order.vendorName} \u2192 ${order.customerName}',
                style: TextStyle(fontSize: 11, color: sub), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(order.status.displayName.toUpperCase(),
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor, letterSpacing: 0.3)),
            ),
            const SizedBox(height: 4),
            Text(time, style: TextStyle(fontSize: 10, color: sub)),
          ]),
        ]),
      ),
    );
  }

  // ══════════ INSIGHTS ══════════

  Widget _buildInsights(bool isDark, Color text, Color sub, Color card, Color border) {
    final orders = context.watch<AdminOrderProvider>().orders;
    final delivered = orders.where((o) => o.status == OrderStatus.completed).length;
    final cancelled = orders.where((o) => o.status == OrderStatus.cancelled).length;
    final refunds = orders.where((o) =>
        o.status == OrderStatus.cancelled &&
        (o.paymentStatus == 'paid' || o.paymentStatus == 'completed')).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Quick Insights', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.5)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _insightCard('Delivered', '$delivered', _accent, isDark, card, border, text)),
        const SizedBox(width: 8),
        Expanded(child: _insightCard('Cancelled', '$cancelled', const Color(0xFFEF4444), isDark, card, border, text)),
        const SizedBox(width: 8),
        Expanded(child: _insightCard('Refunds', '$refunds', const Color(0xFFF59E0B), isDark, card, border, text)),
      ]),
    ]);
  }

  Widget _insightCard(String label, String value, Color color, bool isDark, Color card, Color border, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text.withOpacity(0.5))),
      ]),
    );
  }

  // ══════════ ASSIGN RIDER — Vendor Orders ══════════

  void _showAssignRiderSheet(Order order) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB);

    showModalBottomSheet(
      context: context, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55, minChildSize: 0.3, maxChildSize: 0.8, expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Assign Rider', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
            const SizedBox(height: 4),
            Text('Order #${order.orderNumber ?? order.id.substring(0, 8)} \u00b7 ${order.vendorName}', style: TextStyle(fontSize: 13, color: sub)),
            const SizedBox(height: 16),
            Divider(color: border),
            const SizedBox(height: 8),
            Expanded(
              child: _riders.isEmpty
                  ? Center(child: Text('No riders available', style: TextStyle(color: sub)))
                  : ListView.separated(
                      controller: scrollController, itemCount: _riders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _riderListTile(_riders[i], text, sub, border, (rider) => _assignRiderToOrder(order, rider, ctx)),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _assignRiderToOrder(Order order, Map<String, dynamic> rider, BuildContext sheetCtx) async {
    final riderId = rider['id']?.toString() ?? '';
    if (riderId.isEmpty) return;
    Navigator.pop(sheetCtx);
    try {
      final auth = context.read<AuthProvider>();
      final service = AdminDashboardService(auth.apiService);
      await service.assignOrderToRider(orderId: order.id, riderId: riderId);
      await context.read<AdminOrderProvider>().fetchOrders();
      if (mounted) _showSnack('Rider assigned to #${order.orderNumber ?? order.id.substring(0, 8)}', false);
    } catch (e) {
      if (mounted) _showSnack('Failed to assign rider', true);
    }
  }

  // ══════════ ASSIGN RIDER — Pickup Orders ══════════

  void _showAssignRiderForPickup(PickupOrder order) {
    final isDark = context.read<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final border = isDark ? Colors.grey[800]! : const Color(0xFFE5E7EB);

    showModalBottomSheet(
      context: context, backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55, minChildSize: 0.3, maxChildSize: 0.8, expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('Assign Rider to Pickup', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
            const SizedBox(height: 4),
            Text('Pickup #${order.orderNumber} \u00b7 ${order.customerName}', style: TextStyle(fontSize: 13, color: sub)),
            const SizedBox(height: 16),
            Divider(color: border),
            const SizedBox(height: 8),
            Expanded(
              child: _riders.isEmpty
                  ? Center(child: Text('No riders available', style: TextStyle(color: sub)))
                  : ListView.separated(
                      controller: scrollController, itemCount: _riders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _riderListTile(_riders[i], text, sub, border, (rider) => _assignRiderToPickup(order, rider, ctx)),
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _assignRiderToPickup(PickupOrder order, Map<String, dynamic> rider, BuildContext sheetCtx) async {
    final riderId = rider['id']?.toString() ?? '';
    final riderName = (rider['full_name'] ?? rider['name'] ?? 'Rider').toString();
    final riderPhone = (rider['phone'] ?? '').toString();
    if (riderId.isEmpty) return;
    Navigator.pop(sheetCtx);
    try {
      final provider = context.read<PickupOrderProvider>();
      final ok = await provider.assignRiderToOrder(order.id, riderId, riderName, riderPhone);
      if (ok) await provider.fetchAllPickupOrders();
      if (mounted) _showSnack(ok ? 'Rider assigned to pickup #${order.orderNumber}' : 'Failed to assign rider', !ok);
    } catch (e) {
      if (mounted) _showSnack('Failed to assign rider', true);
    }
  }

  // ══════════ SHARED HELPERS ══════════

  Widget _riderListTile(Map<String, dynamic> rider, Color text, Color sub, Color border, void Function(Map<String, dynamic>) onSelect) {
    final rName = rider['full_name'] ?? rider['name'] ?? 'Rider';
    final rPhone = rider['phone'] ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelect(rider),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: _accent.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(Icons.two_wheeler, color: _accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$rName', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
              if (rPhone.toString().isNotEmpty)
                Text('$rPhone', style: TextStyle(fontSize: 11, color: sub)),
            ])),
            Icon(Icons.arrow_forward_ios, size: 14, color: sub),
          ]),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildEmpty(IconData icon, String title, String message, bool isDark, Color text, Color sub, Color card, Color border) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
      child: Column(children: [
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _accent.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: _accent)),
        const SizedBox(height: 12),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
        const SizedBox(height: 4),
        Text(message, style: TextStyle(fontSize: 12, color: sub), textAlign: TextAlign.center),
      ]),
    );
  }

  void _showSnack(String message, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      backgroundColor: isError ? Colors.red : _accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed: return _accent;
      case OrderStatus.cancelled: return const Color(0xFFEF4444);
      case OrderStatus.pending: return const Color(0xFFF59E0B);
      case OrderStatus.preparing: return const Color(0xFF6366F1);
      case OrderStatus.ready: return const Color(0xFF06B6D4);
      case OrderStatus.pickedUp: return const Color(0xFF8B5CF6);
      case OrderStatus.confirmed: return const Color(0xFF3B82F6);
      default: return const Color(0xFF6B7280);
    }
  }

  Color _pickupStatusColor(PickupOrderStatus status) {
    switch (status) {
      case PickupOrderStatus.pending: return const Color(0xFFF59E0B);
      case PickupOrderStatus.confirmed: return const Color(0xFF3B82F6);
      case PickupOrderStatus.assignedToRider: return const Color(0xFF8B5CF6);
      case PickupOrderStatus.inTransit: return const Color(0xFF06B6D4);
      case PickupOrderStatus.delivered: return _accent;
      default: return const Color(0xFF6B7280);
    }
  }

  String _fmtCurrency(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
