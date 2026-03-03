import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../models/order.dart';
import '../../models/pickup_order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pickup_order_provider.dart';
import '../../services/api/api_service.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  static const _brand = Color(0xFF1B5E20);
  static const _brandLight = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadOrders();
    _loadPickupOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final auth = context.read<AuthProvider>();
      final api = auth.apiService;
      if (!auth.isAuthenticated || (api.authToken ?? api.token) == null) {
        setState(() { _error = 'Please log in to view your orders.'; _isLoading = false; });
        return;
      }
      final res = await api.getOrders();
      if (res['success'] == true) {
        final list = res['orders'] ?? res['data'] ?? res['results'] ?? [];
        if (list is! List) {
          setState(() { _error = 'Unexpected response.'; _isLoading = false; });
          return;
        }
        setState(() {
          _orders = list.map((j) => Order.fromJson(j)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _isLoading = false;
        });
      } else {
        setState(() { _error = res['message'] ?? res['error'] ?? 'Failed to load orders'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _error = _parseError(e.toString()); _isLoading = false; });
    }
  }

  Future<void> _loadPickupOrders() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated || auth.user?.id == null) return;
    try {
      final provider = context.read<PickupOrderProvider>();
      await provider.fetchCustomerPickupOrders(auth.user!.id!);
    } catch (_) {}
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadOrders(), _loadPickupOrders()]);
  }

  String _parseError(String e) {
    final c = e.replaceAll('Exception: Failed to perform GET request: ', '').replaceAll('Exception: API Error: ', '').replaceAll('Exception: ', '');
    if (c.contains('401') || c.toLowerCase().contains('unauthorized')) return 'Session expired. Please log in again.';
    if (c.toLowerCase().contains('network') || c.toLowerCase().contains('connection')) return 'Network error. Check your connection.';
    return c.isEmpty ? 'Failed to load orders.' : c;
  }

  List<Order> _filtered(String f) {
    switch (f) {
      case 'active':
        return _orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.confirmed || o.status == OrderStatus.preparing || o.status == OrderStatus.ready || o.status == OrderStatus.pickedUp).toList();
      case 'completed':
        return _orders.where((o) => o.status == OrderStatus.completed).toList();
      case 'cancelled':
        return _orders.where((o) => o.status == OrderStatus.cancelled).toList();
      default:
        return _orders;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F6F8);

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar(isDark)],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOrderTab('active'),
            _buildOrderTab('completed'),
            _buildOrderTab('cancelled'),
            _buildPickupTab(),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(bool isDark) {
    final active = _filtered('active').length;
    final completed = _filtered('completed').length;
    final cancelled = _filtered('cancelled').length;
    final pickupCount = context.watch<PickupOrderProvider>().pickupOrders.length;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFF0B0F14),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : context.go('/'),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                  : [const Color(0xFF0B0F14), const Color(0xFF1B2028)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(right: -40, top: 10, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: _brandLight.withOpacity(0.12)))),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My Orders', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Text('Track your deliveries and pickups', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          color: isDark ? const Color(0xFF0D1117) : const Color(0xFF0B0F14),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: _brandLight,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              Tab(text: 'Active ($active)'),
              Tab(text: 'Completed ($completed)'),
              Tab(text: 'Cancelled ($cancelled)'),
              Tab(text: 'Pickup ($pickupCount)'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderTab(String filter) {
    if (_isLoading) return _buildShimmer();
    if (_error != null) return _buildError(_error!);
    final list = _filtered(filter);
    if (list.isEmpty) return _buildEmpty(filter);
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: _brandLight,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final o = list[i];
          return _OrderCard(order: o, onTap: () => context.push('/order/${o.id}', extra: o));
        },
      ),
    );
  }

  Widget _buildPickupTab() {
    final provider = context.watch<PickupOrderProvider>();
    final orders = [...provider.pickupOrders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (provider.isLoading) return _buildShimmer();
    if (provider.error != null) return _buildError(provider.error!);
    if (orders.isEmpty) return _buildEmptyPickup();
    return RefreshIndicator(
      onRefresh: _refreshAll,
      color: _brandLight,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _PickupCard(order: orders[i]),
      ),
    );
  }

  Widget _buildShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        height: 120,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF161B22) : Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.withOpacity(0.3)))),
      ),
    );
  }

  Widget _buildError(String msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.red.withOpacity(0.1)), child: const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28)),
            const SizedBox(height: 16),
            Text(msg, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14)),
            const SizedBox(height: 16),
            TextButton.icon(onPressed: _refreshAll, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Try again'), style: TextButton.styleFrom(foregroundColor: _brandLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String filter) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    IconData icon; String title;
    switch (filter) {
      case 'active': icon = Icons.shopping_bag_outlined; title = 'No active orders'; break;
      case 'completed': icon = Icons.check_circle_outline_rounded; title = 'No completed orders yet'; break;
      case 'cancelled': icon = Icons.cancel_outlined; title = 'No cancelled orders'; break;
      default: icon = Icons.inbox_outlined; title = 'No orders found';
    }
    return _emptyBox(icon, title, isDark);
  }

  Widget _buildEmptyPickup() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _emptyBox(Icons.local_shipping_outlined, 'No pickup orders yet', isDark,
      action: ElevatedButton.icon(
        onPressed: () => context.push('/create-pickup-order'),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Create Pickup'),
        style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _emptyBox(IconData icon, String title, bool isDark, {Widget? action}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, color: _brandLight.withOpacity(0.1)), child: Icon(icon, color: _brandLight, size: 30)),
              const SizedBox(height: 14),
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF111111))),
              const SizedBox(height: 6),
              Text('Orders will appear here.', style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
              if (action != null) ...[const SizedBox(height: 20), action],
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final st = _statusInfo(order.status);
    final card = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final pText = isDark ? Colors.white : const Color(0xFF111111);
    final sText = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: st.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(st.icon, size: 18, color: st.color)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('#${order.orderNumber}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: pText)),
                        const SizedBox(height: 2),
                        Text(_date(order.createdAt), style: TextStyle(fontSize: 11, color: sText)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: st.color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: st.color.withOpacity(0.3))),
                      child: Text(st.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: st.color)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(order.vendorName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pText), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}', style: TextStyle(fontSize: 11, color: sText)),
                  ],
                ),
                if (order.riderName != null && order.riderName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(order.riderName!, style: TextStyle(fontSize: 12, color: sText))),
                  ]),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total', style: TextStyle(fontSize: 10, color: sText)),
                      Text('RWF ${_price(order.total)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: pText)),
                    ]),
                    const Spacer(),
                    _actionButton(order.status, onTap, isDark),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(OrderStatus status, VoidCallback onTap, bool isDark) {
    final isTrackable = status == OrderStatus.pickedUp || status == OrderStatus.ready;
    if (isTrackable) {
      return ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.gps_fixed_rounded, size: 14),
        label: const Text('Track'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1B5E20), foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.white70 : const Color(0xFF374151), side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFD1D5DB)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      child: const Text('Details'),
    );
  }

  _StatusInfo _statusInfo(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending: return _StatusInfo('Pending', Icons.schedule_rounded, const Color(0xFFF59E0B));
      case OrderStatus.confirmed: return _StatusInfo('Confirmed', Icons.check_circle_rounded, const Color(0xFF3B82F6));
      case OrderStatus.preparing: return _StatusInfo('Preparing', Icons.restaurant_rounded, const Color(0xFF8B5CF6));
      case OrderStatus.ready: return _StatusInfo('Ready', Icons.done_all_rounded, const Color(0xFF10B981));
      case OrderStatus.pickedUp: return _StatusInfo('On The Way', Icons.delivery_dining_rounded, const Color(0xFF0EA5E9));
      case OrderStatus.completed: return _StatusInfo('Completed', Icons.check_circle_rounded, const Color(0xFF10B981));
      case OrderStatus.cancelled: return _StatusInfo('Cancelled', Icons.cancel_rounded, const Color(0xFFEF4444));
    }
  }

  String _date(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Today, ${DateFormat('h:mm a').format(d)}';
    if (diff.inDays == 1) return 'Yesterday, ${DateFormat('h:mm a').format(d)}';
    if (diff.inDays < 7) return DateFormat('EEEE, h:mm a').format(d);
    return DateFormat('MMM d, yyyy').format(d);
  }

  String _price(double p) => p.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _PickupCard extends StatelessWidget {
  final PickupOrder order;
  const _PickupCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final st = _pickupStatus(order.status);
    final card = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF21262D) : const Color(0xFFE5E7EB);
    final pText = isDark ? Colors.white : const Color(0xFF111111);
    final sText = isDark ? Colors.white54 : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: st.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)), child: Icon(st.icon, size: 18, color: st.color)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(order.orderNumber, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: pText)),
                  const SizedBox(height: 2),
                  Text('Scheduled: ${order.formattedScheduledTime}', style: TextStyle(fontSize: 11, color: sText)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: st.color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: st.color.withOpacity(0.3))),
                child: Text(st.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: st.color)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: border),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.trip_origin_rounded, size: 16, color: Color(0xFF4CAF50)),
            const SizedBox(width: 8),
            Expanded(child: Text(order.pickupLocation.address, style: TextStyle(fontSize: 12, color: pText), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFFEF6C00)),
            const SizedBox(width: 8),
            Expanded(child: Text(order.dropoffLocation.address, style: TextStyle(fontSize: 12, color: pText), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          if (order.riderName != null && order.riderName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF8B5CF6)),
              const SizedBox(width: 8),
              Text(order.riderName!, style: TextStyle(fontSize: 12, color: sText)),
            ]),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Total', style: TextStyle(fontSize: 10, color: sText)),
                Text('RWF ${order.totalAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: pText)),
              ]),
              const Spacer(),
              Text(order.itemCountDisplay, style: TextStyle(fontSize: 11, color: sText)),
            ],
          ),
        ],
      ),
    );
  }

  _StatusInfo _pickupStatus(PickupOrderStatus s) {
    switch (s) {
      case PickupOrderStatus.pending: return _StatusInfo('Pending', Icons.schedule_rounded, const Color(0xFFF59E0B));
      case PickupOrderStatus.confirmed: return _StatusInfo('Confirmed', Icons.check_circle_rounded, const Color(0xFF3B82F6));
      case PickupOrderStatus.assignedToRider: return _StatusInfo('Assigned', Icons.person_pin_rounded, const Color(0xFF8B5CF6));
      case PickupOrderStatus.pickedUp: return _StatusInfo('Picked Up', Icons.inventory_2_rounded, const Color(0xFF0EA5E9));
      case PickupOrderStatus.inTransit: return _StatusInfo('In Transit', Icons.delivery_dining_rounded, const Color(0xFF0EA5E9));
      case PickupOrderStatus.delivered: return _StatusInfo('Delivered', Icons.check_circle_rounded, const Color(0xFF10B981));
      case PickupOrderStatus.cancelled: return _StatusInfo('Cancelled', Icons.cancel_rounded, const Color(0xFFEF4444));
    }
  }
}

class _StatusInfo {
  final String label;
  final IconData icon;
  final Color color;
  _StatusInfo(this.label, this.icon, this.color);
}
