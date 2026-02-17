import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vendor_order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/order.dart';
import 'vendor_order_detail_screen.dart';
import 'vendor_notifications_screen.dart';
import 'vendor_earnings_screen.dart';
import 'vendor_profile_screen.dart';
import 'vendor_products_screen.dart';
import 'package:go_router/go_router.dart';
import '../../utils/helpers.dart';

class VendorMainScreen extends StatefulWidget {
  const VendorMainScreen({super.key});

  @override
  State<VendorMainScreen> createState() => _VendorMainScreenState();
}

class _VendorMainScreenState extends State<VendorMainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _orderTabController;

  @override
  void initState() {
    super.initState();
    _orderTabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeDashboard());
  }

  Future<void> _initializeDashboard() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null || authProvider.user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      await context.read<NotificationProvider>().initialize(pollingInterval: 10);
      await context.read<VendorOrderProvider>().initialize(autoRefreshSeconds: 10);
    } catch (e) {
      if (e.toString().contains('401') && mounted) {
        await authProvider.logout();
        if (mounted) context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    _orderTabController.dispose();
    context.read<NotificationProvider>().stopPolling();
    context.read<VendorOrderProvider>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final orderProvider = context.watch<VendorOrderProvider>();
    final notificationProvider = context.watch<NotificationProvider>();
    final isDark = themeProvider.isDarkMode;
    final backgroundColor = isDark ? const Color(0xFF202124) : const Color(0xFFDADDE2);

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      );
    }

    if (!authProvider.isVendor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return Scaffold(
        backgroundColor: backgroundColor,
        body: Center(
          child: Text(
            'Vendor access only',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
        ),
      );
    }

    final user = authProvider.user;
    final isRestaurant = _isRestaurant(user);
    final vendorConfig = _getVendorConfig(isRestaurant);
    final businessName = authProvider.user?.businessName ??
        authProvider.user?.email.split('@')[0] ??
        'Vendor';

    final dashboardTab = CustomScrollView(
      slivers: [
        // Compact Header
        SliverToBoxAdapter(
          child: Container(
            color: isDark ? const Color(0xFF202124) : Colors.black,
            padding: const EdgeInsets.fromLTRB(20, 45, 20, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: notificationProvider.isPolling ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            notificationProvider.isPolling ? 'Live' : 'Offline',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildIconButton(
                  icon: Icons.notifications_outlined,
                  badge: notificationProvider.unreadCount,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VendorNotificationsScreen()),
                  ),
                ),
                const SizedBox(width: 8),
                _buildIconButton(
                  icon: Icons.menu,
                  onTap: () => _showMenuSheet(context, authProvider),
                ),
              ],
            ),
          ),
        ),

        // Content
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverToBoxAdapter(
            child: orderProvider.isLoading
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : Colors.black,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTodayStats(
                        orderProvider.todayOrderCount,
                        vendorConfig.orderLabel,
                        () => setState(() => _selectedIndex = 2),
                        isDark,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              orderProvider.pendingCount,
                              'Pending',
                              Colors.orange,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusCard(
                              orderProvider.preparingCount,
                              vendorConfig.preparingLabel,
                              Colors.blue,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              orderProvider.readyCount,
                              'Ready',
                              Colors.green,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusCard(
                              orderProvider.completedCount,
                              'Completed',
                              Colors.grey,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent ${vendorConfig.orderLabel}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selectedIndex = 2),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View all',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (orderProvider.orders.isEmpty)
                        _buildEmptyState(
                          Icons.receipt_outlined,
                          'No ${vendorConfig.orderLabel.toLowerCase()} yet',
                          'New ${vendorConfig.orderLabel.toLowerCase()} will appear here',
                          isDark,
                        )
                      else
                        ...orderProvider.orders.take(5).map(
                              (order) => _buildOrderCard(
                                order,
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VendorOrderDetailScreen(orderId: order.id),
                                  ),
                                ).then((_) => orderProvider.fetchOrders()),
                                isDark,
                              ),
                            ),
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ),
      ],
    );

    final screens = [
      dashboardTab,
      const VendorProductsTab(),
      VendorOrdersTab(tabController: _orderTabController),
      const VendorProfileScreen(),
    ];

    final productIcon = isRestaurant
        ? Icons.restaurant_menu_outlined
        : Icons.inventory_2_outlined;
    final productSelectedIcon = isRestaurant
        ? Icons.restaurant_menu_rounded
        : Icons.inventory_2_rounded;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        color: isDark ? const Color(0xFF202124) : Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: Colors.transparent,
            indicatorColor: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
            height: 64,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(color: isDark ? Colors.white : Colors.black);
              }
              return IconThemeData(
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              );
            }),
            labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, color: Colors.transparent),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(productIcon),
                selectedIcon: Icon(productSelectedIcon),
                label: vendorConfig.tabLabel,
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isRestaurant(user) {
    if (user == null) return false;
    final businessType = user.businessType?.toLowerCase() ?? '';
    final vendorType = user.vendorType?.toLowerCase() ?? '';
    return businessType.contains('restaurant') ||
        vendorType.contains('restaurant') ||
        user.usesMenuSystem == true;
  }

  VendorConfig _getVendorConfig(bool isRestaurant) {
    if (isRestaurant) {
      return VendorConfig(
        icon: Icons.restaurant,
        orderLabel: 'Orders',
        productLabel: 'Menu Items',
        preparingLabel: 'Preparing',
        tabLabel: 'Menu',
      );
    }
    return VendorConfig(
      icon: Icons.shopping_bag,
      orderLabel: 'Orders',
      productLabel: 'Products',
      preparingLabel: 'Packing',
      tabLabel: 'Products',
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    int? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(child: Icon(icon, color: Colors.white, size: 20)),
            if (badge != null && badge > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badge > 9 ? '9+' : badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats(
    int count,
    String label,
    VoidCallback onTap,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TODAY\'S ${label.toUpperCase()}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: -2,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(int count, String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: -1,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order, VoidCallback onTap, bool isDark) {
    Color statusColor = Colors.orange;
    if (order.status == OrderStatus.preparing) statusColor = Colors.blue;
    if (order.status == OrderStatus.ready) statusColor = Colors.green;
    if (order.status == OrderStatus.completed) statusColor = Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF202124) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        shortenOrderNumber(order.orderNumber),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          order.statusDisplay.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${order.customerName} • ${order.itemCount} item${order.itemCount > 1 ? "s" : ""}',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.timeAgo,
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Rwf ${order.total.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    IconData icon,
    String title,
    String message,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[500],
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showMenuSheet(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          final isDark = themeProvider.isDarkMode;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Profile Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.grey[850]!, Colors.grey[800]!]
                            : [Colors.grey[100]!, Colors.grey[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [Colors.white, Colors.grey[300]!]
                                  : [Colors.black, Colors.grey[800]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.store_rounded,
                            color: isDark ? Colors.black : Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authProvider.user?.businessName ??
                                    authProvider.user?.email.split('@')[0] ??
                                    'Vendor',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authProvider.user?.email ?? '',
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
                  
                  // Menu Items
                  _MenuTile(
                    icon: themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    title: 'Dark Mode',
                    isDark: isDark,
                    trailing: Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: themeProvider.isDarkMode,
                        onChanged: (_) => themeProvider.toggleTheme(),
                        activeColor: isDark ? Colors.white : Colors.black,
                        activeTrackColor: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
                      ),
                    ),
                    onTap: () => themeProvider.toggleTheme(),
                  ),
                  
                  _MenuTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Product Earnings',
                    subtitle: 'View your sales income',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VendorEarningsScreen()),
                      );
                    },
                  ),
                  

                  
                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Divider(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      height: 1,
                      thickness: 1,
                    ),
                  ),
                  
                  // Logout Button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Material(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () async {
                          final screenContext = context;
                          final shouldLogout = await showDialog<bool>(
                            context: screenContext,
                            builder: (dialogContext) => AlertDialog(
                              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.logout_rounded,
                                      color: Colors.red,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 22,
                                      color: isDark ? Colors.white : Colors.black,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                              content: Text(
                                'Are you sure you want to logout from your account?',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, false),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 28, vertical: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Logout',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                            ),
                          );
                          if (shouldLogout == true && screenContext.mounted) {
                            await authProvider.logout();
                            if (screenContext.mounted) screenContext.go('/login');
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  color: Colors.red,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Logout',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Sign out of your account',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.red.withOpacity(0.5),
                                size: 18,
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
      ),
    );
  }
}

class VendorConfig {
  final IconData icon;
  final String orderLabel;
  final String productLabel;
  final String preparingLabel;
  final String tabLabel;

  VendorConfig({
    required this.icon,
    required this.orderLabel,
    required this.productLabel,
    required this.preparingLabel,
    required this.tabLabel,
  });
}

class VendorProductsTab extends StatelessWidget {
  const VendorProductsTab({super.key});

  @override
  Widget build(BuildContext context) => const VendorProductsScreen();
}

class VendorOrdersTab extends StatefulWidget {
  final TabController tabController;
  const VendorOrdersTab({super.key, required this.tabController});

  @override
  State<VendorOrdersTab> createState() => _VendorOrdersTabState();
}

class _VendorOrdersTabState extends State<VendorOrdersTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<VendorOrderProvider>();
    final user = context.watch<AuthProvider>().user;
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final isRestaurant = _isRestaurant(user);
    final preparingLabel = isRestaurant ? 'Preparing' : 'Packing';
    final query = _searchQuery.trim().toLowerCase();

    bool matchesQuery(Order order) {
      if (query.isEmpty) return true;
      return order.orderNumber.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query);
    }

    return RefreshIndicator(
      onRefresh: () => orderProvider.fetchOrders(),
      color: isDark ? Colors.white : Colors.black,
      child: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF202124) : Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Orders',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF202124) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.refresh,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        onPressed: () => orderProvider.fetchOrders(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF202124) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                      hintText: 'Search order number or customer',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                        fontSize: 12,
                      ),
                      border: InputBorder.none,
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF202124) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    ),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: TabBar(
                    controller: widget.tabController,
                    indicator: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    labelColor: isDark ? Colors.black : Colors.white,
                    unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: [
                      const Tab(text: 'Pending'),
                      Tab(text: preparingLabel),
                      const Tab(text: 'Ready'),
                      const Tab(text: 'Done'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF202124) : Colors.white,
              child: orderProvider.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDark ? Colors.white : Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                  : TabBarView(
                      controller: widget.tabController,
                      children: [
                        _OrdersList(
                          orders: orderProvider.orders
                              .where((o) => o.status == OrderStatus.pending)
                              .where(matchesQuery)
                              .toList(),
                          emptyMessage: 'No pending orders',
                        ),
                        _OrdersList(
                          orders: orderProvider.orders
                              .where((o) => o.status == OrderStatus.preparing)
                              .where(matchesQuery)
                              .toList(),
                          emptyMessage: 'No orders being ${preparingLabel.toLowerCase()}',
                        ),
                        _OrdersList(
                          orders: orderProvider.orders
                              .where((o) => o.status == OrderStatus.ready)
                              .where(matchesQuery)
                              .toList(),
                          emptyMessage: 'No orders ready',
                        ),
                        _OrdersList(
                          orders: orderProvider.orders
                              .where((o) => o.status == OrderStatus.completed)
                              .where(matchesQuery)
                              .toList(),
                          emptyMessage: 'No completed orders',
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isRestaurant(user) {
    if (user == null) return false;
    final businessType = user.businessType?.toLowerCase() ?? '';
    final vendorType = user.vendorType?.toLowerCase() ?? '';
    return businessType.contains('restaurant') ||
        vendorType.contains('restaurant') ||
        user.usesMenuSystem == true;
  }
}

class _OrdersList extends StatelessWidget {
  final List<Order> orders;
  final String emptyMessage;
  const _OrdersList({required this.orders, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    if (orders.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202124) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 56,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                style: TextStyle(
                  color: isDark ? Colors.grey[200] : Colors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Pull to refresh to check for new orders',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        Color statusColor = Colors.orange;
        if (order.status == OrderStatus.preparing) statusColor = Colors.blue;
        if (order.status == OrderStatus.ready) statusColor = Colors.green;
        if (order.status == OrderStatus.completed) statusColor = Colors.grey;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VendorOrderDetailScreen(orderId: order.id),
            ),
          ).then((_) => context.read<VendorOrderProvider>().fetchOrders()),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 54,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            shortenOrderNumber(order.orderNumber),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              order.statusDisplay.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${order.customerName} • ${order.itemCount} item${order.itemCount > 1 ? "s" : ""}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.timeAgo,
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Rwf ${order.total.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MinimalNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;
  const _MinimalNavBar({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final authProvider = context.watch<AuthProvider>();
    final isDark = themeProvider.isDarkMode;

    final navItems = [
      _NavBarItem(icon: Icons.home_outlined, label: 'Home'),
      _NavBarItem(icon: Icons.inventory_2_outlined, label: 'Products'),
      _NavBarItem(icon: Icons.receipt_long_outlined, label: 'Orders'),
      _NavBarItem(icon: Icons.person_outline, label: 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202124) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(navItems.length, (index) {
              final item = navItems[index];
              return _NavItem(
                icon: item.icon,
                label: item.label,
                isSelected: selectedIndex == index,
                onTap: () => onTap(index),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem {
  final IconData icon;
  final String label;
  _NavBarItem({required this.icon, required this.label});
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.grey[600] : Colors.black),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? Colors.grey[600] : Colors.black),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDark;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.isDark,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDark ? Colors.white : Colors.black,
                  size: 22,
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
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
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
              if (trailing != null)
                trailing!
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
