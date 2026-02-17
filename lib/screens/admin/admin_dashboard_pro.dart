// lib/screens/admin/admin_dashboard_pro.dart
// PROFESSIONAL ADMIN DASHBOARD - Mobile-First Design
// Focuses on: Orders (Pickups/Dropoffs), Riders, Money Management, Issues & Alerts
// Real data only - no web-specific features or dummy data

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/order.dart';
import '../../utils/helpers.dart';
import '../../services/api/api_service.dart';
import '../../services/admin_dashboard_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/admin/modern_admin_header.dart';
import '../../widgets/admin/notifications_panel.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// Helper function to format currency
String formatCurrency(double amount) {
  return amount.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},'
  );
}

// Color palette - match rider app (black, white, gray, green accent)
class AppColors {
  static const primary = Color(0xFF4CAF50);  // Green accent
  static const success = Color(0xFF2E7D32);  // Deep green
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF4CAF50);  // Green
  
  // Legacy static colors - used where context is not available
  static const background = Color(0xFFDADDE2);  // Rider light background
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF0B0B0B);  // Rider black
  static const textSecondary = Color(0xFF6B7280);  // Rider muted gray
  static const border = Color(0xFFE5E7EB);  // Rider border gray
  
  // Theme-aware methods - use these in new code with context
  static Color getBackground(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
    ? const Color(0xFF0B0B0B) : const Color(0xFFDADDE2);
  
  static Color getSurface(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
    ? const Color(0xFF000000) : Colors.white;
  
  static Color getTextPrimary(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
    ? const Color(0xFFFFFFFF) : const Color(0xFF0B0B0B);
  
  static Color getTextSecondary(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
    ? Colors.white70 : const Color(0xFF6B7280);
  
  static Color getBorder(BuildContext context) => Theme.of(context).brightness == Brightness.dark 
    ? const Color(0xFF1F1F1F) : const Color(0xFFE5E7EB);
}

class AdminDashboardPro extends StatefulWidget {
  const AdminDashboardPro({super.key});

  @override
  State<AdminDashboardPro> createState() => _AdminDashboardProState();
}

class _AdminDashboardProState extends State<AdminDashboardPro> {
  int _selectedIndex = 0;
  static const int _pollSeconds = 10;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  Future<void> _initializeDashboard() async {
    try {
      // Initialize notification provider and start polling
      final notificationProvider = context.read<NotificationProvider>();
      await notificationProvider.initialize(pollingInterval: _pollSeconds);
      print('✅ NotificationProvider initialized with ${_pollSeconds}s polling');
      
      // Initialize push notifications (handles permissions internally)
      final notificationService = NotificationService();
      await notificationService.initialize();
      
      // Get FCM token with retry logic
      String? fcmToken;
      for (int i = 0; i < 3; i++) {
        try {
          fcmToken = await notificationService.getFCMToken();
          if (fcmToken != null) break;
        } catch (e) {
          print('⚠️ Attempt ${i + 1} to get FCM token failed: $e');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      if (fcmToken != null) {
        print('✅ Push notifications enabled - FCM Token: ${fcmToken.substring(0, 20)}...');
        print('📱 Push notifications will be received in real-time');
        // TODO: Send FCM token to backend to associate with admin user
        // This allows the backend to send push notifications to this device
      } else {
        print('⚠️ FCM token not available - push notifications disabled');
        print('💬 Falling back to polling method every ${_pollSeconds} seconds');
      }
      
      // Initialize orders provider
      await context.read<AdminOrderProvider>().initialize(autoRefreshSeconds: _pollSeconds);
      print('✅ AdminOrderProvider initialized');
      
    } catch (e) {
      print('❌ Dashboard init error: $e');
    }
  }

  @override
  void dispose() {
    context.read<NotificationProvider>().stopPolling();
    context.read<AdminOrderProvider>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    
    if (!authProvider.isAdmin) {
      return _buildAccessDenied(context);
    }

    final screens = [
      const OrdersOverviewTab(),
      const RidersManagementTab(),
      const MoneyManagementTab(),
      const IssuesAlertsTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: _selectedIndex == 0 ? ModernAdminHeader(
        onNotifications: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (context) => SizedBox(
              height: MediaQuery.of(context).size.height,
              child: const NotificationsPanel(),
            ),
          );
        },
        unreadNotifications: context.watch<NotificationProvider>().unreadCount,
      ) : null,
      endDrawer: _buildHamburgerMenu(context),
      body: screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildAccessDenied(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, size: 64, color: AppColors.danger),
            ),
            const SizedBox(height: 24),
            Text(
              'Admin Access Required',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.getTextPrimary(context)),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHamburgerMenu(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkMode = themeProvider.isDarkMode;

    return Drawer(
      backgroundColor: AppColors.getBackground(context),
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode
                      ? [const Color(0xFF0B0B0B), const Color(0xFF1A1A1A)]
                      : [const Color(0xFFFFFFFF), const Color(0xFFFAFAFA)],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.1)
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF45a049)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (authProvider.user?.email ?? 'admin@NTWAZA.com').toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextSecondary(context),
                            letterSpacing: 0.5,
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

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Dark/Light Mode Toggle
                  _MenuSection(
                    title: 'Theme',
                    isDarkMode: isDarkMode,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isDarkMode
                                  ? Icons.dark_mode_rounded
                                  : Icons.light_mode_rounded,
                              color: isDarkMode
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFF4CAF50),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isDarkMode ? 'Dark Mode' : 'Light Mode',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                          ],
                        ),
                        Material(
                          color: Colors.transparent,
                          child: Switch(
                            value: isDarkMode,
                            onChanged: (_) => themeProvider.toggleTheme(),
                            activeColor: const Color(0xFF4CAF50),
                            inactiveThumbColor: const Color(0xFFFFD700),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  _MenuSection(
                    title: 'Quick Actions',
                    isDarkMode: isDarkMode,
                  ),
                  _MenuItemButton(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    subtitle: 'View orders overview',
                    isDarkMode: isDarkMode,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  _MenuItemButton(
                    icon: Icons.people_outline_rounded,
                    title: 'Riders',
                    subtitle: 'Manage delivery partners',
                    isDarkMode: isDarkMode,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 8),
                  _MenuItemButton(
                    icon: Icons.assessment_rounded,
                    title: 'Reports',
                    subtitle: 'View analytics & reports',
                    isDarkMode: isDarkMode,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),

            // Logout Button - Bottom
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor:
                            isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.logout_rounded,
                                  color: Colors.red, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: AppColors.getTextPrimary(context),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        content: Text(
                          'Are you sure you want to logout from the admin dashboard?',
                          style: TextStyle(
                              color: AppColors.getTextSecondary(context)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: AppColors.getBorder(context),
                                ),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                  color: AppColors.getTextSecondary(context)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              authProvider.logout();
                              context.go('/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Logout',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Colors.white.withOpacity(0.9)),
                      const SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF1F2937),
          height: 64,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.white);
            }
            return const IconThemeData(color: Color(0xFF9CA3AF));
          }),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, color: Colors.transparent),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.two_wheeler_outlined),
              selectedIcon: Icon(Icons.two_wheeler_rounded),
              label: 'Riders',
            ),
            NavigationDestination(
              icon: Icon(Icons.attach_money_outlined),
              selectedIcon: Icon(Icons.attach_money_rounded),
              label: 'Money',
            ),
            NavigationDestination(
              icon: Icon(Icons.warning_amber_outlined),
              selectedIcon: Icon(Icons.warning_amber_rounded),
              label: 'Alerts',
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. ORDERS OVERVIEW TAB - Pickups & Drop-offs
// ═══════════════════════════════════════════════════════════════════════════
class OrdersOverviewTab extends StatefulWidget {
  const OrdersOverviewTab({super.key});

  @override
  State<OrdersOverviewTab> createState() => _OrdersOverviewTabState();
}

class _OrdersOverviewTabState extends State<OrdersOverviewTab> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      if (authProvider.token != null) {
        apiService.setAuthToken(authProvider.token!);
      }
      
      final service = AdminDashboardService(apiService);
      final stats = await service.getStats();
      await context.read<AdminOrderProvider>().fetchOrders();
      
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('❌ Error loading orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersProvider = context.watch<AdminOrderProvider>();
    final activeOrders = ordersProvider.orders
        .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
        .toList();

    if (_isLoading || ordersProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final orders = _stats?['orders'] as Map<String, dynamic>? ?? {};
    final pendingPickups = activeOrders
        .where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.confirmed)
        .length;
    final inTransit = activeOrders.where((o) => o.status == OrderStatus.pickedUp).length;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            
            // Quick Stats
            Row(
              children: [
                Expanded(child: _StatCard('Pending Pickups', '$pendingPickups', Icons.schedule, AppColors.warning)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard('In Transit', '$inTransit', Icons.local_shipping, AppColors.info)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _StatCard('Completed Today', '${orders['completed_today'] ?? 0}', Icons.check_circle, AppColors.success)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard('Total Today', '${orders['today'] ?? 0}', Icons.receipt_long, AppColors.primary)),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Active Orders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Orders',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                TextButton.icon(
                  onPressed: () => context.push('/admin-pickup-orders'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (activeOrders.isEmpty)
              _buildEmptyState()
            else
              ...activeOrders.take(10).map((order) => _OrderCard(order)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Orders',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        Text(
          DateFormat('EEEE, MMMM d').format(nowInRwanda()),
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No active orders',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.getTextPrimary(context),
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.getTextSecondary(context),
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard(this.order);

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (order.status.value) {
      case 'pending':
        statusColor = AppColors.warning;
        statusText = 'Waiting Pickup';
        statusIcon = Icons.schedule;
        break;
      case 'confirmed':
        statusColor = AppColors.info;
        statusText = 'Ready for Pickup';
        statusIcon = Icons.check_circle;
        break;
      case 'picked_up':
        statusColor = AppColors.primary;
        statusText = 'In Transit';
        statusIcon = Icons.local_shipping;
        break;
      case 'delivered':
        statusColor = AppColors.success;
        statusText = 'Delivered';
        statusIcon = Icons.done_all;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusText = order.status.value;
        statusIcon = Icons.info;
    }

    final isInTransit = order.status.value == 'picked_up';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showOrderDetails(context, order),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row - Order Number & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${order.orderNumber ?? order.id}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            order.customerName ?? 'Customer',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [statusColor, statusColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Location & Amount Row (Minimal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.getBackground(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.getTextSecondary(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.deliveryInfo?.address ?? 'No address',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.getTextSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'RWF ${formatCurrency(order.total)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                // Footer - Time, Items, Chat
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13, color: AppColors.getTextSecondary(context).withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(order.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextSecondary(context).withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.shopping_bag_outlined, size: 13, color: AppColors.getTextSecondary(context).withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text(
                      '${order.items.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.getTextSecondary(context).withOpacity(0.8),
                      ),
                    ),
                    const Spacer(),
                    if (isInTransit)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outlined, size: 12, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Chat',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
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

  void _showOrderDetails(BuildContext context, Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderDetailsSheet(order),
    );
  }

  String _formatTime(DateTime dateTime) {
    final diff = nowInRwanda().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return formatRwandaTime(dateTime, 'MMM d, h:mm a');
  }
}

// Enhanced Order Details Sheet with Communication
class _OrderDetailsSheet extends StatefulWidget {
  final Order order;

  const _OrderDetailsSheet(this.order);

  @override
  State<_OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends State<_OrderDetailsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      if (authProvider.token != null) {
        apiService.setAuthToken(authProvider.token!);
      }
      
      final service = AdminDashboardService(apiService);
      final messages = await service.getOrderMessages(widget.order.id);
      
      setState(() {
        _comments.clear();
        
        // Add special instructions as first message if exists
        if (widget.order.specialInstructions != null && 
            widget.order.specialInstructions!.isNotEmpty) {
          _comments.add({
            'sender': 'customer',
            'name': widget.order.customerName ?? 'Customer',
            'message': widget.order.specialInstructions!,
            'time': widget.order.createdAt,
          });
        }
        
        // Add API messages
        _comments.addAll(messages.map((msg) => {
          'sender': msg['sender_type'] ?? 'system',
          'name': msg['sender_name'] ?? 'System',
          'message': msg['message'] ?? '',
          'time': parseServerTime(msg['created_at'] ?? DateTime.now().toIso8601String()),
        }));
        
        _isLoadingComments = false;
      });
    } catch (e) {
      print('❌ Error loading comments: $e');
      setState(() {
        // Fallback to showing special instructions only
        if (widget.order.specialInstructions != null && 
            widget.order.specialInstructions!.isNotEmpty) {
          _comments.add({
            'sender': 'customer',
            'name': widget.order.customerName ?? 'Customer',
            'message': widget.order.specialInstructions!,
            'time': widget.order.createdAt,
          });
        }
        _isLoadingComments = false;
      });
    }
  }

  void _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    final message = _commentController.text.trim();
    
    setState(() {
      _comments.add({
        'sender': 'admin',
        'name': 'Admin',
        'message': message,
        'time': nowInRwanda(),
      });
    });
    
    _commentController.clear();
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      if (authProvider.token != null) {
        apiService.setAuthToken(authProvider.token!);
      }
      
      final service = AdminDashboardService(apiService);
      await service.sendOrderMessage(
        orderId: widget.order.id,
        message: message,
        recipients: ['customer', 'vendor', 'rider'], // Send to all parties
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.white),
              SizedBox(width: 8),
              Text('Message sent • Push notifications delivered'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInTransit = widget.order.status.value == 'picked_up';
    bool isDarkMode(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height,
      color: isDarkMode(context) ? const Color(0xFF0F0F0F) : Colors.white,
      child: Column(
        children: [
          // Header - Full width, prominent
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(32, 36, 32, 24),
            color: isDarkMode(context) ? const Color(0xFF1A1A1A) : Colors.white,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode(context) ? Colors.white : Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${widget.order.orderNumber ?? widget.order.id}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, size: 32, color: isDarkMode(context) ? Colors.white : Colors.black),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              children: [
                // Status Timeline
                _buildStatusTimeline(isDarkMode(context)),
                const SizedBox(height: 32),
                // Customer Info Section
                _buildDetailSection(
                  'Customer Information',
                  Icons.person,
                  widget.order.customerName ?? 'Unknown',
                  [
                    {'label': 'Phone', 'value': widget.order.customerPhone ?? 'No phone number'},
                  ],
                  isDarkMode(context),
                ),
                const SizedBox(height: 24),
                // Delivery Address
                _buildDetailSection(
                  'Delivery Address',
                  Icons.location_on,
                  widget.order.deliveryInfo?.address ?? 'No address',
                  [
                    {'label': 'Notes', 'value': widget.order.deliveryInfo?.notes ?? 'No delivery notes'},
                  ],
                  isDarkMode(context),
                ),
                const SizedBox(height: 24),
                // Rider Info (if assigned)
                if (widget.order.deliveryInfo?.driverName != null)
                  _buildDetailSection(
                    'Rider Information',
                    Icons.delivery_dining,
                    widget.order.deliveryInfo!.driverName!,
                    [
                      {'label': 'Phone', 'value': widget.order.deliveryInfo!.driverPhone ?? 'No phone'},
                    ],
                    isDarkMode(context),
                  ),
                const SizedBox(height: 24),
                // Special Instructions
                if (widget.order.specialInstructions != null && widget.order.specialInstructions!.isNotEmpty)
                  _buildSpecialInstructionsCard(isDarkMode(context)),
                const SizedBox(height: 24),
                // Order Items
                _buildOrderItemsCard(isDarkMode(context)),
                const SizedBox(height: 24),
                // Order Summary
                _buildOrderSummaryCard(isDarkMode(context)),
                const SizedBox(height: 32),
                // Communication Section (for in-transit orders)
                if (isInTransit) ...[
                  _buildCommunicationHeader(isDarkMode(context)),
                  const SizedBox(height: 16),
                  // Comments List
                  if (_isLoadingComments)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  else if (_comments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDarkMode(context) ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'No messages yet • Start the conversation',
                          style: TextStyle(
                            color: isDarkMode(context) ? Colors.grey.shade600 : Colors.grey.shade600,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._comments.map((comment) => _CommentBubble(comment, isDarkMode(context))).toList(),
                ],
              ],
            ),
          ),
          
          // Comment Input (for in-transit orders)
          if (isInTransit)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode(context) ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode(context) ? 0.3 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: TextStyle(
                          color: isDarkMode(context) ? Colors.white : Colors.black,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Send message to customer & rider...',
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: isDarkMode(context) ? Colors.grey.shade600 : Colors.grey.shade500,
                          ),
                          filled: true,
                          fillColor: isDarkMode(context) ? const Color(0xFF2A2A2A) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDarkMode(context) ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: isDarkMode(context) ? Colors.white12 : Colors.black12,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.info],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _sendComment,
                        icon: const Icon(Icons.send, color: Colors.white, size: 24),
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildStatusTimeline(bool isDarkMode) {
    final statuses = ['Pending', 'Confirmed', 'Picked Up', 'Delivered'];
    final currentIndex = ['pending', 'confirmed', 'picked_up', 'delivered'].indexOf(widget.order.status.value);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Order Status Timeline',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(statuses.length, (index) {
              final isCompleted = index <= currentIndex;
              final isCurrent = index == currentIndex;
              
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.primary : (isDarkMode ? Colors.white12 : Colors.black12),
                        shape: BoxShape.circle,
                        boxShadow: isCurrent ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ] : null,
                      ),
                      child: Center(
                        child: Text(
                          (index + 1).toString(),
                          style: TextStyle(
                            color: isCompleted ? Colors.white : (isDarkMode ? Colors.grey : Colors.black54),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      statuses[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w500,
                        color: isCompleted 
                          ? (isDarkMode ? Colors.white : Colors.black)
                          : (isDarkMode ? Colors.grey.shade600 : Colors.black54),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailSection(String title, IconData icon, String mainValue, List<Map<String, String>> details, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mainValue,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...details.map((detail) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    detail['icon'] as IconData? ?? Icons.info,
                    size: 14,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail['label'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail['value'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ],
      ),
    );
  }
  
  Widget _buildSpecialInstructionsCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2, size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              Text(
                'Special Instructions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.order.specialInstructions!,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.white70 : Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOrderItemsCard(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shopping_bag, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Order Items',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.order.items.length} items',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.order.items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.quantity}x',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'RWF ${formatCurrency(item.price)} each',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'RWF ${formatCurrency(item.price * item.quantity)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
  
  Widget _buildOrderSummaryCard(bool isDarkMode) {
    final subtotal = widget.order.items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));
    final deliveryFee = widget.order.total - subtotal; // Assuming total = subtotal + delivery
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Subtotal', subtotal, isDarkMode),
          _buildSummaryRow('Delivery Fee', deliveryFee, isDarkMode),
          Divider(color: isDarkMode ? Colors.white12 : Colors.black12, height: 12),
          _buildSummaryRow('Total', widget.order.total, isDarkMode, isTotal: true),
        ],
      ),
    );
  }
  
  Widget _buildSummaryRow(String label, double amount, bool isDarkMode, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          Text(
            'RWF ${formatCurrency(amount)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 13,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? AppColors.primary : (isDarkMode ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommunicationHeader(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chat_bubble, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  'Live Communication',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }


  Widget _buildInfoCard(String title, IconData icon, List<Map<String, String>> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    item['label']!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    item['value']!,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildItemsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.shopping_bag, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Items',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${widget.order.items.length} items',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.order.items.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${item.quantity}x',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.productName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
                Text(
                  'RWF ${formatCurrency(item.price * item.quantity)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
          )).toList(),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                'RWF ${formatCurrency(widget.order.total)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Comment Bubble Widget - Updated with Dark Mode Support
class _CommentBubble extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool isDarkMode;

  const _CommentBubble(this.comment, this.isDarkMode);

  @override
  Widget build(BuildContext context) {
    final isAdmin = comment['sender'] == 'admin';
    
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isAdmin ? AppColors.primary : (isDarkMode ? const Color(0xFF2A2A2A) : Colors.grey.shade100),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isAdmin ? const Radius.circular(16) : Radius.zero,
            bottomRight: isAdmin ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isAdmin ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              comment['name'] ?? 'Unknown',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isAdmin ? Colors.white.withOpacity(0.9) : (isDarkMode ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              comment['message'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isAdmin ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(comment['time'] as DateTime),
              style: TextStyle(
                fontSize: 10,
                color: isAdmin ? Colors.white.withOpacity(0.6) : (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final diff = nowInRwanda().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return formatRwandaTime(dateTime, 'h:mm a');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. RIDERS MANAGEMENT TAB - Enhanced with Location & Assignment
// ═══════════════════════════════════════════════════════════════════════════
class RidersManagementTab extends StatefulWidget {
  const RidersManagementTab({super.key});

  @override
  State<RidersManagementTab> createState() => _RidersManagementTabState();
}

class _RidersManagementTabState extends State<RidersManagementTab> {
  List<Map<String, dynamic>> _riders = [];
  Map<String, int> _stats = {'online': 0, 'busy': 0, 'offline': 0, 'total': 0};
  bool _isLoading = true;
  bool _showMap = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      if (authProvider.token != null) {
        apiService.setAuthToken(authProvider.token!);
      }
      
      final service = AdminDashboardService(apiService);
      final ridersResponse = await service.getRiders();
      final ridersList = ridersResponse['riders'] as List<dynamic>? ?? [];
      
      // Extract stats from response if available
      final statsData = ridersResponse['stats'] as Map<String, dynamic>?;
      
      await context.read<AdminOrderProvider>().fetchOrders(silent: true);
      
      setState(() {
        _riders = ridersList.map((r) => r as Map<String, dynamic>).toList();
        if (statsData != null) {
          _stats = {
            'online': statsData['online'] ?? 0,
            'busy': statsData['busy'] ?? 0,
            'offline': statsData['offline'] ?? 0,
            'total': statsData['total'] ?? _riders.length,
          };
        } else {
          // Calculate stats from riders list
          _stats = {
            'online': _riders.where((r) => r['status'] == 'online').length,
            'busy': _riders.where((r) => r['status'] == 'busy').length,
            'offline': _riders.where((r) => r['status'] == 'offline').length,
            'total': _riders.length,
          };
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading riders: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredRiders {
    if (_selectedFilter == 'all') return _riders;
    return _riders.where((r) => r['status'] == _selectedFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    final unassignedOrders = context.watch<AdminOrderProvider>().orders.where((o) {
      final isAssignable = o.status == OrderStatus.confirmed || o.status == OrderStatus.ready;
      final hasRider = (o.riderId != null && o.riderId!.isNotEmpty);
      return isAssignable && !hasRider;
    }).toList();

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(unassignedCount: unassignedOrders.length),
            // Stats Cards
            _buildStatsRow(),
            // Filter Tabs
            _buildFilterTabs(),
            // Content
            Expanded(
              child: _showMap ? _buildMapView() : _buildListView(unassignedOrders),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required int unassignedCount}) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Riders',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_stats['online']} online • $unassignedCount unassigned orders',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildHeaderButton(
                icon: _showMap ? Icons.list_alt : Icons.map_outlined,
                color: const Color(0xFF00D9A5),
                onTap: () => setState(() => _showMap = !_showMap),
              ),
              const SizedBox(width: 12),
              _buildHeaderButton(
                icon: Icons.refresh,
                color: Colors.white.withOpacity(0.3),
                onTap: _loadData,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('Online', _stats['online'] ?? 0, const Color(0xFF00D9A5), Icons.check_circle)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Busy', _stats['busy'] ?? 0, const Color(0xFFFFB020), Icons.local_shipping)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('Offline', _stats['offline'] ?? 0, const Color(0xFF6B7280), Icons.do_not_disturb)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('All', 'all', _riders.length),
            const SizedBox(width: 8),
            _buildFilterChip('Online', 'online', _stats['online'] ?? 0),
            const SizedBox(width: 8),
            _buildFilterChip('Busy', 'busy', _stats['busy'] ?? 0),
            const SizedBox(width: 8),
            _buildFilterChip('Offline', 'offline', _stats['offline'] ?? 0),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.black : Colors.white,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    // Show rider locations with option to open in external maps
    final activeRiders = _riders.where((r) => r['status'] == 'online' || r['status'] == 'busy').toList();
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on, color: Color(0xFF10B981), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rider Locations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Tap to open in Google Maps',
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        
        if (activeRiders.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.location_off, size: 48, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  'No active riders',
                  style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          )
        else
          ...activeRiders.map((rider) => _buildRiderLocationCard(rider)).toList(),
        
        const SizedBox(height: 100),
      ],
    );
  }

  void _openInMaps(double? lat, double? lng, String name) async {
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available for this rider'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    // For now, just show a snackbar with the location
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening $name\'s location: $lat, $lng'),
        backgroundColor: const Color(0xFF10B981),
        action: SnackBarAction(
          label: 'COPY',
          textColor: Colors.white,
          onPressed: () {
            // Copy to clipboard
          },
        ),
      ),
    );
  }

  Widget _buildRiderLocationCard(Map<String, dynamic> rider) {
    final status = rider['status'] ?? 'offline';
    final lat = rider['latitude'] as double?;
    final lng = rider['longitude'] as double?;
    final hasLocation = lat != null && lng != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasLocation ? () => _openInMaps(lat, lng, rider['name'] ?? 'Rider') : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: status == 'online' 
                        ? const Color(0xFF10B981).withOpacity(0.2)
                        : const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (rider['name']?.toString().substring(0, 1).toUpperCase() ?? 'R'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: status == 'online' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            rider['name']?.toString() ?? 'Unknown',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: status == 'online' 
                                  ? const Color(0xFF10B981).withOpacity(0.2)
                                  : const Color(0xFFF59E0B).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: status == 'online' ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            hasLocation ? Icons.location_on : Icons.location_off,
                            size: 14,
                            color: hasLocation ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasLocation ? '$lat, $lng' : 'Location unavailable',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(hasLocation ? 0.5 : 0.3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Open in maps button
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasLocation 
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.open_in_new,
                    size: 20,
                    color: hasLocation ? const Color(0xFF10B981) : Colors.white.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListView(List<Order> unassignedOrders) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF10B981),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Unassigned Orders Section
          if (unassignedOrders.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Unassigned Orders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${unassignedOrders.length}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...unassignedOrders.map((order) => _UnassignedOrderCard(order, onAssign: (riderId) => _assignOrder(order, riderId))).toList(),
            const SizedBox(height: 24),
          ],
          
          // Riders List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedFilter == 'all' ? 'All Riders' : '${_selectedFilter[0].toUpperCase()}${_selectedFilter.substring(1)} Riders',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                '${_filteredRiders.length} riders',
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.4)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_filteredRiders.isEmpty)
            _buildEmptyState()
          else
            ..._filteredRiders.map((rider) => _buildRiderCard(rider)).toList(),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildRiderCard(Map<String, dynamic> rider) {
    final status = rider['status'] ?? 'offline';
    final Color statusColor = status == 'online' 
        ? const Color(0xFF10B981) 
        : status == 'busy' 
            ? const Color(0xFFF59E0B) 
            : const Color(0xFF6B7280);
    final currentOrder = rider['current_order'];
    final rating = rider['rating'] ?? 4.5;
    final deliveries = rider['deliveries'] ?? 0;

    return GestureDetector(
      onTap: () => _showRiderDetails(rider),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            // Avatar with status
            Stack(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      (rider['name']?.toString().substring(0, 1).toUpperCase() ?? 'R'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF111111), width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          rider['name']?.toString() ?? 'Unknown Rider',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      if (rider['is_verified'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 10, color: Color(0xFF10B981)),
                              SizedBox(width: 2),
                              Text('Verified', style: TextStyle(fontSize: 9, color: Color(0xFF10B981))),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 13, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Text(
                        rider['phone']?.toString() ?? 'No phone',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.star, size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text(
                        rating.toString(),
                        style: const TextStyle(fontSize: 12, color: Color(0xFFF59E0B), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.delivery_dining, size: 13, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 2),
                      Text(
                        '$deliveries',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                      ),
                    ],
                  ),
                  if (currentOrder != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_shipping, size: 11, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            'Order #$currentOrder',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.delivery_dining,
            size: 48,
            color: Colors.white.withOpacity(0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'No riders available',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.5)),
          ),
          const SizedBox(height: 8),
          Text(
            'Add riders to start managing deliveries',
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.3)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to add rider screen
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Rider'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _assignOrder(Order order, String riderId) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      if (authProvider.token != null) {
        apiService.setAuthToken(authProvider.token!);
      }
      
      final service = AdminDashboardService(apiService);
      await service.assignOrderToRider(
        orderId: order.id,
        riderId: riderId,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Order #${order.orderNumber} assigned • Rider notified'),
            ],
          ),
          backgroundColor: const Color(0xFF00D9A5),
          duration: const Duration(seconds: 3),
        ),
      );
      
      await _loadData(); // Refresh data
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to assign order: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _showRiderDetails(Map<String, dynamic> rider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RiderDetailsSheet(rider),
    );
  }
}

// Unassigned Order Card - Black Theme
class _UnassignedOrderCard extends StatelessWidget {
  final Order order;
  final Function(String) onAssign;

  const _UnassignedOrderCard(this.order, {required this.onAssign});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber, color: Color(0xFFEF4444), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber ?? order.id}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      order.customerName ?? 'Unknown',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAssignDialog(context),
                icon: const Icon(Icons.person_add, size: 14),
                label: const Text('Assign'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 13, color: Colors.white.withOpacity(0.4)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  order.deliveryInfo?.address ?? 'No address',
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RWF ${formatCurrency(order.total)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Assign Rider', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Text('Select a rider to assign this order', style: TextStyle(color: Colors.white.withOpacity(0.5))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.4))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onAssign('rider_id');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
            ),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}

// Rider Details Bottom Sheet - Black Theme
class _RiderDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> rider;

  const _RiderDetailsSheet(this.rider);

  @override
  Widget build(BuildContext context) {
    final status = rider['status'] ?? 'offline';
    final Color statusColor = status == 'online' 
        ? const Color(0xFF10B981)
        : status == 'busy' 
            ? const Color(0xFFF59E0B) 
            : const Color(0xFF6B7280);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header with Avatar
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          (rider['name']?.toString().substring(0, 1).toUpperCase() ?? 'R'),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  rider['name']?.toString() ?? 'Unknown',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              if (rider['is_verified'] == true)
                                const Icon(Icons.verified, color: Color(0xFF10B981), size: 20),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.white.withOpacity(0.4)),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Stats Row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(Icons.star, '${rider['rating'] ?? 4.5}', 'Rating', const Color(0xFFF59E0B)),
                      Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
                      _buildStatItem(Icons.delivery_dining, '${rider['deliveries'] ?? 0}', 'Trips', const Color(0xFF10B981)),
                      Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
                      _buildStatItem(Icons.attach_money, '${rider['earnings'] ?? 0}', 'Earned', const Color(0xFF8B5CF6)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Details Section
                _buildDetailRow('Phone', rider['phone']?.toString() ?? 'No phone', Icons.phone_outlined),
                _buildDetailRow('Vehicle', rider['vehicle']?.toString() ?? 'Not specified', Icons.two_wheeler),
                _buildDetailRow('License', rider['license_plate']?.toString() ?? 'Not provided', Icons.badge_outlined),
                
                if (rider['current_order'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Currently Delivering',
                                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5)),
                              ),
                              Text(
                                'Order #${rider['current_order']}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Location button
                if (rider['latitude'] != null && rider['longitude'] != null) ...[
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Open in external maps
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Opening ${rider['name']}'s location"),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_on),
                    label: const Text('Open Location in Maps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.message_outlined, size: 18),
                        label: const Text('Message'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.phone, size: 18),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF10B981)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. MONEY MANAGEMENT TAB
// ═══════════════════════════════════════════════════════════════════════════
class MoneyManagementTab extends StatefulWidget {
  const MoneyManagementTab({super.key});

  @override
  State<MoneyManagementTab> createState() => _MoneyManagementTabState();
}

class _MoneyManagementTabState extends State<MoneyManagementTab> {
  Map<String, dynamic>? _revenueReport;
  bool _isLoading = true;
  String _selectedPeriod = 'month';

  @override
  void initState() {
    super.initState();
    _loadRevenueData();
  }

  Future<void> _loadRevenueData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      if (authProvider.token != null) {
        apiService.setAuthToken(authProvider.token!);
      }
      
      final service = AdminDashboardService(apiService);
      final report = await service.getRevenueReport(period: _selectedPeriod);
      
      setState(() {
        _revenueReport = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading revenue data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading financial data...',
              style: TextStyle(color: AppColors.getTextSecondary(context)),
            ),
          ],
        ),
      );
    }

    // Extract data from report
    final summary = _revenueReport?['summary'] as Map<String, dynamic>? ?? {};
    final totalRevenue = (summary['total_revenue'] ?? 0).toDouble();
    final platformCommission = (summary['platform_commission'] ?? 0).toDouble();
    final deliveryFees = (summary['driver_payouts'] ?? 0).toDouble();
    final vendorPayouts = (summary['vendor_payouts'] ?? 0).toDouble();
    final totalOrders = summary['total_orders'] ?? 0;

    return Container(
      color: AppColors.getBackground(context),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRevenueData,
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Revenue',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.getTextPrimary(context),
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Financial overview',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Period Selector
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _PeriodChip(
                        'Today',
                        'day',
                        _selectedPeriod,
                        (p) {
                          setState(() => _selectedPeriod = p);
                          _loadRevenueData();
                        },
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        'Week',
                        'week',
                        _selectedPeriod,
                        (p) {
                          setState(() => _selectedPeriod = p);
                          _loadRevenueData();
                        },
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        'Month',
                        'month',
                        _selectedPeriod,
                        (p) {
                          setState(() => _selectedPeriod = p);
                          _loadRevenueData();
                        },
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        'Year',
                        'year',
                        _selectedPeriod,
                        (p) {
                          setState(() => _selectedPeriod = p);
                          _loadRevenueData();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              
              // Main Revenue Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildMainRevenueCard(totalRevenue, totalOrders, context),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              
              // Quick Stats Grid
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  delegate: SliverChildListDelegate([
                    _StatCard(
                      'Orders',
                      '$totalOrders',
                      Icons.shopping_bag,
                      AppColors.info,
                    ),
                    _StatCard(
                      'Avg Order Value',
                      'RWF ${formatCurrency(totalOrders > 0 ? totalRevenue / totalOrders : 0)}',
                      Icons.trending_up,
                      AppColors.primary,
                    ),
                  ]),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              
              // Revenue Breakdown
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revenue Breakdown',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildBreakdownCard(
                        'Platform Fee',
                        platformCommission,
                        platformCommission > 0 
                          ? 'Commission from orders'
                          : 'No commission earned yet',
                        Icons.account_balance,
                        AppColors.primary,
                        context,
                      ),
                      const SizedBox(height: 12),
                      _buildBreakdownCard(
                        'Delivery Fees',
                        deliveryFees,
                        deliveryFees > 0 
                          ? 'Rider payouts'
                          : 'No delivery fees yet',
                        Icons.delivery_dining,
                        AppColors.info,
                        context,
                      ),
                      const SizedBox(height: 12),
                      _buildBreakdownCard(
                        'Vendor Payouts',
                        vendorPayouts,
                        vendorPayouts > 0 
                          ? 'Payments to vendors'
                          : 'No vendor payouts yet',
                        Icons.store,
                        AppColors.success,
                        context,
                      ),
                      const SizedBox(height: 12),
                      _buildBreakdownCard(
                        'Net Platform Earnings',
                        platformCommission - deliveryFees - vendorPayouts,
                        'Platform profit',
                        Icons.trending_up,
                        AppColors.warning,
                        context,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMainRevenueCard(double amount, int orders, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.success,
            AppColors.success.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
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
                _selectedPeriod.toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '$orders',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Total Revenue',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'RWF ${formatCurrency(amount)}',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                orders > 0 ? 'Avg: RWF ${formatCurrency(amount / orders)} per order' : 'No orders yet',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildBreakdownCard(String label, double amount, String subtitle, IconData icon, Color color, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'RWF ${formatCurrency(amount)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// Period Chip Widget
class _PeriodChip extends StatelessWidget {
  final String label;
  final String value;
  final String selectedValue;
  final Function(String) onTap;

  const _PeriodChip(this.label, this.value, this.selectedValue, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selectedValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.getBorder(context),
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. ISSUES & ALERTS TAB
// ═══════════════════════════════════════════════════════════════════════════
class IssuesAlertsTab extends StatefulWidget {
  const IssuesAlertsTab({super.key});

  @override
  State<IssuesAlertsTab> createState() => _IssuesAlertsTabState();
}

class _IssuesAlertsTabState extends State<IssuesAlertsTab> {
  Map<String, dynamic>? _ticketsData;
  bool _isLoading = true;
  String _selectedFilter = 'open';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final apiService = ApiService();
      if (authProvider.token != null) {
        apiService.setAuthToken(authProvider.token!);
      }
      
      final service = AdminDashboardService(apiService);
      final data = await service.getSupportTickets(
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );
      
      setState(() {
        _ticketsData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tickets: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        color: AppColors.getBackground(context),
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Issues & Feedback',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.getTextPrimary(context),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Customer support and system alerts',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Filter Chips
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip('All', 'all', _selectedFilter, (f) {
                        setState(() => _selectedFilter = f);
                        _loadTickets();
                      }),
                      const SizedBox(width: 8),
                      _FilterChip('Open', 'open', _selectedFilter, (f) {
                        setState(() => _selectedFilter = f);
                        _loadTickets();
                      }),
                      const SizedBox(width: 8),
                      _FilterChip('In Progress', 'in_progress', _selectedFilter, (f) {
                        setState(() => _selectedFilter = f);
                        _loadTickets();
                      }),
                      const SizedBox(width: 8),
                      _FilterChip('Resolved', 'resolved', _selectedFilter, (f) {
                        setState(() => _selectedFilter = f);
                        _loadTickets();
                      }),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Stats Summary
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildTicketStats(),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // Tickets List
            if (_isLoading)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              )
            else if ((_ticketsData?['tickets'] as List?)?.isEmpty ?? true)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: AppColors.getTextSecondary(context),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tickets found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All systems operational',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tickets = _ticketsData?['tickets'] as List? ?? [];
                      if (index >= tickets.length) return null;
                      
                      final ticket = tickets[index] as Map<String, dynamic>;
                      return _buildTicketCard(ticket, context);
                    },
                    childCount: ((_ticketsData?['tickets'] as List?)?.length ?? 0),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketStats() {
    final counts = _ticketsData?['counts'] as Map<String, dynamic>? ?? {};
    final open = counts['open'] ?? 0;
    final inProgress = counts['in_progress'] ?? 0;
    final resolved = counts['resolved'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorder(context)),
            ),
            child: Column(
              children: [
                Text(
                  '$open',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorder(context)),
            ),
            child: Column(
              children: [
                Text(
                  '$inProgress',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'In Progress',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.getBorder(context)),
            ),
            child: Column(
              children: [
                Text(
                  '$resolved',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Resolved',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, BuildContext context) {
    final category = ticket['category'] as String? ?? 'general';
    final status = ticket['status'] as String? ?? 'open';
    final priority = ticket['priority'] as String? ?? 'medium';
    final subject = ticket['subject'] as String? ?? 'No subject';
    final createdAt = ticket['created_at'] as String?;

    Color getPriorityColor() {
      switch (priority) {
        case 'urgent':
          return AppColors.danger;
        case 'high':
          return AppColors.warning;
        case 'medium':
          return AppColors.info;
        default:
          return AppColors.getTextSecondary(context);
      }
    }

    Color getStatusColor() {
      switch (status) {
        case 'open':
          return AppColors.danger;
        case 'in_progress':
          return AppColors.warning;
        case 'resolved':
          return AppColors.success;
        default:
          return AppColors.getTextSecondary(context);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  subject,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.getTextPrimary(context),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: getStatusColor(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: getPriorityColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  priority,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: getPriorityColor(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ),
              if (createdAt != null)
                Text(
                  _formatDate(createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = parseServerTime(dateString);
      final diff = nowInRwanda().difference(date);
      
      if (diff.inHours < 1) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return date.toString().split(' ')[0];
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final Function(String) onTap;

  const _FilterChip(this.label, this.value, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.getSurface(context),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.getBorder(context),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.getTextPrimary(context),
          ),
        ),
      ),
    );
  }
}

// Menu Section Header
class _MenuSection extends StatelessWidget {
  final String title;
  final bool isDarkMode;

  const _MenuSection({
    required this.title,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDarkMode ? Colors.white70 : Colors.black54,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// Menu Item Button
class _MenuItemButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _MenuItemButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  State<_MenuItemButton> createState() => _MenuItemButtonState();
}

class _MenuItemButtonState extends State<_MenuItemButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered
              ? const Color(0xFF4CAF50).withOpacity(0.1)
              : (context.watch<ThemeProvider>().isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered
                ? const Color(0xFF4CAF50).withOpacity(0.3)
                : (context.watch<ThemeProvider>().isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.06)),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.icon,
                    color: const Color(0xFF4CAF50),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDarkMode ? Colors.grey : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
