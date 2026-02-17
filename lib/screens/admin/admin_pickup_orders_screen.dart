// lib/screens/admin/admin_pickup_orders_screen.dart
// PREMIUM ADMIN ORDERS SCREEN - Pure Black Professional Design
// Features: All orders from vendors, riders, customer data access, beautiful UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../../models/pickup_order.dart';
import '../../providers/pickup_order_provider.dart';
import '../../providers/rider_provider.dart';
import '../../providers/vendor_order_provider.dart';
import '../../utils/helpers.dart';
import 'package:go_router/go_router.dart';

// Premium Color Palette - Pure Black Theme
class _Colors {
  static const background = Color(0xFF0B0B0B);
  static const surface = Color(0xFF000000);
  static const card = Color(0xFF111111);
  static const primary = Color(0xFF4CAF50);
  static const accent = Color(0xFF3B82F6);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const purple = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF06B6D4);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFF1F1F1F);
}

class AdminPickupOrdersScreen extends StatefulWidget {
  const AdminPickupOrdersScreen({super.key});

  @override
  State<AdminPickupOrdersScreen> createState() => _AdminPickupOrdersScreenState();
}

class _AdminPickupOrdersScreenState extends State<AdminPickupOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _sourceFilter = 'all';
  bool _isLoading = true;
  int _totalOrders = 0;
  int _pendingCount = 0;
  int _inTransitCount = 0;
  int _completedToday = 0;
  Timer? _refreshTimer;
  static const int _autoRefreshSeconds = 15;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAllData();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: _autoRefreshSeconds),
      (_) => _loadAllData(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final pickupProvider = context.read<PickupOrderProvider>();
      await pickupProvider.fetchAllPickupOrders();
      final vendorProvider = context.read<VendorOrderProvider>();
      await vendorProvider.fetchOrders();
      _calculateStats();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _calculateStats() {
    final pickupProvider = context.read<PickupOrderProvider>();
    final vendorProvider = context.read<VendorOrderProvider>();
    final pickupOrders = pickupProvider.pickupOrders;
    final vendorOrders = vendorProvider.orders;
    _totalOrders = pickupOrders.length + vendorOrders.length;
    _pendingCount = pickupOrders.where((o) => o.status == PickupOrderStatus.pending || o.status == PickupOrderStatus.confirmed).length;
    _inTransitCount = pickupOrders.where((o) => o.status == PickupOrderStatus.inTransit || o.status == PickupOrderStatus.assignedToRider).length;
    final today = nowInRwanda();
    _completedToday = pickupOrders.where((o) => o.status == PickupOrderStatus.delivered && o.createdAt.day == today.day && o.createdAt.month == today.month && o.createdAt.year == today.year).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchFilter(),
            _buildStatsRow(),
            _buildTabBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildAllOrdersTab(),
                        _buildOrdersListByStatus(PickupOrderStatus.pending),
                        _buildOrdersListByStatus(PickupOrderStatus.assignedToRider),
                        _buildOrdersListByStatus(PickupOrderStatus.inTransit),
                        _buildOrdersListByStatus(PickupOrderStatus.delivered),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_Colors.surface, _Colors.background], begin: Alignment.topCenter, end: Alignment.bottomCenter),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: _Colors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _Colors.border)),
            child: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_back_ios_new, color: _Colors.textPrimary, size: 20)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Orders Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _Colors.textPrimary)),
                Text('$_totalOrders total orders', style: const TextStyle(fontSize: 14, color: _Colors.textSecondary)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [_Colors.primary, _Colors.primary.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12)),
            child: IconButton(onPressed: _loadAllData, icon: const Icon(Icons.refresh, color: Colors.white), tooltip: 'Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _Colors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _Colors.border)),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(color: _Colors.surface, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: _Colors.textPrimary),
              decoration: const InputDecoration(hintText: 'Search by order #, customer, rider...', hintStyle: TextStyle(color: _Colors.textSecondary), prefixIcon: Icon(Icons.search, color: _Colors.textSecondary), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All Sources', 'all', Icons.apps),
                const SizedBox(width: 8),
                _buildFilterChip('Vendor Orders', 'vendor', Icons.store),
                const SizedBox(width: 8),
                _buildFilterChip('Pickup Orders', 'pickup', Icons.local_shipping),
                const SizedBox(width: 8),
                _buildFilterChip('Customer Direct', 'customer', Icons.person),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _sourceFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _sourceFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? LinearGradient(colors: [_Colors.primary, _Colors.primary.withOpacity(0.7)]) : null,
          color: isSelected ? null : _Colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? _Colors.primary : _Colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : _Colors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : _Colors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Pending', _pendingCount, _Colors.warning, Icons.schedule)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('In Transit', _inTransitCount, _Colors.accent, Icons.local_shipping)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('Today', _completedToday, _Colors.primary, Icons.check_circle)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _Colors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
          const SizedBox(height: 8),
          Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: _Colors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: _Colors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _Colors.border)),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(gradient: LinearGradient(colors: [_Colors.primary, _Colors.primary.withOpacity(0.7)]), borderRadius: BorderRadius.circular(12)),
        labelColor: Colors.white,
        unselectedLabelColor: _Colors.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.all(4),
        tabs: const [Tab(text: '  All  '), Tab(text: ' Pending '), Tab(text: ' Assigned '), Tab(text: ' Transit '), Tab(text: ' Done ')],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: _Colors.card, shape: BoxShape.circle), child: const CircularProgressIndicator(color: _Colors.primary, strokeWidth: 3)),
          const SizedBox(height: 16),
          const Text('Loading orders...', style: TextStyle(color: _Colors.textSecondary, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildAllOrdersTab() {
    return Consumer2<PickupOrderProvider, VendorOrderProvider>(
      builder: (context, pickupProvider, vendorProvider, _) {
        List<dynamic> allOrders = [];
        if (_sourceFilter == 'all' || _sourceFilter == 'pickup') {
          allOrders.addAll(pickupProvider.pickupOrders.map((o) => {'type': 'pickup', 'order': o}));
        }
        if (_sourceFilter == 'all' || _sourceFilter == 'vendor') {
          allOrders.addAll(vendorProvider.orders.map((o) => {'type': 'vendor', 'order': o}));
        }
        if (_searchQuery.isNotEmpty) {
          allOrders = allOrders.where((item) {
            if (item['type'] == 'pickup') {
              final o = item['order'] as PickupOrder;
              return o.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) || o.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) || (o.riderName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
            } else {
              final o = item['order'];
              return (o['order_number']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) || (o['customer_name']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
            }
          }).toList();
        }
        if (allOrders.isEmpty) return _buildEmptyState('No orders found');
        return RefreshIndicator(
          onRefresh: _loadAllData,
          color: _Colors.primary,
          backgroundColor: _Colors.card,
          child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: allOrders.length, itemBuilder: (context, index) {
            final item = allOrders[index];
            if (item['type'] == 'pickup') return _buildPremiumOrderCard(item['order'] as PickupOrder);
            return _buildVendorOrderCard(item['order']);
          }),
        );
      },
    );
  }

  Widget _buildOrdersListByStatus(PickupOrderStatus status) {
    return Consumer<PickupOrderProvider>(
      builder: (context, provider, _) {
        var orders = provider.pickupOrders.where((o) => o.status == status).toList();
        if (_searchQuery.isNotEmpty) {
          orders = orders.where((o) => o.orderNumber.toLowerCase().contains(_searchQuery.toLowerCase()) || o.customerName.toLowerCase().contains(_searchQuery.toLowerCase()) || (o.riderName?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)).toList();
        }
        if (orders.isEmpty) return _buildEmptyState('No ${status.displayName} orders');
        return RefreshIndicator(onRefresh: _loadAllData, color: _Colors.primary, backgroundColor: _Colors.card, child: ListView.builder(padding: const EdgeInsets.all(20), itemCount: orders.length, itemBuilder: (context, index) => _buildPremiumOrderCard(orders[index])));
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _Colors.card, shape: BoxShape.circle, border: Border.all(color: _Colors.border)), child: const Icon(Icons.inbox_outlined, size: 48, color: _Colors.textSecondary)),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _Colors.textSecondary)),
          const SizedBox(height: 8),
          TextButton.icon(onPressed: _loadAllData, icon: const Icon(Icons.refresh, color: _Colors.primary), label: const Text('Refresh', style: TextStyle(color: _Colors.primary))),
        ],
      ),
    );
  }

  Widget _buildPremiumOrderCard(PickupOrder order) {
    final statusColor = _getStatusColor(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: _Colors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _Colors.border), boxShadow: [BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showOrderDetailsSheet(order),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _Colors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.local_shipping, color: _Colors.primary, size: 20)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('#${order.orderNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _Colors.textPrimary)),
                            Text(formatRwandaTime(order.createdAt, 'MMM dd, HH:mm'), style: const TextStyle(fontSize: 12, color: _Colors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                    _buildStatusBadge(order.status),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _Colors.surface, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _Colors.accent.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.person, color: _Colors.accent, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(order.customerName, style: const TextStyle(fontWeight: FontWeight.w600, color: _Colors.textPrimary)),
                            Text(order.customerPhone, style: const TextStyle(fontSize: 12, color: _Colors.textSecondary)),
                          ],
                        ),
                      ),
                      _buildActionButton(Icons.phone, _Colors.primary, () => _callNumber(order.customerPhone)),
                      const SizedBox(width: 8),
                      _buildActionButton(Icons.message, _Colors.accent, () => _sendSMS(order.customerPhone)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildLocationChip(Icons.circle, _Colors.warning, order.pickupLocation.address, 'Pickup'),
                const SizedBox(height: 8),
                Row(children: [Container(width: 2, height: 20, margin: const EdgeInsets.only(left: 11), decoration: BoxDecoration(gradient: LinearGradient(colors: [_Colors.warning, _Colors.primary], begin: Alignment.topCenter, end: Alignment.bottomCenter)))]),
                const SizedBox(height: 8),
                _buildLocationChip(Icons.location_on, _Colors.primary, order.dropoffLocation.address, 'Dropoff'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _Colors.surface, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.inventory_2, size: 14, color: _Colors.textSecondary), const SizedBox(width: 4), Text('${order.items.length} items', style: const TextStyle(fontSize: 12, color: _Colors.textSecondary))])),
                        const SizedBox(width: 8),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _Colors.surface, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.scale, size: 14, color: _Colors.textSecondary), const SizedBox(width: 4), Text('${order.totalWeightKg}kg', style: const TextStyle(fontSize: 12, color: _Colors.textSecondary))])),
                      ],
                    ),
                    if (order.riderName != null)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _Colors.purple.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: _Colors.purple.withOpacity(0.3))), child: Row(children: [const Icon(Icons.motorcycle, size: 14, color: _Colors.purple), const SizedBox(width: 4), Text(order.riderName!, style: const TextStyle(fontSize: 12, color: _Colors.purple, fontWeight: FontWeight.w600))]))
                    else if (order.status == PickupOrderStatus.pending || order.status == PickupOrderStatus.confirmed)
                      GestureDetector(
                        onTap: () => _showAssignRiderDialog(order),
                        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(gradient: LinearGradient(colors: [_Colors.accent, _Colors.accent.withOpacity(0.7)]), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.person_add, size: 14, color: Colors.white), SizedBox(width: 4), Text('Assign', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))])),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVendorOrderCard(Map<String, dynamic> order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: _Colors.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: _Colors.border), boxShadow: [BoxShadow(color: _Colors.warning.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _Colors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.store, color: _Colors.warning, size: 20)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${order['order_number'] ?? 'N/A'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _Colors.textPrimary)),
                        const Text('Vendor Order', style: TextStyle(fontSize: 12, color: _Colors.warning)),
                      ],
                    ),
                  ],
                ),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _Colors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: _Colors.warning.withOpacity(0.3))), child: Text(order['status'] ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _Colors.warning))),
              ],
            ),
            const SizedBox(height: 16),
            if (order['customer_name'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _Colors.surface, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _Colors.accent.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.person, color: _Colors.accent, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(order['customer_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, color: _Colors.textPrimary)),
                          if (order['customer_phone'] != null) Text(order['customer_phone'], style: const TextStyle(fontSize: 12, color: _Colors.textSecondary)),
                        ],
                      ),
                    ),
                    if (order['customer_phone'] != null) ...[_buildActionButton(Icons.phone, _Colors.primary, () => _callNumber(order['customer_phone'])), const SizedBox(width: 8), _buildActionButton(Icons.message, _Colors.accent, () => _sendSMS(order['customer_phone']))],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount', style: TextStyle(color: _Colors.textSecondary)),
                Text('RWF ${(order['total_amount'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _Colors.primary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)));
  }

  Widget _buildLocationChip(IconData icon, Color color, String address, String label) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _Colors.surface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                Text(address, style: const TextStyle(fontSize: 13, color: _Colors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PickupOrderStatus status) {
    final color = _getStatusColor(status);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))), child: Text(status.displayName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)));
  }

  Color _getStatusColor(PickupOrderStatus status) {
    switch (status) {
      case PickupOrderStatus.pending: return _Colors.warning;
      case PickupOrderStatus.confirmed: return _Colors.accent;
      case PickupOrderStatus.assignedToRider: return _Colors.purple;
      case PickupOrderStatus.pickedUp: return _Colors.cyan;
      case PickupOrderStatus.inTransit: return _Colors.accent;
      case PickupOrderStatus.delivered: return _Colors.primary;
      case PickupOrderStatus.cancelled: return _Colors.danger;
    }
  }

  Future<void> _callNumber(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendSMS(String phone) async {
    final uri = Uri.parse('sms:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showOrderDetailsSheet(PickupOrder order) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => _OrderDetailsSheet(order: order, onAssignRider: () => _showAssignRiderDialog(order)));
  }

  void _showAssignRiderDialog(PickupOrder order) {
    showDialog(context: context, builder: (context) => _PremiumAssignRiderDialog(order: order, onRefresh: _loadAllData));
  }
}

class _OrderDetailsSheet extends StatelessWidget {
  final PickupOrder order;
  final VoidCallback onAssignRider;
  const _OrderDetailsSheet({required this.order, required this.onAssignRider});

  String? _extractPickupCode(String? notes) {
    if (notes == null || notes.trim().isEmpty) return null;
    final match = RegExp(r'Pickup code\s*:\s*(\d{4,6})', caseSensitive: false).firstMatch(notes);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final pickupCode = _extractPickupCode(order.notes);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(color: _Colors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _Colors.border, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Order Details', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _Colors.textPrimary)),
                        const SizedBox(height: 4),
                        Text('#${order.orderNumber}', style: const TextStyle(fontSize: 16, color: _Colors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    _buildStatusBadge(order.status),
                  ],
                ),
                const SizedBox(height: 24),
                _buildSection('Customer Information', Icons.person, _Colors.accent, [_DetailRow('Name', order.customerName), _DetailRow('Phone', order.customerPhone, isPhone: true), _DetailRow('Email', order.customerEmail)]),
                const SizedBox(height: 16),
                _buildSection('Pickup Location', Icons.circle, _Colors.warning, [_DetailRow('Address', order.pickupLocation.address), if (order.pickupLocation.phoneNumber != null) _DetailRow('Contact', order.pickupLocation.phoneNumber!, isPhone: true)]),
                const SizedBox(height: 16),
                _buildSection('Dropoff Location', Icons.location_on, _Colors.primary, [_DetailRow('Address', order.dropoffLocation.address), if (order.dropoffLocation.phoneNumber != null) _DetailRow('Contact', order.dropoffLocation.phoneNumber!, isPhone: true)]),
                const SizedBox(height: 16),
                _buildSection('Items (${order.items.length})', Icons.inventory_2, _Colors.purple, order.items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.description, style: const TextStyle(color: _Colors.textPrimary, fontWeight: FontWeight.w500)), Text('${item.category} • ${item.estimatedWeight}kg • Qty: ${item.quantity}', style: const TextStyle(fontSize: 12, color: _Colors.textSecondary))]))).toList()),
                const SizedBox(height: 16),
                _buildSection('Payment', Icons.payment, _Colors.primary, [_DetailRow('Method', order.paymentMethod), _DetailRow('Delivery Fee', 'RWF ${order.deliveryFee.toStringAsFixed(0)}'), _DetailRow('Total', 'RWF ${order.totalAmount.toStringAsFixed(0)}', isBold: true), _DetailRow('Status', order.isPaid ? 'Paid ✓' : 'Pending', isSuccess: order.isPaid)]),
                if (pickupCode != null) ...[
                  const SizedBox(height: 16),
                  _buildSection('Verification', Icons.verified, _Colors.primary, [
                    _DetailRow('Pickup Code', pickupCode, isBold: true),
                  ]),
                ],
                if (order.riderId != null) ...[const SizedBox(height: 16), _buildSection('Assigned Rider', Icons.motorcycle, _Colors.purple, [_DetailRow('Name', order.riderName ?? 'N/A'), _DetailRow('Phone', order.riderPhone ?? 'N/A', isPhone: true)])],
                const SizedBox(height: 24),
                if (order.status == PickupOrderStatus.pending || order.status == PickupOrderStatus.confirmed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () { Navigator.pop(context); onAssignRider(); },
                      style: ElevatedButton.styleFrom(backgroundColor: _Colors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Assign Rider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _Colors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _Colors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)), const SizedBox(width: 12), Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _Colors.textPrimary))]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusBadge(PickupOrderStatus status) {
    Color color;
    switch (status) { case PickupOrderStatus.pending: color = _Colors.warning; break; case PickupOrderStatus.confirmed: color = _Colors.accent; break; case PickupOrderStatus.assignedToRider: color = _Colors.purple; break; case PickupOrderStatus.inTransit: color = _Colors.cyan; break; case PickupOrderStatus.delivered: color = _Colors.primary; break; default: color = _Colors.danger; }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))), child: Text(status.displayName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)));
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isSuccess;
  final bool isPhone;
  const _DetailRow(this.label, this.value, {this.isBold = false, this.isSuccess = false, this.isPhone = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _Colors.textSecondary)),
          if (isPhone)
            GestureDetector(
              onTap: () async { final uri = Uri.parse('tel:$value'); if (await canLaunchUrl(uri)) await launchUrl(uri); },
              child: Row(children: [Text(value, style: TextStyle(color: _Colors.accent, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)), const SizedBox(width: 4), const Icon(Icons.phone, size: 14, color: _Colors.accent)]),
            )
          else
            Flexible(child: Text(value, style: TextStyle(color: isSuccess ? _Colors.primary : _Colors.textPrimary, fontWeight: isBold ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _PremiumAssignRiderDialog extends StatefulWidget {
  final PickupOrder order;
  final VoidCallback onRefresh;
  const _PremiumAssignRiderDialog({required this.order, required this.onRefresh});
  @override
  State<_PremiumAssignRiderDialog> createState() => _PremiumAssignRiderDialogState();
}

class _PremiumAssignRiderDialogState extends State<_PremiumAssignRiderDialog> {
  String? _selectedRiderId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(color: _Colors.surface, borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _Colors.accent.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_add, color: _Colors.accent, size: 24)), const SizedBox(width: 16), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Assign Rider', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _Colors.textPrimary)), Text('Select an available rider', style: TextStyle(fontSize: 13, color: _Colors.textSecondary))]))]),
            const SizedBox(height: 24),
            Consumer<RiderProvider>(
              builder: (context, riderProvider, _) {
                final availableRiders = riderProvider.riders.where((r) => r['is_available'] == true).toList();
                if (availableRiders.isEmpty) return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _Colors.card, borderRadius: BorderRadius.circular(12)), child: const Column(children: [Icon(Icons.person_off, size: 48, color: _Colors.textSecondary), SizedBox(height: 12), Text('No available riders', style: TextStyle(color: _Colors.textSecondary))]));
                return Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableRiders.length,
                    itemBuilder: (context, index) {
                      final rider = availableRiders[index];
                      final isSelected = _selectedRiderId == rider['id'];
                      return GestureDetector(
                        onTap: () => setState(() => _selectedRiderId = rider['id'] as String),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: isSelected ? _Colors.accent.withOpacity(0.15) : _Colors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? _Colors.accent : _Colors.border, width: isSelected ? 2 : 1)),
                          child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: _Colors.accent.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.person, color: _Colors.accent)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(rider['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600, color: _Colors.textPrimary)), Text(rider['phone'] ?? '', style: const TextStyle(fontSize: 12, color: _Colors.textSecondary))])), if (isSelected) Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: _Colors.accent, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 16))]),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _Colors.border))), child: const Text('Cancel', style: TextStyle(color: _Colors.textSecondary)))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedRiderId == null || _isLoading ? null : () => _assignRider(context),
                    style: ElevatedButton.styleFrom(backgroundColor: _Colors.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), disabledBackgroundColor: _Colors.accent.withOpacity(0.3)),
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Assign Rider', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignRider(BuildContext context) async {
    if (_selectedRiderId == null) return;
    final riderProvider = context.read<RiderProvider>();
    final selectedRider = riderProvider.riders.firstWhere((r) => r['id'] == _selectedRiderId);
    setState(() => _isLoading = true);
    final provider = context.read<PickupOrderProvider>();
    final success = await provider.assignRiderToOrder(widget.order.id, selectedRider['id'] as String, selectedRider['name'] as String, selectedRider['phone'] as String);
    setState(() => _isLoading = false);
    if (mounted) {
      Navigator.pop(context);
      widget.onRefresh();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Rider assigned successfully!' : 'Failed to assign rider', style: const TextStyle(color: Colors.white)), backgroundColor: success ? _Colors.primary : _Colors.danger, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
    }
  }
}
