// lib/screens/customer/my_orders_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../admin/admin_dashboard_pro.dart';
import '../../services/api/api_service.dart';
import '../../services/realtime/realtime_service.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;
  static const int _autoRefreshSeconds = 15;
  StreamSubscription? _orderUpdatesSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadOrders();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().initialize(pollingInterval: 10);
    });
    _refreshTimer = Timer.periodic(
      const Duration(seconds: _autoRefreshSeconds),
      (_) => _loadOrders(silent: true),
    );
    _orderUpdatesSub = RealtimeService().orderUpdates.listen((_) => _loadOrders(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _orderUpdatesSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final apiService = ApiService();

      // Set the auth token
      apiService.setToken(authProvider.token);

      // Fetch customer vendor orders
      final data = await apiService.get('/api/orders');
      final vendorOrders = (data['orders'] as List<dynamic>? ?? [])
          .map((order) => _normalizeVendorOrder(order as Map<String, dynamic>))
          .toList();

      // Fetch customer pickup orders
      final customerId = authProvider.user?.id;
      List<Map<String, dynamic>> pickupOrders = [];
      if (customerId != null && customerId.isNotEmpty) {
        try {
          final pickupData = await apiService.get('/api/pickup-orders/customer/$customerId');
          pickupOrders = (pickupData['orders'] as List<dynamic>? ?? [])
              .map((order) => _normalizePickupOrder(order as Map<String, dynamic>))
              .toList();
        } catch (e) {
          // Pickup orders are optional; keep vendor orders if pickup fetch fails.
          print('⚠️ Failed to load pickup orders: $e');
        }
      }

      final combined = [...vendorOrders, ...pickupOrders];
      combined.sort((a, b) => _parseOrderCreatedAt(b).compareTo(_parseOrderCreatedAt(a)));

      setState(() {
        _orders = combined;
        _isLoading = false;
        if (silent) _error = null;
      });
    } catch (e) {
      print('❌ Error loading orders: $e');
      // If it's a "not found" error, treat it as no orders instead of an error
      if (e.toString().contains('Order not found') || e.toString().contains('404')) {
        setState(() {
          _orders = [];
          _isLoading = false;
          _error = null; // No error, just no orders
        });
      } else {
        if (!silent) {
          setState(() {
            _error = 'Failed to load orders. Please try again.';
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  List<Map<String, dynamic>> _filterOrdersByStatus(String status) {
    var filtered = _orders;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        final orderNumber = order['order_number']?.toString().toLowerCase() ?? '';
        final vendorName = order['vendor_name']?.toString().toLowerCase() ?? '';
        final pickupAddress = order['pickup_location']?.toString().toLowerCase() ?? '';
        final dropoffAddress = order['dropoff_location']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return orderNumber.contains(query) ||
            vendorName.contains(query) ||
            pickupAddress.contains(query) ||
            dropoffAddress.contains(query);
      }).toList();
    }
    
    // Apply status filter
    if (status == 'all') return filtered;
    
    if (status == 'active') {
      return filtered.where((order) {
        final orderStatus = order['status']?.toString().toLowerCase() ?? '';
        return orderStatus == 'pending' ||
            orderStatus == 'confirmed' ||
            orderStatus == 'preparing' ||
            orderStatus == 'ready' ||
            orderStatus == 'out_for_delivery' ||
            orderStatus == 'assignedtorider' ||
            orderStatus == 'pickedup' ||
            orderStatus == 'intransit';
      }).toList();
    }
    
    if (status == 'completed') {
      return filtered.where((order) {
        final orderStatus = order['status']?.toString().toLowerCase() ?? '';
        return orderStatus == 'delivered' || orderStatus == 'completed';
      }).toList();
    }
    
    return filtered.where((order) => 
      order['status']?.toString().toLowerCase() == status.toLowerCase()
    ).toList();
  }

  bool _isPickupOrder(Map<String, dynamic> order) {
    return order['order_type'] == 'pickup';
  }

  String _shortOrderNumber(String? orderNumber) {
    if (orderNumber == null || orderNumber.isEmpty) return 'Unknown';
    if (orderNumber.length <= 8) return orderNumber;
    final tail = orderNumber.substring(orderNumber.length - 6);
    return '${orderNumber.substring(0, 3)}...$tail';
  }

  String? _extractPickupCode(Map<String, dynamic> order) {
    final direct = order['pickup_code']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final notes = order['notes']?.toString() ?? '';
    final match = RegExp(r'Pickup code\s*:\s*(\d{4,6})').firstMatch(notes);
    return match?.group(1);
  }

  DateTime _parseOrderCreatedAt(Map<String, dynamic> order) {
    final raw = order['created_at'] ?? order['createdAt'];
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, dynamic> _normalizeVendorOrder(Map<String, dynamic> order) {
    return {
      ...order,
      'order_type': 'vendor',
      'vendor_name': order['vendor_name'] ?? order['vendor']?['business_name'],
    };
  }

  Map<String, dynamic> _normalizePickupOrder(Map<String, dynamic> order) {
    final items = (order['items'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .toList();
    final itemCount = items.fold<int>(0, (sum, item) => sum + (item['quantity'] as int? ?? 1));
    return {
      'id': order['id'],
      'order_number': order['orderNumber'] ?? order['order_number'],
      'status': order['status'],
      'created_at': order['createdAt'] ?? order['created_at'],
      'items': items,
      'item_count': itemCount,
      'amount': order['amount'] ?? 0,
      'delivery_fee': order['deliveryFee'] ?? order['delivery_fee'] ?? 0,
      'total': order['totalAmount'] ?? order['total'] ?? 0,
      'payment_method': order['paymentMethod'] ?? order['payment_method'],
      'pickup_location': order['pickupLocation']?['address'] ?? '',
      'dropoff_location': order['dropoffLocation']?['address'] ?? '',
      'scheduled_pickup_time': order['scheduledPickupTime'] ?? order['scheduled_pickup_time'],
      'pickup_code': order['pickupCode'] ?? order['pickup_code'],
      'notes': order['notes'],
      'order_type': 'pickup',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final colorScheme = theme.colorScheme;
    final pageColor = AppColors.getBackground(context);
    final cardColor = AppColors.getSurface(context);
    final accentColor = Colors.green[700] ?? Colors.green;
    final pickupCount = _orders.where(_isPickupOrder).length;

    return Scaffold(
      backgroundColor: pageColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              pinned: true,
              snap: false,
              backgroundColor: pageColor,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.getTextPrimary(context)),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Orders',
                    style: TextStyle(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                  if (!_isLoading && _orders.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${_orders.length} order${_orders.length != 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(context),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          if (pickupCount > 0) _buildTypeChip('Pickup', pickupCount, accentColor),
                        ],
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh, color: AppColors.getTextPrimary(context)),
                  onPressed: _loadOrders,
                  tooltip: 'Refresh',
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(110),
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: AppColors.getTextPrimary(context)),
                        decoration: InputDecoration(
                          hintText: 'Search by order number or vendor',
                          hintStyle: TextStyle(color: AppColors.getTextSecondary(context)),
                          prefixIcon: Icon(Icons.search, color: AppColors.getTextSecondary(context)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: AppColors.getTextSecondary(context)),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: pageColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.getBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.getBorder(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accentColor, width: 1.2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),
                    // Tabs
                    TabBar(
                      controller: _tabController,
                      labelColor: accentColor,
                      unselectedLabelColor: AppColors.getTextSecondary(context),
                      indicatorColor: accentColor,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'All'),
                        Tab(text: 'Active'),
                        Tab(text: 'Completed'),
                        Tab(text: 'Cancelled'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentColor))
            : _error != null
                ? _buildErrorState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrdersList(_filterOrdersByStatus('all'), isDark, cardColor, colorScheme),
                      _buildOrdersList(_filterOrdersByStatus('active'), isDark, cardColor, colorScheme),
                      _buildOrdersList(_filterOrdersByStatus('completed'), isDark, cardColor, colorScheme),
                      _buildOrdersList(_filterOrdersByStatus('cancelled'), isDark, cardColor, colorScheme),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = Colors.green[700] ?? Colors.green;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline, size: 64, color: accentColor),
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.getTextPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders, bool isDark, Color cardColor, ColorScheme colorScheme) {
    if (orders.isEmpty) {
      final accentColor = Colors.green[700] ?? Colors.green;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  size: 80,
                  color: accentColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _searchQuery.isNotEmpty ? 'No matching orders' : 'No orders yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isNotEmpty
                    ? 'Try adjusting your search'
                    : 'Your orders will appear here once you make a purchase',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              if (_searchQuery.isEmpty) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    context.go('/');
                  },
                  icon: const Icon(Icons.shopping_bag),
                  label: const Text('Start Shopping'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: Colors.green[700] ?? Colors.green,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final isPickup = _isPickupOrder(order);
          final accentColor = Colors.green[700] ?? Colors.green;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showOrderDetails(order),
            child: Card(
              margin: const EdgeInsets.only(bottom: 18),
              elevation: 0,
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppColors.getBorder(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPickup ? Icons.local_shipping_outlined : Icons.receipt_long,
                          color: AppColors.getTextPrimary(context),
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${isPickup ? 'Pickup' : 'Order'} #${_shortOrderNumber(order['order_number']?.toString())}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 19,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isPickup ? 'PICKUP' : 'ORDER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!isPickup)
                      Row(
                        children: [
                          Icon(Icons.store, size: 18, color: AppColors.getTextSecondary(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order['vendor']?['business_name'] ?? order['vendor_name'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.store_mall_directory_outlined, size: 18, color: AppColors.getTextSecondary(context)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order['pickup_location'] ?? 'Pickup location',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 18, color: AppColors.getTextSecondary(context)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order['dropoff_location'] ?? 'Drop-off location',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    if (!isPickup)
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 18, color: AppColors.getTextSecondary(context)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order['delivery_address'] ?? 'Address not available',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, size: 18, color: AppColors.getTextSecondary(context)),
                        const SizedBox(width: 8),
                        Text(
                          'Items: ${order['item_count'] ?? (order['items']?.length ?? 0)}',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.getTextSecondary(context),
                            ),
                        ),
                        const SizedBox(width: 18),
                        Icon(Icons.attach_money, size: 18, color: accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Total: ${order['total'] ?? 0} RWF',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label $count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailsSheet(
        order: order,
        onTrackOrder: (orderId) {
          context.go('/order/track/$orderId');
        },
      ),
    );
  }
}

// Order Card Widget
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final orderNumber = order['order_number'] ?? 'Unknown Order';
    final vendorName = order['vendor']?['business_name'] ?? 'Vendor not available';
    final deliveryAddress = order['delivery_address'] ?? 'Address not available';
    final itemCount = order['item_count'] ?? (order['items']?.length ?? 0);
    final totalPrice = order['total'] ?? 0;
    final currency = 'RWF'; // Change to your currency

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: AppColors.getTextPrimary(context), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      orderNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.getTextSecondary(context)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.store, size: 16, color: AppColors.getTextSecondary(context)),
                  const SizedBox(width: 6),
                  Text(
                    vendorName,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppColors.getTextSecondary(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      deliveryAddress,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.shopping_cart, size: 16, color: AppColors.getTextSecondary(context)),
                  const SizedBox(width: 6),
                  Text(
                    'Items: $itemCount',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.attach_money, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Text(
                    'Total: ${totalPrice.toStringAsFixed(2)} $currency',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Order Details Sheet
class _OrderDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> order;
  final void Function(String orderId)? onTrackOrder;
  const _OrderDetailsSheet({required this.order, this.onTrackOrder});

  String? _extractPickupCode(Map<String, dynamic> order) {
    final direct = order['pickup_code']?.toString().trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final notes = order['notes']?.toString() ?? '';
    final match = RegExp(r'Pickup code\s*:\s*(\d{4,6})').firstMatch(notes);
    return match?.group(1);
  }

  String _buildOrderItemImageUrl(Map<String, dynamic> item) {
    final raw = (item['image_url'] ??
            item['image_url_full'] ??
            item['product_image_url'] ??
            item['product_image'] ??
            item['image'] ??
            (item['product'] is Map
                ? (item['product']['image_url_full'] ?? item['product']['image_url'] ?? item['product']['image'])
                : null))
        ?.toString()
        .trim();

    if (raw == null || raw.isEmpty) return '';
    var normalized = raw.replaceAll('\\', '/');

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      if (normalized.contains('/static/uploads/catalog/')) {
        final filename = normalized.split('/').last;
        return '${ApiService.baseUrl}/static/uploads/products/$filename';
      }
      return normalized;
    }

    if (normalized.startsWith('/static/products/')) {
      normalized = normalized.replaceFirst('/static/products/', '/static/uploads/products/');
    }

    if (normalized.contains('/static/uploads/catalog/')) {
      final filename = normalized.split('/').last;
      return '${ApiService.baseUrl}/static/uploads/products/$filename';
    }

    if (normalized.startsWith('/static/')) {
      return '${ApiService.baseUrl}$normalized';
    }

    if (normalized.startsWith('/')) {
      return '${ApiService.baseUrl}$normalized';
    }

    if (normalized.startsWith('static/')) {
      return '${ApiService.baseUrl}/$normalized';
    }

    return '${ApiService.baseUrl}/static/uploads/products/$normalized';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = Colors.green[700] ?? Colors.green;
    final items = order['items'] ?? [];
    final subtotal = order['subtotal'] ?? order['amount'] ?? 0;
    final deliveryFee = order['delivery_fee'] ?? order['deliveryFee'] ?? 0;
    final total = order['total'] ?? order['totalAmount'] ?? 0;
    final isPickup = order['order_type'] == 'pickup';
    final address = isPickup
        ? (order['dropoff_location'] ?? 'Drop-off address not available')
        : (order['delivery_address'] ?? 'Address not available');
    final status = order['status'] ?? 'pending';
    final orderNumber = order['order_number'] ?? '';
    final vendorName = isPickup ? null : (order['vendor']?['business_name'] ?? order['vendor_name']);
    final createdAt = order['created_at'] ?? order['createdAt'];
    final paymentMethod = order['payment_method'] ?? order['paymentMethod'];
    final pickupLocation = order['pickup_location'];
    final dropoffLocation = order['dropoff_location'];
    final scheduledPickup = order['scheduled_pickup_time'] ?? order['scheduledPickupTime'];
    final pickupCode = _extractPickupCode(order);

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isPickup ? Icons.local_shipping_outlined : Icons.receipt_long, size: 22, color: colorScheme.onSurface),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPickup ? 'Pickup Details' : 'Order Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colorScheme.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${isPickup ? 'Pickup' : 'Order'} #$orderNumber',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
              ),
              if (vendorName != null) ...[
                const SizedBox(height: 4),
                Text(
                  vendorName.toString(),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                ),
              ],
              if (createdAt != null) ...[
                const SizedBox(height: 2),
                Text(
                  createdAt.toString(),
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    _StatusBadge(status: status),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _getStatusMessage(status),
                        style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.location_on, size: 18, color: accentColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPickup && pickupLocation != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.store_mall_directory_outlined, size: 18, color: accentColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pickupLocation.toString(),
                          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isPickup && dropoffLocation != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.location_on_outlined, size: 18, color: accentColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dropoffLocation.toString(),
                          style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isPickup && scheduledPickup != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Scheduled pickup: $scheduledPickup',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ],
              if (isPickup && pickupCode != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        'Pickup Code: $pickupCode',
                        style: TextStyle(fontWeight: FontWeight.w700, color: accentColor),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(isPickup ? 'Packages' : 'Items', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colorScheme.onSurface)),
              const SizedBox(height: 10),
              ...items.map((item) {
                if (isPickup) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.black.withOpacity(0.05)),
                          ),
                          child: Icon(Icons.inventory_2_outlined, color: Colors.grey[600], size: 24),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['description'] ?? 'Package',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Qty: ${item['quantity'] ?? 1}',
                                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final imageUrl = _buildOrderItemImageUrl(item);
                final hasImage = imageUrl.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black.withOpacity(0.05)),
                          image: hasImage
                              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: hasImage
                            ? null
                            : Icon(Icons.fastfood_outlined, color: Colors.grey[600], size: 26),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['product_name'] ?? 'Unknown Item',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item['quantity'] ?? 1}x',
                                style: TextStyle(fontWeight: FontWeight.bold, color: accentColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'RWF ${item['total_price'] ?? item['unit_price'] ?? 0}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: accentColor),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
                        Text('RWF ${subtotal.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Delivery Fee', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
                        Text('RWF ${deliveryFee.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                      ],
                    ),
                    if (paymentMethod != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Payment', style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
                          Text(paymentMethod.toString(), style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(height: 1, color: Colors.black.withOpacity(0.08)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        Text('RWF ${total.toStringAsFixed(0)}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: accentColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onTrackOrder != null) {
                      Future.microtask(() => onTrackOrder!(order['id']));
                    }
                  },
                  icon: const Icon(Icons.location_searching),
                  label: Text(isPickup ? 'Track Pickup' : 'Track Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Waiting for vendor confirmation';
      case 'confirmed':
        return 'Order confirmed by vendor';
      case 'preparing':
        return 'Order is being prepared';
      case 'ready':
        return 'Order is ready for pickup/delivery';
      case 'out_for_delivery':
        return 'Order is out for delivery';
      case 'assignedtorider':
        return 'Rider assigned and on the way to pickup';
      case 'pickedup':
        return 'Pickup completed, heading to drop-off';
      case 'intransit':
        return 'Order is in transit to drop-off';
      case 'delivered':
        return 'Order delivered';
      case 'completed':
        return 'Order completed';
      case 'cancelled':
        return 'Order cancelled';
      default:
        return 'Status unknown';
    }
  }
}

// Status Badge Widget
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color _getColor(BuildContext context) {
    switch (status.toLowerCase()) {
      case 'ready':
      case 'out_for_delivery':
      case 'delivered':
      case 'completed':
      case 'pending':
      case 'confirmed':
      case 'preparing':
        return Colors.green[700] ?? Colors.green;
      case 'cancelled':
        return AppColors.getTextSecondary(context);
      default:
        return AppColors.getTextSecondary(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}
