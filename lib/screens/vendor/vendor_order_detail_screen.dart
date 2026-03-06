import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/vendor_order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/order.dart';
import '../../services/api/api_service.dart';
import '../../utils/helpers.dart';

class VendorOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const VendorOrderDetailScreen({super.key, required this.orderId});

  @override
  State<VendorOrderDetailScreen> createState() => _VendorOrderDetailScreenState();
}

class _VendorOrderDetailScreenState extends State<VendorOrderDetailScreen> {
  bool _isProcessing = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VendorOrderProvider>().getOrderById(widget.orderId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<VendorOrderProvider>();
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    
    if (orderProvider.orders.isEmpty) {
      return Scaffold(
        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
      );
    }
    
    final order = orderProvider.orders.firstWhere((o) => o.id == widget.orderId);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final isRestaurant = _isRestaurant(authProvider.user);
    final query = _searchQuery.trim().toLowerCase();
    final matchesOrderNumber = query.isNotEmpty && order.orderNumber.toLowerCase().contains(query);
    final matchesCustomer = query.isNotEmpty && order.customerName.toLowerCase().contains(query);
    final filteredItems = query.isEmpty
      ? order.items
      : order.items.where((item) {
        final name = item.productName.toLowerCase();
        final notes = item.notes?.toLowerCase() ?? '';
        return name.contains(query) || notes.contains(query) || matchesOrderNumber || matchesCustomer;
        }).toList();
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(order, cardColor, textColor, subtextColor, isDark),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusBanner(order, isDark, cardColor),
            const SizedBox(height: 14),
            _buildStatusChips(order, isDark),
            if (order.vendorPickupCode != null) ...[
              const SizedBox(height: 16),
              _buildVendorPickupCodeCard(order, cardColor, textColor, subtextColor, isDark),
            ],
            const SizedBox(height: 16),
            _buildInfoCard('Customer Information', Icons.person, [
              _InfoItem(Icons.person_outline, order.customerName),
              if (order.customerPhone != null) _InfoItem(Icons.phone, order.customerPhone!),
            ], cardColor, textColor, subtextColor, isDark),
            if (order.riderId != null && order.riderName != null) ...[
              const SizedBox(height: 14),
              _buildInfoCard('Delivery Rider', Icons.two_wheeler, [
                _InfoItem(Icons.person_outline, order.riderName!),
                if (order.riderPhone != null) _InfoItem(Icons.phone, order.riderPhone!),
                _InfoItem(Icons.badge, 'ID: ${order.riderId!.substring(0, 12)}'),
              ], cardColor, const Color(0xFF2E7D32), subtextColor, isDark),
            ],
            const SizedBox(height: 14),
            _buildOrderItemsCard(order, order.items, '', cardColor, textColor, subtextColor, isDark),
            const SizedBox(height: 14),
            _buildPricingCard(order, cardColor, textColor, subtextColor, isDark),
            if (order.deliveryInfo != null) ...[
              const SizedBox(height: 14),
              _buildInfoCard('Delivery Information', Icons.location_on, [
                _InfoItem(Icons.home, order.deliveryInfo!.address),
                if (order.deliveryInfo!.notes != null) 
                  _InfoItem(Icons.note, order.deliveryInfo!.notes!),
              ], cardColor, textColor, subtextColor, isDark),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildActionBar(context, order, orderProvider, cardColor, isDark, isRestaurant),
    );
  }
  
  bool _isRestaurant(user) {
    return user?.businessType?.toLowerCase() == 'restaurant' ||
           user?.vendorType?.toLowerCase() == 'restaurant' ||
           (user?.usesMenuSystem ?? true);
  }
  
  PreferredSizeWidget _buildAppBar(Order order, Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    return AppBar(
      backgroundColor: cardColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textColor),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order ${shortenOrderNumber(order.orderNumber)}', 
            style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(order.timeAgo, 
            style: TextStyle(color: subtextColor, fontSize: 11)),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.more_vert, color: textColor),
          onPressed: () => _showOrderMenu(cardColor),
        ),
      ],
    );
  }
  
  Widget _buildStatusBanner(Order order, bool isDark, Color cardColor) {
    final config = _getStatusConfig(order.status.value);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B1B1B),
            const Color(0xFF0F0F0F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(config.icon, color: config.color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.statusDisplay, 
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(config.message, 
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips(Order order, bool isDark) {
    final statuses = [
      'confirmed',
      'ready',
      'completed',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final config = _getStatusConfig(status);
        final currentVal = order.status.value;
        final isActive = currentVal == status ||
            (status == 'confirmed' && (currentVal == 'accepted' || currentVal == 'pending' || currentVal == 'preparing')) ||
            (status == 'completed' && currentVal == 'delivered');
        // Determine if step is done (past)
        final statusOrder = ['confirmed', 'ready', 'completed'];
        final currentIdx = statusOrder.indexOf(currentVal == 'accepted' || currentVal == 'pending' || currentVal == 'preparing' ? 'confirmed' : currentVal == 'delivered' ? 'completed' : currentVal);
        final chipIdx = statusOrder.indexOf(status);
        final isDone = currentIdx >= 0 && chipIdx >= 0 && chipIdx < currentIdx;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? config.color.withOpacity(0.15) 
                   : isDone ? const Color(0xFF2E7D32).withOpacity(0.10) 
                   : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? config.color 
                     : isDone ? const Color(0xFF2E7D32).withOpacity(0.5) 
                     : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDone) ...[
                Icon(Icons.check_circle, size: 12, color: const Color(0xFF2E7D32)),
                const SizedBox(width: 4),
              ],
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isActive ? config.color 
                         : isDone ? const Color(0xFF2E7D32) 
                         : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVendorPickupCodeCard(Order order, Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: isDark
              ? [const Color(0xFF081529), const Color(0xFF0E2854)]
              : [const Color(0xFF0E2854), const Color(0xFF1A3E7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Pickup Code',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'For Rider',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                order.vendorPickupCode ?? 'N/A',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D4ED8),
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 12, color: Colors.white.withOpacity(0.9)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Show this code to the rider on arrival',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 12, color: Colors.white.withOpacity(0.75)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Valid for this order only',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(Color cardColor, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(color: textColor, fontSize: 14),
        decoration: InputDecoration(
          icon: Icon(Icons.search, color: subtextColor),
          hintText: 'Search items, customer, or order number',
          hintStyle: TextStyle(color: subtextColor, fontSize: 13),
          border: InputBorder.none,
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: subtextColor, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildMatchHint(bool matchesOrderNumber, bool matchesCustomer, bool isDark) {
    final chips = <String>[];
    if (matchesOrderNumber) chips.add('Order number');
    if (matchesCustomer) chips.add('Customer');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: isDark ? Colors.white : Colors.black),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Matched: ${chips.join(' / ')}',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoCard(String title, IconData icon, List<_InfoItem> items, 
      Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    return Card(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
                ),
                const SizedBox(width: 10),
                Text(title, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(item.icon, size: 18, color: subtextColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.text,
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOrderItemsCard(
    Order order,
    List<OrderItem> items,
    String query,
    Color cardColor,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    return Card(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant_menu, color: Color(0xFF2E7D32), size: 20),
                ),
                const SizedBox(width: 10),
                Text('Order Items', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final imageUrl = _resolveImageUrl(item.imageUrl);
              final modifierTotal = item.modifiers == null
                  ? 0.0
                  : item.modifiers!.fold<double>(0, (sum, mod) => sum + mod.priceAdjustment);
              return Container(
                margin: EdgeInsets.only(bottom: index < items.length - 1 ? 12 : 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141414) : const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                      ),
                      child: imageUrl == null
                          ? const Icon(Icons.image_outlined, color: Color(0xFF9CA3AF))
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '•',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E7D32),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${item.quantity} x RWF ${NumberFormat('#,###').format(item.price)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (modifierTotal > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  '•',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Modifiers: +RWF ${NumberFormat('#,###').format(modifierTotal)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (item.modifiers != null && item.modifiers!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...item.modifiers!.map((mod) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Text(
                                      '–',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF2E7D32),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      mod.name,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF2E7D32),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                          if (item.notes != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.note_outlined, size: 12, color: subtextColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    item.notes!,
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RWF ${NumberFormat('#,###').format(item.total)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String? _resolveImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty) return null;
    final trimmed = imageUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) return trimmed;
    if (trimmed.startsWith('/')) {
      return '${ApiService.baseUrl}$trimmed';
    }
    return '${ApiService.baseUrl}/$trimmed';
  }
  
  Widget _buildPricingCard(Order order, Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    return Card(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(isDark ? 0.5 : 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _priceRow('Total Order Value', order.subtotal, textColor, const Color(0xFF2E7D32), bold: true),
          ],
        ),
      ),
    );
  }
  
  Widget _priceRow(String label, double amount, Color labelColor, Color amountColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: bold ? 16 : 14, 
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        Text('${NumberFormat('#,###').format(amount)} Rwf', 
          style: TextStyle(color: amountColor, fontSize: bold ? 18 : 14, 
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }
  
  Widget _buildActionBar(BuildContext context, Order order, VendorOrderProvider provider, 
      Color cardColor, bool isDark, bool isRestaurant) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.08), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildButtons(context, order, provider, isRestaurant),
        ),
      ),
    );
  }
  
  Widget _buildButtons(BuildContext context, Order order, VendorOrderProvider provider, bool isRestaurant) {
    if (_isProcessing) return const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)));
    
    final status = order.status.value;
    
    // Pending: Confirm order first
    if (status == 'pending') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Confirm this order to accept and prepare it',
                    style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          _actionButton('Confirm Order', () => _updateStatus(order, provider, 'confirmed')),
          const SizedBox(height: 12),
          _actionButton(
            'Reject Order',
            () => _handleReject(context, order, provider),
            backgroundColor: Colors.red.shade600,
          ),
        ],
      );
    }
    
    // Confirmed/Accepted/Preparing: Mark as ready
    if (status == 'confirmed' || status == 'accepted' || status == 'preparing') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mark as "Ready" when the order is prepared',
                    style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          _actionButton('Mark as Ready', () => _updateStatus(order, provider, 'ready')),
        ],
      );
    }
    
    if (status == 'ready') {
      return _actionButton('Complete Order', () => _handleComplete(order, provider));
    }
    
    return const SizedBox.shrink();
  }
  
  Widget _actionButton(String label, VoidCallback onPressed, {Color backgroundColor = const Color(0xFF2E7D32)}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }
  
  Future<void> _handleAccept(BuildContext context, Order order, VendorOrderProvider provider) async {
    if (order.status.value != 'pending') {
      _showSnackBar(context, 'Order already processed', Colors.orange);
      return;
    }
    
    setState(() => _isProcessing = true);
    try {
      final success = await provider.acceptOrder(order.id);
      if (success) {
        await provider.getOrderById(widget.orderId);
        if (mounted) _showSnackBar(context, 'Order accepted', const Color(0xFF2E7D32));
      } else {
        if (mounted) _showSnackBar(context, 'Failed to accept order', Colors.red);
      }
    } catch (e) {
      if (mounted) _showSnackBar(context, 'Error: ${e.toString()}', Colors.red);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
  
  Future<void> _handleReject(BuildContext context, Order order, VendorOrderProvider provider) async {
    final reason = await _showRejectDialog(context);
    if (reason == null) return;
    
    setState(() => _isProcessing = true);
    try {
      final success = await provider.rejectOrder(order.id, reason);
      
      if (success && mounted) {
        _showSnackBar(context, 'Order rejected', Colors.red);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted && context.canPop()) {
          context.pop();
        }
      } else if (mounted) {
        _showSnackBar(context, 'Failed to reject order', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  
  Future<void> _updateStatus(Order order, VendorOrderProvider provider, String status) async {
    setState(() => _isProcessing = true);
    try {
      bool success = false;
      
      if (status == 'confirmed') {
        success = await provider.updateOrderStatus(order.id, OrderStatus.confirmed);
      } else if (status == 'ready') {
        success = await provider.markOrderReady(order.id);
      }
      
      if (success) {
        await provider.getOrderById(widget.orderId);
        if (mounted) {
          final message = status == 'confirmed' 
              ? 'Order confirmed! Start preparing...'
              : 'Order marked as ready for pickup';
          _showSnackBar(context, message, const Color(0xFF2E7D32));
        }
      } else {
        if (mounted) {
          _showSnackBar(context, 'Failed to update order status', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  
  Future<void> _handleComplete(Order order, VendorOrderProvider provider) async {
    setState(() => _isProcessing = true);
    try {
      bool success = await provider.markOrderCompleted(order.id);
      
      if (success) {
        await provider.getOrderById(widget.orderId);
        if (mounted) {
          _showSnackBar(context, 'Order completed! ✓', const Color(0xFF2E7D32));
          // Give user feedback before navigating
          await Future.delayed(const Duration(milliseconds: 1000));
          if (mounted && context.canPop()) {
            context.pop();
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(context, 'Failed to complete order', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Error: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
  
  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
  
  Future<String?> _showRejectDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order', style: TextStyle(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Enter reason...', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
  
  void _showOrderMenu(Color cardColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.print), title: const Text('Print Order'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.share), title: const Text('Share Order'), onTap: () => Navigator.pop(context)),
            ListTile(leading: const Icon(Icons.phone), title: const Text('Call Customer'), onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
  
  _StatusConfig _getStatusConfig(String status) {
    switch (status) {
      case 'pending': case 'confirmed': case 'accepted': case 'preparing': 
        return _StatusConfig(Colors.blue, Icons.check_circle, 'Order confirmed - preparing');
      case 'ready': return _StatusConfig(Colors.green, Icons.done_all, 'Ready for pickup/delivery');
      case 'completed': case 'delivered': return _StatusConfig(const Color(0xFF2E7D32), Icons.check_circle_outline, 'Completed');
      case 'cancelled': case 'rejected': return _StatusConfig(Colors.red, Icons.cancel, 'Cancelled');
      default: return _StatusConfig(Colors.grey, Icons.help_outline, 'Unknown status');
    }
  }
}

class _InfoItem {
  final IconData icon;
  final String text;
  _InfoItem(this.icon, this.text);
}

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String message;
  _StatusConfig(this.color, this.icon, this.message);
}