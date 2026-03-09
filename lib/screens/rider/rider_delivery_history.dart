// lib/screens/rider/rider_delivery_history.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/rider_order_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';
import 'rider_order_detail.dart';

class RiderDeliveryHistory extends StatefulWidget {
  const RiderDeliveryHistory({super.key});

  @override
  State<RiderDeliveryHistory> createState() => _RiderDeliveryHistoryState();
}

class _RiderDeliveryHistoryState extends State<RiderDeliveryHistory>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final p = context.read<RiderOrderProvider>();
        if (p.deliveryHistory.isEmpty && !p.isLoadingHistory) p.fetchDeliveryHistory();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Order> _filterByTime(List<Order> orders, String filter) {
    final now = nowInRwanda();
    switch (filter) {
      case 'today':
        return orders.where((o) {
          final c = o.completedAt;
          if (c == null) return false;
          final rw = toRwandaTime(c);
          return rw.year == now.year && rw.month == now.month && rw.day == now.day;
        }).toList();
      case 'week':
        final w = now.subtract(const Duration(days: 7));
        return orders.where((o) {
          final c = o.completedAt;
          if (c == null) return false;
          return toRwandaTime(c).isAfter(w);
        }).toList();
      case 'month':
        final m = now.subtract(const Duration(days: 30));
        return orders.where((o) {
          final c = o.completedAt;
          if (c == null) return false;
          return toRwandaTime(c).isAfter(m);
        }).toList();
      default:
        return orders;
    }
  }

  List<Order> _applySearch(List<Order> orders) {
    if (_searchQuery.isEmpty) return orders;
    return orders.where((o) =>
      o.vendorName.toLowerCase().contains(_searchQuery) ||
      (o.deliveryInfo?.address ?? '').toLowerCase().contains(_searchQuery) ||
      (o.orderNumber ?? '').toLowerCase().contains(_searchQuery)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF1F2F4);
    final text = isDark ? Colors.white : Colors.black;
    final sub = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return SafeArea(
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF1F2F4),
          child: Column(children: [
            Row(children: [
              Text('Earnings',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8, color: text)),
            ]),
            const SizedBox(height: 14),
            // Search
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isDark ? null : [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                style: TextStyle(color: text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by vendor, order #...',
                  hintStyle: TextStyle(color: sub, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: sub, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // TabBar
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isDark ? null : [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(9),
                ),
                labelColor: isDark ? Colors.black : Colors.white,
                unselectedLabelColor: sub,
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                splashFactory: NoSplash.splashFactory,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Today'),
                  Tab(text: 'Week'),
                  Tab(text: 'Month'),
                ],
              ),
            ),
          ]),
        ),
        // Content
        Expanded(
          child: Consumer<RiderOrderProvider>(
            builder: (ctx, p, _) {
              if (p.isLoadingHistory) {
                return Center(child: CircularProgressIndicator(color: text, strokeWidth: 2));
              }
              return TabBarView(
                controller: _tabController,
                children: ['all', 'today', 'week', 'month'].map((filter) {
                  final filtered = _applySearch(_filterByTime(p.deliveryHistory, filter));
                  if (filtered.isEmpty) {
                    return _buildEmptyState(isDark, text, sub);
                  }
                  return RefreshIndicator(
                    onRefresh: () => p.fetchDeliveryHistory(),
                    color: text,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
                      itemCount: filtered.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) return _buildSummary(filtered, isDark, text, sub);
                        return _buildHistoryCard(filtered[i - 1], isDark, text, sub);
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildSummary(List<Order> orders, bool isDark, Color text, Color sub) {
    final totalFee = orders.fold<double>(0, (s, o) => s + o.deliveryFee);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111111), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        // Left: earnings info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RWF ${totalFee.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text('Total delivery earnings',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11, fontWeight: FontWeight.w500)),
          ]),
        ),
        // Right: delivery count badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.two_wheeler_rounded, color: Color(0xFF22C55E), size: 14),
            const SizedBox(width: 5),
            Text('${orders.length}',
                style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildHistoryCard(Order order, bool isDark, Color text, Color sub) {
    final cardBg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final time = order.completedAt != null
        ? formatRwandaTime(parseServerTime(order.completedAt.toString()), 'MMM d, h:mm a')
        : '';
    final fee = order.deliveryFee;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RiderOrderDetailScreen(order: order))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? null : [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(children: [
          // Vendor logo
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: order.vendorLogo != null && order.vendorLogo!.isNotEmpty
                ? Image.network(
                    order.vendorLogo!,
                    width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _vendorIconFallback(order, isDark),
                  )
                : _vendorIconFallback(order, isDark),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(order.vendorName,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text, letterSpacing: -0.2),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text('RWF ${fee.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: text, letterSpacing: -0.3)),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                Text(shortenOrderNumber(order.orderNumber),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sub)),
                const SizedBox(width: 6),
                Container(width: 3, height: 3,
                    decoration: BoxDecoration(color: sub, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${order.items.length} item${order.items.length != 1 ? "s" : ""}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: sub)),
                const Spacer(),
                if (time.isNotEmpty)
                  Text(time, style: TextStyle(fontSize: 10, color: sub)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _vendorIconFallback(Order order, bool isDark) {
    final isRestaurant = order.vendorName.toLowerCase().contains('restaurant');
    final iconColor = isRestaurant ? const Color(0xFF22C55E) : const Color(0xFF3B82F6);
    final iconData = isRestaurant ? Icons.restaurant_rounded : Icons.store_rounded;
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  Widget _buildEmptyState(bool isDark, Color text, Color sub) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF22C55E).withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.history_rounded, size: 40, color: Color(0xFF22C55E)),
        ),
        const SizedBox(height: 20),
        Text('No deliveries yet',
            style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Completed deliveries will appear here',
            style: TextStyle(color: sub, fontSize: 13)),
      ]),
    );
  }
}
