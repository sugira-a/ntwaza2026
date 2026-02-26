// lib/screens/admin/admin_main_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_order_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';
import 'admin_dashboard_home.dart';
import 'admin_orders_screen.dart';
import 'admin_finance_screen.dart';
import 'admin_performance_screen.dart';
import 'admin_profile_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _selectedIndex = 0;
  static const int _pollSeconds = 30;  // Increased from 10 for cost savings

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.token == null || authProvider.user == null) {
      if (mounted) context.go('/login');
      return;
    }

    try {
      final notifProvider = context.read<NotificationProvider>();
      await notifProvider.initialize(pollingInterval: _pollSeconds);

      final notifService = NotificationService();
      await notifService.initialize();

      await context.read<AdminOrderProvider>().initialize(
            autoRefreshSeconds: _pollSeconds,
          );
    } catch (e) {
      debugPrint('❌ Admin init error: $e');
      if (e.toString().contains('401') && mounted) {
        context.read<AuthProvider>().logout();
        context.go('/login');
      }
    }
  }

  @override
  void dispose() {
    try {
      context.read<NotificationProvider>().stopPolling();
      context.read<AdminOrderProvider>().stopAutoRefresh();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isAuthenticated || authProvider.token == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (!authProvider.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Admin access only', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final screens = const [
      AdminDashboardHome(),
      AdminOrdersScreen(),
      AdminFinanceScreen(),
      AdminPerformanceScreen(),
      AdminProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
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
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet_rounded),
                label: 'Finance',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Performance',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
