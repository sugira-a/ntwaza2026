// lib/screens/rider/rider_all_orders_screen.dart
import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';
import 'rider_order_detail.dart';

class RiderAllOrdersScreen extends StatefulWidget {
  final List<Order> orders;
  const RiderAllOrdersScreen({super.key, required this.orders});

  @override
  State<RiderAllOrdersScreen> createState() => _RiderAllOrdersScreenState();
}

class _RiderAllOrdersScreenState extends State<RiderAllOrdersScreen> {
  late List<Order> _filteredOrders;
  String _sortBy = 'time'; // 'time' or 'distance'
  final TextEditingController _searchController = TextEditingController();

  static const Color accentGreen = Color(0xFF4CAF50);
  static const Color pureBlack = Color(0xFF0B0B0B);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color softBlack = Colors.black;

  @override
  void initState() {
    super.initState();
    _filteredOrders = List.from(widget.orders);
    _sortOrders();
  }

  void _sortOrders() {
    if (_sortBy == 'time') {
      _filteredOrders.sort((a, b) {
        final aTime = a.createdAt;
        final bTime = b.createdAt;
        if (aTime != null && bTime != null) {
          return aTime.compareTo(bTime);
        }
        return 0;
      });
    } else {
      // Sort by price (distance proxy)
      _filteredOrders.sort((a, b) => b.total.compareTo(a.total));
    }
  }

  void _filterOrders(String query) {
    _filteredOrders = widget.orders.where((order) {
      final vendorName = order.vendorName.toLowerCase();
      final address = (order.deliveryInfo?.address ?? '').toLowerCase();
      final searchLower = query.toLowerCase();
      return vendorName.contains(searchLower) || address.contains(searchLower);
    }).toList();
    _sortOrders();
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? pureBlack : const Color(0xFFDADDE2);
    final cardColor = isDark ? softBlack : const Color(0xFFDADDE2);
    final textColor = isDark ? pureWhite : pureBlack;
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final borderColor = isDark ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (mounted) Navigator.pop(context);
          },
        ),
        title: Text(
          'All Available Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _filterOrders,
                  style: TextStyle(color: textColor, fontSize: 14, letterSpacing: -0.3),
                  decoration: InputDecoration(
                    hintText: 'Search vendor or location',
                    hintStyle: TextStyle(color: subtextColor, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: subtextColor, size: 20),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: accentGreen, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Sort Buttons
                Row(
                  children: [
                    Expanded(
                      child: _buildSortButton(
                        'Newest First',
                        _sortBy == 'time',
                        () {
                          setState(() => _sortBy = 'time');
                          _sortOrders();
                        },
                        isDark,
                        textColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildSortButton(
                        'Best Earnings',
                        _sortBy == 'distance',
                        () {
                          setState(() => _sortBy = 'distance');
                          _sortOrders();
                        },
                        isDark,
                        textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Orders List
          Expanded(
            child: _filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: accentGreen.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.search_off_rounded,
                            size: 40,
                            color: accentGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Orders Found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtextColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: _filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = _filteredOrders[index];
                      return _buildOrderCard(
                        order,
                        isDark,
                        cardColor,
                        borderColor,
                        textColor,
                        subtextColor,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton(
    String label,
    bool isSelected,
    VoidCallback onTap,
    bool isDark,
    Color textColor,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accentGreen : (isDark ? const Color(0xFF1F1F1F) : const Color(0xFFDADDE2)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentGreen : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? pureWhite : textColor,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    Order order,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    final createdAt = order.createdAt != null
        ? formatRwandaTime(parseServerTime(order.createdAt.toString()), 'MMM d, h:mm a')
        : 'N/A';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiderOrderDetailScreen(order: order),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
            boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.vendorName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'RWF ${order.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentGreen,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Location
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 13, color: subtextColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.deliveryInfo?.address ?? 'Delivery location',
                  style: TextStyle(
                    fontSize: 11,
                    color: subtextColor,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Time & Items
          Row(
            children: [
              Icon(Icons.access_time, size: 13, color: subtextColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  createdAt,
                  style: TextStyle(
                    fontSize: 10,
                    color: subtextColor,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.inventory_2_outlined, size: 13, color: subtextColor),
              const SizedBox(width: 4),
              Text(
                '${order.items.length} items',
                style: TextStyle(
                  fontSize: 10,
                  color: subtextColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}
