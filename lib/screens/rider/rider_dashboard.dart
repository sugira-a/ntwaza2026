// lib/screens/rider/rider_dashboard.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/rider_order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/pickup_order_provider.dart';
import '../../models/order.dart';
import '../../models/pickup_order.dart';
import '../rider/rider_earnings_screen.dart';
import '../rider/rider_delivery_history.dart';
import '../rider/rider_profile_screen.dart';
import '../rider/rider_order_detail.dart';
import '../rider/rider_pickup_order_detail.dart';
import '../rider/rider_all_orders_screen.dart';
import '../../utils/helpers.dart';

class RiderDashboard extends StatefulWidget {
  const RiderDashboard({super.key});

  @override
  State<RiderDashboard> createState() => _RiderDashboardState();
}

class _RiderDashboardState extends State<RiderDashboard> {
  bool _isOnline = false;
  bool _dataInitialized = false;
  static const int _pollSeconds = 15;
  late RiderOrderProvider _riderOrderProvider;

  // Neutral palette (black + white + gray) + green accent
  static const Color pureBlack = Color(0xFF0B0B0B);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color softBlack = Colors.black;
  static const Color borderGray = Color(0xFFE5E7EB);
  static const Color mutedGray = Color(0xFF6B7280);
  static const Color accentGreen = Color(0xFF4CAF50);
  
  static const String supportPhone = '0782195474';

  @override
  void initState() {
    super.initState();
    // Don't load online status here - keep existing state across rebuilds/theme changes
    // _isOnline defaults to false when widget is first created only
    // Store reference to provider for safe disposal
    _riderOrderProvider = context.read<RiderOrderProvider>();
  }

  Future<void> _loadOnlineStatus() async {
    // In a real app, load from SharedPreferences or backend
    // For now, keep the current state (don't reset on rebuild)
    // This prevents going offline when theme changes
  }

  Future<void> _toggleOnlineStatus(bool newStatus) async {
    setState(() => _isOnline = newStatus);
    
    // In a real implementation, save to SharedPreferences and notify backend
    // For now, just show a snackbar to indicate the change
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(
          newStatus ? 'You are now online - ready to accept orders!' : 'You are now offline',
        ),
      );
    }
    
    // If going offline, you might want to stop accepting new orders
    // If going online, ensure notification polling is active
    if (newStatus) {
      final notificationProvider = context.read<NotificationProvider>();
      if (!notificationProvider.isPolling) {
        notificationProvider.startPolling(intervalSeconds: _pollSeconds);
      }
    }
  }

  @override
  void dispose() {
    try {
      _riderOrderProvider?.stopAutoRefresh();
    } catch (e) {
      // Provider already disposed
    }
    super.dispose();
  }

  SnackBar _buildSnackBar(String message, {bool isError = false}) {
    return SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: pureWhite,
        ),
      ),
      backgroundColor: isError ? Colors.red[900] : accentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    );
  }

  Future<bool> _confirmOrderAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return (await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              backgroundColor: isDark ? Colors.black : Colors.white,
              title: Text(title, style: TextStyle(color: textColor)),
              content: Text(message, style: TextStyle(color: textColor)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: textColor.withOpacity(0.7)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  Future<void> _callSupport(BuildContext context) async {
    if (supportPhone.contains('X') || supportPhone.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _buildSnackBar('Support number not configured', isError: true),
        );
      }
      return;
    }
    final uri = Uri.parse('tel:$supportPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Unable to open phone dialer', isError: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? pureBlack : const Color(0xFFDADDE2);
    final cardColor = isDark ? softBlack : Colors.transparent;
    final textColor = isDark ? pureWhite : pureBlack;
    final subtextColor = isDark ? Colors.white70 : mutedGray;
    final borderColor = isDark ? const Color(0xFF1F1F1F) : borderGray;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Consumer<RiderOrderProvider>(
          builder: (context, riderProvider, _) {
            if (authProvider.isAuthenticated &&
                authProvider.user != null &&
                !_dataInitialized) {
              _dataInitialized = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  final riderId = authProvider.user!.id;
                  riderProvider.fetchAvailableOrders();
                  riderProvider.fetchAssignedOrders();
                  riderProvider.fetchDeliveryHistory();
                  riderProvider.startAutoRefresh(_pollSeconds);
                  if (riderId != null) {
                    context.read<PickupOrderProvider>().fetchRiderPickupOrders(riderId);
                  }
                  context
                      .read<NotificationProvider>()
                      .initialize(pollingInterval: _pollSeconds);
                }
              });
            }

            if (riderProvider.isLoading &&
                riderProvider.availableOrders.isEmpty) {
              return Center(
                child: CircularProgressIndicator(
                  color: isDark ? pureWhite : pureBlack,
                  strokeWidth: 2,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await riderProvider.fetchAvailableOrders();
                await riderProvider.fetchAssignedOrders();
                await riderProvider.fetchDeliveryHistory();
              },
              color: isDark ? pureWhite : pureBlack,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildHeader(
                    authProvider,
                    isDark,
                    textColor,
                    subtextColor,
                    borderColor,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Column(
                      children: [
                        _buildStatCards(
                          riderProvider,
                          isDark,
                          textColor,
                          subtextColor,
                          borderColor,
                          cardColor,
                        ),
                        const SizedBox(height: 12),
                        _buildActionCards(riderProvider, isDark),
                        const SizedBox(height: 18),
                        _buildAvailableOrdersSection(
                          context,
                          riderProvider,
                          isDark,
                          textColor,
                          subtextColor,
                          borderColor,
                          cardColor,
                        ),
                        const SizedBox(height: 18),
                        _buildActiveOrdersSection(
                          riderProvider,
                          isDark,
                          textColor,
                          subtextColor,
                          borderColor,
                          cardColor,
                          context,
                        ),
                        const SizedBox(height: 18),
                        _buildPickupOrdersSection(
                          context,
                          isDark,
                          textColor,
                          subtextColor,
                          borderColor,
                          cardColor,
                        ),
                        const SizedBox(height: 18),
                        _buildTodayActivitySection(
                          riderProvider,
                          isDark,
                          textColor,
                          subtextColor,
                          borderColor,
                          cardColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    AuthProvider authProvider,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
  ) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: SizedBox(
          height: 72,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'NTWAZA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: pureWhite,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                _buildStatusPill(true, borderColor),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _toggleOnlineStatus(true),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isOnline ? pureBlack : accentGreen,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      "Let's Ride",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pureWhite,
                      ),
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

  Widget _buildStatusPill(bool isDark, Color borderColor) {
    return InkWell(
      onTap: () => _toggleOnlineStatus(!_isOnline),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isOnline
              ? accentGreen.withOpacity(0.15)
              : (isDark ? const Color(0xFF1C1C26) : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _isOnline ? accentGreen : (isDark ? borderColor : Colors.grey.shade400),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: _isOnline ? accentGreen : Colors.grey.shade600,
                shape: BoxShape.circle,
                boxShadow: _isOnline
                    ? [
                        BoxShadow(
                          color: accentGreen.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _isOnline ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _isOnline ? accentGreen : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildStatCards(
    RiderOrderProvider riderProvider,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color cardColor,
  ) {
    final summary = _computeTodaySummary(riderProvider);
    final earnings = summary['earnings'] as double;
    final deliveries = summary['deliveries'] as int;
    final available = summary['available'] as int;
    final active = summary['active'] as int;
    final highlightText = Colors.white;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Available Orders',
                value: '$available',
                textColor: textColor,
                subtextColor: subtextColor,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Active Orders',
                value: '$active',
                textColor: textColor,
                subtextColor: subtextColor,
                cardColor: cardColor,
                borderColor: borderColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF000000),
                Color(0xFF1A1A1A),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today Earnings',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: highlightText.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'RWF ${earnings.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: highlightText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: highlightText.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$deliveries completed',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: highlightText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required Color textColor,
    required Color subtextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final isDark = cardColor == softBlack;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1C1C1C)
            : const Color(0xFFDADDE2),
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
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: subtextColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCards(RiderOrderProvider riderProvider, bool isDark) {
    final summary = _computeTodaySummary(riderProvider);
    final earnings = summary['earnings'] as double;
    final textColor = isDark ? pureWhite : pureBlack;
    final cardColor = isDark ? softBlack : pureWhite;
    final borderColor = isDark ? const Color(0xFF1F1F1F) : borderGray;

    return Row(
      children: [
        Expanded(
          child: Material(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.transparent,
            child: InkWell(
              onTap: () => _callSupport(context),
              borderRadius: BorderRadius.circular(12),
              splashColor: accentGreen.withOpacity(0.1),
              highlightColor: accentGreen.withOpacity(0.05),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2937) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.support_agent,
                        color: textColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Support',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: textColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Material(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RiderEarningsScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              splashColor: accentGreen.withOpacity(0.1),
              highlightColor: accentGreen.withOpacity(0.05),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2937) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: textColor,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Earnings',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                    Text(
                      'RWF ${earnings.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableOrdersSection(
    BuildContext context,
    RiderOrderProvider riderProvider,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color cardColor,
  ) {
    // Only show available orders when rider is online
    if (!_isOnline) {
      return const SizedBox.shrink();
    }

    final availableOrders = _sortOrdersByPriority(riderProvider.availableOrders);
    final displayOrders = availableOrders.take(5).toList();
    final hasMore = availableOrders.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Available Orders',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${availableOrders.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentGreen,
                  letterSpacing: 0,
                ),
              ),
            ),
            const Spacer(),
            if (hasMore)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RiderAllOrdersScreen(orders: availableOrders),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accentGreen,
                    letterSpacing: 0,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (availableOrders.isEmpty)
          _buildEmptyAvailableOrders(cardColor, borderColor, textColor, subtextColor)
        else
          Column(
            children: displayOrders
                .map(
                  (order) => _buildAvailableOrderCard(
                    context,
                    order,
                    riderProvider,
                    isDark,
                    textColor,
                    subtextColor,
                    borderColor,
                    cardColor,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  List<Order> _sortOrdersByPriority(List<Order> orders) {
    final sortedOrders = List<Order>.from(orders);
    sortedOrders.sort((a, b) {
      // First, sort by creation time (oldest first - most urgent)
      final aTime = a.createdAt;
      final bTime = b.createdAt;
      if (aTime != null && bTime != null) {
        final timeComparison = aTime.compareTo(bTime);
        if (timeComparison != 0) return timeComparison;
      }
      
      // Then by total amount (higher first - better earnings)
      return b.total.compareTo(a.total);
    });
    return sortedOrders;
  }

  Widget _buildEmptyAvailableOrders(
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Center(
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
                Icons.inbox_outlined,
                size: 32,
                color: accentGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Available Orders',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'New delivery requests will appear here',
              style: TextStyle(
                fontSize: 12,
                color: subtextColor,
                letterSpacing: 0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableOrderCard(
    BuildContext context,
    Order order,
    RiderOrderProvider riderProvider,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color cardColor,
  ) {
    final address = order.deliveryInfo?.address ?? 'Delivery location';
    final itemCount = order.items.length;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RiderOrderDetailScreen(order: order),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Vendor & Price
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
          // Location & Items
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 13, color: subtextColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    fontSize: 11,
                    color: subtextColor,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.inventory_2_outlined, size: 13, color: subtextColor),
              const SizedBox(width: 3),
              Text(
                '$itemCount',
                style: TextStyle(
                  fontSize: 11,
                  color: subtextColor,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    if (order.id == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          _buildSnackBar('Order ID missing', isError: true),
                        );
                      }
                      return;
                    }
                    final confirmed = await _confirmOrderAction(
                      context,
                      title: 'Decline Order',
                      message: 'Are you sure you want to decline this order?',
                      confirmLabel: 'Decline',
                    );
                    if (!confirmed) return;
                    final ok = await riderProvider.rejectOrder(order.id!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        _buildSnackBar(
                          ok ? 'Order declined' : 'Decline failed',
                          isError: !ok,
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (order.id == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          _buildSnackBar('Order ID missing', isError: true),
                        );
                      }
                      return;
                    }
                    final confirmed = await _confirmOrderAction(
                      context,
                      title: 'Accept Order',
                      message: 'Are you sure you want to accept this order?',
                      confirmLabel: 'Accept',
                    );
                    if (!confirmed) return;
                    final ok = await riderProvider.acceptOrder(order.id!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        _buildSnackBar(
                          ok ? 'Order accepted' : 'Accept failed',
                          isError: !ok,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGreen,
                    foregroundColor: pureWhite,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: -0.3,
                    ),
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

  Widget _buildActiveOrdersSection(
    RiderOrderProvider riderProvider,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color cardColor,
    BuildContext context,
  ) {
    final activeOrders = riderProvider.orders;

    if (activeOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Orders',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${activeOrders.length}',
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
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            
          ),
          child: Column(
            children: activeOrders
                .map((order) => _buildActiveOrderCard(
                      order,
                      isDark,
                      textColor,
                      subtextColor,
                      borderColor,
                      cardColor,
                      context,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveOrderCard(
    Order order,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color cardColor,
    BuildContext context,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RiderOrderDetailScreen(order: order),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(11),
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.1 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.orderNumber ?? order.id?.substring(0, 8) ?? 'N/A'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    order.status.value.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: accentGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 13, color: subtextColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.deliveryInfo?.address ?? 'No address',
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
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(Icons.attach_money, size: 13, color: subtextColor),
                Text(
                  'RWF ${order.total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.inventory_2_outlined, size: 13, color: subtextColor),
                const SizedBox(width: 3),
                Text(
                  '${order.items?.length ?? 0} items',
                  style: TextStyle(
                    fontSize: 11,
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

  Widget _buildPickupOrdersSection(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color cardColor,
  ) {
    final pickupProvider = context.watch<PickupOrderProvider>();
    final pickupOrders = pickupProvider.riderAssignedOrders;

    if (pickupOrders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pickup Orders',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${pickupOrders.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            
          ),
          child: Column(
            children: pickupOrders
                .map((order) => _buildPickupOrderCard(
                      order,
                      isDark,
                      textColor,
                      subtextColor,
                      borderColor,
                      context,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _promptPickupCode(PickupOrder order) async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Pickup Code'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: '4-digit code',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (code == null || code.isEmpty) return;

    final provider = context.read<PickupOrderProvider>();
    final ok = await provider.updateOrderStatus(
      order.id,
      PickupOrderStatus.pickedUp,
      pickupCode: code,
    );

    if (!mounted) return;

    if (ok) {
      final riderId = context.read<AuthProvider>().user?.id;
      if (riderId != null && riderId.isNotEmpty) {
        await provider.fetchRiderPickupOrders(riderId);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar('Pickup confirmed. Status updated.'),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        _buildSnackBar(provider.error ?? 'Failed to verify pickup code'),
      );
    }
  }

  Widget _buildPickupOrderCard(
    PickupOrder order,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    BuildContext context,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RiderPickupOrderDetailScreen(order: order),
          ),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.black : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pickup #${order.orderNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentGreen.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentGreen.withOpacity(0.3)),
                  ),
                  child: Text(
                    order.statusDisplay.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: accentGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: subtextColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.pickupLocation.address,
                    style: TextStyle(
                      fontSize: 11,
                      color: subtextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.attach_money, size: 14, color: subtextColor),
                Text(
                  'RWF ${order.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.inventory_2_outlined, size: 14, color: subtextColor),
                const SizedBox(width: 4),
                Text(
                  '${order.items.length} items',
                  style: TextStyle(
                    fontSize: 11,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
            if (order.status == PickupOrderStatus.assignedToRider) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _promptPickupCode(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Enter Pickup Code',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodayActivitySection(
    RiderOrderProvider riderProvider,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color cardColor,
  ) {
    final recentOrders = riderProvider.deliveryHistory.take(6).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Today\'s Activity',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            if (recentOrders.isNotEmpty)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RiderDeliveryHistory(),
                    ),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (recentOrders.isEmpty)
          _buildEmptyActivityCard(isDark, cardColor, borderColor)
        else
          Column(
            children: recentOrders
                .map((order) => _buildActivityTile(
              order,
              isDark,
              textColor,
              subtextColor,
              borderColor,
              cardColor,
            ))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildEmptyActivityCard(
    bool isDark,
    Color cardColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 32, color: isDark ? pureWhite : pureBlack),
            const SizedBox(height: 12),
            Text(
              'No active deliveries',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stay ready. New orders can drop anytime.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(
    Order order,
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color borderColor,
    Color cardColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.transparent,
            child: Icon(Icons.person, color: textColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.vendorName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  order.deliveryInfo?.address ?? 'Delivery location',
                  style: TextStyle(
                    fontSize: 10,
                    color: subtextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RWF ${order.total.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: accentGreen,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _computeTodaySummary(RiderOrderProvider riderProvider) {
    final now = nowInRwanda();
    final todayOrders = riderProvider.deliveryHistory.where((order) {
      final completedAt = order.completedAt;
      if (completedAt == null) return false;
      final rwandaTime = toRwandaTime(completedAt);
      return rwandaTime.year == now.year &&
          rwandaTime.month == now.month &&
          rwandaTime.day == now.day;
    }).toList();

    final earnings = todayOrders.fold<double>(
      0,
      (sum, order) =>
          sum + (order.deliveryFee > 0 ? order.deliveryFee : order.total),
    );

    return {
      'earnings': earnings,
      'deliveries': todayOrders.length,
      'available': riderProvider.availableOrders.length,
      'active': riderProvider.orders.length,
    };
  }

  void _showMenuSheet(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final user = authProvider.user;

        return Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : borderGray,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isDark ? pureWhite : pureBlack,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.two_wheeler,
                          color: isDark ? pureBlack : pureWhite,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.firstName ?? 'Rider',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user?.email ?? '',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildMenuTile(
                  icon: Icons.account_balance_wallet,
                  title: 'Earnings',
                  isDark: isDark,
                  onTap: () {
                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RiderEarningsScreen(),
                        ),
                      );
                    }
                  },
                ),
                _buildMenuTile(
                  icon: Icons.person,
                  title: 'Profile',
                  isDark: isDark,
                  onTap: () {
                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RiderProfileScreen(),
                        ),
                      );
                    }
                  },
                ),
                _buildMenuTile(
                  icon: Icons.support_agent,
                  title: 'Support',
                  subtitle: supportPhone,
                  isDark: isDark,
                  onTap: () => _callSupport(context),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Divider(
                    color: isDark ? const Color(0xFF2A2A2A) : borderGray,
                    height: 1,
                    thickness: 1,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Material(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () async {
                        final outerContext = context;
                        Navigator.pop(outerContext);
                        final shouldLogout = await showDialog<bool>(
                          context: outerContext,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: isDark ? Colors.black : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            title: Text(
                              'Logout',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            content: Text(
                              'Are you sure you want to logout?',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 15,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(dialogContext, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: pureWhite,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (shouldLogout == true && outerContext.mounted) {
                          await authProvider.logout();
                          if (outerContext.mounted) outerContext.go('/login');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.logout,
                                color: Colors.red,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Logout',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.red,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).brightness == Brightness.dark ? Colors.transparent : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  icon,
                  color: isDark ? Colors.white : Colors.black,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
