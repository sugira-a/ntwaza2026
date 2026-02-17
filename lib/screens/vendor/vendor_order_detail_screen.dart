import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/vendor_order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/order.dart';
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
        backgroundColor: themeProvider.isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
      );
    }
    
    final order = orderProvider.orders.firstWhere((o) => o.id == widget.orderId);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5);
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
            _buildStatusBanner(order, isDark),
            const SizedBox(height: 10),
            _buildStatusChips(order, isDark),
            const SizedBox(height: 12),
            _buildSearchBar(cardColor, textColor, subtextColor),
            if (query.isNotEmpty && (matchesOrderNumber || matchesCustomer)) ...[
              const SizedBox(height: 8),
              _buildMatchHint(matchesOrderNumber, matchesCustomer, isDark),
            ],
            const SizedBox(height: 12),
            _buildInfoCard('Customer Information', Icons.person, [
              _InfoItem(Icons.person_outline, order.customerName),
              if (order.customerPhone != null) _InfoItem(Icons.phone, order.customerPhone!),
            ], cardColor, textColor, subtextColor),
            const SizedBox(height: 12),
            _buildOrderItemsCard(order, filteredItems, query, cardColor, textColor, subtextColor),
            const SizedBox(height: 12),
            _buildPricingCard(order, cardColor, textColor, subtextColor, isDark),
            if (order.deliveryInfo != null) ...[
              const SizedBox(height: 12),
              _buildInfoCard('Delivery Information', Icons.location_on, [
                _InfoItem(Icons.home, order.deliveryInfo!.address),
                if (order.deliveryInfo!.notes != null) 
                  _InfoItem(Icons.note, order.deliveryInfo!.notes!),
              ], cardColor, textColor, subtextColor),
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
  
  Widget _buildStatusBanner(Order order, bool isDark) {
    final config = _getStatusConfig(order.status.value);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(config.icon, color: config.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.statusDisplay, 
                  style: TextStyle(color: config.color, fontSize: 18, fontWeight: FontWeight.bold)),
                Text(config.message, 
                  style: TextStyle(color: config.color.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChips(Order order, bool isDark) {
    final statuses = [
      'pending',
      'confirmed',
      'preparing',
      'ready',
      'completed',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses.map((status) {
        final config = _getStatusConfig(status);
        final isActive = order.status.value == status ||
            (status == 'confirmed' && (order.status.value == 'accepted')) ||
            (status == 'completed' && order.status.value == 'delivered');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? config.color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? config.color : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            ),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: isActive ? config.color : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        );
      }).toList(),
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
      Color cardColor, Color textColor, Color subtextColor) {
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF2E7D32), size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(item.icon, size: 16, color: subtextColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.text, style: TextStyle(color: textColor, fontSize: 13))),
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
  ) {
    final showingFiltered = query.isNotEmpty && items.length != order.itemCount;
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_bag, color: const Color(0xFF2E7D32), size: 20),
                const SizedBox(width: 8),
                Text('Order Items', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    showingFiltered
                        ? '${items.length} of ${order.itemCount}'
                        : '${order.itemCount} items',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No items match your search',
                  style: TextStyle(color: subtextColor, fontSize: 12),
                ),
              )
            else
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: item.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.restaurant,
                                      color: Colors.grey[400],
                                      size: 18,
                                    ),
                                  ),
                                )
                              : Icon(Icons.restaurant, color: Colors.grey[400], size: 18),
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
                              ),
                              if (item.notes != null)
                                Text(
                                  item.notes!,
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'x${item.quantity}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${NumberFormat('#,###').format(item.total)} Rwf',
                              style: TextStyle(color: subtextColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPricingCard(Order order, Color cardColor, Color textColor, Color subtextColor, bool isDark) {
    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _priceRow('Subtotal', order.subtotal, textColor, subtextColor),
            const SizedBox(height: 8),
            _priceRow('Delivery Fee', order.deliveryFee, textColor, subtextColor),
            Divider(height: 20, color: isDark ? Colors.grey[800] : Colors.grey[300]),
            _priceRow('Total', order.total, textColor, textColor, bold: true),
          ],
        ),
      ),
    );
  }
  
  Widget _priceRow(String label, double amount, Color labelColor, Color amountColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: bold ? 16 : 13, 
          fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
        Text('${NumberFormat('#,###').format(amount)} Rwf', 
          style: TextStyle(color: amountColor, fontSize: bold ? 17 : 13, 
            fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
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
    final preparingLabel = isRestaurant ? 'Preparing' : 'Packing';
    
    // Show info message for confirmed/preparing status
    Widget? infoMessage;
    if (status == 'confirmed' || status == 'accepted' || status == 'preparing') {
      infoMessage = Container(
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
            Icon(
              Icons.info_outline,
              size: 18,
              color: const Color(0xFF3B82F6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mark as "Ready" when finished to notify riders',
                style: TextStyle(
                  color: const Color(0xFF3B82F6),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _handleReject(context, order, provider),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Reject', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _handleAccept(context, order, provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Accept Order', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }
    
    if (status == 'confirmed' || status == 'accepted') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (infoMessage != null) infoMessage,
          _actionButton('Start $preparingLabel', () => _updateStatus(order, provider, 'preparing')),
        ],
      );
    }
    
    if (status == 'preparing') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (infoMessage != null) infoMessage,
          _actionButton('Mark as Ready', () => _updateStatus(order, provider, 'ready')),
        ],
      );
    }
    
    if (status == 'ready') {
      return _actionButton('Complete Order', () => _handleComplete(order, provider));
    }
    
    return const SizedBox.shrink();
  }
  
  Widget _actionButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
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
    final success = await provider.rejectOrder(order.id, reason);
    setState(() => _isProcessing = false);
    
    if (success && mounted) {
      _showSnackBar(context, 'Order rejected', Colors.red);
      if (context.canPop()) {
        context.pop();
      } else {
        Navigator.pop(context);
      }
    }
  }
  
  Future<void> _updateStatus(Order order, VendorOrderProvider provider, String status) async {
    setState(() => _isProcessing = true);
    if (status == 'preparing') await provider.markOrderPreparing(order.id);
    if (status == 'ready') await provider.markOrderReady(order.id);
    setState(() => _isProcessing = false);
  }
  
  Future<void> _handleComplete(Order order, VendorOrderProvider provider) async {
    setState(() => _isProcessing = true);
    await provider.markOrderCompleted(order.id);
    setState(() => _isProcessing = false);
    
    if (mounted) {
      _showSnackBar(context, 'Order completed!', const Color(0xFF2E7D32));
      if (context.canPop()) {
        context.pop();
      }
    }
  }
  
  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color, behavior: SnackBarBehavior.floating),
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
      case 'pending': return _StatusConfig(Colors.orange, Icons.schedule, 'Awaiting confirmation');
      case 'confirmed': case 'accepted': return _StatusConfig(Colors.blue, Icons.check_circle, 'Ready to prepare');
      case 'preparing': return _StatusConfig(Colors.purple, Icons.restaurant_menu, 'Being prepared');
      case 'ready': return _StatusConfig(Colors.green, Icons.done_all, 'Ready for pickup/delivery');
      case 'completed': case 'delivered': return _StatusConfig(Colors.grey, Icons.check_circle_outline, 'Completed');
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